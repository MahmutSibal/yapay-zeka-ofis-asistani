import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api.dart';
import '../core/ortak.dart';
import '../core/tema.dart';

class _Mesaj {
  _Mesaj(this.metin, {required this.ben, this.kaynaklar = const [], this.bulunamadi = false, this.hata = false});
  final String metin;
  final bool ben;
  final List<String> kaynaklar;
  final bool bulunamadi;
  final bool hata;
}

/// Modül 2: doküman tabanlı sohbet. Bellek n8n'de (MongoDB) oturum_id ile tutulur.
class SohbetEkrani extends ConsumerStatefulWidget {
  const SohbetEkrani({super.key});

  @override
  ConsumerState<SohbetEkrani> createState() => _SohbetEkraniState();
}

class _SohbetEkraniState extends ConsumerState<SohbetEkrani> {
  final _girdi = TextEditingController();
  final _kaydirma = ScrollController();
  final _mesajlar = <_Mesaj>[];
  late String _oturum = _yeniOturum();
  bool _bekliyor = false;

  static String _yeniOturum() {
    final r = Random.secure();
    return List.generate(16, (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
  }

  @override
  void dispose() {
    _girdi.dispose();
    _kaydirma.dispose();
    super.dispose();
  }

  Future<void> _gonder([String? hazir]) async {
    final metin = (hazir ?? _girdi.text).trim();
    if (metin.length < 2 || _bekliyor) return;
    _girdi.clear();
    setState(() {
      _mesajlar.add(_Mesaj(metin, ben: true));
      _bekliyor = true;
    });
    _asagi();
    try {
      final r = await ref.read(apiProvider).sohbet(_oturum, metin);
      setState(
        () => _mesajlar.add(
          _Mesaj(
            (r['yanit'] ?? '').toString(),
            ben: false,
            kaynaklar: ((r['kaynaklar'] as List?) ?? const []).map((e) => e.toString()).toList(),
            bulunamadi: r['bilgi_bulundu'] == false,
          ),
        ),
      );
    } on ApiHata catch (e) {
      setState(() => _mesajlar.add(_Mesaj(e.mesaj, ben: false, hata: true)));
    } finally {
      if (mounted) setState(() => _bekliyor = false);
      _asagi();
    }
  }

  void _asagi() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_kaydirma.hasClients) _kaydirma.animateTo(_kaydirma.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
  });

  Future<void> _dokumanEkle() async {
    final baslik = TextEditingController();
    final metin = TextEditingController();
    final tamam = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Doküman ekle'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baslik,
                decoration: const InputDecoration(labelText: 'Başlık (ör. Ders 3 notları)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: metin,
                minLines: 6,
                maxLines: 10,
                decoration: const InputDecoration(labelText: 'Metni yapıştır', alignLabelWithHint: true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('İndeksle')),
        ],
      ),
    );
    if (tamam != true || !mounted) return;
    try {
      bildir(context, 'Doküman parçalanıyor ve indeksleniyor…');
      final r = await ref.read(apiProvider).dokumanIndeksle(baslik: baslik.text.trim().isEmpty ? 'Metin' : baslik.text.trim(), metin: metin.text);
      if (mounted) bildir(context, '${r['parca_sayisi'] ?? 0} parça eklendi.');
    } on ApiHata catch (e) {
      if (mounted) bildir(context, e.mesaj, hata: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doküman Asistanı'),
        actions: [
          IconButton(tooltip: 'Doküman ekle', onPressed: _dokumanEkle, icon: const Icon(Icons.note_add_rounded)),
          IconButton(
            tooltip: 'Yeni sohbet',
            onPressed: () => setState(() {
              _mesajlar.clear();
              _oturum = _yeniOturum();
            }),
            icon: const Icon(Icons.add_comment_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _mesajlar.isEmpty
                ? _Karsilama(oneri: _gonder)
                : ListView.builder(
                    controller: _kaydirma,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                    itemCount: _mesajlar.length + (_bekliyor ? 1 : 0),
                    itemBuilder: (_, i) => i == _mesajlar.length ? const _Yaziyor() : _Balon(m: _mesajlar[i]),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _girdi,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _gonder(),
                      decoration: InputDecoration(
                        hintText: 'Notlara bir soru sor…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _bekliyor ? null : _gonder,
                    style: IconButton.styleFrom(minimumSize: const Size(52, 52), backgroundColor: cs.primary),
                    icon: const Icon(Icons.arrow_upward_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Karsilama extends StatelessWidget {
  const _Karsilama({required this.oneri});
  final void Function(String) oneri;

  @override
  Widget build(BuildContext context) {
    const oneriler = ['Bu dokümanın ana konuları neler?', 'Önemli tarihleri listeler misin?', 'Kısa bir özet çıkar'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        const Center(child: IkonRozet(Icons.menu_book_rounded, renk: Tema.tohum, boyut: 72)),
        const SizedBox(height: 20),
        Text(
          'Dokümanlarına sor',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Yanıtlar yalnızca yüklediğin dokümanlara dayanır. Bilgi yoksa “Notlarda bu bilgi yok” der, tahmin yürütmez.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Theme.of(context).colorScheme.outline),
        ),
        const SizedBox(height: 24),
        for (final o in oneriler)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(onPressed: () => oneri(o), child: Text(o)),
          ),
      ],
    );
  }
}

class _Balon extends StatelessWidget {
  const _Balon({required this.m});
  final _Mesaj m;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final arka = m.ben
        ? null
        : m.hata
        ? cs.errorContainer
        : m.bulunamadi
        ? cs.tertiaryContainer
        : Theme.of(context).cardTheme.color;
    return Align(
      alignment: m.ben ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        decoration: BoxDecoration(
          gradient: m.ben ? Tema.degrade : null,
          color: arka,
          border: m.ben ? null : Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(m.ben ? 20 : 6),
            bottomRight: Radius.circular(m.ben ? 6 : 20),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SelectableText(m.metin, style: TextStyle(color: m.ben ? Colors.white : null, height: 1.4, fontSize: 15)),
            if (m.kaynaklar.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [for (final k in m.kaynaklar) Etiket('📄 $k', renk: cs.primary)]),
            ],
          ],
        ),
      ),
    );
  }
}

class _Yaziyor extends StatelessWidget {
  const _Yaziyor();
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(color: Theme.of(context).cardTheme.color, borderRadius: BorderRadius.circular(20)),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 10),
          Text('Dokümanlarda arıyor…'),
        ],
      ),
    ),
  );
}
