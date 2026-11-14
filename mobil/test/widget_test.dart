import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:ofis_asistani/core/api.dart';
import 'package:ofis_asistani/core/ayarlar.dart';
import 'package:ofis_asistani/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ağ olmadan otomatik keşfin sonucunu taklit eder
class _SahteSunucu extends SunucuNotifier {
  _SahteSunucu(this.adres);
  final String? adres;
  @override
  Future<String> build() async => adres ?? (throw SunucuBulunamadi(['http://10.0.2.2:5678', 'http://localhost:5678']));
}

Future<void> _ac(WidgetTester tester, String? adres) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        prefsProvider.overrideWithValue(prefs),
        sunucuProvider.overrideWith(() => _SahteSunucu(adres)),
        panelProvider.overrideWith((ref) async => {'acil_eposta_7g': 3, 'bekleyen_onay': 1}),
        listeProvider.overrideWith((ref, yol) async => <Json>[]),
      ],
      child: const OfisAsistaniUygulamasi(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('tr'));

  testWidgets('Sunucu otomatik bulunursa doğrudan panel açılır (API anahtarı sorulmaz)', (tester) async {
    await _ac(tester, 'http://10.0.2.2:5678');
    expect(find.text('Panel'), findsOneWidget);
    expect(find.text('Acil e-posta'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.textContaining('API anahtarı'), findsNothing);

    await tester.tap(find.text('Daha'));
    await tester.pumpAndSettle();
    expect(find.text('İçerik Onayı'), findsOneWidget);
  });

  testWidgets('Sunucu bulunamazsa denenen adresler ve yeniden arama gösterilir', (tester) async {
    await _ac(tester, null);
    expect(find.text('Sunucu bulunamadı'), findsOneWidget);
    expect(find.textContaining('http://localhost:5678'), findsOneWidget);
    expect(find.text('Otomatik yeniden ara'), findsOneWidget);
    expect(find.text('Panel'), findsNothing);
  });
}
