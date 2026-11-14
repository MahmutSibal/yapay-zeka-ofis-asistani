import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

class EpostalarEkrani extends ConsumerStatefulWidget {
  const EpostalarEkrani({super.key});

  @override
  ConsumerState<EpostalarEkrani> createState() => _EpostalarEkraniState();
}

class _EpostalarEkraniState extends ConsumerState<EpostalarEkrani> {
  String _filtre = ''; // '' | 'acil' | kategori

  String get _yol => switch (_filtre) {
    '' => 'epostalar',
    'acil' => 'epostalar?acil=true',
    final k => 'epostalar?kategori=$k',
  };

  @override
  Widget build(BuildContext context) {
    final liste = ref.watch(listeProvider(_yol));
    final filtreler = {'': 'Tümü', 'acil': 'Acil', ...kategoriAdlari};

    return Scaffold(
      appBar: AppBar(title: const Text('E-postalar')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in filtreler.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(label: Text(f.value), selected: _filtre == f.key, onSelected: (_) => setState(() => _filtre = f.key)),
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
                    ? const BosDurum(ikon: Icons.inbox_rounded, mesaj: 'Bu filtrede özetlenmiş e-posta yok.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(top: 4, bottom: 24),
                        itemCount: ogeler.length,
                        itemBuilder: (_, i) => _EpostaKarti(e: ogeler[i]),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EpostaKarti extends StatelessWidget {
  const _EpostaKarti({required this.e});
  final Json e;

  @override
  Widget build(BuildContext context) {
    final acil = e['acil'] == true;
    final gonderen = (e['gonderen'] ?? '').toString();
    final ad = gonderen.replaceAll(RegExp(r'<.*>'), '').replaceAll('"', '').trim();
    final cs = Theme.of(context).colorScheme;

    return OgeKart(
      vurguRengi: acil ? const Color(0xFFEF4444) : null,
      onTap: () => _detay(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  ad.isEmpty ? '?' : ad.characters.first.toUpperCase(),
                  style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ad.isEmpty ? gonderen : ad,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(tarihYaz(e['alinma']), style: TextStyle(fontSize: 12, color: cs.outline)),
                  ],
                ),
              ),
              if (acil) const Etiket('ACİL', renk: Color(0xFFEF4444)),
              const SizedBox(width: 6),
              Etiket(kategoriAdlari[e['kategori']] ?? 'Diğer'),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            (e['konu'] ?? '').toString(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            (e['ozet'] ?? '').toString(),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
          ),
        ],
      ),
    );
  }

  void _detay(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text((e['konu'] ?? '').toString(), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text('${e['gonderen']}\n${tarihYaz(e['alinma'])}', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 16),
            Row(
              children: [
                const IkonRozet(Icons.auto_awesome_rounded, renk: Tema.tohum, boyut: 28),
                const SizedBox(width: 8),
                Text('Yapay zekâ özeti', style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            Text((e['ozet'] ?? '').toString(), style: const TextStyle(height: 1.45, fontSize: 15)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                Etiket(kategoriAdlari[e['kategori']] ?? 'Diğer'),
                Etiket(e['acil'] == true ? 'Acil' : 'Acil değil', renk: e['acil'] == true ? const Color(0xFFEF4444) : Colors.green),
                if (e['bildirim_gonderildi'] == true) const Etiket('Telegram bildirimi gönderildi', renk: Color(0xFF0EA5E9)),
              ],
            ),
            if ((e['gerekce'] ?? '').toString().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Gerekçe: ${e['gerekce']}', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),
    );
  }
}
