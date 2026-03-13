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
  static ThemeData forSkin(AppSkin skin, {bool darkMode = false}) {
    final brightness = darkMode ? Brightness.dark : Brightness.light;

    switch (skin) {
      case AppSkin.light:
        return _buildFromSeed(primarySeed, secondarySeed, tertiarySeed, brightness);
      case AppSkin.dark:
        // "Teal Dark" skin — always uses teal seed colors in dark mode.
        return _buildFromSeed(primarySeed, secondarySeed, tertiarySeed, Brightness.dark);
      case AppSkin.sunset:
        return _buildFromSeed(_sunsetPrimary, _sunsetSecondary, _sunsetTertiary, brightness);
      case AppSkin.ocean:
        return _buildFromSeed(_oceanPrimary, _oceanSecondary, _oceanTertiary, brightness);
      case AppSkin.lavender:
        return _buildFromSeed(_lavenderPrimary, _lavenderSecondary, _lavenderTertiary, brightness);
    }
  }

  static ThemeData _buildFromSeed(
      Color primary, Color secondary, Color tertiary, Brightness brightness) {
    return _build(
      ColorScheme.fromSeed(
        seedColor: primary,
        secondary: secondary,
        tertiary: tertiary,
        brightness: brightness,
      ),
      brightness,
    );
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

  // ── Legacy accessors (kept for compatibility) ────────────────────────────
  static ThemeData get lightTheme => forSkin(AppSkin.light);
  static ThemeData get darkTheme => forSkin(AppSkin.dark);
  static ThemeData get sunsetTheme => forSkin(AppSkin.sunset);
  static ThemeData get oceanTheme => forSkin(AppSkin.ocean);
  static ThemeData get lavenderTheme => forSkin(AppSkin.lavender);
}
