import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';

/// A high-quality, Instagram-story-sized (1080x1920) shareable card widget.
///
/// Supported card types:
/// - `daily_nutrition` — macro breakdown, micronutrient highlights
/// - `streak` — current streak, avg calories, avg hydration
/// - `weekly_report` — 7-day averages, consistency score
/// - `achievement` — badge name, description, date earned
class ShareCardGenerator extends StatelessWidget {
  final GlobalKey repaintBoundaryKey;
  final String cardType;
  final Map<String, dynamic> data;

  const ShareCardGenerator({
    super.key,
    required this.repaintBoundaryKey,
    required this.cardType,
    required this.data,
  });

  // ── Gradient definitions ────────────────────────────────────────────────

  static const _gradients = <String, List<Color>>{
    'daily_nutrition': [Color(0xFF0D7377), Color(0xFF064E50)],
    'streak': [Color(0xFFF97316), Color(0xFFD97706)],
    'weekly_report': [Color(0xFF6366F1), Color(0xFF7C3AED)],
    'achievement': [Color(0xFFF59E0B), Color(0xFFB45309)],
  };

  static const _icons = <String, IconData>{
    'daily_nutrition': Icons.restaurant_menu,
    'streak': Icons.local_fire_department,
    'weekly_report': Icons.bar_chart_rounded,
    'achievement': Icons.emoji_events,
  };

  static const _titles = <String, String>{
    'daily_nutrition': "TODAY'S NUTRITION",
    'streak': 'LOGGING STREAK',
    'weekly_report': 'WEEKLY REPORT',
    'achievement': 'ACHIEVEMENT UNLOCKED',
  };

