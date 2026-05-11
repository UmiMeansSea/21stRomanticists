import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens mirroring the Stitch/HTML reference design.
class AppColors {
  AppColors._();

  // --- Antigravity Light Palette ---
  static const background = Color(0xFFEFF7CF);
  static const surface = Color(0xFFEFF7CF);
  static const surfaceContainer = Color(0xFFBAD9B5);
  static const surfaceContainerLow = Color(0xFFE5EFD3); // Derived slightly lighter for depth
  static const surfaceContainerHigh = Color(0xFFD4E5C4); // Derived slightly darker
  static const surfaceContainerHighest = Color(0xFFC4D6B5);
  static const onSurface = Color(0xFFABA361);
  static const onSurfaceVariant = Color(0xFF7E766D);
  static const outline = Color(0xFFABA361);
  static const outlineVariant = Color(0xFFBAD9B5);
  static const primary = Color(0xFF732C2C);
  static const onPrimary = Color(0xFFEFF7CF);
  static const primaryContainer = Color(0xFF420C14);
  static const secondary = Color(0xFF420C14);
  static const onSecondary = Color(0xFFEFF7CF);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);

  // --- Antigravity Dark Palette ---
  static const romanticSurface = Color(0xFF420C14);
  static const romanticSurfaceContainer = Color(0xFF732C2C);
  static const romanticSurfaceBright = Color(0xFF8B3A3A);
  static const romanticOnSurface = Color(0xFFEFF7CF);
  static const romanticOnSurfaceVariant = Color(0xFFBAD9B5);
  static const romanticPrimary = Color(0xFFBAD9B5);
  static const romanticOnPrimary = Color(0xFF420C14);
  static const romanticBackground = Color(0xFF420C14);
  static const romanticSurfaceContainerLow = Color(0xFF5A161E);

  // Backward compatibility
  static const surfaceBright = Color(0xFF8B3A3A);
  static const accent = Color(0xFFBAD9B5);
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
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.onPrimary,
        secondary: AppColors.secondary,
        onSecondary: AppColors.onSecondary,
        surface: AppColors.surface,
        onSurface: AppColors.onSurface,
        surfaceContainer: AppColors.surfaceContainer,
        onSurfaceVariant: AppColors.onSurfaceVariant,
        error: AppColors.error,
        outline: AppColors.outline,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      textTheme: _buildTextTheme(isDark: false),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.background,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        surfaceTintColor: AppColors.primary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        indicatorColor: AppColors.primary.withValues(alpha: 0.1),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.onSurface),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.background,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.outlineVariant.withValues(alpha: 0.5), width: 0.5),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.outline.withValues(alpha: 0.1),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        fillColor: AppColors.surfaceContainerLow,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.onSurface.withValues(alpha: 0.5),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.background,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.onSurface.withValues(alpha: 0.6),
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500),
        showSelectedLabels: true,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainer,
        selectedColor: AppColors.primary,
        labelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.onSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.onPrimary,
        ),
        side: BorderSide(color: AppColors.outline.withValues(alpha: 0.3)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 2,
          shadowColor: AppColors.primary.withValues(alpha: 0.3),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surfaceContainerHigh,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.outline.withValues(alpha: 0.1)),
        ),
        textStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.primary, fontWeight: FontWeight.w500),
      ),
    );
  }

  static ThemeData get dark {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.romanticSurface,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.romanticPrimary,
        onPrimary: AppColors.romanticOnPrimary,
        primaryContainer: AppColors.romanticSurfaceContainer,
        onPrimaryContainer: AppColors.romanticOnSurface,
        secondary: AppColors.romanticOnSurfaceVariant,
        onSecondary: AppColors.romanticSurface,
        surface: AppColors.romanticSurface,
        onSurface: AppColors.romanticOnSurface,
        surfaceContainer: AppColors.romanticSurfaceContainer,
        onSurfaceVariant: AppColors.romanticOnSurfaceVariant,
        error: AppColors.error,
        outline: AppColors.romanticOnSurfaceVariant,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.romanticSurface,
        foregroundColor: AppColors.romanticOnSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.ebGaramond(
          fontSize: 24,
          fontWeight: FontWeight.w600,
          color: AppColors.romanticOnSurface,
          letterSpacing: -0.5,
        ),
        iconTheme: const IconThemeData(color: AppColors.romanticOnSurface),
      ),
      textTheme: _buildTextTheme(isDark: true),
      drawerTheme: DrawerThemeData(
        backgroundColor: AppColors.romanticBackground,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
        ),
        surfaceTintColor: AppColors.romanticPrimary,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.romanticSurfaceContainerLow,
        indicatorColor: AppColors.romanticPrimary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.romanticOnSurface),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.romanticSurfaceContainer,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.romanticPrimary.withValues(alpha: 0.1), width: 1.0),
        ),
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: AppColors.romanticOnSurface.withValues(alpha: 0.1),
        space: 1,
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.1)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.1)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.romanticPrimary, width: 2),
        ),
        fillColor: AppColors.romanticSurfaceContainer.withValues(alpha: 0.5),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        hintStyle: GoogleFonts.inter(
          fontSize: 16,
          color: AppColors.romanticOnSurface.withValues(alpha: 0.4),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: AppColors.romanticSurface,
        selectedItemColor: AppColors.romanticPrimary,
        unselectedItemColor: AppColors.romanticOnSurface.withValues(alpha: 0.5),
        selectedLabelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
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
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: AppColors.romanticOnSurface,
        ),
        secondaryLabelStyle: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.romanticSurface,
        ),
        side: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.1)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.romanticPrimary,
          foregroundColor: AppColors.romanticSurface,
          elevation: 4,
          shadowColor: AppColors.romanticPrimary.withValues(alpha: 0.2),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.romanticSurfaceContainer,
        elevation: 12,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppColors.romanticOnSurface.withValues(alpha: 0.1)),
        ),
        textStyle: GoogleFonts.inter(fontSize: 15, color: AppColors.romanticOnSurface, fontWeight: FontWeight.w500),
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
