import 'package:flutter/material.dart';

/// Uygulamanın modern teması: yumuşak yüzeyler, büyük köşe yarıçapları, dolgulu alanlar.
class Tema {
  static const tohum = Color(0xFF4F46E5); // indigo
  static const vurgu = Color(0xFF06B6D4); // camgöbeği

  static const degrade = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4F46E5), Color(0xFF7C3AED), Color(0xFF06B6D4)],
  );

  static ThemeData acik() => _kur(Brightness.light);
  static ThemeData koyu() => _kur(Brightness.dark);

  static ThemeData _kur(Brightness b) {
    final cs = ColorScheme.fromSeed(seedColor: tohum, brightness: b, dynamicSchemeVariant: DynamicSchemeVariant.vibrant);
    final koyu = b == Brightness.dark;
    final zemin = koyu ? const Color(0xFF0F1117) : const Color(0xFFF5F6FB);
    final kart = koyu ? const Color(0xFF1A1D27) : Colors.white;
    final cizgi = koyu ? Colors.white10 : const Color(0xFFE7E8F0);
    final r16 = BorderRadius.circular(16);

    return ThemeData(
      useMaterial3: true,
      colorScheme: cs.copyWith(surface: zemin, surfaceContainerLow: kart),
      scaffoldBackgroundColor: zemin,
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: zemin,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: cs.onSurface),
      ),
      cardTheme: CardThemeData(
        color: kart,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: cizgi),
        ),
      ),
      listTileTheme: ListTileThemeData(shape: RoundedRectangleBorder(borderRadius: r16)),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: kart,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: cizgi),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: cizgi),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: r16,
          borderSide: BorderSide(color: cs.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: r16),
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 50),
          shape: RoundedRectangleBorder(borderRadius: r16),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        side: BorderSide(color: cizgi),
        backgroundColor: kart,
        showCheckmark: false,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)), elevation: 2),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: kart,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        height: 68,
        indicatorShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(fontSize: 12, fontWeight: s.contains(WidgetState.selected) ? FontWeight.w700 : FontWeight.w500),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: kart,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: kart,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: r16),
      ),
      dividerTheme: DividerThemeData(color: cizgi, space: 1),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
      ),
    );
  }
}

/// Degrade arka planlı ikon rozeti
class IkonRozet extends StatelessWidget {
  const IkonRozet(this.ikon, {super.key, required this.renk, this.boyut = 40});
  final IconData ikon;
  final Color renk;
  final double boyut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: boyut,
      height: boyut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(boyut * 0.32),
        gradient: LinearGradient(colors: [renk, Color.lerp(renk, Colors.white, 0.25)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: renk.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Icon(ikon, color: Colors.white, size: boyut * 0.52),
    );
  }
}

/// Liste ekranlarında kullanılan, kenar boşluklu kart
class OgeKart extends StatelessWidget {
  const OgeKart({super.key, required this.child, this.onTap, this.vurguRengi});
  final Widget child;
  final VoidCallback? onTap;
  final Color? vurguRengi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: vurguRengi == null
                ? null
                : BoxDecoration(
                    border: Border(left: BorderSide(color: vurguRengi!, width: 4)),
                  ),
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
