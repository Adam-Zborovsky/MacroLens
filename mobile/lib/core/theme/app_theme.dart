import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// MacroLens Design System — "Optical Precision"
/// Dark-mode first, clinical terminal meets high-end camera optics.
abstract class MLColors {
  // Backgrounds — OLED near-black (never pure #000000)
  static const bgDeep     = Color(0xFF050506);
  static const bgBase     = Color(0xFF08080A);
  static const bgElevated = Color(0xFF0A0A0C);
  static const bgCard     = Color(0xFF0F0F12);

  // Surfaces — glassmorphism
  static const surfaceGlass     = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const surfaceGlassHigh = Color(0x1AFFFFFF); // rgba(255,255,255,0.10)

  // Borders — hairline
  static const border       = Color(0x14FFFFFF); // rgba(255,255,255,0.08)
  static const borderActive = Color(0x33FFFFFF); // rgba(255,255,255,0.20)

  // Primary accent — electric cyan (laser reticle / scanning state)
  static const accentCyan     = Color(0xFF06B6D4);
  static const accentCyanGlow = Color(0x3306B6D4); // rgba(6,182,212,0.20)
  static const accentCyanDim  = Color(0xFF0E7490);

  // Macro nutrient colors
  static const macroProtein = Color(0xFFF87171); // red-400
  static const macroCarbs   = Color(0xFFFBBF24); // amber-400
  static const macroFat     = Color(0xFF818CF8); // indigo-400
  static const macroFiber   = Color(0xFF34D399); // emerald-400

  // Status
  static const statusVerified = Color(0xFF22C55E); // green-500
  static const statusWarning  = Color(0xFFF59E0B); // amber-500
  static const statusError    = Color(0xFFEF4444); // red-500

  // Text
  static const textPrimary = Color(0xFFEDEDEF);
  static const textMuted   = Color(0xFF8A8F98);
  static const textDim     = Color(0xFF3D4149);

  // Confidence badge backgrounds
  static const confidenceHigh   = Color(0x2222C55E);
  static const confidenceMedium = Color(0x22F59E0B);
  static const confidenceLow    = Color(0x22EF4444);
}

abstract class MLTextStyles {
  /// Inter — UI chrome, labels, body
  static TextStyle inter(double size, FontWeight weight, Color color, {double? letterSpacing}) =>
      GoogleFonts.inter(fontSize: size, fontWeight: weight, color: color, letterSpacing: letterSpacing);

  /// JetBrains Mono — all data values, odometer numbers, confidence scores
  static TextStyle mono(double size, FontWeight weight, Color color, {double? letterSpacing}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // Named styles
  static TextStyle get displayLarge =>
      inter(32, FontWeight.w700, MLColors.textPrimary, letterSpacing: -1.5);

  static TextStyle get headingMedium =>
      inter(20, FontWeight.w600, MLColors.textPrimary, letterSpacing: -0.5);

  static TextStyle get headingSmall =>
      inter(16, FontWeight.w600, MLColors.textPrimary);

  static TextStyle get bodyRegular =>
      inter(14, FontWeight.w400, MLColors.textPrimary);

  static TextStyle get bodyMuted =>
      inter(14, FontWeight.w400, MLColors.textMuted);

  static TextStyle get labelCaps =>
      inter(11, FontWeight.w500, MLColors.textMuted, letterSpacing: 1.2);

  static TextStyle get dataLarge =>
      mono(28, FontWeight.w700, MLColors.textPrimary);

  static TextStyle get dataMedium =>
      mono(18, FontWeight.w600, MLColors.textPrimary);

  static TextStyle get dataSmall =>
      mono(12, FontWeight.w400, MLColors.textMuted, letterSpacing: 0.5);

  static TextStyle get statusReadout =>
      mono(11, FontWeight.w400, MLColors.statusVerified, letterSpacing: 0.8);
}

abstract class MLSpacing {
  static const double xs  = 4.0;
  static const double sm  = 8.0;
  static const double md  = 16.0;
  static const double lg  = 24.0;
  static const double xl  = 32.0;
  static const double xxl = 48.0;
}

abstract class MLRadius {
  static const double sm  = 8.0;
  static const double md  = 12.0;
  static const double lg  = 16.0;
  static const double xl  = 24.0;
  static const double pill = 100.0;
}

ThemeData buildMLTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: MLColors.bgDeep,
    colorScheme: const ColorScheme.dark(
      primary: MLColors.accentCyan,
      surface: MLColors.bgElevated,
      onSurface: MLColors.textPrimary,
      error: MLColors.statusError,
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyMedium: MLTextStyles.bodyRegular,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: MLColors.bgDeep,
      surfaceTintColor: Colors.transparent,
      systemOverlayStyle: SystemUiOverlayStyle.light,
      elevation: 0,
      titleTextStyle: MLTextStyles.headingSmall,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: MLColors.bgBase,
      selectedItemColor: MLColors.accentCyan,
      unselectedItemColor: MLColors.textDim,
      elevation: 0,
    ),
  );
}
