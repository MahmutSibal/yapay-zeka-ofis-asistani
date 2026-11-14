import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ayarlar.dart';

typedef Json = Map<String, dynamic>;

class ApiHata implements Exception {
  ApiHata(this.mesaj, {this.kod});
  final String mesaj;
  final int? kod;
  @override
  String toString() => mesaj;
}

/// n8n webhook'larıyla konuşan istemci. Tüm uç noktalar {N8N}/webhook/api/... altında (anahtarsız).
class ApiClient {
  ApiClient(this.sunucu)
    : _dio = Dio(
        BaseOptions(
          baseUrl: '$sunucu/webhook/api/',
          connectTimeout: const Duration(seconds: 10),
          // Yerel LLM yanıtları uzun sürebilir (özellikle ilk yüklemede)
          receiveTimeout: const Duration(minutes: 4),
          contentType: Headers.jsonContentType,
        ),
      );

  final String sunucu;
  final Dio _dio;

  Future<Json> _istek(String yontem, String yol, {Object? veri}) async {
    try {
      final r = await _dio.request<dynamic>(
        yol,
        data: veri,
        options: Options(method: yontem),
      );
      final d = r.data;
      if (d is Map) return Map<String, dynamic>.from(d);
      return {'veri': d};
    } on DioException catch (e) {
      final kod = e.response?.statusCode;
      final govde = e.response?.data;
      String mesaj;
      if (govde is Map && govde['hata'] != null) {
        mesaj = govde['hata'].toString();
      } else if (kod == 404) {
        mesaj = 'Uç nokta bulunamadı. İlgili n8n akışı aktif mi?';
      } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.connectionError) {
        mesaj = 'Sunucuya bağlanılamadı ($sunucu). n8n çalışıyor ve telefon aynı ağda mı?';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        mesaj = 'Yanıt zaman aşımına uğradı. Model hâlâ çalışıyor olabilir, biraz sonra tekrar dene.';
      } else {
        mesaj = 'Beklenmeyen hata${kod != null ? ' ($kod)' : ''}: ${e.message ?? e.type.name}';
      }
      throw ApiHata(mesaj, kod: kod);
    }
  }

  // ---- Okuma ----
  Future<Json> panel() async => Map<String, dynamic>.from((await _istek('GET', 'panel'))['sayaclar'] as Map? ?? {});

  /// yol: 'epostalar?kategori=fatura' gibi sorgulu yol
  Future<List<Json>> liste(String yol) async {
    final r = await _istek('GET', yol);
    return ((r['veriler'] as List?) ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  // ---- Yazma / AI ----
  Future<Json> sohbet(String oturumId, String mesaj) => _istek('POST', 'sohbet', veri: {'oturum_id': oturumId, 'mesaj': mesaj});

  Future<Json> dokumanIndeksle({required String baslik, String? metin, String? driveId}) =>
      _istek('POST', 'dokuman/indeksle', veri: {'baslik': baslik, 'metin': ?metin, 'drive_id': ?driveId});

  Future<Json> yorumEkle(String metin, {String? musteri}) => _istek('POST', 'yorumlar', veri: {'metin': metin, 'musteri': ?musteri, 'kaynak': 'uygulama'});

  Future<Json> toplanti({required String baslik, required String notlar, required List<String> katilimcilar}) =>
      _istek('POST', 'toplanti', veri: {'baslik': baslik, 'notlar': notlar, 'katilimcilar': katilimcilar});

  Future<Json> gorevDurum(String kid, String durum) => _istek('POST', 'gorevler/durum', veri: {'kid': kid, 'durum': durum});

  Future<Json> konuEkle(String konu, {String platform = 'linkedin'}) => _istek('POST', 'icerikler', veri: {'konu': konu, 'platform': platform});

  Future<Json> icerikKarar(String kid, {required bool onay, String geriBildirim = '', bool gorselIste = false}) =>
      _istek('POST', 'icerikler/karar', veri: {'kid': kid, 'onay': onay, 'geri_bildirim': geriBildirim, 'gorsel_iste': gorselIste});

  Future<Json> bultenBaslat() => _istek('POST', 'bulten/simdi', veri: {});

  Future<Json> icerikBaslat() => _istek('POST', 'icerik/simdi', veri: {});
}

/// Sunucu otomatik bulunduktan sonra kullanılır (AnaKabuk bağlantı kurulmadan ekranları göstermez).
final apiProvider = Provider<ApiClient>((ref) => ApiClient(ref.watch(sunucuProvider).requireValue));

final panelProvider = FutureProvider.autoDispose<Json>((ref) => ref.watch(apiProvider).panel());

/// Parametre: sorgulu yol (ör. 'gorevler?durum=acik'). String eşitliği sayesinde önbellek doğru çalışır.
final listeProvider = FutureProvider.autoDispose.family<List<Json>, String>((ref, yol) => ref.watch(apiProvider).liste(yol));
