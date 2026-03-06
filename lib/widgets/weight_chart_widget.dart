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

    if (logs.isEmpty) {
      return const Center(child: Text('No weight entries yet'));
    }

    final weights = logs.map((l) => l.weight).toList();
    double minY = weights.reduce((a, b) => a < b ? a : b) - 2;
    double maxY = weights.reduce((a, b) => a > b ? a : b) + 2;

    if (idealMin != null) minY = minY < idealMin - 2 ? minY : idealMin - 2;
    if (idealMax != null) maxY = maxY > idealMax + 2 ? maxY : idealMax + 2;

    final spots = logs.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.weight);
    }).toList();

    final lines = <LineChartBarData>[
      // Actual weight line (solid blue)
      LineChartBarData(
        spots: spots,
        isCurved: true,
        color: Colors.blue.shade600,
        barWidth: 2.5,
        dotData: FlDotData(show: logs.length <= 14),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.blue.withOpacity(0.08),
        ),
      ),
    ];

    // Ideal weight line (dashed green)
    if (ideal != null) {
      lines.add(LineChartBarData(
        spots: [FlSpot(0, ideal), FlSpot((logs.length - 1).toDouble(), ideal)],
        isCurved: false,
        color: Colors.green.shade500,
        barWidth: 1.5,
        dashArray: [6, 4],
        dotData: FlDotData(show: false),
      ));
    }

    // BMI band boundaries (invisible anchor lines)
    if (idealMin != null && idealMax != null) {
      lines.add(LineChartBarData(
        spots: [FlSpot(0, idealMin), FlSpot((logs.length - 1).toDouble(), idealMin)],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(show: false),
      ));
      lines.add(LineChartBarData(
        spots: [FlSpot(0, idealMax), FlSpot((logs.length - 1).toDouble(), idealMax)],
        isCurved: false,
        color: Colors.transparent,
        barWidth: 0,
        dotData: FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: Colors.green.withOpacity(0.10),
        ),
      ));
      // BetweenBarsData shading
    }

    final dates = logs.map((l) => l.date).toList();

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: LineChart(LineChartData(
            minY: minY,
            maxY: maxY,
            lineBarsData: lines,
            betweenBarsData: (ideal != null && idealMin != null && idealMax != null)
                ? [
                    BetweenBarsData(
                      fromIndex: 2, // idealMin line
                      toIndex: 3,   // idealMax line
                      color: Colors.green.withOpacity(0.12),
                    ),
                  ]
                : [],
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 36,
                  getTitlesWidget: (v, _) => Text(
                    v.toStringAsFixed(0),
                    style: const TextStyle(fontSize: 9, color: Colors.grey),
                  ),
                ),
              ),
              topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 24,
                  interval: logs.length > 10 ? (logs.length / 4).roundToDouble() : 1,
                  getTitlesWidget: (v, _) {
                    final idx = v.toInt();
                    if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                    final parts = dates[idx].split('-');
                    final label = parts.length >= 3 ? '${parts[2]}/${parts[1]}' : dates[idx];
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(label, style: const TextStyle(fontSize: 8, color: Colors.grey)),
                    );
                  },
                ),
              ),
            ),
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: 5,
              getDrawingHorizontalLine: (_) => FlLine(
                color: Colors.grey.withOpacity(0.15),
                strokeWidth: 1,
              ),
            ),
            borderData: FlBorderData(show: false),
            lineTouchData: LineTouchData(
              touchTooltipData: LineTouchTooltipData(
                getTooltipItems: (touchedSpots) => touchedSpots.map((s) {
                  if (s.barIndex == 0) {
                    return LineTooltipItem(
                      '${s.y.toStringAsFixed(1)} kg',
                      const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                    );
                  }
                  return null;
                }).toList(),
              ),
            ),
          )),
        ),
        if (ideal != null) ...[
          const SizedBox(height: 8),
          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendDot(color: Colors.blue.shade600, label: 'Actual'),
              const SizedBox(width: 16),
              _LegendDash(color: Colors.green.shade500, label: 'Ideal (${ideal.toStringAsFixed(1)} kg)'),
              if (idealMin != null && idealMax != null) ...[
                const SizedBox(width: 16),
                _LegendBand(color: Colors.green.withOpacity(0.3), label: 'Healthy BMI'),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 3, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}

class _LegendDash extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDash({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 2, color: color),
      const SizedBox(width: 2),
      Container(width: 5, height: 2, color: color),
    ]),
    const SizedBox(width: 4),
    Text(label, style: TextStyle(fontSize: 10, color: color)),
  ]);
}

class _LegendBand extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendBand({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 12, height: 8, color: color),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
  ]);
}
