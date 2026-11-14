import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Yükleniyor / hata / veri durumlarını tek yerde gösterir.
class AsyncGorunum<T> extends StatelessWidget {
  const AsyncGorunum({super.key, required this.deger, required this.veri, required this.yenile});

  final AsyncValue<T> deger;
  final Widget Function(T veri) veri;
  final VoidCallback yenile;

  @override
  Widget build(BuildContext context) {
    return deger.when(
      skipLoadingOnRefresh: true,
      data: veri,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => HataGorunumu(mesaj: e.toString(), yenile: yenile),
    );
  }
}

class HataGorunumu extends StatelessWidget {
  const HataGorunumu({super.key, required this.mesaj, required this.yenile});
  final String mesaj;
  final VoidCallback yenile;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            Text(mesaj, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.tonalIcon(onPressed: yenile, icon: const Icon(Icons.refresh), label: const Text('Tekrar dene')),
          ],
        ),
      ),
    );
  }
}

class BosDurum extends StatelessWidget {
  const BosDurum({super.key, required this.ikon, required this.mesaj});
  final IconData ikon;
  final String mesaj;

  @override
  Widget build(BuildContext context) {
    // RefreshIndicator'ın boş listede de çalışması için kaydırılabilir
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 120),
        Icon(ikon, size: 56, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Text(
          mesaj,
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
      ],
    );
  }
}

/// Küçük renkli etiket
class Etiket extends StatelessWidget {
  const Etiket(this.metin, {super.key, this.renk});
  final String metin;
  final Color? renk;

  @override
  Widget build(BuildContext context) {
    final r = renk ?? Theme.of(context).colorScheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: r.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(
        metin,
        style: TextStyle(color: r, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}

String tarihYaz(Object? iso, {bool saat = true}) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso.toString());
  if (d == null) return iso.toString();
  return DateFormat(saat ? 'd MMM yyyy HH:mm' : 'd MMM yyyy', 'tr').format(d.toLocal());
}

void bildir(BuildContext context, String mesaj, {bool hata = false}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(mesaj), backgroundColor: hata ? Theme.of(context).colorScheme.error : null));
}

const kategoriAdlari = {'is': 'İş', 'fatura': 'Fatura', 'kisisel': 'Kişisel', 'bulten': 'Bülten', 'diger': 'Diğer'};
const duyguAdlari = {'olumlu': 'Olumlu', 'olumsuz': 'Olumsuz', 'notr': 'Nötr'};

Color duyguRengi(String? d) => switch (d) {
  'olumlu' => Colors.green.shade700,
  'olumsuz' => Colors.red.shade700,
  'notr' => Colors.blueGrey,
  _ => Colors.orange.shade800,
};
