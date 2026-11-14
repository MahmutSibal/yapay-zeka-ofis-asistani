import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// main() içinde gerçek örnekle override edilir.
final prefsProvider = Provider<SharedPreferences>((ref) => throw UnimplementedError('prefsProvider override edilmedi'));

/// Derleme anında verilebilen adres: flutter run --dart-define=SUNUCU=http://192.168.1.20:5678
const derlemeSunucusu = String.fromEnvironment('SUNUCU');

class SunucuBulunamadi implements Exception {
  SunucuBulunamadi(this.denenenler);
  final List<String> denenenler;
  @override
  String toString() => 'n8n sunucusu bulunamadı. Denenen adresler:\n${denenenler.join('\n')}';
}

/// Uygulama açılışında n8n sunucusunu otomatik bulur ve bağlanır (API anahtarı yok).
/// Sıra: son başarılı adres → derlemede verilen adres → platforma göre varsayılanlar.
class SunucuNotifier extends AsyncNotifier<String> {
  static const _kSunucu = 'sunucu';

  List<String> get _adaylar {
    final kayitli = ref.read(prefsProvider).getString(_kSunucu);
    final liste = <String>[
      ?kayitli,
      if (derlemeSunucusu.isNotEmpty) derlemeSunucusu,
      if (kIsWeb) '${Uri.base.scheme}://${Uri.base.host}:5678',
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) 'http://10.0.2.2:5678', // Android emülatörü → bilgisayar
      'http://localhost:5678',
      'http://127.0.0.1:5678',
    ];
    return liste.map((s) => s.replaceAll(RegExp(r'/+$'), '')).toSet().toList();
  }

  /// Aday adresin gerçekten bu uygulamanın n8n'i olduğunu panel uç noktasıyla doğrular.
  static Future<bool> dene(String adres) async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 3), receiveTimeout: const Duration(seconds: 8)));
    try {
      final r = await dio.get<dynamic>('$adres/webhook/api/panel');
      return r.statusCode == 200 && r.data is Map && (r.data as Map).containsKey('sayaclar');
    } catch (_) {
      return false;
    } finally {
      dio.close(force: true);
    }
  }

  @override
  Future<String> build() async {
    final adaylar = _adaylar;
    // Tüm adayları aynı anda dene, listedeki önceliğe göre ilk başarılıyı seç
    final sonuclar = await Future.wait(adaylar.map(dene));
    for (var i = 0; i < adaylar.length; i++) {
      if (sonuclar[i]) {
        await ref.read(prefsProvider).setString(_kSunucu, adaylar[i]);
        return adaylar[i];
      }
    }
    throw SunucuBulunamadi(adaylar);
  }

  /// İsteğe bağlı: adresi elle ver (otomatik bulunamazsa). Başarılıysa kaydeder.
  Future<bool> elleBaglan(String adres) async {
    final temiz = adres.trim().replaceAll(RegExp(r'/+$'), '');
    if (!await dene(temiz)) return false;
    await ref.read(prefsProvider).setString(_kSunucu, temiz);
    state = AsyncData(temiz);
    return true;
  }

  /// Yeniden otomatik ara
  Future<void> yenidenAra() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(build);
  }
}

final sunucuProvider = AsyncNotifierProvider<SunucuNotifier, String>(SunucuNotifier.new);
