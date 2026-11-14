import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

/// Modül 5: toplantı notundan görev çıkarma
class ToplantiEkrani extends ConsumerStatefulWidget {
  const ToplantiEkrani({super.key});

  @override
  ConsumerState<ToplantiEkrani> createState() => _ToplantiEkraniState();
}

class _ToplantiEkraniState extends ConsumerState<ToplantiEkrani> {
  final _baslik = TextEditingController();
  final _katilimcilar = TextEditingController();
  final _notlar = TextEditingController();
  bool _bekliyor = false;
  Json? _sonuc;

  @override
  void dispose() {
    _baslik.dispose();
    _katilimcilar.dispose();
    _notlar.dispose();
    super.dispose();
  }

  Future<void> _gonder() async {
    if (_notlar.text.trim().length < 20) {
      bildir(context, 'Toplantı notu en az 20 karakter olmalı.', hata: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _bekliyor = true);
    try {
      final r = await ref
          .read(apiProvider)
          .toplanti(
            baslik: _baslik.text.trim().isEmpty ? 'Toplantı' : _baslik.text.trim(),
            notlar: _notlar.text.trim(),
            katilimcilar: _katilimcilar.text.split(RegExp(r'[,;\s]+')).where((s) => s.contains('@')).toList(),
          );
      setState(() => _sonuc = r);
      ref.invalidate(panelProvider);
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    } finally {
      if (mounted) setState(() => _bekliyor = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Toplantı → Görev')),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _sonuc == null ? _form() : _SonucGorunumu(sonuc: _sonuc!, yeni: () => setState(() => _sonuc = null)),
      ),
    );
  }

  Widget _form() => ListView(
    key: const ValueKey('form'),
    padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
    children: [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const IkonRozet(Icons.auto_awesome_rounded, renk: Color(0xFF0EA5E9)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Notları yapıştır; yapay zekâ görevleri, sorumluları ve tarihleri çıkarsın. Notlarda olmayan bilgi tahmin edilmez, "EKSİK" olarak işaretlenir.',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _baslik,
        decoration: const InputDecoration(labelText: 'Toplantı başlığı', prefixIcon: Icon(Icons.title_rounded)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _katilimcilar,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(labelText: 'Katılımcı e-postaları (virgülle)', prefixIcon: Icon(Icons.alternate_email_rounded)),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _notlar,
        minLines: 10,
        maxLines: 20,
        decoration: const InputDecoration(
          labelText: 'Toplantı notları',
          alignLabelWithHint: true,
          hintText: 'Ör. Ayşe teklif dosyasını Cuma\'ya kadar hazırlayacak…',
        ),
      ),
      const SizedBox(height: 20),
      FilledButton.icon(
        onPressed: _bekliyor ? null : _gonder,
        icon: _bekliyor ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.bolt_rounded),
        label: Text(_bekliyor ? 'Görevler çıkarılıyor…' : 'Görevleri çıkar'),
      ),
    ],
  );
}

class _SonucGorunumu extends StatelessWidget {
  const _SonucGorunumu({required this.sonuc, required this.yeni});
  final Json sonuc;
  final VoidCallback yeni;

  @override
  Widget build(BuildContext context) {
    final gorevler = ((sonuc['gorevler'] as List?) ?? const []).cast<Map>();
    final eksikler = ((sonuc['eksikler'] as List?) ?? const []).cast<Map>();
    const kirmizi = Color(0xFFEF4444);

    return ListView(
      key: const ValueKey('sonuc'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: Tema.degrade, borderRadius: BorderRadius.circular(24)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${gorevler.length} görev çıkarıldı',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  gorevler.isEmpty
                      ? (sonuc['mesaj'] ?? 'Notlarda yapılacak iş bulunamadı.').toString()
                      : '${eksikler.length} görevde eksik bilgi var · ${sonuc['katilimcilara_gonderildi'] == true ? 'katılımcılara özet gönderildi' : 'e-posta gönderilmedi'}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                ),
              ],
            ),
          ),
        ),
        for (final g in gorevler)
          OgeKart(
            vurguRengi: (g['eksik_alanlar'] as List).isNotEmpty ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(g['gorev'].toString(), style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    g['sorumlu'] != null ? Etiket('👤 ${g['sorumlu']}', renk: Tema.tohum) : const Etiket('Sorumlu EKSİK', renk: kirmizi),
                    g['tarih'] != null ? Etiket('📅 ${g['tarih']}', renk: const Color(0xFF0EA5E9)) : const Etiket('Tarih EKSİK', renk: kirmizi),
                    if (g['kart_url'] != null) const Etiket('Trello kartı açıldı', renk: Color(0xFF10B981)),
                  ],
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: OutlinedButton.icon(onPressed: yeni, icon: const Icon(Icons.add_rounded), label: const Text('Yeni toplantı notu')),
        ),
      ],
    );
  }
}
