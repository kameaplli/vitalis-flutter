import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MacroDonutChart extends StatelessWidget {
  final double protein;
  final double carbs;
  final double fat;

  const MacroDonutChart({
    super.key,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  @override
  Widget build(BuildContext context) {
    final total = protein + carbs + fat;
    if (total <= 0) {
      return Center(child: Text('No macro data', style: Theme.of(context).textTheme.bodyMedium));
    }

    return Row(
      children: [
        SizedBox(
          width: 140,
          height: 140,
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              PieChartSectionData(
                value: protein,
                color: Colors.blue,
                title: '${(protein / total * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                radius: 30,
              ),
              PieChartSectionData(
                value: carbs,
                color: Colors.orange,
                title: '${(carbs / total * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                radius: 30,
              ),
              PieChartSectionData(
                value: fat,
                color: Colors.red,
                title: '${(fat / total * 100).toStringAsFixed(0)}%',
                titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                radius: 30,
              ),
            ],
          )),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _legend(Colors.blue, 'Protein', '${protein.toStringAsFixed(1)}g'),
            const SizedBox(height: 8),
            _legend(Colors.orange, 'Carbs', '${carbs.toStringAsFixed(1)}g'),
            const SizedBox(height: 8),
            _legend(Colors.red, 'Fat', '${fat.toStringAsFixed(1)}g'),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, String value) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text('$label: $value', style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}
