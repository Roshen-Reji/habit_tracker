import 'package:flutter/material.dart';

class AppTheme {
  // Colors
  static const Color primary = Colors.tealAccent;
  static const Color background = Colors.black;
  static const Color surface = Color(0xFF1C1C1E);
  static const Color surfaceLight = Color(0xFF2C2C2E);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Colors.white70;
  static const Color textFaded = Colors.white24;

  // Gradients
  static const LinearGradient glassGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x26FFFFFF), // 15% white
      Color(0x0DFFFFFF), // 5% white
    ],
  );

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      colorScheme: const ColorScheme.dark(
        primary: primary,
        surface: surface,
      ),
      // Set the default font if you want, else leave standard
      // fontFamily: 'Inter',
    );
  }
}
