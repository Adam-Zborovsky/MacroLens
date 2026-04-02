import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Colors: The Forensic Lens ─────────────────────────────────────────────
  static const Color background = Color(0xFF0C1324);
  static const Color surface = Color(0xFF0C1324);
  static const Color surfaceContainerLow = Color(0xFF151B2D);
  static const Color surfaceContainerHigh = Color(0xFF23293C);
  static const Color surfaceContainerHighest = Color(0xFF2E3447);
  static const Color surfaceBright = Color(0xFF33394C);
  
  static const Color primary = Color(0xFF4BE277);
  static const Color primaryContainer = Color(0xFF22C55E);
  static const Color secondary = Color(0xFFBEC6E0);
  static const Color outlineVariant = Color(0xFF3D4A3D);
  static const Color ghostWhite = Color(0xFFDCE1FB);

  // ─── Theme Data ────────────────────────────────────────────────────────────
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        background: background,
        surface: surface,
        primary: primary,
        secondary: secondary,
        onPrimary: Color(0xFF003915),
        onBackground: ghostWhite,
        onSurface: ghostWhite,
      ),
      scaffoldBackgroundColor: background,
      
      // Typography: utilitarian and precise
      textTheme: TextTheme(
        displayLarge: GoogleFonts.spaceGrotesk(
          fontSize: 48,
          fontWeight: FontWeight.bold,
          letterSpacing: -1.0,
          color: ghostWhite,
        ),
        headlineMedium: GoogleFonts.spaceGrotesk(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: ghostWhite,
        ),
        bodyLarge: GoogleFonts.inter(
          fontSize: 16,
          color: ghostWhite,
        ),
        bodySmall: GoogleFonts.firaCode(
          fontSize: 12,
          color: secondary,
        ),
        labelMedium: GoogleFonts.firaCode(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primary,
        ),
      ),
      
      // Components: 0px border radius for 'Forensic Lab' precision
      cardTheme: const CardThemeData(
        color: surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        elevation: 0,
      ),
      
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryContainer,
          foregroundColor: Colors.white,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          textStyle: GoogleFonts.spaceGrotesk(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ),
      
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: outlineVariant, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceContainerLow,
        border: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineVariant),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: outlineVariant),
        ),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: primary),
        ),
        labelStyle: GoogleFonts.firaCode(color: secondary),
        hintStyle: GoogleFonts.firaCode(color: secondary.withOpacity(0.5)),
      ),
    );
  }
}
