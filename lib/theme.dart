import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData light = ThemeData(
    colorScheme: const ColorScheme.light(
      primary: Color(0xFF006C4F),
      secondary: Color(0xFF1E88E5),
      surface: Colors.white,
      background: Colors.white,
      error: Color(0xFFB00020),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
    useMaterial3: true,
  );

  static ThemeData dark = ThemeData(
    colorScheme: const ColorScheme.dark(
      primary: Color(0xFF80D2BD),
      secondary: Color(0xFF90CAF9),
      surface: Color(0xFF121212),
      background: Color(0xFF101012),
      error: Color(0xFFCF6679),
    ),
    scaffoldBackgroundColor: const Color(0xFF0F1113),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      titleMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      bodyLarge: TextStyle(fontSize: 16),
      bodyMedium: TextStyle(fontSize: 14),
    ),
    useMaterial3: true,
  );
}
