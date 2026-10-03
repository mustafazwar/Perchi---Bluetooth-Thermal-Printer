import 'package:flutter/material.dart';

enum Tone { acc, ok, warn, bad, neutral }

class Pal extends ThemeExtension<Pal> {
  const Pal({
    required this.bg, required this.card, required this.ink, required this.mute, required this.line,
    required this.acc, required this.accInk, required this.accTint,
    required this.ok, required this.okTint, required this.warn, required this.warnTint,
    required this.bad, required this.badTint,
  });
  final Color bg, card, ink, mute, line, acc, accInk, accTint, ok, okTint, warn, warnTint, bad, badTint;

  static const light = Pal(
    bg: Color(0xFFF2F4F7), card: Colors.white, ink: Color(0xFF12161C), mute: Color(0xFF667085), line: Color(0xFFE3E7ED),
    acc: Color(0xFF2447F5), accInk: Colors.white, accTint: Color(0xFFE8EDFF),
    ok: Color(0xFF0F9D6B), okTint: Color(0xFFDDF5EA), warn: Color(0xFFB77900), warnTint: Color(0xFFFFF1CC),
    bad: Color(0xFFD92D3A), badTint: Color(0xFFFDE4E6),
  );
  static const dark = Pal(
    bg: Color(0xFF0D1015), card: Color(0xFF171B22), ink: Color(0xFFEEF1F6), mute: Color(0xFF8B94A3), line: Color(0xFF262C36),
    acc: Color(0xFF7189FF), accInk: Color(0xFF0D1015), accTint: Color(0xFF1C2547),
    ok: Color(0xFF2BC48A), okTint: Color(0xFF10352A), warn: Color(0xFFF0B429), warnTint: Color(0xFF3A2E0B),
    bad: Color(0xFFFF6B75), badTint: Color(0xFF3D1A1E),
  );

  Color toneBg(Tone t) {
    switch (t) {
      case Tone.acc: return accTint;
      case Tone.ok: return okTint;
      case Tone.warn: return warnTint;
      case Tone.bad: return badTint;
      case Tone.neutral: return bg;
    }
  }

  Color toneFg(Tone t) {
    switch (t) {
      case Tone.acc: return acc;
      case Tone.ok: return ok;
      case Tone.warn: return warn;
      case Tone.bad: return bad;
      case Tone.neutral: return ink;
    }
  }

  @override
  Pal copyWith() => this;
  @override
  Pal lerp(ThemeExtension<Pal>? other, double t) => t < 0.5 ? this : (other is Pal ? other : this);
}

extension PalContext on BuildContext {
  Pal get pal => Theme.of(this).extension<Pal>()!;
}

ThemeData buildTheme(Brightness b) {
  final p = b == Brightness.dark ? Pal.dark : Pal.light;
  return ThemeData(
    useMaterial3: true,
    brightness: b,
    colorScheme: ColorScheme.fromSeed(seedColor: p.acc, brightness: b).copyWith(primary: p.acc, onPrimary: p.accInk),
    scaffoldBackgroundColor: p.bg,
    extensions: [p],
    appBarTheme: AppBarTheme(
      backgroundColor: p.bg, foregroundColor: p.ink, elevation: 0, scrolledUnderElevation: 0, centerTitle: false,
      titleTextStyle: TextStyle(color: p.ink, fontSize: 22, fontWeight: FontWeight.w700),
    ),
    navigationBarTheme: NavigationBarThemeData(backgroundColor: p.card, indicatorColor: p.accTint),
    dividerColor: p.line,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
