import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

/// Modül 4: haftalık bülten arşivi
class BultenlerEkrani extends ConsumerWidget {
  const BultenlerEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const yol = 'bultenler';
    final liste = ref.watch(listeProvider(yol));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bültenler'),
        actions: [
          IconButton(
            tooltip: 'Bu haftanın bültenini şimdi oluştur',
            icon: const Icon(Icons.play_circle_outline_rounded),
            onPressed: () async {
              try {
                await ref.read(apiProvider).bultenBaslat();
                if (context.mounted) bildir(context, 'Bülten hazırlanıyor; birkaç dakika içinde e-postana gelecek.');
              } on ApiHata catch (e) {
                if (context.mounted) bildir(context, e.mesaj, hata: true);
              }
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(listeProvider(yol).future),
        child: AsyncGorunum<List<Json>>(
          deger: liste,
          yenile: () => ref.invalidate(listeProvider(yol)),
          veri: (ogeler) => ogeler.isEmpty
              ? const BosDurum(ikon: Icons.newspaper_rounded, mesaj: 'Henüz bülten yok. İlk bülten Pazartesi 09:00\'da gönderilir.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: ogeler.length,
                  itemBuilder: (_, i) {
                    final b = ogeler[i];
                    final bos = b['durum'] == 'bos';
                    final haberSayisi = ((b['haberler'] as List?) ?? const []).length;
                    return OgeKart(
                      onTap: bos ? null : () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => _BultenDetay(b: b))),
                      child: Row(
                        children: [
                          IkonRozet(bos ? Icons.inbox_rounded : Icons.newspaper_rounded, renk: bos ? Colors.grey : const Color(0xFFF59E0B), boyut: 44),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  bos ? 'Haber bulunamadı' : (b['konu_basligi'] ?? '').toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${b['hafta']} · ${bos ? 'gönderilmedi' : '$haberSayisi haber'}',
                                  style: TextStyle(color: Theme.of(context).colorScheme.outline),
                                ),
                              ],
                            ),
                          ),
                          if (!bos) Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}

class _BultenDetay extends StatelessWidget {
  const _BultenDetay({required this.b});
  final Json b;

  @override
  Widget build(BuildContext context) {
    final haberler = ((b['haberler'] as List?) ?? const []).cast<Map>();
    return Scaffold(
      appBar: AppBar(title: Text(b['hafta'].toString())),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(gradient: Tema.degrade, borderRadius: BorderRadius.circular(24)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (b['konu_basligi'] ?? '').toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  Text((b['giris'] ?? '').toString(), style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.45)),
                ],
              ),
            ),
          ),
          for (final (i, h) in haberler.indexed)
            OgeKart(
              onTap: () => launchUrl(Uri.parse(h['link'].toString()), mode: LaunchMode.externalApplication),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${h['kaynak']} · ${tarihYaz(h['yayin_tarihi'], saat: false)}',
                          style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                        ),
                      ),
                      Icon(Icons.open_in_new_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(h['baslik'].toString(), style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(h['ozet'].toString(), style: const TextStyle(height: 1.4)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
