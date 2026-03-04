import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LineChartWidget extends StatelessWidget {
  final List<FlSpot> spots;
  final String yLabel;
  final Color? lineColor;
  final double? minY;
  final double? maxY;
  /// ISO date strings (e.g. '2024-03-01') indexed same as spots.
  /// When provided, used for bottom-axis labels instead of spots[i].x as epoch ms.
  final List<String>? xDates;

  const LineChartWidget({
    super.key,
    required this.spots,
    this.yLabel = '',
    this.lineColor,
    this.minY,
    this.maxY,
    this.xDates,
  });

  @override
  Widget build(BuildContext context) {
    final color = lineColor ?? Theme.of(context).colorScheme.primary;

    if (spots.isEmpty) {
      return Center(child: Text('No data yet', style: Theme.of(context).textTheme.bodyMedium));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(color: Colors.grey.withValues(alpha: 0.2), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, _) => Text(
                value.toStringAsFixed(1),
                style: const TextStyle(fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (spots.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= spots.length) return const SizedBox();
                final DateTime dt;
                if (xDates != null && idx < xDates!.length) {
                  dt = DateTime.parse(xDates![idx]);
                } else {
                  dt = DateTime.fromMillisecondsSinceEpoch(spots[idx].x.toInt());
                }
                return Text(
                  DateFormat('M/d').format(dt),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: minY,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: spots.length <= 20,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
  }
}
