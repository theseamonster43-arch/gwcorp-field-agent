import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class GwColors {
  final Color bg;
  final Color bg2;
  final Color bg3;
  final Color border;
  final Color text;
  final Color muted;
  final Color green;
  final Color greenGlow;
  final Color greenDim;
  final Color red;
  final Color amber;
  final bool isDark;

  const GwColors({
    required this.bg,
    required this.bg2,
    required this.bg3,
    required this.border,
    required this.text,
    required this.muted,
    required this.green,
    required this.greenGlow,
    required this.greenDim,
    required this.red,
    required this.amber,
    required this.isDark,
  });

  static const dark = GwColors(
    bg:        Color(0xFF080C0A),
    bg2:       Color(0xFF0D1410),
    bg3:       Color(0xFF131A15),
    border:    Color(0x1AFFFFFF),
    text:      Color(0xFFE8F0E9),
    muted:     Color(0x80E8F0E9),
    green:     Color(0xFF22C55E),
    greenGlow: Color(0x1422C55E),
    greenDim:  Color(0xFF16A34A),
    red:       Color(0xFFEF4444),
    amber:     Color(0xFFF59E0B),
    isDark:    true,
  );

  static const light = GwColors(
    bg:        Color(0xFFF4F9F5),
    bg2:       Color(0xFFEBF2EC),
    bg3:       Color(0xFFDFEDE1),
    border:    Color(0x1A000000),
    text:      Color(0xFF0D1A10),
    muted:     Color(0x800D1A10),
    green:     Color(0xFF16A34A),
    greenGlow: Color(0x1416A34A),
    greenDim:  Color(0xFF15803D),
    red:       Color(0xFFDC2626),
    amber:     Color(0xFFD97706),
    isDark:    false,
  );
}

class GwTheme extends InheritedWidget {
  final GwColors colors;
  const GwTheme({super.key, required this.colors, required super.child});

  static GwColors of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GwTheme>()?.colors ?? GwColors.dark;

  @override
  bool updateShouldNotify(GwTheme old) => colors != old.colors;
}

ThemeData buildMaterialTheme(GwColors gw) {
  final brightness = gw.isDark ? Brightness.dark : Brightness.light;
  final base = ThemeData(
    brightness: brightness,
    colorScheme: ColorScheme(
      brightness: brightness,
      primary: gw.green,
      onPrimary: gw.isDark ? gw.bg : Colors.white,
      secondary: gw.green,
      onSecondary: gw.isDark ? gw.bg : Colors.white,
      error: gw.red,
      onError: Colors.white,
      surface: gw.bg2,
      onSurface: gw.text,
    ),
    useMaterial3: true,
  );
  return base.copyWith(
    scaffoldBackgroundColor: gw.bg,
    textTheme: GoogleFonts.dmSansTextTheme(base.textTheme)
        .apply(bodyColor: gw.text, displayColor: gw.text),
  );
}
