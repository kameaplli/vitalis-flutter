import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/nutrition_utils.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/selected_person_provider.dart';
import '../models/analytics_data.dart';
import '../widgets/line_chart_widget.dart';

// ── Colour palette ─────────────────────────────────────────────────────────────
const _proteinColor = Color(0xFF3B82F6);
const _carbsColor   = Color(0xFFF97316);
const _fatColor     = Color(0xFFEF4444);
const _bfastColor   = Color(0xFFF59E0B);
const _lunchColor   = Color(0xFF10B981);
const _dinnerColor  = Color(0xFF6366F1);
const _snackColor   = Color(0xFFEC4899);

// ── Root screen ────────────────────────────────────────────────────────────────

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

// ── Body ───────────────────────────────────────────────────────────────────────

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

    final days = data.periodDays > 0 ? data.periodDays.toDouble() : 1;
    final avgCal = data.dailyTotals.isEmpty
        ? 0.0
        : data.dailyTotals.map((d) => d.calories).reduce((a, b) => a + b) /
            data.dailyTotals.length;
    final avgProtein = data.macroTotals.protein / days;
    final avgCarbs   = data.macroTotals.carbs   / days;
    final avgFat     = data.macroTotals.fat     / days;
    final macroTotal = avgProtein + avgCarbs + avgFat;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. Daily Calories line chart ─────────────────────────────────────
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
                    spots: data.dailyTotals.asMap().entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value.calories))
                        .toList(),
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

        // ── 2. Macro Performance card (animated + tappable) ──────────────────
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Avg Daily Macros (${data.periodDays}d)',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 2),
                Text('Tap a macro bar to see food contributors',
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade500)),
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
                                        _proteinColor),
                                    _section(avgCarbs, macroTotal,
                                        _carbsColor),
                                    _section(avgFat, macroTotal, _fatColor),
                                  ],
                                )),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _dot(_proteinColor, 'P'),
                            const SizedBox(width: 6),
                            _dot(_carbsColor, 'C'),
                            const SizedBox(width: 6),
                            _dot(_fatColor, 'F'),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    // Animated + tappable macro bars
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
                          _AnimatedIntakeRow(
                            label: 'Calories',
                            current: avgCal,
                            daily: intake.calories,
                            unit: 'kcal',
                            color: Colors.deepOrange,
                            onTap: null,
                          ),
                          _AnimatedIntakeRow(
                            label: 'Protein',
                            current: avgProtein,
                            daily: intake.protein,
                            unit: 'g',
                            color: _proteinColor,
                            onTap: () => _showContributor(
                                context, 'Protein', _proteinColor,
                                data.topFoods, 'protein'),
                          ),
                          _AnimatedIntakeRow(
                            label: 'Carbs',
                            current: avgCarbs,
                            daily: intake.carbs,
                            unit: 'g',
                            color: _carbsColor,
                            onTap: () => _showContributor(
                                context, 'Carbs', _carbsColor,
                                data.topFoods, 'carbs'),
                          ),
                          _AnimatedIntakeRow(
                            label: 'Fat',
                            current: avgFat,
                            daily: intake.fat,
                            unit: 'g',
                            color: _fatColor,
                            onTap: () => _showContributor(
                                context, 'Fat', _fatColor,
                                data.topFoods, 'fat'),
                          ),
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

        // ── 3. 7-Day Macro Consistency grouped bar chart (Phase 1) ───────────
        if (data.dailyTotals.isNotEmpty)
          _MacroConsistencyCard(
              dailyTotals: data.dailyTotals, intake: intake),

        const SizedBox(height: 12),

        // ── 4. Meal Distribution stacked bar chart (Phase 2) ─────────────────
        if (data.mealCalories.isNotEmpty)
          _MealDistributionCard(mealCalories: data.mealCalories),

        const SizedBox(height: 12),

        // ── 5. Meal Timing timeline (Phase 3) ────────────────────────────────
        if (data.mealTimings.isNotEmpty)
          _MealTimelineCard(
            timings: data.mealTimings,
            avgWindowHours: data.avgEatingWindowHours,
            avgFrontLoadPct: data.avgFrontLoadPct,
          ),

        const SizedBox(height: 12),

        // ── 6. Nutrition-Health Correlations (Phase 3) ───────────────────────
        if (data.correlations.isNotEmpty)
          _CorrelationSection(correlations: data.correlations),

        const SizedBox(height: 12),

        // ── 7. Top Foods with macro mini-bars ────────────────────────────────
        if (data.topFoods.isNotEmpty)
          _TopFoodsCard(topFoods: data.topFoods),
      ],
    );
  }

  void _showContributor(BuildContext context, String macro, Color color,
      List<TopFood> foods, String field) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _MacroContributorSheet(
          macro: macro, color: color, foods: foods, field: field),
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
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white),
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

