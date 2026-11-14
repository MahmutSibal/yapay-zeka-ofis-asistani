import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

/// Modül 6: onaylı sosyal medya içeriği. Onay vermeden hiçbir paylaşım yayınlanmaz.
class IcerikEkrani extends ConsumerStatefulWidget {
  const IcerikEkrani({super.key});

  @override
  ConsumerState<IcerikEkrani> createState() => _IcerikEkraniState();
}

class _IcerikEkraniState extends ConsumerState<IcerikEkrani> {
  static const _sekmeler = [('onay_bekliyor', 'Onay'), ('sirada', 'Sırada'), ('yayinlandi', 'Yayında'), ('reddedildi_son', 'Reddedilen')];

  void _tazele() {
    for (final s in _sekmeler) {
      ref.invalidate(listeProvider('icerikler?durum=${s.$1}'));
    }
    ref.invalidate(panelProvider);
  }

  Future<void> _konuEkle() async {
    final konu = TextEditingController();
    var platform = 'linkedin';
    final tamam = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (c) => StatefulBuilder(
        builder: (c, ss) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(c).bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Yeni içerik konusu', style: Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextField(
                controller: konu,
                autofocus: true,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Konu', hintText: 'Ör. Küçük işletmeler için yapay zekâ ile zaman tasarrufu'),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'linkedin', label: Text('LinkedIn')),
                  ButtonSegment(value: 'x', label: Text('X')),
                ],
                selected: {platform},
                onSelectionChanged: (s) => ss(() => platform = s.first),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sıraya ekle')),
            ],
          ),
        ),
      ),
    );
    if (tamam != true || !mounted) return;
    try {
      await ref.read(apiProvider).konuEkle(konu.text.trim(), platform: platform);
      if (mounted) bildir(context, 'Konu sıraya eklendi. Taslak her gün 10:00\'da hazırlanır.');
      _tazele();
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: _sekmeler.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('İçerik Onayı'),
          actions: [
            IconButton(
              tooltip: 'Sıradaki konu için şimdi taslak üret',
              icon: const Icon(Icons.play_circle_outline_rounded),
              onPressed: () async {
                try {
                  await ref.read(apiProvider).icerikBaslat();
                  if (context.mounted) bildir(context, 'Taslak hazırlanıyor; birazdan Onay sekmesinde görünecek.');
                } on ApiHata catch (e) {
                  if (context.mounted) bildir(context, e.mesaj, hata: true);
                }
              },
            ),
          ],
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [for (final s in _sekmeler) Tab(text: s.$2)],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(onPressed: _konuEkle, icon: const Icon(Icons.add_rounded), label: const Text('Konu ekle')),
        body: TabBarView(
          children: [for (final s in _sekmeler) _IcerikListesi(durum: s.$1, tazele: _tazele)],
        ),
      ),
    );
  }
}

class _IcerikListesi extends ConsumerWidget {
  const _IcerikListesi({required this.durum, required this.tazele});
  final String durum;
  final VoidCallback tazele;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final yol = 'icerikler?durum=$durum';
    final liste = ref.watch(listeProvider(yol));
    return RefreshIndicator(
      onRefresh: () => ref.refresh(listeProvider(yol).future),
      child: AsyncGorunum<List<Json>>(
        deger: liste,
        yenile: () => ref.invalidate(listeProvider(yol)),
        veri: (ogeler) => ogeler.isEmpty
            ? BosDurum(ikon: Icons.campaign_outlined, mesaj: durum == 'onay_bekliyor' ? 'Onay bekleyen taslak yok.' : 'Bu bölüm boş.')
            : ListView.builder(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: ogeler.length,
                itemBuilder: (_, i) => durum == 'onay_bekliyor' ? _OnayKarti(c: ogeler[i], tazele: tazele) : _OzetKart(c: ogeler[i]),
              ),
      ),
    );
  }
}

class _OzetKart extends StatelessWidget {
  const _OzetKart({required this.c});
  final Json c;

  @override
  Widget build(BuildContext context) {
    return OgeKart(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Etiket((c['platform'] ?? 'linkedin').toString().toUpperCase(), renk: const Color(0xFF0A66C2)),
              const Spacer(),
              Text(tarihYaz(c['yayin_tarihi'] ?? c['guncelleme']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
            ],
          ),
          const SizedBox(height: 8),
          Text((c['konu'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
          if ((c['metin'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              c['metin'].toString(),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

class _OnayKarti extends ConsumerStatefulWidget {
  const _OnayKarti({required this.c, required this.tazele});
  final Json c;
  final VoidCallback tazele;

  @override
  ConsumerState<_OnayKarti> createState() => _OnayKartiState();
}

class _OnayKartiState extends ConsumerState<_OnayKarti> {
  bool _gorsel = false;
  bool _bekliyor = false;

  Future<void> _karar(bool onay) async {
    var geriBildirim = '';
    if (!onay) {
      final t = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: const Text('Neyi değiştirelim?'),
          content: TextField(
            controller: t,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(hintText: 'Ör. Daha kısa olsun, somut bir örnek ekle, emoji kullanma'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Reddet ve yeniden yazdır')),
          ],
        ),
      );
      if (ok != true) return;
      geriBildirim = t.text.trim();
    }
    setState(() => _bekliyor = true);
    try {
      final r = await ref.read(apiProvider).icerikKarar(widget.c['kid'] as String, onay: onay, geriBildirim: geriBildirim, gorselIste: _gorsel);
      if (mounted) bildir(context, (r['mesaj'] ?? 'Kaydedildi').toString());
      widget.tazele();
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final hashtagler = ((c['hashtagler'] as List?) ?? const []).join(' ');
    final tur = c['tur'] ?? 1;
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              decoration: const BoxDecoration(gradient: Tema.degrade),
              child: Row(
                children: [
                  const Icon(Icons.edit_note_rounded, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (c['konu'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10)),
                    child: Text(
                      'Tur $tur/3',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SelectableText((c['metin'] ?? '').toString(), style: const TextStyle(height: 1.45, fontSize: 15)),
                  if (hashtagler.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    Text(
                      hashtagler,
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w600),
                    ),
                  ],
                  if ((c['gorsel_istemi'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: cs.surfaceContainerHighest.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.image_outlined, size: 18, color: cs.outline),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Görsel istemi: ${c['gorsel_istemi']}', style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _gorsel,
                      onChanged: _bekliyor ? null : (v) => setState(() => _gorsel = v),
                      title: const Text('Görselle paylaş'),
                      subtitle: const Text('İsteğe bağlı görsel üretim servisi gerekir'),
                    ),
                  ],
                  const SizedBox(height: 8),
                  if (_bekliyor)
                    const Center(
                      child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                    )
                  else
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(onPressed: () => _karar(false), icon: const Icon(Icons.close_rounded), label: const Text('Reddet')),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _karar(true),
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Onayla'),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
