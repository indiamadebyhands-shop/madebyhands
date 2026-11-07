import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  // Artistic Earthy Palette
  static const background = Color(0xFFFCF0DE); // App's Beige/Cream Background
  static const surface = Color(0xFFFFFFFF);
  static const primary = Color(0xFF6B7E43); // Sage Green
  static const primaryDark = Color(0xFF3E4B25);
  static const accent = Color(0xFFCD7B4E); // Terracotta
  static const accentLight = Color(0xFFE7AD8B);
  static const text = Color(0xFF2D3128); // Deep Charcoal Green
  static const mutedText = Color(0xFF8A8F82);
  static const outline = Color(0xFFEAE7DC);

  // New "Baked" colors from references
  static const sienna = Color(0xFF8B4513);
  static const gold = Color(0xFFE7C889);
  static const pinkArchTop = Color(0xFFEF7790); // Solid Pink for Decorative Arch
}

const defaultSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0xFFFCF0DE),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0xFFFCF0DE),
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
);

const pinkArchSystemUiOverlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0xFFEF7790),
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0xFFFCF0DE),
  systemNavigationBarDividerColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.dark,
);

class AppTheme {
  static OutlineInputBorder _border([Color color = Colors.grey]) =>
      OutlineInputBorder(
        borderSide: BorderSide(color: color, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      );

  static final lightThemeMode = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      secondary: AppColors.accent,
      surface: AppColors.surface,
      onSurface: AppColors.text,
    ),
    scaffoldBackgroundColor: AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.background,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      systemOverlayStyle: defaultSystemUiOverlayStyle,
      titleTextStyle: GoogleFonts.montserrat(
        color: AppColors.text,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Color(0xFFFCF0DE),
      indicatorColor: Color(0xFFDDE5CA),
    ),
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.outline),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        side: const BorderSide(color: AppColors.primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: GoogleFonts.montserrat(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    textTheme: GoogleFonts.montserratTextTheme()
        .copyWith(
          displayLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w900,
            color: AppColors.text,
          ),
          displayMedium: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.w800,
            color: AppColors.text,
          ),
          headlineLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          headlineMedium: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
          titleLarge: GoogleFonts.playfairDisplay(
            fontWeight: FontWeight.bold,
            color: AppColors.text,
          ),
        )
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      border: _border(AppColors.outline),
      enabledBorder: _border(AppColors.outline),
      focusedBorder: _border(AppColors.primary),
      errorBorder: _border(Colors.redAccent),
      labelStyle: const TextStyle(color: AppColors.mutedText),
      hintStyle: const TextStyle(color: AppColors.mutedText),
    ),
  );
}
