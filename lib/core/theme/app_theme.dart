import 'package:flutter/material.dart';

/// Tema visual do MDuck Lives — estilo gamer moderno, escuro, preto e roxo.
class AppTheme {
  static const Color background = Color(0xFF0E0B16);
  static const Color surface = Color(0xFF1A1425);
  static const Color primaryPurple = Color(0xFF7B2CBF);
  static const Color accentPurple = Color(0xFF9D4EDD);
  static const Color textLight = Color(0xFFF2E9FF);

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      colorScheme: const ColorScheme.dark(
        primary: primaryPurple,
        secondary: accentPurple,
        surface: surface,
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(
          color: textLight,
          fontWeight: FontWeight.bold,
          fontSize: 24,
        ),
        bodyMedium: TextStyle(color: textLight, fontSize: 16),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        elevation: 0,
      ),
      useMaterial3: true,
    );
  }
}
