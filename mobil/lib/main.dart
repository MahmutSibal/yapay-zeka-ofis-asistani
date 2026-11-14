import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/ayarlar.dart';
import 'core/tema.dart';
import 'ekranlar/ana_kabuk.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr');
  final prefs = await SharedPreferences.getInstance();
  runApp(ProviderScope(overrides: [prefsProvider.overrideWithValue(prefs)], child: const OfisAsistaniUygulamasi()));
}

class OfisAsistaniUygulamasi extends StatelessWidget {
  const OfisAsistaniUygulamasi({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ofis Asistanı',
      debugShowCheckedModeBanner: false,
      locale: const Locale('tr'),
      theme: Tema.acik(),
      darkTheme: Tema.koyu(),
      home: const AnaKabuk(),
    );
  }
}
