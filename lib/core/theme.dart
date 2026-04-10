import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/theme_provider.dart';

class AppTheme {
  // ── Brand colours (app icon: pink → orange → purple) ─────────────────────────
  static const Color primarySeed  = Color(0xFFE91E63); // QoreHealth Pink
  static const Color secondarySeed = Color(0xFFFF6D00); // Orange
  static const Color tertiarySeed  = Color(0xFF7B1FA2); // Purple

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
  // Aggressive weight hierarchy: Black/ExtraBold headlines, Bold titles,
  // Medium body, Regular captions. Tight letter-spacing on large text.
  static TextTheme _textTheme(Brightness brightness) {
    final color = brightness == Brightness.dark ? Colors.white : Colors.black;

    return TextTheme(
      // Display — hero numbers, big stats
      displayLarge:  GoogleFonts.plusJakartaSans(fontSize: 57, fontWeight: FontWeight.w900, letterSpacing: -1.5, color: color),
      displayMedium: GoogleFonts.plusJakartaSans(fontSize: 45, fontWeight: FontWeight.w800, letterSpacing: -1.0, color: color),
      displaySmall:  GoogleFonts.plusJakartaSans(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: color),

      // Headline — screen titles, section headers
      headlineLarge:  GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: color),
      headlineMedium: GoogleFonts.plusJakartaSans(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.3, color: color),
      headlineSmall:  GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: color),

      // Title — card titles, list headers
      titleLarge:  GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: color),
      titleMedium: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: color),
      titleSmall:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0, color: color),

      // Body — readable paragraphs, descriptions
      bodyLarge:  GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.5, color: color),
      bodyMedium: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w400, letterSpacing: 0.1, height: 1.4, color: color),
      bodySmall:  GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w400, letterSpacing: 0.2, height: 1.4, color: color),

      // Label — buttons, chips, badges, captions
      labelLarge:  GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1, color: color),
      labelMedium: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.3, color: color),
      labelSmall:  GoogleFonts.plusJakartaSans(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5, color: color),
    );
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
        centerTitle: false,
        elevation: 0,
        backgroundColor: cs.surface,
        foregroundColor: cs.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: cs.onSurface,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: cs.outlineVariant.withValues(alpha: 0.2),
          ),
        ),
        color: cs.surfaceContainerLow,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 28),
          textStyle: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w600),
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
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeScaleTransitionBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: _FadeScaleTransitionBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: _FadeScaleTransitionBuilder(),
        },
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

/// Fade + subtle scale page transition (Material 3 style, 300ms).
class _FadeScaleTransitionBuilder extends PageTransitionsBuilder {
  const _FadeScaleTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.96, end: 1.0).animate(
          CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
        ),
        child: child,
      ),
    );
  }
}
