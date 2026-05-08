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
}

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.primary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        shadowColor: AppColors.outlineVariant.withValues(alpha: 0.2),
        centerTitle: true,
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w500,
          color: AppColors.primary,
          letterSpacing: -0.3,
        ),
      ),
      textTheme: _buildTextTheme(),
      cardTheme: CardThemeData(
        color: AppColors.surfaceContainerLow,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
        ),
        margin: EdgeInsets.zero,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.outlineVariant,
        space: 1,
        thickness: 0.4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        fillColor: AppColors.surfaceContainerLow,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.literata(
          fontSize: 16,
          color: AppColors.onSurfaceVariant,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurfaceVariant,
        selectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerHigh,
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurfaceVariant,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.08,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.onSurface,
        contentTextStyle: GoogleFonts.literata(
          color: AppColors.background,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // displayLarge → EB Garamond 42px  (display-lg)
      displayLarge: GoogleFonts.ebGaramond(
        fontSize: 42,
        fontWeight: FontWeight.w500,
        height: 1.1,
        letterSpacing: -0.02 * 42,
        color: AppColors.onSurface,
      ),
      // headlineLarge → EB Garamond 32px  (headline-lg)
      headlineLarge: GoogleFonts.ebGaramond(
        fontSize: 32,
        fontWeight: FontWeight.w500,
        height: 1.2,
        color: AppColors.onSurface,
      ),
      // headlineMedium → EB Garamond 24px (headline-md)
      headlineMedium: GoogleFonts.ebGaramond(
        fontSize: 24,
        fontWeight: FontWeight.w500,
        height: 1.3,
        color: AppColors.onSurface,
      ),
      // bodyLarge → Literata 18px (body-lg)
      bodyLarge: GoogleFonts.literata(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AppColors.onSurface,
      ),
      // bodyMedium → Literata 16px (body-md)
      bodyMedium: GoogleFonts.literata(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: AppColors.onSurface,
      ),
      // labelLarge → Inter 14px (label-lg)
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.05 * 14,
        color: AppColors.onSurface,
      ),
      // labelMedium → Inter 12px (label-md)
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.onSurfaceVariant,
      ),
      // bodySmall → Literata 13px (caption)
      bodySmall: GoogleFonts.literata(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: AppColors.onSurfaceVariant,
      ),
    );
  }
}
