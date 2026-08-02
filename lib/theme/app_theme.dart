import 'package:flutter/material.dart';

/// PrestaMesta brand palette, taken from prestamesta.fun
/// (meta-theme-color: #0c222f, green gradient cards on the demo screens).
class AppColors {
  AppColors._();

  static const Color navy = Color(0xFF0C222F); // primary dark
  static const Color navyLight = Color(0xFF16324A);
  static const Color background = Color(0xFFF4F7F8);
  static const Color card = Color(0xFFFFFFFF);
  static const Color greenStart = Color(0xFF0E7C61);
  static const Color greenEnd = Color(0xFF1DA679);
  static const Color textPrimary = Color(0xFF0C222F);
  static const Color textSecondary = Color(0xFF6B7A81);
  static const Color divider = Color(0xFFE4EAEC);
  static const Color warningBg = Color(0xFFEFF4F5);
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.navy,
        primary: AppColors.navy,
        secondary: AppColors.greenEnd,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