// ── Animated tappable macro intake row ────────────────────────────────────────

class _AnimatedIntakeRow extends StatelessWidget {
  final String label;
  final double current;
  final double daily;
  final String unit;
  final Color color;
  final VoidCallback? onTap;

  const _AnimatedIntakeRow({
    required this.label,
    required this.current,
    required this.daily,
    required this.unit,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pct = daily > 0 ? (current / daily).clamp(0.0, 1.0) : 0.0;
    final overGoal = daily > 0 && current > daily;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w500)),
                    if (onTap != null) ...[
                      const SizedBox(width: 3),
                      Icon(Icons.chevron_right, size: 12, color: color),
                    ],
                  ],
                ),
                Text(
                  '${current.toStringAsFixed(0)} / ${daily.toStringAsFixed(0)} $unit',
                  style: TextStyle(
                      fontSize: 10, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 3),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: pct),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (_, value, __) => ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: value,
                  color: overGoal ? Colors.red.shade400 : color,
                  backgroundColor: color.withValues(alpha: 0.15),
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Macro Contributor bottom sheet ────────────────────────────────────────────

class _MacroContributorSheet extends StatelessWidget {
  final String macro;
  final Color color;
  final List<TopFood> foods;
  final String field; // 'protein' | 'carbs' | 'fat'

  const _MacroContributorSheet({
    required this.macro,
    required this.color,
    required this.foods,
    required this.field,
  });

  double _val(TopFood f) =>
      field == 'protein' ? f.protein : field == 'carbs' ? f.carbs : f.fat;

  @override
  Widget build(BuildContext context) {
    final sorted = [...foods]..sort((a, b) => _val(b).compareTo(_val(a)));
    final meaningful = sorted.where((f) => _val(f) > 0).take(8).toList();
    final maxVal = meaningful.isEmpty ? 1.0 : _val(meaningful.first);
    final totalVal =
        meaningful.fold(0.0, (sum, f) => sum + _val(f));

    final icon = macro == 'Protein'
        ? Icons.fitness_center
        : macro == 'Carbs'
            ? Icons.grain
            : Icons.water_drop_outlined;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$macro Contributors',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    Text('Top foods by ${macro.toLowerCase()} content',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 12),
            if (meaningful.isEmpty)
              const Center(child: Text('No data available'))
            else
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: meaningful.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final f = meaningful[i];
                    final val = _val(f);
                    final barPct = maxVal > 0 ? val / maxVal : 0.0;
                    final sharePct = totalVal > 0
                        ? '${(val / totalVal * 100).toStringAsFixed(0)}%'
                        : '0%';

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 22,
                              height: 22,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text('${i + 1}',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: color)),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(f.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                            ),
                            Text(
                              '${val.toStringAsFixed(0)}g  ($sharePct)',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: barPct),
                          duration:
                              Duration(milliseconds: 400 + i * 80),
                          curve: Curves.easeOutCubic,
                          builder: (_, v, __) => ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: v,
                              color: color,
                              backgroundColor:
                                  color.withValues(alpha: 0.12),
                              minHeight: 9,
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ── 7-Day Macro Consistency grouped bar chart (Phase 1) ───────────────────────

class _MacroConsistencyCard extends StatelessWidget {
  final List<DailyNutritionTotal> dailyTotals;
  final DailyIntake intake;

  const _MacroConsistencyCard(
      {required this.dailyTotals, required this.intake});

