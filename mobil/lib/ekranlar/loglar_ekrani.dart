import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

class LoglarEkrani extends ConsumerWidget {
  const LoglarEkrani({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const yol = 'loglar';
    final liste = ref.watch(listeProvider(yol));
    return Scaffold(
      appBar: AppBar(title: const Text('Hata Kayıtları')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(listeProvider(yol).future),
        child: AsyncGorunum<List<Json>>(
          deger: liste,
          yenile: () => ref.invalidate(listeProvider(yol)),
          veri: (ogeler) => ogeler.isEmpty
              ? const BosDurum(ikon: Icons.verified_rounded, mesaj: 'Hata yok, her şey yolunda.')
              : ListView.builder(
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: ogeler.length,
                  itemBuilder: (_, i) {
                    final l = ogeler[i];
                    return OgeKart(
                      vurguRengi: const Color(0xFFEF4444),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text((l['akis'] ?? '').toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
                              ),
                              Text(tarihYaz(l['tarih']), style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
                            ],
                          ),
                          if ((l['dugum'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 4), Etiket(l['dugum'].toString(), renk: Tema.tohum)],
                          const SizedBox(height: 8),
                          SelectableText(
                            (l['hata'] ?? '').toString(),
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontFamily: 'monospace', fontSize: 13),
                          ),
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
