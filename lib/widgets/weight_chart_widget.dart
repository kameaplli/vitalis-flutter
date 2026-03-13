import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/weight_log.dart';

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
      return const SizedBox(
        height: 120,
        child: Center(child: Text('No weight entries yet')),
      );
    }

    final weights = logs.map((l) => l.weight).toList();
    final dataMin = weights.reduce((a, b) => a < b ? a : b);
    final dataMax = weights.reduce((a, b) => a > b ? a : b);

    // Y-axis: start 5kg below ideal (or data min), end 5kg above ideal (or data max)
    double minY, maxY;
    if (idealMin != null && idealMax != null) {
      minY = [dataMin - 2, idealMin - 5.0].reduce((a, b) => a < b ? a : b);
      maxY = [dataMax + 2, idealMax + 5.0].reduce((a, b) => a > b ? a : b);
    } else {
      minY = dataMin - 3;
      maxY = dataMax + 3;
    }
    // Round to nearest 0.5
    minY = (minY * 2).floorToDouble() / 2;
    maxY = (maxY * 2).ceilToDouble() / 2;

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weight);
    }).toList();

    final dates = logs.map((l) => l.date).toList();

    return Column(
      children: [
        SizedBox(
          height: 280,
          width: double.infinity,
          child: LineChart(LineChartData(
            minY: minY,
            maxY: maxY,
            clipData: FlClipData.all(),
            lineBarsData: _buildLines(spots, logs, ideal, idealMin, idealMax),
            betweenBarsData: _buildBands(ideal, idealMin, idealMax, logs.length),
            rangeAnnotations: _buildZones(idealMin, idealMax, minY, maxY),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 44,
                  interval: _yInterval(minY, maxY),
                  getTitlesWidget: (v, _) => Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      v.toStringAsFixed(1),
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 28,
                  interval: logs.length > 10 ? (logs.length / 5).roundToDouble() : 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                    final parts = dates[idx].split('-');
                    final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : dates[idx];
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label, style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: _yInterval(minY, maxY),
              getDrawingHorizontalLine: (_) => FlLine(
                color: cs.outlineVariant.withOpacity(0.3),
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border(
                bottom: BorderSide(color: cs.outlineVariant, width: 0.5),
                left: BorderSide(color: cs.outlineVariant, width: 0.5),
              ),
            ),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                tooltipRoundedRadius: 8,
                fitInsideHorizontally: true,
                fitInsideVertically: true,
                getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                  if (s.barIndex != 0) return null;
                  final idx = s.x.toInt();
                  final dateStr = idx >= 0 && idx < dates.length ? dates[idx] : '';
                  final parts = dateStr.split('-');
                  final fmtDate = parts.length >= 3 ? '${parts[2]}/${parts[1]}/${parts[0]}' : dateStr;
                  final diffStr = ideal != null
                      ? '\n${(s.y - ideal) > 0 ? "+" : ""}${(s.y - ideal).toStringAsFixed(1)} from ideal'
                      : '';
                  return LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} kg\n$fmtDate$diffStr',
                    const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600, height: 1.4),
                  );
                }).toList(),
              ),
            ),
          )),
        ),
        const SizedBox(height: 12),
        // Legend row
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 4,
          children: [
            _legendItem(cs.primary, 'Actual', isLine: true),
            if (ideal != null)
              _legendItem(Colors.green.shade600, 'Ideal (${ideal.toStringAsFixed(1)} kg)', isDashed: true),
            if (idealMin != null && idealMax != null) ...[
              _legendItem(Colors.green.withOpacity(0.25), 'Healthy', isBand: true),
              _legendItem(Colors.amber.withOpacity(0.25), 'Caution', isBand: true),
              _legendItem(Colors.red.withOpacity(0.20), 'Risk', isBand: true),
            ],
          ],
        ),
      ],
    );
  }

  double _yInterval(double minY, double maxY) {
    final range = maxY - minY;
    if (range <= 5) return 0.5;
    if (range <= 10) return 1;
    if (range <= 20) return 2;
    return 5;
  }

  List<LineChartBarData> _buildLines(
    List<FlSpot> spots,
    List<WeightLog> logs,
    double? ideal,
    double? idealMin,
    double? idealMax,
  ) {
    final lines = <LineChartBarData>[
      // Actual weight line
      LineChartBarData(
        spots: spots,
        isCurved: true,
        preventCurveOverShooting: true,
        color: Colors.blue.shade600,
        barWidth: 2.5,
        dotData: FlDotData(
          show: true,
          getDotPainter: (spot, _, __, ___) {
            Color dotColor = Colors.blue.shade600;
            if (idealMin != null && idealMax != null) {
              final w = spot.y;
              if (w >= idealMin && w <= idealMax) {
                dotColor = Colors.green.shade600;
              } else if (w < idealMin - 5 || w > idealMax + 5) {
                dotColor = Colors.red.shade600;
              } else {
                dotColor = Colors.amber.shade700;
              }
            }
            return FlDotCirclePainter(
              radius: logs.length <= 14 ? 3.5 : 2,
              color: dotColor,
              strokeWidth: 1.5,
              strokeColor: Colors.white,
            );
          },
        ),
        belowBarData: BarAreaData(show: false),
      ),
    ];

    // Ideal weight dashed line
    if (ideal != null && logs.length > 1) {
      lines.add(LineChartBarData(
        spots: [FlSpot(0, ideal), FlSpot((logs.length - 1).toDouble(), ideal)],
        isCurved: false,
        color: Colors.green.shade600,
        barWidth: 1.5,
        dashArray: [6, 4],
        dotData: FlDotData(show: false),
      ));
    }

    return lines;
  }

  List<BetweenBarsData> _buildBands(
    double? ideal,
    double? idealMin,
    double? idealMax,
    int count,
  ) {
    return []; // Using rangeAnnotations instead for cleaner zone rendering
  }

  RangeAnnotations _buildZones(
    double? idealMin,
    double? idealMax,
    double minY,
    double maxY,
  ) {
    if (idealMin == null || idealMax == null) return RangeAnnotations();

    return RangeAnnotations(
      horizontalRangeAnnotations: [
        // Red zone: far below
        if (minY < idealMin - 5)
          HorizontalRangeAnnotation(
            y1: minY,
            y2: idealMin - 5,
            color: Colors.red.withOpacity(0.08),
          ),
        // Amber zone: slightly below
        HorizontalRangeAnnotation(
          y1: (idealMin - 5).clamp(minY, idealMin),
          y2: idealMin,
          color: Colors.amber.withOpacity(0.08),
        ),
        // Green zone: healthy range
        HorizontalRangeAnnotation(
          y1: idealMin,
          y2: idealMax,
          color: Colors.green.withOpacity(0.10),
        ),
        // Amber zone: slightly above
        HorizontalRangeAnnotation(
          y1: idealMax,
          y2: (idealMax + 5).clamp(idealMax, maxY),
          color: Colors.amber.withOpacity(0.08),
        ),
        // Red zone: far above
        if (maxY > idealMax + 5)
          HorizontalRangeAnnotation(
            y1: idealMax + 5,
            y2: maxY,
            color: Colors.red.withOpacity(0.08),
          ),
      ],
    );
  }

  static Widget _legendItem(Color color, String label,
      {bool isLine = false, bool isDashed = false, bool isBand = false}) {
    Widget marker;
    if (isBand) {
      marker = Container(
        width: 14, height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    } else if (isDashed) {
      marker = Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 2, color: color),
        const SizedBox(width: 2),
        Container(width: 5, height: 2, color: color),
      ]);
    } else {
      marker = Container(
        width: 14, height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      );
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      marker,
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
    ]);
  }
}
