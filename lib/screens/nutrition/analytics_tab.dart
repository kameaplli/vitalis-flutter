import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/insight_data.dart';
import '../../models/nutrition_analytics.dart';
import '../../providers/nutrient_provider.dart';
import '../../providers/nutrition_analytics_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/medical_disclaimer.dart';
import '../../widgets/friendly_error.dart';
import '../../widgets/days_slider.dart';
import 'nutrition_insights_card.dart';

// ─── Nutrition AI Insights provider ──────────────────────────────────────────

// key = "person:days"
final nutritionInsightsProvider =
    FutureProvider.family<WeeklyInsight?, String>((ref, key) async {
  try {
    final parts = key.split(':');
    final person = parts[0];
    final days = parts.length > 1 ? parts[1] : '30';
    final res = await apiClient.dio.get(
      ApiConstants.insightsNutrition,
      queryParameters: {'person': person, 'days': int.parse(days)},
    );
    return WeeklyInsight.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

// ─── Analytics tab ────────────────────────────────────────────────────────────

class AnalyticsTab extends ConsumerStatefulWidget {
  const AnalyticsTab({super.key});
  @override
  ConsumerState<AnalyticsTab> createState() => _AnalyticsTabState();
}

class _AnalyticsTabState extends ConsumerState<AnalyticsTab> {
  int _days = 30;

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final key = '$person:$_days';
    final async = ref.watch(nutritionAnalyticsProvider(key));

    return Column(
      children: [
        // Period selector
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: DaysSlider(
            value: _days,
            onChanged: (d) => setState(() => _days = d),
          ),
        ),
        Expanded(
          child: async.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => FriendlyError(error: e, context: 'nutrition analytics'),
            data: (data) => _AnalyticsContent(data: data, days: _days, personKey: key),
          ),
        ),
      ],
    );
  }
}

class _AnalyticsContent extends ConsumerWidget {
  final NutritionAnalyticsData data;
  final int days;
  final String personKey;
  const _AnalyticsContent({required this.data, required this.days, required this.personKey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insightAsync = ref.watch(nutritionInsightsProvider(personKey));
    final microAsync = ref.watch(periodNutrientProvider(personKey));
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // AI Insights card
        insightAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
          data: (insight) => insight != null
              ? NutritionInsightsCard(insight: insight)
              : const SizedBox.shrink(),
        ),
        _MacroDonut(data: data),
        const SizedBox(height: 12),
        // Micronutrient insights
        microAsync.when(
          loading: () => const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (micro) => micro != null
              ? _MicronutrientSection(data: micro, days: days)
              : const SizedBox.shrink(),
        ),
        const SizedBox(height: 12),
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text('Meal Type Breakdown',
                style: Theme.of(context).textTheme.titleMedium),
            initiallyExpanded: false,
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 4),
            children: _mealTypes.map((mt) => _MealTypeCard(
                  mealType: mt,
                  macros: data.byMealType[mt],
                  topFoods: data.mealFoods[mt] ?? [],
                  maxCalories: _maxMealCalories(data),
                )).toList(),
          ),
        ),
        const SizedBox(height: 8),
        const MedicalDisclaimer(),
      ],
    );
  }

  static const _mealTypes = ['breakfast', 'lunch', 'dinner', 'snack'];

  double _maxMealCalories(NutritionAnalyticsData d) {
    double max = 1;
    for (final mt in _mealTypes) {
      final c = d.byMealType[mt]?.calories ?? 0;
      if (c > max) max = c;
    }
    return max;
  }
}

// ─── Macro donut chart ────────────────────────────────────────────────────────

class _MacroDonut extends StatefulWidget {
  final NutritionAnalyticsData data;
  const _MacroDonut({required this.data});
  @override
  State<_MacroDonut> createState() => _MacroDonutState();
}

class _MacroDonutState extends State<_MacroDonut> {
  int? _touched;

