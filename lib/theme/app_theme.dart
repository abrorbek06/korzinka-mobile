import 'package:flutter/material.dart';

class AppTheme {
  // Palette: deep navy background, warm slate surface, amber accent
  static const Color _background = Color(0xFF0F1923);
  static const Color _surface = Color(0xFF1A2535);
  static const Color _surfaceVariant = Color(0xFF243042);
  static const Color _primary = Color(0xFFF59E0B); // amber
  static const Color _primaryDark = Color(0xFFD97706);
  static const Color _onPrimary = Color(0xFF0F1923);
  static const Color _onSurface = Color(0xFFE8EDF4);
  static const Color _onSurfaceMuted = Color(0xFF8A9BB5);
  static const Color _border = Color(0xFF2E3F58);

  static ThemeData get dark {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.dark(
        primary: _primary,
        onPrimary: _onPrimary,
        secondary: Color(0xFF38BDF8),
        onSecondary: _onPrimary,
        surface: _surface,
        onSurface: _onSurface,
        error: Color(0xFFEF4444),
        onError: Colors.white,
        outline: _border,
      ),
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _onSurface,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _onSurface,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        labelStyle: const TextStyle(color: _onSurfaceMuted),
        hintStyle: const TextStyle(color: _onSurfaceMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _onSurface,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _border, thickness: 1),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w800,
          color: _onSurface,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: _onSurface,
          letterSpacing: -0.3,
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: _onSurface,
        ),
        titleMedium: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        titleSmall: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: _onSurfaceMuted,
          letterSpacing: 0.5,
        ),
        bodyLarge: TextStyle(fontSize: 15, color: _onSurface),
        bodyMedium: TextStyle(fontSize: 13, color: _onSurface),
        bodySmall: TextStyle(fontSize: 12, color: _onSurfaceMuted),
        labelSmall: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
          color: _onSurfaceMuted,
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }

  static const Color background = _background;
  static const Color surface = _surface;
  static const Color surfaceVariant = _surfaceVariant;
  static const Color primary = _primary;
  static const Color onSurface = _onSurface;
  static const Color onSurfaceMuted = _onSurfaceMuted;
  static const Color border = _border;
}
