import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/nutrition_utils.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/selected_person_provider.dart';
import '../models/analytics_data.dart';
import '../widgets/line_chart_widget.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final analyticsAsync = ref.watch(analyticsProvider('$person:$_days'));

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 7, label: Text('7 days')),
                ButtonSegment(value: 30, label: Text('30 days')),
                ButtonSegment(value: 90, label: Text('90 days')),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
            const SizedBox(height: 20),
            analyticsAsync.when(
              skipLoadingOnReload: true,
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (data) => _AnalyticsBody(data: data, person: person),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsBody extends ConsumerWidget {
  final NutritionAnalytics data;
  final String person;

  const _AnalyticsBody({required this.data, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);

    int? personAge;
    String? personGender;
    if (person == 'self') {
      personAge = auth.user?.age;
      personGender = auth.user?.gender;
    } else {
      final member = auth.user?.profile.children
          .where((c) => c.id == person)
          .firstOrNull;
      personAge = member?.age;
      personGender = member?.gender;
    }
    final intake = getDailyIntake(personAge, personGender);
    final ageStr    = personAge   != null ? '${personAge}yr' : '—';
    final genderStr = personGender ?? '—';

    // Average daily macros over the period
    final days = data.periodDays > 0 ? data.periodDays.toDouble() : 1;
    final avgCal = data.dailyTotals.isEmpty
        ? 0.0
        : data.dailyTotals.map((d) => d.calories).reduce((a, b) => a + b) /
            data.dailyTotals.length;
    final avgProtein = data.macroTotals.protein / days;
    final avgCarbs = data.macroTotals.carbs / days;
    final avgFat = data.macroTotals.fat / days;
    final macroTotal = avgProtein + avgCarbs + avgFat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Calorie line chart
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Daily Calories',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: LineChartWidget(
                    spots: data.dailyTotals.asMap().entries.map((e) {
                      return FlSpot(e.key.toDouble(), e.value.calories);
                    }).toList(),
                    xDates: data.dailyTotals.map((d) => d.date).toList(),
                    yLabel: 'kcal',
                    lineColor: Colors.orange,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Macro breakdown card (same style as nutrition screen)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avg Daily Macros (${data.periodDays}d)',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Donut
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
                                    _section(avgProtein, macroTotal,
                                        Colors.blue),
                                    _section(
                                        avgCarbs, macroTotal, Colors.orange),
                                    _section(avgFat, macroTotal, Colors.red),
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
                    // Daily intake guide
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
                          _IntakeRow('Calories', avgCal, intake.calories,
                              'kcal', Colors.deepOrange),
                          _IntakeRow('Protein', avgProtein, intake.protein,
                              'g', Colors.blue),
                          _IntakeRow('Carbs', avgCarbs, intake.carbs, 'g',
                              Colors.orange),
                          _IntakeRow(
                              'Fat', avgFat, intake.fat, 'g', Colors.red),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // Top foods
        if (data.topFoods.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Top Foods',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  ...data.topFoods.take(10).map((f) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        leading: CircleAvatar(
                          radius: 16,
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: Text('${data.topFoods.indexOf(f) + 1}',
                              style: const TextStyle(fontSize: 12)),
                        ),
                        title: Text(f.name),
                        trailing: Text(
                            '${f.calories.toStringAsFixed(0)} kcal',
                            style:
                                Theme.of(context).textTheme.bodySmall),
                      )),
                ],
              ),
            ),
          ),
      ],
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
              decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
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
