import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';

/// Modül 3: yorumlar ve duygu analizi
class YorumlarEkrani extends ConsumerStatefulWidget {
  const YorumlarEkrani({super.key});

  @override
  ConsumerState<YorumlarEkrani> createState() => _YorumlarEkraniState();
}

class _YorumlarEkraniState extends ConsumerState<YorumlarEkrani> {
  String _duygu = '';
  String get _yol => _duygu.isEmpty ? 'yorumlar' : 'yorumlar?duygu=$_duygu';

  Future<void> _ekle() async {
    final metin = TextEditingController();
    final musteri = TextEditingController();
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Yeni yorum', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextField(
              controller: musteri,
              decoration: const InputDecoration(labelText: 'Müşteri (isteğe bağlı)', prefixIcon: Icon(Icons.person_outline)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: metin,
              autofocus: true,
              minLines: 4,
              maxLines: 8,
              decoration: const InputDecoration(labelText: 'Yorum metni', alignLabelWithHint: true),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Kaydet ve analiz et')),
          ],
        ),
      ),
    );
    if (tamam != true || !mounted) return;
    try {
      await ref.read(apiProvider).yorumEkle(metin.text.trim(), musteri: musteri.text.trim().isEmpty ? null : musteri.text.trim());
      if (!mounted) return;
      bildir(context, 'Yorum kaydedildi, duygu analizi birkaç saniye içinde tamamlanacak.');
      ref.invalidate(listeProvider(_yol));
      // Analiz arka planda sürüyor; kısa süre sonra listeyi tazele
      Future.delayed(const Duration(seconds: 8), () => ref.invalidate(listeProvider(_yol)));
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(listeProvider(_yol));
    return Scaffold(
      appBar: AppBar(title: const Text('Yorumlar')),
      floatingActionButton: FloatingActionButton.extended(onPressed: _ekle, icon: const Icon(Icons.add_comment_rounded), label: const Text('Yorum ekle')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in {'': 'Tümü', ...duyguAdlari}.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(f.value), selected: _duygu == f.key, onSelected: (_) => setState(() => _duygu = f.key)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(listeProvider(_yol).future),
              child: AsyncGorunum<List<Json>>(
                deger: liste,
                yenile: () => ref.invalidate(listeProvider(_yol)),
                veri: (ogeler) => ogeler.isEmpty
                    ? const BosDurum(ikon: Icons.forum_outlined, mesaj: 'Henüz yorum yok.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: ogeler.length,
                        itemBuilder: (_, i) {
                          final y = ogeler[i];
                          final d = y['duygu'] as String?;
                          final renk = duyguRengi(d);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(switch (d) {
                                          'olumlu' => Icons.sentiment_satisfied_alt_rounded,
                                          'olumsuz' => Icons.sentiment_very_dissatisfied_rounded,
                                          'notr' => Icons.sentiment_neutral_rounded,
                                          _ => Icons.hourglass_top_rounded,
                                        }, color: renk),
                                        const SizedBox(width: 8),
                                        Etiket(duyguAdlari[d] ?? (y['analiz_durumu'] == 'hata' ? 'Belirsiz' : 'Analiz ediliyor'), renk: renk),
                                        const Spacer(),
                                        Text(tarihYaz(y['olusturma']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    Text((y['metin'] ?? '').toString(), style: const TextStyle(height: 1.4)),
                                    if (y['gerekce'] != null) ...[
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(color: renk.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12)),
                                        child: Text('💡 ${y['gerekce']}', style: TextStyle(color: renk)),
                                      ),
                                    ],
                                    if (y['musteri'] != null || y['ekip_bildirildi'] == true) ...[
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 6,
                                        children: [
                                          if (y['musteri'] != null) Etiket('👤 ${y['musteri']}'),
                                          if (y['ekip_bildirildi'] == true) const Etiket('Ekibe bildirildi', renk: Color(0xFF0EA5E9)),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
