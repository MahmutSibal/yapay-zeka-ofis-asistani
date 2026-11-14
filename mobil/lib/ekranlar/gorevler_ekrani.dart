import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';
import 'toplanti_ekrani.dart';

class GorevlerEkrani extends ConsumerStatefulWidget {
  const GorevlerEkrani({super.key});

  @override
  ConsumerState<GorevlerEkrani> createState() => _GorevlerEkraniState();
}

class _GorevlerEkraniState extends ConsumerState<GorevlerEkrani> {
  String _durum = 'acik';
  final _isleniyor = <String>{};

  String get _yol => 'gorevler?durum=$_durum';

  Future<void> _degistir(Json g) async {
    final kid = g['kid'] as String;
    setState(() => _isleniyor.add(kid));
    try {
      await ref.read(apiProvider).gorevDurum(kid, g['durum'] == 'tamam' ? 'acik' : 'tamam');
      ref.invalidate(listeProvider(_yol));
      ref.invalidate(panelProvider);
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _isleniyor.remove(kid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(listeProvider(_yol));
    return Scaffold(
      appBar: AppBar(title: const Text('Görevler')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ToplantiEkrani())),
        icon: const Icon(Icons.auto_awesome_rounded),
        label: const Text('Toplantı notundan'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'acik', label: Text('Açık'), icon: Icon(Icons.radio_button_unchecked)),
                  ButtonSegment(value: 'tamam', label: Text('Tamamlanan'), icon: Icon(Icons.check_circle_outline)),
                ],
                selected: {_durum},
                onSelectionChanged: (s) => setState(() => _durum = s.first),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(listeProvider(_yol).future),
              child: AsyncGorunum<List<Json>>(
                deger: liste,
                yenile: () => ref.invalidate(listeProvider(_yol)),
                veri: (ogeler) => ogeler.isEmpty
                    ? BosDurum(ikon: Icons.task_alt_rounded, mesaj: _durum == 'acik' ? 'Açık görev yok 🎉' : 'Henüz tamamlanan görev yok.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount: ogeler.length,
                        itemBuilder: (_, i) =>
                            _GorevKarti(g: ogeler[i], isleniyor: _isleniyor.contains(ogeler[i]['kid']), onDegistir: () => _degistir(ogeler[i])),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GorevKarti extends StatelessWidget {
  const _GorevKarti({required this.g, required this.isleniyor, required this.onDegistir});
  final Json g;
  final bool isleniyor;
  final VoidCallback onDegistir;

  @override
  Widget build(BuildContext context) {
    final tamam = g['durum'] == 'tamam';
    final eksik = ((g['eksik_alanlar'] as List?) ?? const []).cast<Object?>();
    final cs = Theme.of(context).colorScheme;
    const kirmizi = Color(0xFFEF4444);

    return OgeKart(
      vurguRengi: eksik.isNotEmpty && !tamam ? const Color(0xFFF59E0B) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          isleniyor
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)),
                )
              : IconButton(
                  onPressed: onDegistir,
                  icon: Icon(tamam ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded, color: tamam ? Colors.green : cs.outline, size: 28),
                ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                Text(
                  (g['gorev'] ?? '').toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    decoration: tamam ? TextDecoration.lineThrough : null,
                    color: tamam ? cs.outline : null,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    g['sorumlu'] != null ? Etiket('👤 ${g['sorumlu']}', renk: Tema.tohum) : const Etiket('Sorumlu EKSİK', renk: kirmizi),
                    g['tarih'] != null
                        ? Etiket('📅 ${tarihYaz(g['tarih'], saat: false)}', renk: const Color(0xFF0EA5E9))
                        : const Etiket('Tarih EKSİK', renk: kirmizi),
                  ],
                ),
                const SizedBox(height: 6),
                Text((g['toplanti_basligi'] ?? '').toString(), style: TextStyle(fontSize: 12, color: cs.outline)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