  void _showMacroSheet(BuildContext context, String macro, List<MacroFood> foods) {
    showModalBottomSheet(
      context: context,
      builder: (_) => _MacroFoodSheet(macro: macro, foods: foods),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.data.totals;
    final total = t.protein + t.carbs + t.fat;
    if (total <= 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No nutrition data for this period')),
        ),
      );
    }
    final sections = [
      PieChartSectionData(
        value: t.protein,
        color: const Color(0xFF1565C0),
        title: '${(t.protein / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 0 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: t.carbs,
        color: const Color(0xFF2E7D32),
        title: '${(t.carbs / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 1 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
      PieChartSectionData(
        value: t.fat,
        color: const Color(0xFFE65100),
        title: '${(t.fat / total * 100).toStringAsFixed(0)}%',
        radius: _touched == 2 ? 60 : 50,
        titleStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    ];
    const macroKeys = ['protein', 'carbs', 'fat'];
    const macroLabels = ['Protein', 'Carbs', 'Fat'];
    const macroColors = [Color(0xFF1565C0), Color(0xFF2E7D32), Color(0xFFE65100)];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macro Distribution',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text('Tap a segment to see top foods',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  centerSpaceRadius: 40,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      if (event is FlTapUpEvent) {
                        final idx = response?.touchedSection?.touchedSectionIndex;
                        setState(() => _touched = idx);
                        if (idx != null) {
                          _showMacroSheet(
                            context,
                            macroLabels[idx],
                            widget.data.macroFoods[macroKeys[idx]] ?? [],
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(3, (i) => Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(
                          color: macroColors[i], shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  Text(macroLabels[i], style: const TextStyle(fontSize: 12)),
                ]),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Meal type card ───────────────────────────────────────────────────────────

class _MealTypeCard extends StatelessWidget {
  final String mealType;
  final MealTypeMacros? macros;
  final List<MacroFood> topFoods;
  final double maxCalories;

  const _MealTypeCard({
    required this.mealType,
    required this.macros,
    required this.topFoods,
    required this.maxCalories,
  });

  static const _icons = {
    'breakfast': Icons.wb_sunny_outlined,
    'lunch':     Icons.light_mode_outlined,
    'dinner':    Icons.nights_stay_outlined,
    'snack':     Icons.local_cafe_outlined,
  };

  void _showFoodSheet(BuildContext context) {
    if (topFoods.isEmpty) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => _MealFoodSheet(mealType: mealType, foods: topFoods),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = macros;
    if (m == null || m.calories == 0) {
      return Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(_icons[mealType] ?? Icons.restaurant_outlined,
              color: Colors.grey),
          title: Text(_capitalize(mealType)),
          subtitle: const Text('No data'),
          dense: true,
        ),
      );
    }
    final frac = (m.calories / maxCalories).clamp(0.0, 1.0);
    final total = m.protein + m.carbs + m.fat;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _showFoodSheet(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(_icons[mealType] ?? Icons.restaurant_outlined,
                    size: 20, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(_capitalize(mealType),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${m.calories.toStringAsFixed(0)} kcal',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.bold)),
                if (topFoods.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Icon(Icons.chevron_right, size: 16,
                      color: Colors.grey.shade500),
                ],
              ]),
              const SizedBox(height: 6),
              // Calorie bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: frac,
                  minHeight: 8,
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
              const SizedBox(height: 6),
              // Macro sub-bars (stacked horizontal)
              if (total > 0)
                Row(children: [
                  _macroChip('P', m.protein, total, const Color(0xFF1565C0)),
                  const SizedBox(width: 4),
                  _macroChip('C', m.carbs, total, const Color(0xFF2E7D32)),
                  const SizedBox(width: 4),
                  _macroChip('F', m.fat, total, const Color(0xFFE65100)),
                ]),
              Text('${m.logCount} logs',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _macroChip(String label, double val, double total, Color color) {
    return Expanded(
      flex: (val / total * 100).round().clamp(1, 100),
      child: Container(
        height: 6,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

// ─── Bottom sheet: top foods for a macro ─────────────────────────────────────

class _MacroFoodSheet extends StatelessWidget {
  final String macro;
  final List<MacroFood> foods;
  const _MacroFoodSheet({required this.macro, required this.foods});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text('Top $macro Sources',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: foods.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = foods[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(f.foodName, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${f.occurrences}\u00d7 logged'),
                      trailing: Text(
                        '${f.total.toStringAsFixed(1)} g',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── Bottom sheet: top foods for a meal type ─────────────────────────────────

class _MealFoodSheet extends StatelessWidget {
  final String mealType;
  final List<MacroFood> foods;
  const _MealFoodSheet({required this.mealType, required this.foods});

  @override
  Widget build(BuildContext context) {
    final title = mealType.isEmpty
        ? 'Top Foods'
        : 'Top ${mealType[0].toUpperCase()}${mealType.substring(1)} Foods';
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        const SizedBox(height: 8),
        Container(width: 36, height: 4,
            decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        Expanded(
          child: foods.isEmpty
              ? const Center(child: Text('No data'))
              : ListView.separated(
                  controller: ctrl,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: foods.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final f = foods[i];
                    return ListTile(
                      leading: CircleAvatar(
                        radius: 14,
                        child: Text('${i + 1}',
                            style: const TextStyle(fontSize: 12)),
                      ),
                      title: Text(f.foodName, style: const TextStyle(fontSize: 14)),
                      subtitle: Text('${f.occurrences}\u00d7 logged'),
                      trailing: Text(
                        '${f.total.toStringAsFixed(1)} kcal',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      dense: true,
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

// ─── Micronutrient Insights Section ──────────────────────────────────────────

class _MicronutrientSection extends StatelessWidget {
  final PeriodNutrientData data;
  final int days;
  const _MicronutrientSection({required this.data, required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final s = data.summary;
    final periodLabel = days == 1 ? 'Today' : '${days}d avg';

    // Top 3 lowest + top 3 highest = 6 key nutrients
    final topLow = data.consumedLess.take(3).toList();
    final topHigh = data.consumedMore.take(3).toList();

    if (s.daysWithData == 0) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.science_outlined, size: 18, color: cs.primary),
              const SizedBox(width: 6),
              Text('Micronutrient Status',
                  style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(periodLabel,
                    style: TextStyle(fontSize: 11, color: cs.onPrimaryContainer)),
              ),
            ]),
            const SizedBox(height: 10),
            // Compact summary row
            Row(
              children: [
                _summaryChip(Icons.check_circle, Colors.green, '${s.adequateCount} OK'),
                const SizedBox(width: 8),
                _summaryChip(Icons.warning_amber, Colors.orange, '${s.approachingCount} Near'),
                const SizedBox(width: 8),
                _summaryChip(Icons.arrow_downward, Colors.red, '${s.lowCount} Low'),
                if (s.excessiveCount > 0) ...[
                  const SizedBox(width: 8),
                  _summaryChip(Icons.arrow_upward, Colors.deepPurple, '${s.excessiveCount} High'),
                ],
              ],
            ),
            // Top low nutrients
            if (topLow.isNotEmpty) ...[
              const SizedBox(height: 14),
              Row(children: [
                Icon(Icons.trending_down, size: 14, color: Colors.red.shade600),
                const SizedBox(width: 4),
                Text('Needs Attention', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.red.shade600)),
              ]),
              const SizedBox(height: 6),
              ...topLow.map((item) => _NutrientRow(item: item, isDeficient: true)),
            ],
            // Top high nutrients
            if (topHigh.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.trending_up, size: 14, color: Colors.green.shade600),
                const SizedBox(width: 4),
                Text('Above Target', style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.green.shade600)),
              ]),
              const SizedBox(height: 6),
              ...topHigh.map((item) => _NutrientRow(item: item, isDeficient: false)),
            ],
            if (topLow.isEmpty && topHigh.isEmpty) ...[
              const SizedBox(height: 10),
              Text('All tracked nutrients are within range',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 6),
            Text(
              '${s.daysWithData} day${s.daysWithData > 1 ? 's' : ''} of data · ${s.totalTracked} nutrients tracked',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryChip(IconData icon, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 2),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _NutrientRow extends StatelessWidget {
  final PeriodNutrientItem item;
  final bool isDeficient;
  const _NutrientRow({required this.item, required this.isDeficient});

  @override
  Widget build(BuildContext context) {
    final pct = item.percentDri;
    final pctText = pct != null ? '${pct.toStringAsFixed(0)}%' : '--';
    final barFrac = pct != null ? (pct / 100).clamp(0.0, 1.5) / 1.5 : 0.0;

    Color barColor;
    if (pct == null) {
      barColor = Colors.grey;
    } else if (pct > 150) {
      barColor = Colors.deepPurple;
    } else if (pct >= 100) {
      barColor = Colors.green;
    } else if (pct >= 50) {
      barColor = Colors.orange;
    } else {
      barColor = Colors.red;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              item.shortName ?? item.displayName,
              style: const TextStyle(fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: barFrac,
                minHeight: 6,
                backgroundColor: Colors.grey.shade200,
                color: barColor,
              ),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: Text(pctText,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: barColor,
                ),
                textAlign: TextAlign.right),
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: 60,
            child: Text(
              '${_formatValue(item.avgDaily)} ${item.unit}',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatValue(double v) {
    if (v >= 100) return v.toStringAsFixed(0);
    if (v >= 1) return v.toStringAsFixed(1);
    return v.toStringAsFixed(2);
  }
}
