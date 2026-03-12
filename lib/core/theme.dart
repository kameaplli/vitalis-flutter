import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  // ── Brand colours ────────────────────────────────────────────────────────────
  static const Color primarySeed  = Color(0xFF1A6B5C); // Vitalis Teal
  static const Color secondarySeed = Color(0xFFD97706); // Amber
  static const Color tertiarySeed  = Color(0xFF4F46E5); // Indigo

  // ── Sunset skin colours ──────────────────────────────────────────────────────
  static const Color _sunsetPrimary   = Color(0xFFB5451B); // Burnt orange
  static const Color _sunsetSecondary = Color(0xFF9B2C6E); // Magenta rose
  static const Color _sunsetTertiary  = Color(0xFF6D28D9); // Violet

  // ── Ocean Blue skin colours ────────────────────────────────────────────────
  static const Color _oceanPrimary    = Color(0xFF1565C0); // Strong blue
  static const Color _oceanSecondary  = Color(0xFF00897B); // Teal accent
  static const Color _oceanTertiary   = Color(0xFFFF8F00); // Warm amber

  // ── Lavender skin colours ──────────────────────────────────────────────────
  static const Color _lavenderPrimary   = Color(0xFF7B1FA2); // Deep purple
  static const Color _lavenderSecondary = Color(0xFFE91E63); // Pink accent
  static const Color _lavenderTertiary  = Color(0xFF00ACC1); // Cyan

  // ── Typography ─────────────────────────────────────────────────────────────
  static TextTheme _textTheme(Brightness brightness) {
    final base = brightness == Brightness.dark
        ? ThemeData.dark().textTheme
        : ThemeData.light().textTheme;
    return GoogleFonts.plusJakartaSansTextTheme(base);
  }

  // ── Resolve skin → ThemeData ───────────────────────────────────────────────
  static ThemeData forSkin(AppSkin skin) {
    switch (skin) {
      case AppSkin.light:
        return lightTheme;
      case AppSkin.dark:
        return darkTheme;
      case AppSkin.sunset:
        return sunsetTheme;
      case AppSkin.ocean:
        return oceanTheme;
      case AppSkin.lavender:
        return lavenderTheme;
    }
  }

  // ── Shared component config ────────────────────────────────────────────────
  static ThemeData _build(ColorScheme cs, Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: cs,
      textTheme: _textTheme(brightness),
      appBarTheme: AppBarTheme(
        centerTitle: true,
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 3,
        indicatorColor: cs.primaryContainer,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return IconThemeData(color: cs.onPrimaryContainer);
          }
          return IconThemeData(color: cs.onSurfaceVariant);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final font = GoogleFonts.plusJakartaSans(fontSize: 11);
          if (states.contains(WidgetState.selected)) {
            return font.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            );
          }
          return font.copyWith(color: cs.onSurfaceVariant);
        }),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  // ── Light theme (Daylight) ─────────────────────────────────────────────────
  static ThemeData get lightTheme => _build(
        ColorScheme.fromSeed(
          seedColor: primarySeed,
          secondary: secondarySeed,
          tertiary: tertiarySeed,
          brightness: Brightness.light,
        ),
        Brightness.light,
      );

  // ── Dark theme ─────────────────────────────────────────────────────────────
  static ThemeData get darkTheme => _build(
        ColorScheme.fromSeed(
          seedColor: primarySeed,
          secondary: secondarySeed,
          tertiary: tertiarySeed,
          brightness: Brightness.dark,
        ),
        Brightness.dark,
      );

  // ── Sunset Glow theme ──────────────────────────────────────────────────────
  static ThemeData get sunsetTheme => _build(
        ColorScheme.fromSeed(
          seedColor: _sunsetPrimary,
          secondary: _sunsetSecondary,
          tertiary: _sunsetTertiary,
          brightness: Brightness.light,
        ),
        Brightness.light,
      );

  // ── Ocean Blue theme ──────────────────────────────────────────────────────
  static ThemeData get oceanTheme => _build(
        ColorScheme.fromSeed(
          seedColor: _oceanPrimary,
          secondary: _oceanSecondary,
          tertiary: _oceanTertiary,
          brightness: Brightness.light,
        ),
        Brightness.light,
      );

  // ── Lavender theme ────────────────────────────────────────────────────────
  static ThemeData get lavenderTheme => _build(
        ColorScheme.fromSeed(
          seedColor: _lavenderPrimary,
          secondary: _lavenderSecondary,
          tertiary: _lavenderTertiary,
          brightness: Brightness.light,
        ),
        Brightness.light,
      );
}
