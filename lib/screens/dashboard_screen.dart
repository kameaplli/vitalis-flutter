import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/selected_person_provider.dart';
import '../models/dashboard_data.dart';
import '../core/nutrition_utils.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final dashAsync = ref.watch(dashboardProvider(person));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(dashboardProvider(person)),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(dashboardProvider(person)),
        child: dashAsync.when(
          skipLoadingOnReload: true,
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error loading dashboard: $e')),
          data: (data) => _DashboardBody(data: data),
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  final DashboardData data;
  const _DashboardBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Quick log buttons ──────────────────────────────────────────────
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickButton('Log Meal', Icons.restaurant, Colors.green,
                    () => context.go('/nutrition')),
                const SizedBox(width: 8),
                _QuickButton('Log Water', Icons.water_drop, Colors.blue,
                    () => context.go('/hydration')),
                const SizedBox(width: 8),
                _QuickButton('Log Weight', Icons.monitor_weight, Colors.purple,
                    () => context.go('/weight')),
                const SizedBox(width: 8),
                _QuickButton('Log Health', Icons.favorite, Colors.red,
                    () => context.go('/health')),
              ],
            ),
          ),

          const SizedBox(height: 20),
          _sectionTitle(context, "Today's Summary"),
          const SizedBox(height: 8),

          // ── Calories + Water ──────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _StatCard(
                label: 'Calories',
                todayValue: data.todayCalories.toStringAsFixed(0),
                todayUnit: 'kcal',
                weekAvg: '${data.weekAvgCalories.toStringAsFixed(0)} kcal',
                prevAvg: data.prevWeekAvgCalories.toStringAsFixed(0),
                up: data.weekAvgCalories >= data.prevWeekAvgCalories,
                icon: Icons.local_fire_department,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Water',
                todayValue: (data.todayWater / 1000).toStringAsFixed(1),
                todayUnit: 'L',
                weekAvg: '${(data.weekAvgWater / 1000).toStringAsFixed(1)} L',
                prevAvg:
                    '${(data.prevWeekAvgWater / 1000).toStringAsFixed(1)} L',
                up: data.weekAvgWater >= data.prevWeekAvgWater,
                icon: Icons.water_drop,
                color: Colors.blue,
              ),
            ),
          ]),

          const SizedBox(height: 10),

          // ── Weight + Meals ────────────────────────────────────────────────
          Row(children: [
            Expanded(
              child: _StatCard(
                label: 'Weight',
                todayValue: data.currentWeight != null
                    ? data.currentWeight!.toStringAsFixed(1)
                    : '—',
                todayUnit: data.currentWeight != null ? 'kg' : '',
                weekAvg: data.weightChange != null
                    ? '${data.weightChange! >= 0 ? '+' : ''}${data.weightChange!.toStringAsFixed(1)} kg vs prev'
                    : 'No prev entry',
                prevAvg: data.previousWeight != null
                    ? '${data.previousWeight!.toStringAsFixed(1)} kg'
                    : '—',
                up: (data.weightChange ?? 0) <= 0,
                icon: Icons.monitor_weight_outlined,
                color: Colors.purple,
                showTrend: data.weightChange != null,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Meals Today',
                todayValue: '${data.mealsCount}',
                todayUnit: 'meals',
                weekAvg: '${data.weekAvgMeals.toStringAsFixed(1)}/day (7d)',
                prevAvg: '${data.prevWeekAvgMeals.toStringAsFixed(1)}/day',
                up: data.weekAvgMeals >= data.prevWeekAvgMeals,
                icon: Icons.restaurant,
                color: Colors.green,
              ),
            ),
          ]),

          const SizedBox(height: 16),

          // ── Today's macros ────────────────────────────────────────────────
          _MacrosCard(data: data),

          const SizedBox(height: 16),

          // ── Meal distribution ─────────────────────────────────────────────
          _MealDistributionCard(distribution: data.mealDistribution),

          const SizedBox(height: 16),

          // ── Health score ──────────────────────────────────────────────────
          _HealthScoreCard(
              score: data.healthScore, prev: data.prevHealthScore),

          const SizedBox(height: 16),

          // ── Top calorie foods ─────────────────────────────────────────────
          if (data.topCalorieFoods.isNotEmpty)
            _TopFoodsCard(foods: data.topCalorieFoods),

          const SizedBox(height: 16),

          // ── Personalized insights ─────────────────────────────────────────
          _InsightsCard(insights: data.insights),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold),
      );
}

