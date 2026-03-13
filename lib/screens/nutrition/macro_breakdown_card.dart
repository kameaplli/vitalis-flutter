import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/auth_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/selected_person_provider.dart';
import 'daily_intake.dart';

// ─── Macro breakdown card ─────────────────────────────────────────────────────

class MacroBreakdownCard extends ConsumerWidget {
  final NutritionState nutrition;
  const MacroBreakdownCard({super.key, required this.nutrition});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final selectedPerson = ref.watch(selectedPersonProvider);
    int? personAge;
    String? personGender;
    if (selectedPerson == 'self') {
      personAge = auth.user?.age;
      personGender = auth.user?.gender;
    } else {
      final member = auth.user?.profile.children
          .where((c) => c.id == selectedPerson).firstOrNull;
      personAge = member?.age;
      personGender = member?.gender;
    }
    final intake = dailyIntake(personAge, personGender);
    final protein = nutrition.totalProtein;
    final carbs = nutrition.totalCarbs;
    final fat = nutrition.totalFat;
    final macroTotal = protein + carbs + fat;

    final ageStr = personAge != null ? '${personAge}yr' : '—';
    final genderStr = personGender ?? '—';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Breakdown',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // ── Donut + legend ───────────────────────────────────────────
                Column(
                  children: [
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: macroTotal <= 0
                          ? Center(
                              child: Text('—',
                                  style: TextStyle(
                                      color: Colors.grey.shade400,
                                      fontSize: 24)))
                          : PieChart(PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 28,
                              sections: [
                                _section(protein, macroTotal, Colors.blue),
                                _section(carbs, macroTotal, Colors.orange),
                                _section(fat, macroTotal, Colors.red),
                              ],
                            )),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dot(Colors.blue, 'P'),
                        const SizedBox(width: 6),
                        _dot(Colors.orange, 'C'),
                        const SizedBox(width: 6),
                        _dot(Colors.red, 'F'),
                      ],
                    ),
                  ],
                ),

                const SizedBox(width: 16),

                // ── Daily intake guide ───────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Daily Guide ($genderStr, $ageStr)',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      _IntakeRow('Calories',
                          nutrition.totalCalories, intake.calories, 'kcal',
                          Colors.deepOrange),
                      _IntakeRow('Protein',
                          protein, intake.protein, 'g', Colors.blue),
                      _IntakeRow('Carbs',
                          carbs, intake.carbs, 'g', Colors.orange),
                      _IntakeRow('Fat',
                          fat, intake.fat, 'g', Colors.red),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  PieChartSectionData _section(double val, double total, Color color) =>
      PieChartSectionData(
        value: val,
        color: color,
        title: total > 0
            ? '${(val / total * 100).toStringAsFixed(0)}%'
            : '',
        titleStyle: const TextStyle(
            fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
        radius: 22,
      );

  Widget _dot(Color color, String label) => Row(
        children: [
          Container(
              width: 9,
              height: 9,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 3),
          Text(label, style: const TextStyle(fontSize: 10)),
        ],
      );
}

class _IntakeRow extends StatelessWidget {
  final String label;
  final double current;
  final double daily;
  final String unit;
  final Color color;

  const _IntakeRow(this.label, this.current, this.daily, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = daily > 0 ? (current / daily).clamp(0.0, 1.0) : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w500)),
              Text(
                '${current.toStringAsFixed(0)} / ${daily.toStringAsFixed(0)} $unit',
                style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              color: pct >= 1.0 ? Colors.red : color,
              backgroundColor: color.withValues(alpha: 0.15),
              minHeight: 5,
            ),
          ),
        ],
      ),
    );
  }
}
