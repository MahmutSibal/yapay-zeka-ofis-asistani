import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ayarlar.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

/// Açılışta sunucu aranırken gösterilen ekran
class BaglaniyorEkrani extends StatelessWidget {
  const BaglaniyorEkrani({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const IkonRozet(Icons.auto_awesome_rounded, renk: Tema.tohum, boyut: 76),
            const SizedBox(height: 24),
            Text('Ofis Asistanı', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Sunucu aranıyor…', style: TextStyle(color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 24),
            const SizedBox(width: 160, child: LinearProgressIndicator(borderRadius: BorderRadius.all(Radius.circular(4)))),
          ],
        ),
      ),
    );
  }
}

/// Sunucu bilgisi: otomatik bulunan adres, yeniden arama ve (gerekirse) elle adres.
/// [hata] doluysa otomatik bağlantı başarısız olmuştur.
class AyarlarEkrani extends ConsumerStatefulWidget {
  const AyarlarEkrani({super.key, this.hata});
  final Object? hata;

  @override
  ConsumerState<AyarlarEkrani> createState() => _AyarlarEkraniState();
}

class _AyarlarEkraniState extends ConsumerState<AyarlarEkrani> {
  final _adres = TextEditingController(text: derlemeSunucusu.isNotEmpty ? derlemeSunucusu : 'http://192.168.1.');
  bool _bekliyor = false;

  @override
  void dispose() {
    _adres.dispose();
    super.dispose();
  }

  Future<void> _elle() async {
    setState(() => _bekliyor = true);
    final ok = await ref.read(sunucuProvider.notifier).elleBaglan(_adres.text);
    if (!mounted) return;
    setState(() => _bekliyor = false);
    if (ok) {
      ref.invalidate(panelProvider);
      bildir(context, 'Bağlandı: ${_adres.text.trim()}');
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } else {
      bildir(context, 'Bu adreste Ofis Asistanı n8n sunucusu bulunamadı.', hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sunucu = ref.watch(sunucuProvider);
    final hataVar = widget.hata != null;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: hataVar ? null : AppBar(title: const Text('Sunucu')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (hataVar) ...[
              const SizedBox(height: 32),
              Center(child: IkonRozet(Icons.wifi_find_rounded, renk: cs.error, boyut: 76)),
              const SizedBox(height: 20),
              Text(
                'Sunucu bulunamadı',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                'n8n çalışıyor mu ve telefon bilgisayarla aynı Wi-Fi ağında mı? Denenen adresler:\n'
                '${widget.hata is SunucuBulunamadi ? (widget.hata as SunucuBulunamadi).denenenler.join('\n') : widget.hata}',
                textAlign: TextAlign.center,
                style: TextStyle(color: cs.outline),
              ),
              const SizedBox(height: 24),
            ] else
              Card(
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: const IkonRozet(Icons.dns_rounded, renk: Color(0xFF10B981)),
                  title: const Text('Bağlı', style: TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(sunucu.value ?? '…'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: sunucu.isLoading ? null : () => ref.read(sunucuProvider.notifier).yenidenAra(),
              icon: sunucu.isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.radar_rounded),
              label: Text(sunucu.isLoading ? 'Aranıyor…' : 'Otomatik yeniden ara'),
            ),
            const SizedBox(height: 28),
            Text('Gerekirse adresi elle gir', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _adres,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.link_rounded),
                helperText: 'Ör. http://192.168.1.20:5678 (bilgisayarın yerel IP adresi)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _bekliyor ? null : _elle, child: Text(_bekliyor ? 'Deneniyor…' : 'Bu adrese bağlan')),
          ],
        ),
      ),
    );
  }
}