  /// Renders the RepaintBoundary to a PNG image at 3x scale.
  static Future<Uint8List?> renderToImage(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[cardType] ??
        const [Color(0xFF64748B), Color(0xFF94A3B8)];
    final headerTitle = _titles[cardType] ?? 'VITALIS';

    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Container(
        width: 360,
        height: 640,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              // ── User Header ──────────────────────────────────────────
              _buildUserHeader(),
              const SizedBox(height: 20),
              // ── Main Content ─────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildGlassSection(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            headerTitle,
                            style: _labelStyle(11, FontWeight.w700,
                                letterSpacing: 1.5),
                          ),
                          const SizedBox(height: 12),
                          _buildCardContent(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (cardType == 'daily_nutrition' ||
                        cardType == 'weekly_report')
                      _buildMicroSection(),
                    const Spacer(),
                    // ── Footer ────────────────────────────────────────────
                    _buildFooter(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── User Header ──────────────────────────────────────────────────────────

  Widget _buildUserHeader() {
    final userName = data['user_display_name'] ?? 'Vitalis User';
    final dateStr = data['date'] ?? '';

    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withOpacity(0.2),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
          ),
          child: const Icon(Icons.person, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              userName,
              style: _textStyle(16, FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              _formatDate(dateStr),
              style: _textStyle(12, FontWeight.w400,
                  color: Colors.white.withOpacity(0.7)),
            ),
          ],
        ),
      ],
    );
  }

  // ── Card Content (varies by type) ────────────────────────────────────────

  Widget _buildCardContent() {
    switch (cardType) {
      case 'daily_nutrition':
        return _buildDailyNutrition();
      case 'streak':
        return _buildStreak();
      case 'weekly_report':
        return _buildWeeklyReport();
      case 'achievement':
        return _buildAchievement();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDailyNutrition() {
    final calories = (data['total_calories'] as num?)?.toDouble() ?? 0;
    final goalPercent = (data['goal_percent'] as num?)?.toDouble() ?? 0;
    final protein = (data['protein'] as num?)?.toDouble() ?? 0;
    final carbs = (data['carbs'] as num?)?.toDouble() ?? 0;
    final fat = (data['fat'] as num?)?.toDouble() ?? 0;
    final mealsCount = (data['meals_count'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calories
        Text(
          '${calories.toInt().toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} kcal',
          style: _textStyle(32, FontWeight.w800),
        ),
        const SizedBox(height: 8),
        // Progress bar
        _buildProgressBar(goalPercent / 100, '${goalPercent.toInt()}% of goal'),
        const SizedBox(height: 6),
        Text(
          '$mealsCount meals logged',
          style: _textStyle(11, FontWeight.w400,
              color: Colors.white.withOpacity(0.6)),
        ),
        const SizedBox(height: 16),
        // Macro cards
        Row(
          children: [
            _buildMacroCard('P', '${protein.toInt()}g', const Color(0xFF22D3EE)),
            const SizedBox(width: 10),
            _buildMacroCard('C', '${carbs.toInt()}g', const Color(0xFF34D399)),
            const SizedBox(width: 10),
            _buildMacroCard('F', '${fat.toInt()}g', const Color(0xFFFBBF24)),
          ],
        ),
      ],
    );
  }

  Widget _buildStreak() {
    final streakDays = (data['streak_days'] as num?)?.toInt() ?? 0;
    final avgCalories = (data['avg_calories'] as num?)?.toDouble() ?? 0;
    final avgHydration = (data['avg_hydration'] as num?)?.toDouble() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Text(
            '$streakDays',
            style: _textStyle(72, FontWeight.w900),
          ),
        ),
        Center(
          child: Text(
            'DAYS',
            style: _labelStyle(14, FontWeight.w700, letterSpacing: 3),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildStatColumn('Avg Cal', '${avgCalories.toInt()}', Icons.local_fire_department),
            _buildStatColumn('Avg Water', '${avgHydration.toInt()} ml', Icons.water_drop),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyReport() {
    final avgCalories = (data['avg_daily_calories'] as num?)?.toDouble() ?? 0;
    final avgProtein = (data['avg_protein'] as num?)?.toDouble() ?? 0;
    final avgCarbs = (data['avg_carbs'] as num?)?.toDouble() ?? 0;
    final avgFat = (data['avg_fat'] as num?)?.toDouble() ?? 0;
    final consistency = (data['consistency_score'] as num?)?.toDouble() ?? 0;
    final daysLogged = (data['days_logged'] as num?)?.toInt() ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${avgCalories.toInt()} kcal/day',
          style: _textStyle(28, FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '$daysLogged of 7 days logged',
          style: _textStyle(12, FontWeight.w400,
              color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(height: 12),
        _buildProgressBar(
            consistency / 100, '${consistency.toInt()}% consistency'),
        const SizedBox(height: 16),
        Row(
          children: [
            _buildMacroCard(
                'P', '${avgProtein.toInt()}g', const Color(0xFF22D3EE)),
            const SizedBox(width: 10),
            _buildMacroCard(
                'C', '${avgCarbs.toInt()}g', const Color(0xFF34D399)),
            const SizedBox(width: 10),
            _buildMacroCard(
                'F', '${avgFat.toInt()}g', const Color(0xFFFBBF24)),
          ],
        ),
      ],
    );
  }

  Widget _buildAchievement() {
    final badgeName = data['badge_name'] ?? 'Achievement';
    final badgeDesc = data['badge_description'] ?? '';
    final dateEarned = data['date_earned'] ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 8),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.emoji_events,
                color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            badgeName,
            style: _textStyle(22, FontWeight.w800),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            badgeDesc,
            style: _textStyle(13, FontWeight.w400,
                color: Colors.white.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Earned ${_formatDate(dateEarned)}',
            style: _textStyle(11, FontWeight.w400,
                color: Colors.white.withOpacity(0.6)),
          ),
        ),
      ],
    );
  }

  // ── Micronutrient Section ────────────────────────────────────────────────

  Widget _buildMicroSection() {
    final highlights = cardType == 'daily_nutrition'
        ? (data['micro_highlights'] as List<dynamic>? ?? [])
        : (data['top_nutrients'] as List<dynamic>? ?? []);

    if (highlights.isEmpty) return const SizedBox.shrink();

    return _buildGlassSection(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cardType == 'daily_nutrition'
                ? 'MICRONUTRIENT HIGHLIGHTS'
                : 'TOP NUTRIENTS',
            style: _labelStyle(11, FontWeight.w700, letterSpacing: 1.5),
          ),
          const SizedBox(height: 12),
          ...highlights.map((h) {
            final name = (h as Map<String, dynamic>)['name'] ?? '';
            final pct = (h['percent_dri'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildNutrientBar(name, pct),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNutrientBar(String name, double percentDri) {
    final clampedPct = percentDri.clamp(0, 200) / 200; // scale for display

    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            name,
            style: _textStyle(12, FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: clampedPct,
              minHeight: 8,
              backgroundColor: Colors.white.withOpacity(0.15),
              valueColor: AlwaysStoppedAnimation<Color>(
                percentDri >= 100
                    ? const Color(0xFF34D399)
                    : percentDri >= 70
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFF87171),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          child: Text(
            '${percentDri.toInt()}%',
            style: _textStyle(12, FontWeight.w600),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  // ── Footer ──────────────────────────────────────────────────────────────

  Widget _buildFooter() {
    final deepLink = data['deep_link'] ?? 'vitalis.app';

    return _buildGlassSection(
      child: Row(
        children: [
          // Vitalis branding
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.15),
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Vitalis',
                  style: _textStyle(14, FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  deepLink,
                  style: _textStyle(10, FontWeight.w400,
                      color: Colors.white.withOpacity(0.6)),
                ),
              ],
            ),
          ),
          // QR placeholder
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.white.withOpacity(0.15),
            ),
            child:
                const Icon(Icons.qr_code_2, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }

  // ── Shared Helpers ──────────────────────────────────────────────────────

  Widget _buildGlassSection({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }

  Widget _buildMacroCard(String label, String value, Color accent) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(label,
                style: _textStyle(13, FontWeight.w700, color: accent)),
            const SizedBox(height: 4),
            Text(value, style: _textStyle(15, FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressBar(double progress, String label) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.clamp(0, 1),
            minHeight: 10,
            backgroundColor: Colors.white.withOpacity(0.15),
            valueColor:
                const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: _textStyle(11, FontWeight.w500,
              color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white.withOpacity(0.7), size: 20),
        const SizedBox(height: 6),
        Text(value, style: _textStyle(18, FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: _textStyle(11, FontWeight.w400,
                color: Colors.white.withOpacity(0.6))),
      ],
    );
  }

  // ── Typography Helpers ──────────────────────────────────────────────────

  TextStyle _textStyle(double size, FontWeight weight, {Color? color}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: color ?? Colors.white,
    );
  }

  TextStyle _labelStyle(double size, FontWeight weight,
      {double letterSpacing = 0}) {
    return GoogleFonts.plusJakartaSans(
      fontSize: size,
      fontWeight: weight,
      color: Colors.white.withOpacity(0.7),
      letterSpacing: letterSpacing,
    );
  }

  // ── Date Formatting ────────────────────────────────────────────────────

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      const months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (_) {
      return dateStr;
    }
  }
}
