import 'package:flutter/material.dart';
import 'package:visit_schema/visit_schema.dart';

/// Design tokens from the handoff (AmaliTech), with the CLAUDE.md bans
/// applied: no shadows, no pills, no gradients, fonts bundled.
abstract final class C {
  static const navy = Color(0xFF08283B);
  static const navyPressed = Color(0xFF051823);
  static const keyTile = Color(0xFF395362);

  static const surface = Color(0xFFFDFDFD);
  static const card = Color(0xFFFFFFFF);

  static const strong = Color(0xFF1A1A18);
  static const bodyStrong = Color(0xFF2C2B29);
  static const body = Color(0xFF3E3D3A);
  static const muted = Color(0xFF656461);
  static const dashed = Color(0xFF7E7D7B);

  static const border = Color(0xFFE5E7EB);
  static const input = Color(0xFFD1D5DB);
  static const divider = Color(0xFFF0F1F3);
  static const pressed = Color(0xFFF3F4F6);

  static const red = Color(0xFFC81E1E);
  static const redBg = Color(0xFFFDE8E8);
  static const yellow = Color(0xFFB48700);
  static const yellowBg = Color(0xFFFDF6B2);
  static const yellowDeep = Color(0xFF723B13);
  static const green = Color(0xFF057A55);
  static const greenDeep = Color(0xFF046C4E);
  static const greenBg = Color(0xFFDEF7EC);
  static const greenTint = Color(0xFFF3FAF7);
  static const infoTint = Color(0xFFEFF7FE);

  static Color urgency(Urgency u) => switch (u) {
        Urgency.emergency => red,
        Urgency.urgent => yellow,
        Urgency.routine => greenDeep,
      };
}

abstract final class Sp {
  static const page = 22.0;
  static const radius = 8.0;
  static const minTarget = 48.0;
}

const _sans = 'Inter';
const _display = 'Poppins';
const _mono = 'JetBrainsMono';

abstract final class T {
  static TextStyle display(double size, {Color color = C.navy, double? height}) =>
      TextStyle(
          fontFamily: _display,
          fontWeight: FontWeight.w700,
          fontSize: size,
          height: height ?? 1.25,
          color: color);

  static TextStyle ui(double size,
          {FontWeight w = FontWeight.w400, Color color = C.body, double? height}) =>
      TextStyle(
          fontFamily: _sans, fontWeight: w, fontSize: size, height: height, color: color);

  static TextStyle mono(double size,
          {FontWeight w = FontWeight.w500, Color color = C.strong, double? height}) =>
      TextStyle(
          fontFamily: _mono, fontWeight: w, fontSize: size, height: height, color: color);

  static TextStyle get label => ui(14, w: FontWeight.w600, color: C.navy);
  static TextStyle get sectionTitle => ui(16, w: FontWeight.w600, color: C.navy);
  static TextStyle get bodyText => ui(15, height: 1.5);
}

ThemeData buildTheme() {
  const scheme = ColorScheme.light(
    primary: C.navy,
    onPrimary: C.surface,
    secondary: C.navy,
    onSecondary: C.surface,
    surface: C.surface,
    onSurface: C.strong,
    error: C.red,
    outline: C.input,
  );
  final r = BorderRadius.circular(Sp.radius);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: C.surface,
    fontFamily: _sans,
    splashFactory: NoSplash.splashFactory,
    highlightColor: C.pressed,
    textSelectionTheme: const TextSelectionThemeData(
        cursorColor: C.navy, selectionHandleColor: C.navy),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      filled: true,
      fillColor: C.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      hintStyle: T.ui(16, color: C.muted),
      enabledBorder: OutlineInputBorder(
          borderRadius: r, borderSide: const BorderSide(color: C.input)),
      focusedBorder: OutlineInputBorder(
          borderRadius: r, borderSide: const BorderSide(color: C.navy, width: 2)),
      border: OutlineInputBorder(borderRadius: r),
    ),
    datePickerTheme: DatePickerThemeData(
      backgroundColor: C.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: C.card,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: r),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
    }),
  );
}
