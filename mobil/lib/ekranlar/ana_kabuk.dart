import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/ayarlar.dart';
import '../core/tema.dart';
import 'ayarlar_ekrani.dart';
import 'bultenler_ekrani.dart';
import 'epostalar_ekrani.dart';
import 'gorevler_ekrani.dart';
import 'icerik_ekrani.dart';
import 'loglar_ekrani.dart';
import 'panel_ekrani.dart';
import 'sohbet_ekrani.dart';
import 'toplanti_ekrani.dart';
import 'yorumlar_ekrani.dart';

/// Alt gezinme çubuklu ana kabuk. Panel kartları diğer sekmelere/sayfalara yönlendirir.
class AnaKabuk extends ConsumerStatefulWidget {
  const AnaKabuk({super.key});

  @override
  ConsumerState<AnaKabuk> createState() => _AnaKabukState();
}

enum Hedef { panel, epostalar, sohbet, gorevler, daha, yorumlar, bultenler, toplanti, icerik, loglar, ayarlar }

class _AnaKabukState extends ConsumerState<AnaKabuk> {
  int _sekme = 0;

  void git(Hedef h) {
    switch (h) {
      case Hedef.panel:
        setState(() => _sekme = 0);
      case Hedef.epostalar:
        setState(() => _sekme = 1);
      case Hedef.sohbet:
        setState(() => _sekme = 2);
      case Hedef.gorevler:
        setState(() => _sekme = 3);
      case Hedef.daha:
        setState(() => _sekme = 4);
      default:
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => sayfa(h)));
    }
  }

  static Widget sayfa(Hedef h) => switch (h) {
    Hedef.yorumlar => const YorumlarEkrani(),
    Hedef.bultenler => const BultenlerEkrani(),
    Hedef.toplanti => const ToplantiEkrani(),
    Hedef.icerik => const IcerikEkrani(),
    Hedef.loglar => const LoglarEkrani(),
    Hedef.ayarlar => const AyarlarEkrani(),
    _ => const SizedBox.shrink(),
  };

  @override
  Widget build(BuildContext context) {
    // Sunucu otomatik bulunana kadar bekle; bulunamazsa bağlantı ekranını göster
    final sunucu = ref.watch(sunucuProvider);
    if (!sunucu.hasValue) {
      return sunucu.hasError && !sunucu.isLoading ? AyarlarEkrani(hata: sunucu.error) : const BaglaniyorEkrani();
    }
    final sekmeler = [PanelEkrani(git: git), const EpostalarEkrani(), const SohbetEkrani(), const GorevlerEkrani(), _DahaFazla(git: git)];

    return Scaffold(
      body: IndexedStack(index: _sekme, children: sekmeler),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _sekme,
        onDestinationSelected: (i) => setState(() => _sekme = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Panel'),
          NavigationDestination(icon: Icon(Icons.mail_outline), selectedIcon: Icon(Icons.mail), label: 'E-posta'),
          NavigationDestination(icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Sohbet'),
          NavigationDestination(icon: Icon(Icons.task_alt_outlined), selectedIcon: Icon(Icons.task_alt), label: 'Görevler'),
          NavigationDestination(icon: Icon(Icons.apps), label: 'Daha'),
        ],
      ),
    );
  }
}

class _DahaFazla extends StatelessWidget {
  const _DahaFazla({required this.git});
  final void Function(Hedef) git;

  @override
  Widget build(BuildContext context) {
    Widget oge(IconData ikon, Color renk, String baslik, String alt, Hedef h) => OgeKart(
      onTap: () => git(h),
      child: Row(
        children: [
          IkonRozet(ikon, renk: renk, boyut: 44),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(baslik, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                const SizedBox(height: 2),
                Text(alt, style: TextStyle(color: Theme.of(context).colorScheme.outline)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Theme.of(context).colorScheme.outline),
        ],
      ),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Modüller')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          oge(Icons.thumbs_up_down_rounded, const Color(0xFFF97316), 'Yorumlar', 'Duygu analizi · Modül 3', Hedef.yorumlar),
          oge(Icons.newspaper_rounded, const Color(0xFFF59E0B), 'Bültenler', 'Haftalık haber bülteni · Modül 4', Hedef.bultenler),
          oge(Icons.groups_rounded, const Color(0xFF0EA5E9), 'Toplantı → Görev', 'Notlardan görev çıkar · Modül 5', Hedef.toplanti),
          oge(Icons.campaign_rounded, const Color(0xFFA855F7), 'İçerik Onayı', 'Sosyal medya taslakları · Modül 6', Hedef.icerik),
          const SizedBox(height: 12),
          oge(Icons.bug_report_rounded, const Color(0xFF78716C), 'Hata Kayıtları', 'Akış hataları', Hedef.loglar),
          oge(Icons.settings_rounded, const Color(0xFF64748B), 'Sunucu', 'Otomatik bağlantı durumu', Hedef.ayarlar),
        ],
      ),
    );
  }
}
