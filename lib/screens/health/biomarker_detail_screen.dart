import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/friendly_error.dart';
import '../../widgets/shimmer_placeholder.dart';

// Tier colors (shared with dashboard)
const _kOptimalColor = Color(0xFF22C55E);
const _kSufficientColor = Color(0xFF3B82F6);
const _kSuboptimalColor = Color(0xFFF59E0B);
const _kCriticalColor = Color(0xFFEF4444);
const _kUnknownColor = Color(0xFF9CA3AF);

Color _tierColor(String? tier) => switch (tier) {
      'optimal' => _kOptimalColor,
      'sufficient' => _kSufficientColor,
      'suboptimal' => _kSuboptimalColor,
      'critical' => _kCriticalColor,
      _ => _kUnknownColor,
    };

class BiomarkerDetailScreen extends ConsumerWidget {
  final String biomarkerCode;
  const BiomarkerDetailScreen({super.key, required this.biomarkerCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final historyAsync = ref.watch(biomarkerHistoryProvider(
        (code: biomarkerCode, person: person)));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: Text(biomarkerCode)),
      body: historyAsync.when(
        loading: () => const ShimmerList(),
        error: (e, st) => FriendlyError(error: e),
        data: (history) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Name + description
              Text(history.name,
                  style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('${history.category} • ${history.healthPillar}',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              if (history.description != null) ...[
                const SizedBox(height: 12),
                Text(history.description!,
                    style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              ],

              const SizedBox(height: 24),

              // ── Range Bar (large) ───────────────────────────────
              if (history.ranges != null) ...[
                Text('Reference Ranges',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _LargeRangeBar(
                  ranges: history.ranges!,
                  currentValue: history.dataPoints.isNotEmpty
                      ? history.dataPoints.last.value
                      : null,
                  unit: history.unit,
                ),

                // Evidence grade disclosure
                if (history.ranges!.evidenceGrade == 'midrange') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          size: 16, color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Optimal range based on midrange of standard clinical reference. '
                          'No specific guideline-endorsed optimal exists for this biomarker.',
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ] else if (history.ranges!.source != null) ...[
                  const SizedBox(height: 8),
                  Text('Source: ${history.ranges!.source}',
                      style: tt.bodySmall?.copyWith(
                          color: cs.primary, fontWeight: FontWeight.w500)),
                ],
              ],

              const SizedBox(height: 24),

              // ── History Chart ────────────────────────────────────
              if (history.dataPoints.length >= 2) ...[
                Text('History',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                SizedBox(
                  height: 220,
                  child: _HistoryChart(
                    dataPoints: history.dataPoints,
                    ranges: history.ranges,
                    unit: history.unit,
                  ),
                ),
              ] else if (history.dataPoints.length == 1) ...[
                Text('History',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text('Only 1 data point. Upload more reports to see trends.',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              ],

              const SizedBox(height: 24),

              // ── Data Points Table ───────────────────────────────
              if (history.dataPoints.isNotEmpty) ...[
                Text('All Results',
                    style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                for (final dp in history.dataPoints.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _tierColor(dp.tier),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(dp.date ?? '',
                            style: tt.bodyMedium),
                        const Spacer(),
                        Text('${dp.value} ${history.unit}',
                            style: tt.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: _tierColor(dp.tier))),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Large Range Bar ──────────────────────────────────────────────────────────

class _LargeRangeBar extends StatelessWidget {
  final BiomarkerRange ranges;
  final double? currentValue;
  final String unit;

  const _LargeRangeBar({
    required this.ranges,
    this.currentValue,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;

    return Column(
      children: [
        // Range bar
        SizedBox(
          height: 32,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                Expanded(flex: 1, child: Container(color: _kCriticalColor.withValues(alpha: 0.4))),
                Expanded(flex: 1, child: Container(color: _kSuboptimalColor.withValues(alpha: 0.4))),
                Expanded(flex: 1, child: Container(color: _kSufficientColor.withValues(alpha: 0.4))),
                Expanded(flex: 2, child: Container(color: _kOptimalColor.withValues(alpha: 0.5))),
                Expanded(flex: 1, child: Container(color: _kSufficientColor.withValues(alpha: 0.4))),
                Expanded(flex: 1, child: Container(color: _kSuboptimalColor.withValues(alpha: 0.4))),
                Expanded(flex: 1, child: Container(color: _kCriticalColor.withValues(alpha: 0.4))),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        // Labels
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _RangeLabel('Critical', _kCriticalColor, tt),
            _RangeLabel('Suboptimal', _kSuboptimalColor, tt),
            _RangeLabel('Sufficient', _kSufficientColor, tt),
            _RangeLabel('Optimal', _kOptimalColor, tt),
          ],
        ),

        // Current value
        if (currentValue != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Latest: ', style: tt.bodyMedium),
                Text('$currentValue $unit',
                    style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],

        // Numeric ranges
        const SizedBox(height: 12),
        _RangeRow('Optimal', ranges.optimalLow, ranges.optimalHigh, unit, _kOptimalColor, tt),
        _RangeRow('Sufficient', ranges.sufficientLow, ranges.sufficientHigh, unit, _kSufficientColor, tt),
        _RangeRow('Standard', ranges.standardLow, ranges.standardHigh, unit, _kSuboptimalColor, tt),
      ],
    );
  }
}

Widget _RangeLabel(String label, Color color, TextTheme tt) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 4),
      Text(label, style: tt.labelSmall),
    ],
  );
}

Widget _RangeRow(String label, double? low, double? high, String unit,
    Color color, TextTheme tt) {
  final range = low != null && high != null
      ? '$low – $high $unit'
      : low != null
          ? '> $low $unit'
          : high != null
              ? '< $high $unit'
              : '—';
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Container(width: 12, height: 3, color: color),
        const SizedBox(width: 8),
        SizedBox(width: 80, child: Text(label, style: tt.bodySmall)),
        Text(range, style: tt.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
      ],
    ),
  );
}

// ── History Chart ────────────────────────────────────────────────────────────

class _HistoryChart extends StatelessWidget {
  final List<BiomarkerDataPoint> dataPoints;
  final BiomarkerRange? ranges;
  final String unit;

  const _HistoryChart({
    required this.dataPoints,
    this.ranges,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].value));
    }

    final values = dataPoints.map((d) => d.value).toList();
    final minY = values.reduce((a, b) => a < b ? a : b) * 0.85;
    final maxY = values.reduce((a, b) => a > b ? a : b) * 1.15;

    // Build horizontal range bands
    final rangeAnnotations = <HorizontalRangeAnnotation>[];
    if (ranges != null) {
      if (ranges!.optimalLow != null && ranges!.optimalHigh != null) {
        rangeAnnotations.add(HorizontalRangeAnnotation(
          y1: ranges!.optimalLow!.clamp(minY, maxY),
          y2: ranges!.optimalHigh!.clamp(minY, maxY),
          color: _kOptimalColor.withValues(alpha: 0.1),
        ));
      }
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.3),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dataPoints.length) return const SizedBox();
                final dp = dataPoints[i];
                final label = dp.date != null && dp.date!.length >= 10
                    ? dp.date!.substring(5, 10) // MM-DD
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: rangeAnnotations,
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: cs.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final tier = index < dataPoints.length
                    ? dataPoints[index].tier
                    : null;
                return FlDotCirclePainter(
                  radius: 5,
                  color: _tierColor(tier),
                  strokeWidth: 2,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: cs.primary.withValues(alpha: 0.08),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final i = spot.spotIndex;
              final dp = dataPoints[i];
              return LineTooltipItem(
                '${dp.value} $unit\n${dp.date ?? ''}',
                TextStyle(color: cs.onSurface, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
