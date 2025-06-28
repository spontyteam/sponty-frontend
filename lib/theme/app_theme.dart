import 'package:flutter/material.dart';
import 'colors.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.highlightDark,
    scaffoldBackgroundColor: AppColors.neutralLightLightest,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.highlightDark,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    textTheme: TextTheme(
      bodyLarge: TextStyle(color: AppColors.neutralDarkest),
      bodyMedium: TextStyle(color: AppColors.neutralDark),
      titleLarge: TextStyle(
        color: AppColors.highlightDarkest,
        fontWeight: FontWeight.bold,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.pinMain,
    ),
  );
}
