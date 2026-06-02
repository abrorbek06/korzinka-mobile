import 'package:flutter/material.dart';

class AppColors {
  // Core
  static const Color primary = Color(0xFF5C5FE4);
  static const Color primaryLight = Color(0xFFEEEFFC);
  static const Color primaryDark = Color(0xFF4547C2);

  // Backgrounds
  static const Color background = Color(0xFFF4F5FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FE);

  // Text
  static const Color textPrimary = Color(0xFF1A1D2E);
  static const Color textSecondary = Color(0xFF9699B5);
  static const Color textMuted = Color(0xFFBFC2D6);

  // Status section headers
  static const Color yangiColor = Color(0xFF22C55E); // Yangi - yashil
  static const Color tasdiqColor = Color(0xFF3B82F6); // Tasdiqlangan - ko'k
  static const Color yigColor = Color(0xFF5C5FE4); // Yig'ilmoqda - binafsha
  static const Color qismanColor = Color(0xFFF59E0B); // Qisman - to'q sariq
  static const Color tayyorColor = Color(0xFF10B981); // Tayyor - yashil
  static const Color yakunColor = Color(0xFF6B7280); // Yakunlangan - kulrang
  static const Color bekorColor = Color(0xFFEF4444); // Bekor - qizil

  // Item status
  static const Color itemGreen = Color(0xFF22C55E);
  static const Color itemOrange = Color(0xFFF59E0B);
  static const Color itemRed = Color(0xFFEF4444);

  // Utility
  static const Color divider = Color(0xFFEEEFF7);
  static const Color border = Color(0xFFE8E9F4);
  static const Color shadow = Color(0x0A5C5FE4);
}

class AppTheme {
  static const Color _background = Color(0xFFFFFFFF);
  static const Color _surface = Color(0xFFFFFFFF);
  static const Color _surfaceVariant = Color(0xFFF2F4FB);
  static const Color _primary = Color(0xFF6D5BFF);
  static const Color _secondary = Color(0xFF9CA3AF);
  static const Color _onPrimary = Color(0xFFFFFFFF);
  static const Color _onSurface = Color(0xFF111827);
  static const Color _onSurfaceMuted = Color(0xFF6B7280);
  static const Color _border = Color(0xFFDCE0EB);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: _background,
      colorScheme: const ColorScheme.light(
        primary: _primary,
        onPrimary: _onPrimary,
        secondary: _secondary,
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
        elevation: 10,
        scrolledUnderElevation: 0,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _onSurface,
          fontSize: 20,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.3,
        ),
      ),
      // cardTheme: CardTheme(
      //   color: _surface,
      //   elevation: 0,
      //   shape: RoundedRectangleBorder(
      //     borderRadius: BorderRadius.circular(18),
      //     side: const BorderSide(color: _border, width: 1),
      //   ),
      //   margin: EdgeInsets.zero,
      // ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        labelStyle: const TextStyle(color: _onSurfaceMuted),
        hintStyle: const TextStyle(color: _onSurfaceMuted),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceVariant,
        side: const BorderSide(color: _border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
