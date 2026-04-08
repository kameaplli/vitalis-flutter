import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/sync_models.dart';
import '../providers/selected_person_provider.dart';
import '../providers/sync_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Dashboard card showing today's key wearable health metrics at a glance.
///
/// Tapping a metric navigates to the health timeline filtered by that type.
/// Gracefully handles no data / no connected devices.
class WearableSummaryCard extends ConsumerWidget {
  const WearableSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final summaryAsync = ref.watch(
      dailyHealthSummaryProvider((person: person, date: today)),
    );

    return summaryAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (summary) {
        if (summary.metrics.isEmpty) return const SizedBox.shrink();
        return _WearableCard(summary: summary);
      },
    );
  }
}

class _WearableCard extends StatelessWidget {
  final DailyHealthSummary summary;
  const _WearableCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final metrics = summary.metrics;

    // Build metric tiles for available data
    final tiles = <Widget>[];
    _addMetricTile(tiles, metrics, 'heart_rate', HugeIcons.strokeRoundedFavourite,
        const Color(0xFFEF4444), 'bpm', _getAvg);
    _addMetricTile(tiles, metrics, 'steps', HugeIcons.strokeRoundedRunningShoes,
        const Color(0xFF22C55E), '', _getSum);
    _addMetricTile(tiles, metrics, 'active_calories',
        HugeIcons.strokeRoundedFire, const Color(0xFFF97316), 'kcal',
        _getSum);
    _addMetricTile(tiles, metrics, 'sleep_session', HugeIcons.strokeRoundedBed,
        const Color(0xFF6366F1), 'hrs', _getSleepHours);
    _addMetricTile(tiles, metrics, 'weight', HugeIcons.strokeRoundedBodyWeight,
        const Color(0xFF8B5CF6), 'kg', _getLatest);
    _addMetricTile(tiles, metrics, 'distance', HugeIcons.strokeRoundedRuler,
        const Color(0xFF06B6D4), 'km', _getDistanceKm);

    if (tiles.isEmpty) return const SizedBox.shrink();

    // Collect all source names
    final allSources = <String>{};
    for (final m in metrics.values) {
      allSources.addAll(m.sources);
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedSmartWatch01, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  "Today's Health Snapshot",
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => context.push('/health-timeline'),
                  child: Text(
                    'View all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metric tiles — responsive grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: tiles,
            ),

            // Sources row
            if (allSources.isNotEmpty) ...[
              const SizedBox(height: 10),
              Divider(
                  height: 1,
                  color: cs.outlineVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 8),
              Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedLink01,
                      size: 12, color: cs.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      'Sources: ${allSources.join(", ")}',
                      style: TextStyle(
                        fontSize: 11,
                        color: cs.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _addMetricTile(
    List<Widget> tiles,
    Map<String, HealthMetric> metrics,
    String key,
    List<List<dynamic>> icon,
    Color color,
    String unit,
    String? Function(HealthMetric) formatter,
  ) {
    final m = metrics[key];
    if (m == null) return;
    final val = formatter(m);
    if (val == null) return;

    tiles.add(_MetricTile(
      icon: icon,
      color: color,
      value: val,
      unit: unit,
      label: m.displayName,
      dataType: key,
    ));
  }

  static String? _getSum(HealthMetric m) {
    if (m.valueSum == null || m.valueSum == 0) return null;
    return NumberFormat.compact().format(m.valueSum!);
  }

  static String? _getAvg(HealthMetric m) {
    if (m.valueAvg == null) return null;
    return m.valueAvg!.toStringAsFixed(0);
  }

  static String? _getLatest(HealthMetric m) {
    if (m.valueLatest == null) return null;
    return m.valueLatest!.toStringAsFixed(1);
  }

  static String? _getSleepHours(HealthMetric m) {
    // Sleep is typically stored in minutes
    final mins = m.valueSum;
    if (mins == null || mins == 0) return null;
    return (mins / 60).toStringAsFixed(1);
  }

  static String? _getDistanceKm(HealthMetric m) {
    // Distance may be in meters
    final meters = m.valueSum;
    if (meters == null || meters == 0) return null;
    if (meters >= 1000) return (meters / 1000).toStringAsFixed(1);
    return meters.toStringAsFixed(0);
  }
}

// ── Individual metric tile ──────────────────────────────────────────────────

class _MetricTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final Color color;
  final String value;
  final String unit;
  final String label;
  final String dataType;

  const _MetricTile({
    required this.icon,
    required this.color,
    required this.value,
    required this.unit,
    required this.label,
    required this.dataType,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: () => context.push('/health-timeline'),
      child: Container(
        width: 100,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.12), width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HugeIcon(icon: icon, size: 16, color: color),
            const SizedBox(height: 4),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: cs.onSurface,
                    ),
                  ),
                  if (unit.isNotEmpty) ...[
                    const TextSpan(text: ' '),
                    TextSpan(
                      text: unit,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
