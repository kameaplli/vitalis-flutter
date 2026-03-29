import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// GitHub-style activity heatmap showing streak days.
/// Each cell = one day, color intensity = activity level.
class StreakCalendar extends StatelessWidget {
  final int currentStreak;
  final int longestStreak;
  final Set<DateTime> activeDays;
  final int weeksToShow;

  const StreakCalendar({
    super.key,
    required this.currentStreak,
    required this.longestStreak,
    this.activeDays = const {},
    this.weeksToShow = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedFire,
                  color: _streakColor(currentStreak), size: 22),
              const SizedBox(width: 6),
              Text(
                '$currentStreak day streak',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _streakColor(currentStreak),
                ),
              ),
              const Spacer(),
              Text(
                'Best: $longestStreak',
                style: tt.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Heatmap grid
          SizedBox(
            height: 7 * 14.0, // 7 days * cell size
            child: _buildHeatmap(cs),
          ),

          const SizedBox(height: 8),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text('Less', style: TextStyle(fontSize: 10, color: cs.outline)),
              const SizedBox(width: 4),
              ...List.generate(4, (i) {
                final alpha = [0.1, 0.3, 0.6, 1.0][i];
                return Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
              const SizedBox(width: 4),
              Text('More', style: TextStyle(fontSize: 10, color: cs.outline)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmap(ColorScheme cs) {
    final today = DateTime.now();
    final startDate =
        today.subtract(Duration(days: weeksToShow * 7 - 1));

    // Normalize active days to date-only for comparison
    final normalizedDays = activeDays
        .map((d) => DateTime(d.year, d.month, d.day))
        .toSet();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cellSize =
            (constraints.maxWidth - (weeksToShow - 1) * 2) / weeksToShow;
        final clamped = cellSize.clamp(8.0, 14.0);

        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(weeksToShow, (weekIdx) {
            return Padding(
              padding: EdgeInsets.only(right: weekIdx < weeksToShow - 1 ? 2 : 0),
              child: Column(
                children: List.generate(7, (dayIdx) {
                  final dayOffset = weekIdx * 7 + dayIdx;
                  final date = startDate.add(Duration(days: dayOffset));
                  final normalized = DateTime(date.year, date.month, date.day);
                  final isActive = normalizedDays.contains(normalized);
                  final isFuture = date.isAfter(today);
                  final isToday = normalized ==
                      DateTime(today.year, today.month, today.day);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Tooltip(
                      message: '${date.month}/${date.day}',
                      child: Container(
                        width: clamped,
                        height: clamped,
                        decoration: BoxDecoration(
                          color: isFuture
                              ? Colors.transparent
                              : isActive
                                  ? cs.primary
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(2),
                          border: isToday
                              ? Border.all(color: cs.primary, width: 1.5)
                              : null,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        );
      },
    );
  }

  Color _streakColor(int days) {
    if (days >= 30) return const Color(0xFFEF4444);
    if (days >= 7) return const Color(0xFFF97316);
    if (days >= 1) return const Color(0xFFFBBF24);
    return const Color(0xFF9CA3AF);
  }
}

/// Compact streak indicator for use in feed cards or profile headers.
class StreakBadge extends StatelessWidget {
  final int streakDays;

  const StreakBadge({super.key, required this.streakDays});

  @override
  Widget build(BuildContext context) {
    if (streakDays <= 0) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    final color = streakDays >= 30
        ? const Color(0xFFEF4444)
        : streakDays >= 7
            ? const Color(0xFFF97316)
            : const Color(0xFFFBBF24);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedFire,
              size: 14, color: color),
          const SizedBox(width: 3),
          Text(
            '$streakDays',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