  @override
  Widget build(BuildContext context) {
    final recent = dailyTotals.length > 7
        ? dailyTotals.sublist(dailyTotals.length - 7)
        : dailyTotals;

    final groups = recent.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      final pPct =
          intake.protein > 0 ? (d.protein / intake.protein).clamp(0.0, 1.5) : 0.0;
      final cPct =
          intake.carbs > 0 ? (d.carbs / intake.carbs).clamp(0.0, 1.5) : 0.0;
      final fPct =
          intake.fat > 0 ? (d.fat / intake.fat).clamp(0.0, 1.5) : 0.0;

      return BarChartGroupData(
        x: i,
        barsSpace: 3,
        barRods: [
          BarChartRodData(
              toY: pPct * 100,
              color: _proteinColor,
              width: 8,
              borderRadius: BorderRadius.circular(2)),
          BarChartRodData(
              toY: cPct * 100,
              color: _carbsColor,
              width: 8,
              borderRadius: BorderRadius.circular(2)),
          BarChartRodData(
              toY: fPct * 100,
              color: _fatColor,
              width: 8,
              borderRadius: BorderRadius.circular(2)),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Consistency',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('% of daily goal — dashed line = 100%',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 10),
            Row(
              children: [
                _dot(_proteinColor, 'Protein'),
                const SizedBox(width: 10),
                _dot(_carbsColor, 'Carbs'),
                const SizedBox(width: 10),
                _dot(_fatColor, 'Fat'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: groups.isEmpty
                  ? const Center(child: Text('No data'))
                  : BarChart(
                      BarChartData(
                        maxY: 150,
                        barGroups: groups,
                        gridData: FlGridData(
                          show: true,
                          horizontalInterval: 50,
                          getDrawingHorizontalLine: (v) => FlLine(
                            color: v == 100
                                ? Colors.grey.shade500
                                : Colors.grey.shade200,
                            strokeWidth: v == 100 ? 1.5 : 1,
                            dashArray: v == 100 ? [6, 4] : [3, 3],
                          ),
                          drawVerticalLine: false,
                        ),
                        borderData: FlBorderData(show: false),
                        titlesData: FlTitlesData(
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 34,
                              interval: 50,
                              getTitlesWidget: (v, _) => Text(
                                  '${v.toInt()}%',
                                  style: const TextStyle(fontSize: 9)),
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles:
                                  SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 22,
                              getTitlesWidget: (v, _) {
                                final idx = v.toInt();
                                if (idx < 0 || idx >= recent.length) {
                                  return const SizedBox();
                                }
                                final parts =
                                    recent[idx].date.split('-');
                                if (parts.length < 3) {
                                  return const SizedBox();
                                }
                                return Text('${parts[2]}/${parts[1]}',
                                    style:
                                        const TextStyle(fontSize: 9));
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

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

// ── Meal Distribution stacked bar chart (Phase 2) ─────────────────────────────

class _MealDistributionCard extends StatelessWidget {
  final List<MealDayCalories> mealCalories;

  const _MealDistributionCard({required this.mealCalories});

  @override
  Widget build(BuildContext context) {
    final recent = mealCalories.length > 7
        ? mealCalories.sublist(mealCalories.length - 7)
        : mealCalories;

    final groups = recent.asMap().entries.map((entry) {
      final i = entry.key;
      final d = entry.value;
      final total = d.total;

      return BarChartGroupData(
        x: i,
        barRods: [
          BarChartRodData(
            toY: total,
            width: 22,
            borderRadius: BorderRadius.circular(3),
            rodStackItems: [
              BarChartRodStackItem(0, d.breakfast, _bfastColor),
              BarChartRodStackItem(
                  d.breakfast, d.breakfast + d.lunch, _lunchColor),
              BarChartRodStackItem(d.breakfast + d.lunch,
                  d.breakfast + d.lunch + d.dinner, _dinnerColor),
              BarChartRodStackItem(
                  d.breakfast + d.lunch + d.dinner, total, _snackColor),
            ],
          ),
        ],
      );
    }).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal Distribution',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('Daily calories by meal type',
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              children: [
                _dot(_bfastColor, 'Breakfast'),
                _dot(_lunchColor, 'Lunch'),
                _dot(_dinnerColor, 'Dinner'),
                _dot(_snackColor, 'Snack'),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 180,
              child: BarChart(
                BarChartData(
                  barGroups: groups,
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: 500,
                    getDrawingHorizontalLine: (v) => FlLine(
                        color: Colors.grey.shade200, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 500,
                        getTitlesWidget: (v, _) => Text(
                            '${v.toInt()}',
                            style: const TextStyle(fontSize: 9)),
                      ),
                    ),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= recent.length) {
                            return const SizedBox();
                          }
                          final parts =
                              recent[idx].date.split('-');
                          if (parts.length < 3) {
                            return const SizedBox();
                          }
                          return Text('${parts[2]}/${parts[1]}',
                              style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

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

// ── Top Foods with macro mini-bars ────────────────────────────────────────────

class _TopFoodsCard extends StatelessWidget {
  final List<TopFood> topFoods;

  const _TopFoodsCard({required this.topFoods});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Top Foods',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('P = protein  C = carbs  F = fat',
                style:
                    TextStyle(fontSize: 10, color: Colors.grey.shade400)),
            const SizedBox(height: 10),
            ...topFoods.take(10).map((f) {
              final rank = topFoods.indexOf(f) + 1;
              final macroTotal = f.protein + f.carbs + f.fat;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: cs.primaryContainer,
                          child: Text('$rank',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: cs.onPrimaryContainer)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(f.name,
                                  style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500),
                                  overflow: TextOverflow.ellipsis),
                              Text(
                                '${f.calories.toStringAsFixed(0)} kcal  ×${f.count}'
                                '  P${f.protein.toStringAsFixed(0)}g  C${f.carbs.toStringAsFixed(0)}g  F${f.fat.toStringAsFixed(0)}g',
                                style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (macroTotal > 0) ...[
                      const SizedBox(height: 5),
                      Padding(
                        padding: const EdgeInsets.only(left: 38),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: SizedBox(
                            height: 6,
                            child: Row(
                              children: [
                                _macroBar(f.protein, macroTotal,
                                    _proteinColor),
                                _macroBar(
                                    f.carbs, macroTotal, _carbsColor),
                                _macroBar(
                                    f.fat, macroTotal, _fatColor),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _macroBar(double val, double total, Color color) {
    final pct = total > 0 ? val / total : 0.0;
    if (pct <= 0) return const SizedBox();
    return Expanded(
      flex: (pct * 100).round().clamp(1, 100),
      child: Container(color: color),
    );
  }
}

// ── Meal Timing Timeline (Phase 3) ─────────────────────────────────────────────
// Timeline axis: 6:00 AM (360 min) to 11:00 PM (1380 min)

class _MealTimelineCard extends StatelessWidget {
  final List<MealTimingDay> timings;
  final double avgWindowHours;
  final double avgFrontLoadPct;

  const _MealTimelineCard({
    required this.timings,
    required this.avgWindowHours,
    required this.avgFrontLoadPct,
  });

  static const _startMin = 360;   // 6 AM
  static const _endMin   = 1380;  // 11 PM
  static const _spanMin  = _endMin - _startMin; // 1020

  Color _colorFor(String mealType) {
    switch (mealType.toLowerCase()) {
      case 'breakfast': return _bfastColor;
      case 'lunch':     return _lunchColor;
      case 'dinner':    return _dinnerColor;
      default:          return _snackColor;
    }
  }

  double _fraction(int timeMinutes) =>
      ((timeMinutes - _startMin) / _spanMin).clamp(0.0, 1.0);

  double _bubbleRadius(double calories) =>
      (calories / 300 * 12).clamp(5.0, 18.0);

  @override
  Widget build(BuildContext context) {
    final recent = timings.length > 7
        ? timings.sublist(timings.length - 7)
        : timings;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Meal Timing',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 2),
            Text('Bubble size = calories  |  6 AM → 11 PM',
                style: TextStyle(
                    fontSize: 11, color: Colors.grey.shade500)),
            const SizedBox(height: 8),
            // Stats row
            Row(
              children: [
                _statChip(Icons.schedule,
                    'Eating window: ${avgWindowHours.toStringAsFixed(1)} hrs'),
                const SizedBox(width: 10),
                _statChip(Icons.wb_sunny_outlined,
                    'Before 3 PM: ${avgFrontLoadPct.toStringAsFixed(0)}%'),
              ],
            ),
            const SizedBox(height: 12),
            // Legend
            Wrap(
              spacing: 10,
              children: [
                _dot(_bfastColor, 'Breakfast'),
                _dot(_lunchColor, 'Lunch'),
                _dot(_dinnerColor, 'Dinner'),
                _dot(_snackColor, 'Snack'),
              ],
            ),
            const SizedBox(height: 10),
            // Axis labels
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('6 AM', style: TextStyle(fontSize: 9)),
                Text('12 PM', style: TextStyle(fontSize: 9)),
                Text('6 PM', style: TextStyle(fontSize: 9)),
                Text('11 PM', style: TextStyle(fontSize: 9)),
              ],
            ),
            const SizedBox(height: 4),
            // Timeline rows
            ...recent.map((day) {
              final parts = day.date.split('-');
              final label = parts.length >= 3
                  ? '${parts[2]}/${parts[1]}'
                  : day.date;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(label,
                          style: const TextStyle(fontSize: 9),
                          textAlign: TextAlign.right),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          final w = constraints.maxWidth;
                          return SizedBox(
                            height: 36,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                // Axis line
                                Positioned(
                                  left: 0,
                                  right: 0,
                                  top: 17,
                                  child: Container(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                ),
                                // Noon marker
                                Positioned(
                                  left: _fraction(720) * w - 0.5,
                                  top: 10,
                                  child: Container(
                                      width: 1,
                                      height: 14,
                                      color: Colors.grey.shade300),
                                ),
                                // Meal bubbles
                                for (final meal in day.meals)
                                  Builder(builder: (_) {
                                    final r = _bubbleRadius(meal.calories);
                                    final x = _fraction(meal.timeMinutes) * w;
                                    final color = _colorFor(meal.mealType);
                                    return Positioned(
                                      left: x - r,
                                      top: 18 - r,
                                      child: Tooltip(
                                        message:
                                            '${meal.mealType} ${meal.time}\n${meal.calories.round()} kcal',
                                        child: Container(
                                          width: r * 2,
                                          height: r * 2,
                                          decoration: BoxDecoration(
                                            color: color.withValues(
                                                alpha: 0.85),
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: color, width: 1.5),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _statChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.grey.shade600),
          const SizedBox(width: 3),
          Text(label,
              style: TextStyle(
                  fontSize: 10, color: Colors.grey.shade700)),
        ],
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

// ── Nutrition-Health Correlation cards (Phase 3) ───────────────────────────────

class _CorrelationSection extends StatelessWidget {
  final List<NutritionCorrelation> correlations;

  const _CorrelationSection({required this.correlations});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health Insights',
                  style: Theme.of(context).textTheme.titleSmall),
              Text('Nutrition patterns vs health metrics',
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
        ...correlations.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CorrelationCard(correlation: c),
            )),
      ],
    );
  }
}

class _CorrelationCard extends StatelessWidget {
  final NutritionCorrelation correlation;

  const _CorrelationCard({required this.correlation});

  @override
  Widget build(BuildContext context) {
    final c = correlation;
    final cs = Theme.of(context).colorScheme;
    final highIsBetter = c.betterWhenHigh;
    final diff = (c.highValue - c.lowValue).abs();
    final diffStr = diff.toStringAsFixed(1);

    // The "better" group
    final betterVal   = highIsBetter ? c.highValue : c.lowValue;
    final betterLabel = highIsBetter ? c.highLabel  : c.lowLabel;
    final worseVal    = highIsBetter ? c.lowValue   : c.highValue;
    final worseLabel  = highIsBetter ? c.lowLabel   : c.highLabel;

    final accentColor = highIsBetter ? Colors.green.shade600 : Colors.red.shade400;
    final insight =
        '${betterLabel.split('(').first.trim()} days average ${betterVal.toStringAsFixed(1)}${c.unit} ${c.metricLabel} — '
        '${diffStr} points higher than ${worseLabel.split('(').first.trim().toLowerCase()} days.';

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Colour header strip
          Container(
            height: 4,
            color: accentColor,
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Text(c.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 10),
                // Two-column comparison
                Row(
                  children: [
                    Expanded(
                        child: _CompareColumn(
                      label: betterLabel,
                      value: betterVal,
                      unit: c.unit,
                      color: Colors.green.shade600,
                      isBetter: true,
                    )),
                    Container(
                        width: 1,
                        height: 50,
                        color: Colors.grey.shade200),
                    Expanded(
                        child: _CompareColumn(
                      label: worseLabel,
                      value: worseVal,
                      unit: c.unit,
                      color: Colors.red.shade400,
                      isBetter: false,
                    )),
                  ],
                ),
                const SizedBox(height: 10),
                // Insight text
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 13, color: accentColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          insight,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade700,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareColumn extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;
  final bool isBetter;

  const _CompareColumn({
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    required this.isBetter,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${value.toStringAsFixed(1)}$unit',
          style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color),
        ),
        const SizedBox(height: 2),
        Icon(
          isBetter ? Icons.arrow_upward : Icons.arrow_downward,
          size: 12,
          color: color,
        ),
        const SizedBox(height: 2),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: TextStyle(fontSize: 9, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