// ── Unified stat card (today + 7d avg + vs prev week) ────────────────────────

class _StatCard extends StatelessWidget {
  final String label;
  final String todayValue;
  final String todayUnit;
  final String weekAvg;   // e.g. "1,234 kcal" or "1.8 L"
  final String prevAvg;   // e.g. "1,100 kcal"
  final bool up;
  final IconData icon;
  final Color color;
  final bool showTrend;

  const _StatCard({
    required this.label,
    required this.todayValue,
    required this.todayUnit,
    required this.weekAvg,
    required this.prevAvg,
    required this.up,
    required this.icon,
    required this.color,
    this.showTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label row
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            // Today value (big)
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(todayValue,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: color)),
              if (todayUnit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(todayUnit,
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            // 7d avg
            Text('7d avg: $weekAvg',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            // vs prev week
            if (showTrend)
              Row(children: [
                Icon(
                  up ? Icons.trending_up : Icons.trending_down,
                  size: 13,
                  color: up ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 3),
                Expanded(
                  child: Text('Prev: $prevAvg',
                      style: TextStyle(
                          fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

// ── Meal distribution ─────────────────────────────────────────────────────────

class _MealDistributionCard extends StatelessWidget {
  final Map<String, int> distribution;

  const _MealDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total =
        distribution.values.fold(0, (s, v) => s + v).toDouble();
    final entries = [
      ('Breakfast', 'breakfast', Colors.amber),
      ('Lunch', 'lunch', Colors.green),
      ('Dinner', 'dinner', Colors.deepOrange),
      ('Snack', 'snack', Colors.purple),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.pie_chart_outline, size: 16),
                const SizedBox(width: 6),
                Text('Meal Distribution (7 days)',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final count = distribution[e.$2] ?? 0;
              final frac = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 72,
                      child: Text(e.$1,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          color: e.$3,
                          backgroundColor: e.$3.withValues(alpha: 0.15),
                          minHeight: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$count',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: e.$3)),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

// ── Health score card ─────────────────────────────────────────────────────────

class _HealthScoreCard extends StatelessWidget {
  final HealthScoreData score;
  final HealthScoreData prev;

  const _HealthScoreCard({required this.score, required this.prev});

  @override
  Widget build(BuildContext context) {
    final delta = score.total - prev.total;
    final deltaStr =
        '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs prev week';
    final deltaColor = delta >= 0 ? Colors.green : Colors.red;

    final components = [
      ('Nutrition', score.nutrition, Icons.restaurant, Colors.green),
      ('Hydration', score.hydration, Icons.water_drop, Colors.blue),
      ('Exercise', score.exercise, Icons.fitness_center, Colors.orange),
      ('Sleep', score.sleep, Icons.bedtime, Colors.indigo),
      ('Mood', score.mood, Icons.mood, Colors.pink),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.health_and_safety_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Health Score (7 days)',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.total.toStringAsFixed(0)}/100',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: _scoreColor(score.total)),
                    ),
                    Text(deltaStr,
                        style: TextStyle(
                            fontSize: 11, color: deltaColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...components.map((c) {
              final prevVal = _prevVal(c.$1, prev);
              final prevDelta = c.$2 - prevVal;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(c.$3, size: 14, color: c.$4),
                    const SizedBox(width: 6),
                    SizedBox(
                      width: 68,
                      child: Text(c.$1,
                          style: const TextStyle(fontSize: 12)),
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: c.$2 / 20,
                          color: c.$4,
                          backgroundColor:
                              c.$4.withValues(alpha: 0.15),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${c.$2.toStringAsFixed(0)}/20',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 4),
                    if (prevVal > 0)
                      Text(
                        '${prevDelta >= 0 ? '+' : ''}${prevDelta.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 10,
                            color:
                                prevDelta >= 0 ? Colors.green : Colors.red),
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

  double _prevVal(String name, HealthScoreData p) {
    switch (name) {
      case 'Nutrition':
        return p.nutrition;
      case 'Hydration':
        return p.hydration;
      case 'Exercise':
        return p.exercise;
      case 'Sleep':
        return p.sleep;
      case 'Mood':
        return p.mood;
      default:
        return 0;
    }
  }

  Color _scoreColor(double v) {
    if (v >= 70) return Colors.green;
    if (v >= 40) return Colors.orange;
    return Colors.red;
  }
}

// ── Top calorie foods card ────────────────────────────────────────────────────

class _TopFoodsCard extends StatelessWidget {
  final List<DashboardTopFood> foods;

  const _TopFoodsCard({required this.foods});

  @override
  Widget build(BuildContext context) {
    final maxCal =
        foods.isEmpty ? 1.0 : foods.first.calories;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_food_beverage_outlined, size: 16),
                const SizedBox(width: 6),
                Text('Top Calorie Sources (7 days)',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            ...foods.map((f) {
              final frac =
                  maxCal > 0 ? f.calories / maxCal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Text(
                        f.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          color: Colors.deepOrange,
                          backgroundColor:
                              Colors.deepOrange.withValues(alpha: 0.15),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${f.calories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600),
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
}

// ── Personalized insights ─────────────────────────────────────────────────────

class _InsightsCard extends StatelessWidget {
  final List<DashboardInsight> insights;

  const _InsightsCard({required this.insights});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lightbulb_outline, size: 16,
                    color: Colors.amber),
                const SizedBox(width: 6),
                Text('Personalised Insights',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 10),
            if (insights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Log meals, water, sleep and exercise to unlock personalised tips.',
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
              )
            else
              ...insights.map((ins) => _InsightTile(insight: ins)),
          ],
        ),
      ),
    );
  }
}

class _InsightTile extends StatelessWidget {
  final DashboardInsight insight;
  const _InsightTile({required this.insight});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (insight.type) {
      'positive' => (Icons.check_circle_outline, Colors.green),
      'warning' => (Icons.warning_amber_outlined, Colors.orange),
      'tip' => (Icons.tips_and_updates_outlined, Colors.blue),
      _ => (Icons.info_outline, Colors.grey),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(insight.message,
                style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// ── Macros card ───────────────────────────────────────────────────────────────

class _MacrosCard extends ConsumerWidget {
  final DashboardData data;
  const _MacrosCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final person = ref.watch(selectedPersonProvider);
    int? personAge;
    String? personGender;
    if (person == 'self') {
      personAge = auth.user?.age;
      personGender = auth.user?.gender;
    } else {
      final member = auth.user?.profile.children
          .where((c) => c.id == person).firstOrNull;
      personAge = member?.age;
      personGender = member?.gender;
    }
    final intake = getDailyIntake(personAge, personGender);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.egg_outlined, size: 16),
                const SizedBox(width: 6),
                Text("Today's Macros",
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            _IntakeRow('Protein', data.todayProtein, intake.protein, 'g',
                Colors.blue),
            _IntakeRow(
                'Carbs', data.todayCarbs, intake.carbs, 'g', Colors.orange),
            _IntakeRow('Fat', data.todayFat, intake.fat, 'g', Colors.red),
          ],
        ),
      ),
    );
  }
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

// ── Quick log button ──────────────────────────────────────────────────────────

class _QuickButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _QuickButton(this.label, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.5)),
      ),
    );
  }
}
