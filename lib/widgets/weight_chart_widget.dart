import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/weight_log.dart';
import 'chart_style.dart';

class WeightChartWidget extends StatelessWidget {
  final WeightHistory history;

  const WeightChartWidget({super.key, required this.history});

  @override
  Widget build(BuildContext context) {
    final logs = history.entries;
    final ideal = history.idealWeight;
    final idealMin = history.idealMin;
    final idealMax = history.idealMax;
    final cs = Theme.of(context).colorScheme;

    if (logs.isEmpty) {
      return SizedBox(
        height: 140,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.show_chart_rounded, size: 40, color: cs.outlineVariant),
              const SizedBox(height: 8),
              Text('No weight entries yet',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ],
          ),
        ),
      );
    }

    final weights = logs.map((l) => l.weight).toList();
    final dataMin = weights.reduce((a, b) => a < b ? a : b);
    final dataMax = weights.reduce((a, b) => a > b ? a : b);

    // Y-axis: tight around data, include ideal range
    double minY, maxY;
    if (idealMin != null && idealMax != null) {
      minY = [dataMin, idealMin].reduce((a, b) => a < b ? a : b) - 3;
      maxY = [dataMax, idealMax].reduce((a, b) => a > b ? a : b) + 3;
    } else {
      minY = dataMin - 2;
      maxY = dataMax + 2;
    }
    minY = minY.floorToDouble();
    maxY = maxY.ceilToDouble();

    final spots = logs.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.weight))
        .toList();
    final dates = logs.map((l) => l.date).toList();

    // Stats
    final latest = weights.last;
    final first = weights.first;
    final change = latest - first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats row
        if (logs.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                _StatChip(
                  label: 'Current',
                  value: '${latest.toStringAsFixed(1)} kg',
                  color: cs.primary,
                ),
                const SizedBox(width: 8),
                if (ideal != null)
                  _StatChip(
                    label: 'Goal',
                    value: '${ideal.toStringAsFixed(1)} kg',
                    color: Colors.green.shade600,
                  ),
                if (ideal != null) const SizedBox(width: 8),
                _StatChip(
                  label: logs.length > 1 ? 'Change' : 'Start',
                  value: '${change >= 0 ? "+" : ""}${change.toStringAsFixed(1)}',
                  color: change.abs() < 0.5
                      ? cs.onSurfaceVariant
                      : change > 0
                          ? Colors.red.shade400
                          : Colors.green.shade600,
                ),
              ],
            ),
          ),

        // Chart
        SizedBox(
          height: 220,
          width: double.infinity,
          child: LineChart(
            LineChartData(
              minY: minY,
              maxY: maxY,
              clipData: const FlClipData.all(),
              rangeAnnotations: _zones(idealMin, idealMax, minY, maxY),
              lineBarsData: [
                // Main weight line — thin coral with glowing latest dot
                ChartStyle.dataLine(
                  spots,
                  dotPainterFn: (spot, percent, barData, index) {
                    final isLast = index == spots.length - 1;
                    if (isLast) {
                      return ChartStyle.dotPainter(spot, percent, barData, index);
                    }
                    // Historical dots colored by weight zone
                    return FlDotCirclePainter(
                      radius: ChartStyle.historicalDotRadius,
                      color: _dotColor(spot.y, idealMin, idealMax),
                      strokeWidth: 1.5,
                      strokeColor: Colors.white,
                    );
                  },
                ),
                // Ideal weight — dashed reference line
                if (ideal != null && logs.length > 1)
                  ChartStyle.referenceLine(
                    [FlSpot(0, ideal), FlSpot((logs.length - 1).toDouble(), ideal)],
                    color: Colors.green.shade400,
                  ),
              ],
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: _interval(maxY - minY),
                    getTitlesWidget: (v, _) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Text(
                        v.toStringAsFixed(v % 1 == 0 ? 0 : 1),
                        style: TextStyle(
                          fontSize: 11,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: _xInterval(logs.length),
                    getTitlesWidget: (v, _) {
                      final idx = v.toInt();
                      if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                      final p = dates[idx].split('-');
                      final label = p.length >= 3 ? '${p[2]}/${p[1]}' : dates[idx];
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              gridData: ChartStyle.grid,
              borderData: ChartStyle.border,
              lineTouchData: LineTouchData(
                handleBuiltInTouches: true,
                touchTooltipData: LineTouchTooltipData(
                  tooltipRoundedRadius: 12,
                  tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) => spots.map((s) {
                    if (s.barIndex != 0) return null;
                    final idx = s.x.toInt();
                    final d = idx >= 0 && idx < dates.length ? dates[idx] : '';
                    final p = d.split('-');
                    final fmtDate = p.length >= 3 ? '${p[2]} ${_monthName(p[1])}' : d;
                    String extra = '';
                    if (ideal != null) {
                      final diff = s.y - ideal;
                      extra = '\n${diff >= 0 ? "+" : ""}${diff.toStringAsFixed(1)} from goal';
                    }
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} kg\n$fmtDate$extra',
                      const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Minimal legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(ChartStyle.dataLineColor, 'Weight'),
            if (ideal != null) ...[
              const SizedBox(width: 16),
              _dash(Colors.green.shade400, 'Goal'),
            ],
            if (idealMin != null) ...[
              const SizedBox(width: 16),
              _band(Colors.green, 'Healthy'),
            ],
          ],
        ),
      ],
    );
  }

  static String _monthName(String m) {
    const months = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                     'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final i = int.tryParse(m) ?? 0;
    return i > 0 && i < 13 ? months[i] : m;
  }

  static double _interval(double range) {
    if (range <= 4) return 0.5;
    if (range <= 8) return 1;
    if (range <= 16) return 2;
    return 5;
  }

  static double _xInterval(int count) {
    if (count <= 7) return 1;
    if (count <= 14) return 2;
    if (count <= 30) return 5;
    return (count / 6).roundToDouble();
  }

  static Color _dotColor(double w, double? idealMin, double? idealMax) {
    if (idealMin == null || idealMax == null) return ChartStyle.historicalDotColor;
    if (w >= idealMin && w <= idealMax) return Colors.green.shade500;
    if (w < idealMin - 5 || w > idealMax + 5) return Colors.red.shade400;
    return Colors.amber.shade600;
  }

  RangeAnnotations _zones(double? idealMin, double? idealMax, double minY, double maxY) {
    if (idealMin == null || idealMax == null) return const RangeAnnotations();
    return RangeAnnotations(
      horizontalRangeAnnotations: [
        HorizontalRangeAnnotation(
          y1: idealMin.clamp(minY, maxY),
          y2: idealMax.clamp(minY, maxY),
          color: Colors.green.withValues(alpha: 0.07),
        ),
      ],
    );
  }

  static Widget _dot(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ],
  );

  static Widget _dash(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      SizedBox(width: 14, child: Row(children: [
        Container(width: 5, height: 1.5, color: c),
        const SizedBox(width: 2),
        Container(width: 5, height: 1.5, color: c),
      ])),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ],
  );

  static Widget _band(Color c, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 14, height: 8,
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
    ],
  );
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(value,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
          ],
        ),
      ),
    );
  }
}
