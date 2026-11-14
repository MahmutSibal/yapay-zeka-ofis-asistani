import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';
import 'ana_kabuk.dart';

class PanelEkrani extends ConsumerWidget {
  const PanelEkrani({super.key, required this.git});
  final void Function(Hedef) git;

  String get _selam {
    final s = DateTime.now().hour;
    if (s < 6) return 'İyi geceler';
    if (s < 12) return 'Günaydın';
    if (s < 18) return 'İyi günler';
    return 'İyi akşamlar';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final panel = ref.watch(panelProvider);
    final s = panel.value ?? const <String, dynamic>{};
    int n(String k) => (s[k] as num?)?.toInt() ?? 0;

    final kartlar = [
      _Kart('Acil e-posta', 'son 7 gün', n('acil_eposta_7g'), Icons.priority_high_rounded, const Color(0xFFEF4444), Hedef.epostalar),
      _Kart('Onay bekleyen', 'paylaşım', n('bekleyen_onay'), Icons.pending_actions_rounded, const Color(0xFF8B5CF6), Hedef.icerik),
      _Kart('Açık görev', '${n('eksik_gorev')} eksik bilgili', n('acik_gorev'), Icons.task_alt_rounded, const Color(0xFF10B981), Hedef.gorevler),
      _Kart('Olumsuz yorum', 'son 7 gün', n('olumsuz_yorum_7g'), Icons.thumb_down_alt_rounded, const Color(0xFFF97316), Hedef.yorumlar),
      _Kart('Yeni e-posta', 'son 24 saat', n('eposta_24s'), Icons.mark_email_unread_rounded, const Color(0xFF3B82F6), Hedef.epostalar),
      _Kart('Sıradaki konu', 'sosyal medya', n('siradaki_konu'), Icons.queue_rounded, const Color(0xFF64748B), Hedef.icerik),
    ];

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(panelProvider.future),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: _Baslik(selam: _selam, hata: n('hata_24s'), onHata: () => git(Hedef.loglar)),
            ),
            if (panel.hasError && !panel.isLoading)
              SliverFillRemaining(
                hasScrollBody: false,
                child: HataGorunumu(mesaj: panel.error.toString(), yenile: () => ref.invalidate(panelProvider)),
              )
            else ...[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                sliver: SliverGrid.count(
                  crossAxisCount: MediaQuery.sizeOf(context).width > 600 ? 3 : 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.25,
                  children: [for (final k in kartlar) _IstatistikKarti(k: k, yukleniyor: panel.isLoading && !panel.hasValue, onTap: () => git(k.hedef))],
                ),
              ),
              SliverToBoxAdapter(child: _HizliIslemler(git: git)),
            ],
          ],
        ),
      ),
    );
  }
}

class _Baslik extends StatelessWidget {
  const _Baslik({required this.selam, required this.hata, required this.onHata});
  final String selam;
  final int hata;
  final VoidCallback onHata;

  @override
  Widget build(BuildContext context) {
    final ust = MediaQuery.paddingOf(context).top;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.fromLTRB(20, ust + 20, 20, 28),
      decoration: const BoxDecoration(
        gradient: Tema.degrade,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14)),
                child: const Icon(Icons.auto_awesome_rounded, color: Colors.white),
              ),
              const Spacer(),
              if (hata > 0)
                ActionChip(
                  onPressed: onHata,
                  avatar: const Icon(Icons.error_outline, size: 18, color: Colors.white),
                  label: Text(
                    '$hata hata',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                  ),
                  backgroundColor: Colors.white.withValues(alpha: 0.18),
                  side: BorderSide.none,
                ),
            ],
          ),
          const SizedBox(height: 22),
          Text(DateFormat('d MMMM EEEE', 'tr').format(DateTime.now()), style: TextStyle(color: Colors.white.withValues(alpha: 0.8))),
          const SizedBox(height: 4),
          Text(
            '$selam 👋',
            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -0.6),
          ),
          const SizedBox(height: 6),
          Text('Yapay zekâ ofis asistanın senin için çalışıyor.', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
        ],
      ),
    );
  }
}

class _IstatistikKarti extends StatelessWidget {
  const _IstatistikKarti({required this.k, required this.yukleniyor, required this.onTap});
  final _Kart k;
  final bool yukleniyor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IkonRozet(k.ikon, renk: k.renk, boyut: 38),
              const Spacer(),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: yukleniyor
                    ? const SizedBox(
                        height: 34,
                        width: 34,
                        child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    : Text(
                        '${k.sayi}',
                        key: ValueKey(k.sayi),
                        style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -1),
                      ),
              ),
              Text(k.baslik, style: t.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
              Text(k.alt, style: t.bodySmall?.copyWith(color: Theme.of(context).colorScheme.outline)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HizliIslemler extends StatelessWidget {
  const _HizliIslemler({required this.git});
  final void Function(Hedef) git;

  @override
  Widget build(BuildContext context) {
    Widget islem(IconData ikon, String ad, Color renk, Hedef h) => Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => git(h),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Column(
            children: [
              IkonRozet(ikon, renk: renk, boyut: 48),
              const SizedBox(height: 8),
              Text(ad, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hızlı işlemler', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  islem(Icons.chat_rounded, 'Dokümana sor', const Color(0xFF4F46E5), Hedef.sohbet),
                  islem(Icons.groups_rounded, 'Toplantı notu', const Color(0xFF0EA5E9), Hedef.toplanti),
                  islem(Icons.campaign_rounded, 'İçerik', const Color(0xFFA855F7), Hedef.icerik),
                  islem(Icons.newspaper_rounded, 'Bülten', const Color(0xFFF59E0B), Hedef.bultenler),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Kart {
  const _Kart(this.baslik, this.alt, this.sayi, this.ikon, this.renk, this.hedef);
  final String baslik;
  final String alt;
  final int sayi;
  final IconData ikon;
  final Color renk;
  final Hedef hedef;
}
