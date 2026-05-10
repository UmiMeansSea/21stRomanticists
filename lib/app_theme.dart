import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens mirroring the Stitch/HTML reference design.
class AppColors {
  AppColors._();

  static const background = Color(0xFFFBF9F3);
  static const surface = Color(0xFFFBF9F3);
  static const surfaceContainer = Color(0xFFEFEEE8);
  static const surfaceContainerLow = Color(0xFFF5F4EE);
  static const surfaceContainerHigh = Color(0xFFE9E8E2);
  static const surfaceContainerHighest = Color(0xFFE4E3DD);
  static const onSurface = Color(0xFF1B1C19);
  static const onSurfaceVariant = Color(0xFF4C463E);
  static const outline = Color(0xFF7E766D);
  static const outlineVariant = Color(0xFFCFC5BB);
  static const primary = Color(0xFF000000);
  static const onPrimary = Color(0xFFFFFFFF);
  static const primaryContainer = Color(0xFF221A10);
  static const secondary = Color(0xFF3A6189);
  static const onSecondary = Color(0xFFFFFFFF);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);

  // Forest green accent from brief
  static const accent = Color(0xFF4A7C59);

  // Modern Romanticist (Dark Palette)
  static const romanticSurface = Color(0xFF1A1816);
  static const romanticSurfaceContainer = Color(0xFF252320);
  static const romanticSurfaceBright = Color(0xFF33302C);
  static const romanticOnSurface = Color(0xFFFBF9F3);
  static const romanticOnSurfaceVariant = Color(0xFFDBDAD4);
  static const romanticPrimary = Color(0xFFC1A68D);
  static const romanticOnPrimary = Color(0xFF1A1816);

  // Alias for backward compatibility during transition
  static const surfaceBright = Color(0xFF33302C);
}

class AppTheme {
  AppTheme._();

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.romanticSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.romanticPrimary,
        onPrimary: AppColors.romanticSurface,
        secondary: AppColors.romanticPrimary,
        onSecondary: AppColors.romanticSurface,
        surface: AppColors.romanticSurface,
        onSurface: AppColors.romanticOnSurface,
        surfaceContainer: AppColors.romanticSurfaceContainer,
        onSurfaceVariant: AppColors.romanticOnSurfaceVariant,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.romanticSurface,
        foregroundColor: AppColors.romanticOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 22,
          fontWeight: FontWeight.w500,
          color: AppColors.romanticOnSurface,
          letterSpacing: -0.3,
        ),
        iconTheme: const IconThemeData(color: AppColors.romanticOnSurface),
      ),
      textTheme: _buildTextTheme(isDark: true),
      cardTheme: CardThemeData(
        color: AppColors.romanticSurfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: AppColors.romanticOnSurface.withValues(alpha: 0.1),
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.romanticOnSurface.withValues(alpha: 0.1),
        space: 1,
        thickness: 0.5,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.romanticPrimary, width: 1.5),
        ),
        fillColor: AppColors.romanticSurfaceContainer,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.literata(
          fontSize: 16,
          color: AppColors.romanticOnSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.romanticSurface,
        selectedItemColor: AppColors.romanticPrimary,
        unselectedItemColor: AppColors.romanticOnSurfaceVariant,
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.romanticSurfaceContainer,
        selectedColor: AppColors.romanticPrimary,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.romanticOnSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.romanticSurface,
        ),
        side: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.romanticPrimary,
          foregroundColor: AppColors.romanticSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme({bool isDark = false}) {
    final color = isDark ? AppColors.romanticOnSurface : AppColors.onSurface;
    final variantColor = isDark ? AppColors.romanticOnSurfaceVariant : AppColors.onSurfaceVariant;

    return TextTheme(
      displayLarge: GoogleFonts.ebGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w500,
        height: 1.1,
        letterSpacing: -0.02 * 42,
        color: color,
      ),
      headlineLarge: GoogleFonts.ebGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: color,
      ),
      headlineMedium: GoogleFonts.ebGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: color,
      ),
      bodyLarge: GoogleFonts.literata(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      ),
      bodyMedium: GoogleFonts.literata(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: color,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05 * 14,
        color: color,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: variantColor,
      ),
      bodySmall: GoogleFonts.literata(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: variantColor,
      ),
    );
  }
}
