import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/nutrition_utils.dart';
import '../models/analytics_data.dart';
import '../models/dashboard_data.dart';
import '../models/grocery_models.dart';
import '../providers/analytics_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/grocery_provider.dart';
import '../providers/hydration_provider.dart';
import '../providers/selected_person_provider.dart';
import 'insights_screen.dart';

// ── Home screen (merged Dashboard + Analytics) ────────────────────────────────

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  // 0 = Today, 7 = 7d, 30 = 30d
  int _days = 0;

  void _refresh(String person) {
    ref.invalidate(dashboardProvider(person));
    if (_days > 0) ref.invalidate(analyticsProvider('$person:$_days'));
    ref.invalidate(grocerySpendingProvider('$person:month'));
    ref.invalidate(todayHydrationProvider(person));
  }

  @override
  Widget build(BuildContext context) {
    final person   = ref.watch(selectedPersonProvider);
    final dashAsync = ref.watch(dashboardProvider(person));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(person),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(person),
        child: dashAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _HomeShimmer(),
          error: (e, _) => _HomeError(
            error: e,
            onRetry: () => _refresh(person),
          ),
          data: (data) => _HomeBody(
            data:   data,
            days:   _days,
            person: person,
            onDaysChanged: (d) => setState(() => _days = d),
          ),
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerWidget {
  final DashboardData data;
  final int days;
  final String person;
  final ValueChanged<int> onDaysChanged;

  const _HomeBody({
    required this.data,
    required this.days,
    required this.person,
    required this.onDaysChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analyticsAsync = days > 0
        ? ref.watch(analyticsProvider('$person:$days'))
        : const AsyncValue<NutritionAnalytics>.loading();

    final groceryAsync = ref.watch(grocerySpendingProvider('$person:month'));
    final hydrationAsync = ref.watch(todayHydrationProvider(person));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Period chips ──────────────────────────────────────────────────
        SliverToBoxAdapter(child: _PeriodSelector(days: days, onChanged: onDaysChanged)),

        // ── Vitality hero card ────────────────────────────────────────────
        SliverToBoxAdapter(child: _VitalityHeroCard(data: data, person: person)),

        // ── Today's summary grid (2×2) ────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionTitle(context, "Today's Summary"),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Calories', icon: Icons.local_fire_department,
                    color: Colors.orange,
                    todayValue: data.todayCalories.toStringAsFixed(0), todayUnit: 'kcal',
                    weekAvg: '${data.weekAvgCalories.toStringAsFixed(0)} kcal',
                    prevAvg: data.prevWeekAvgCalories.toStringAsFixed(0),
                    up: data.weekAvgCalories >= data.prevWeekAvgCalories,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _StatCard(
                    label: 'Weight', icon: Icons.monitor_weight_outlined,
                    color: Colors.purple,
                    todayValue: data.currentWeight != null
                        ? data.currentWeight!.toStringAsFixed(1) : '—',
                    todayUnit: data.currentWeight != null ? 'kg' : '',
                    weekAvg: data.weightChange != null
                        ? '${data.weightChange! >= 0 ? '+' : ''}${data.weightChange!.toStringAsFixed(1)} kg'
                        : 'No prev entry',
                    prevAvg: data.previousWeight != null
                        ? '${data.previousWeight!.toStringAsFixed(1)} kg' : '—',
                    up: (data.weightChange ?? 0) <= 0,
                    showTrend: data.weightChange != null,
                  )),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _StatCard(
                    label: 'Meals Today', icon: Icons.restaurant,
                    color: Colors.green,
                    todayValue: '${data.mealsCount}', todayUnit: 'meals',
                    weekAvg: '${data.weekAvgMeals.toStringAsFixed(1)}/day (7d)',
                    prevAvg: '${data.prevWeekAvgMeals.toStringAsFixed(1)}/day',
                    up: data.weekAvgMeals >= data.prevWeekAvgMeals,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _HydrationStatCard(
                    hydrationAsync: hydrationAsync,
                    weekAvg: data.weekAvgWater,
                    prevAvg: data.prevWeekAvgWater,
                  )),
                ]),
              ],
            ),
          ),
        ),

        // ── Hydration quick-log ───────────────────────────────────────────
        SliverToBoxAdapter(
          child: _HydrationQuickLog(person: person, hydrationAsync: hydrationAsync),
        ),

        // ── Quick action buttons ──────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _QuickButton('Log Meal',   Icons.restaurant,         Colors.green,
                      () => context.go('/nutrition')),
                  const SizedBox(width: 8),
                  _QuickButton('Log Weight', Icons.monitor_weight,     Colors.purple,
                      () => context.push('/weight')),
                  const SizedBox(width: 8),
                  _QuickButton('Log Health', Icons.favorite,           Colors.red,
                      () => context.go('/health')),
                  const SizedBox(width: 8),
                  _QuickButton('Eczema',     Icons.healing_outlined,   Colors.teal,
                      () => context.push('/eczema')),
                  const SizedBox(width: 8),
                  _QuickButton('Products',   Icons.inventory_2_outlined, Colors.indigo,
                      () => context.push('/products')),
                  const SizedBox(width: 8),
                  _QuickButton('Insights',   Icons.psychology_outlined,  Colors.deepPurple,
                      () => context.push('/insights')),
                  const SizedBox(width: 8),
                  _QuickButton('Skin Photos', Icons.camera_alt_outlined, Colors.brown,
                      () => context.push('/skin-photos')),
                ],
              ),
            ),
          ),
        ),

        // ── Macros card ───────────────────────────────────────────────────
        SliverToBoxAdapter(child: _MacrosCard(data: data)),

        // ── Meal distribution ─────────────────────────────────────────────
        SliverToBoxAdapter(child: _MealDistributionCard(distribution: data.mealDistribution)),

        // ── Weekly trends (analytics) — only when 7d or 30d selected ──────
        if (days > 0)
          SliverToBoxAdapter(
            child: _WeeklyTrends(analyticsAsync: analyticsAsync, days: days),
          ),

        // ── Health score ──────────────────────────────────────────────────
        SliverToBoxAdapter(
          child: _HealthScoreCard(score: data.healthScore, prev: data.prevHealthScore),
        ),

        // ── Flare risk snapshot ─────────────────────────────────────────
        SliverToBoxAdapter(child: _FlareRiskSnapshot()),

        // ── Top calorie foods ─────────────────────────────────────────────
        if (data.topCalorieFoods.isNotEmpty)
          SliverToBoxAdapter(child: _TopFoodsCard(foods: data.topCalorieFoods)),

        // ── Personalized insights ─────────────────────────────────────────
        SliverToBoxAdapter(child: _InsightsCard(insights: data.insights)),

        // ── Grocery snapshot ──────────────────────────────────────────────
        SliverToBoxAdapter(child: _GrocerySnapshot(groceryAsync: groceryAsync)),

        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  static Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.bold),
      );
}

// ── Period selector ───────────────────────────────────────────────────────────

class _PeriodSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  const _PeriodSelector({required this.days, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _chip(context, 'Today', 0),
          const SizedBox(width: 8),
          _chip(context, '7 days', 7),
          const SizedBox(width: 8),
          _chip(context, '30 days', 30),
        ],
      ),
    );
  }

  Widget _chip(BuildContext context, String label, int value) {
    final selected = days == value;
    final cs = Theme.of(context).colorScheme;
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onChanged(value),
      backgroundColor: cs.surfaceContainerHighest,
      selectedColor: cs.primaryContainer,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
        color: selected ? cs.onPrimaryContainer : cs.onSurfaceVariant,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

// ── Vitality hero card ────────────────────────────────────────────────────────

class _VitalityHeroCard extends ConsumerWidget {
  final DashboardData data;
  final String person;
  const _VitalityHeroCard({required this.data, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs    = Theme.of(context).colorScheme;
    final score = data.healthScore.total;
    final auth  = ref.watch(authProvider);
    final name  = person == 'self'
        ? (auth.user?.name ?? 'you')
        : (auth.user?.profile.children
                .where((c) => c.id == person)
                .firstOrNull
                ?.name ??
            'them');
    final firstName = name.split(' ').first;
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    final scoreColor = score >= 70 ? Colors.green : score >= 40 ? Colors.orange : Colors.red;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      color: cs.primaryContainer.withValues(alpha: 0.35),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Score ring
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: score / 100,
                    strokeWidth: 6,
                    color: scoreColor,
                    backgroundColor: scoreColor.withValues(alpha: 0.15),
                    strokeCap: StrokeCap.round,
                  ),
                  Text(
                    score.toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: scoreColor,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$greeting, $firstName',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    score >= 70
                        ? 'Great vitality score! Keep it up.'
                        : score >= 40
                            ? 'Room to improve — check your insights below.'
                            : 'Log more activity to boost your score.',
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              score >= 70 ? Icons.sentiment_very_satisfied
                  : score >= 40 ? Icons.sentiment_neutral
                  : Icons.sentiment_dissatisfied,
              size: 28,
              color: scoreColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Hydration stat card (uses async provider) ─────────────────────────────────

class _HydrationStatCard extends StatelessWidget {
  final AsyncValue<double> hydrationAsync;
  final double weekAvg;
  final double prevAvg;
  const _HydrationStatCard({
    required this.hydrationAsync,
    required this.weekAvg,
    required this.prevAvg,
  });

  @override
  Widget build(BuildContext context) {
    final todayL = hydrationAsync.when(
      data: (ml) => (ml / 1000).toStringAsFixed(1),
      loading: () => '…',
      error: (_, __) => '—',
    );
    return _StatCard(
      label: 'Water',
      icon: Icons.water_drop,
      color: Colors.blue,
      todayValue: todayL,
      todayUnit: 'L',
      weekAvg: '${(weekAvg / 1000).toStringAsFixed(1)} L (7d avg)',
      prevAvg: '${(prevAvg / 1000).toStringAsFixed(1)} L',
      up: weekAvg >= prevAvg,
    );
  }
}

// ── Hydration quick-log ───────────────────────────────────────────────────────

class _HydrationQuickLog extends ConsumerStatefulWidget {
  final String person;
  final AsyncValue<double> hydrationAsync;
  const _HydrationQuickLog({required this.person, required this.hydrationAsync});

  @override
  ConsumerState<_HydrationQuickLog> createState() => _HydrationQuickLogState();
}

class _HydrationQuickLogState extends ConsumerState<_HydrationQuickLog> {
  bool _logging = false;

  Future<void> _log(int ml) async {
    if (_logging) return;
    setState(() => _logging = true);
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final now   = TimeOfDay.now();
      final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await apiClient.dio.post(ApiConstants.hydrationLog, data: {
        'quantity':          ml,
        'beverage_type':     'water',
        'date':              today,
        'time':              timeStr,
        if (widget.person != 'self') 'family_member_id': widget.person,
      });
      ref.invalidate(todayHydrationProvider(widget.person));
      ref.invalidate(dashboardProvider(widget.person));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${ml >= 1000 ? '${ml ~/ 1000}.${(ml % 1000) ~/ 100}' : ml} ${ml >= 1000 ? 'L' : 'ml'} logged!'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _logging = false);
    }
  }

  Future<void> _logCustom() async {
    final ctrl = TextEditingController();
    final ml = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Water'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Amount (ml)', suffixText: 'ml'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final v = int.tryParse(ctrl.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const Text('Log'),
          ),
        ],
      ),
    );
    if (ml != null && ml > 0) _log(ml);
  }

  @override
  Widget build(BuildContext context) {
    final cs     = Theme.of(context).colorScheme;
    final todayL = widget.hydrationAsync.when(
      data:    (ml) => '${(ml / 1000).toStringAsFixed(1)} L today',
      loading: () => '…',
      error:   (_, __) => '',
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text('Quick Hydration Log',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(todayL,
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _WaterBtn('200 ml', 200, cs, _logging, _log),
                const SizedBox(width: 6),
                _WaterBtn('350 ml', 350, cs, _logging, _log),
                const SizedBox(width: 6),
                _WaterBtn('500 ml', 500, cs, _logging, _log),
                const SizedBox(width: 6),
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _logging ? null : _logCustom,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Custom', style: TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WaterBtn extends StatelessWidget {
  final String label;
  final int ml;
  final ColorScheme cs;
  final bool disabled;
  final Future<void> Function(int) onLog;

  const _WaterBtn(this.label, this.ml, this.cs, this.disabled, this.onLog);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FilledButton.tonal(
        onPressed: disabled ? null : () => onLog(ml),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: cs.primaryContainer.withValues(alpha: 0.5),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}

// ── Weekly trends (analytics charts) ─────────────────────────────────────────

class _WeeklyTrends extends StatelessWidget {
  final AsyncValue<NutritionAnalytics> analyticsAsync;
  final int days;
  const _WeeklyTrends({required this.analyticsAsync, required this.days});

  @override
  Widget build(BuildContext context) {
    return analyticsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: _ShimmerCard(height: 160),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (analytics) {
        if (analytics.dailyTotals.isEmpty) return const SizedBox.shrink();
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.show_chart, size: 16),
                    const SizedBox(width: 6),
                    Text('Calorie Trend ($days days)',
                        style: Theme.of(context).textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: _CalorieTrendChart(analytics.dailyTotals),
                ),
                const SizedBox(height: 12),
                // Macro totals summary row
                _MacroSummaryRow(analytics.macroTotals, days),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _CalorieTrendChart extends StatelessWidget {
  final List<DailyNutritionTotal> totals;
  const _CalorieTrendChart(this.totals);

  @override
  Widget build(BuildContext context) {
    if (totals.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    final spots = totals.asMap().entries.map((e) {
      return FlSpot(e.key.toDouble(), e.value.calories);
    }).toList();

    final maxY = totals.map((d) => d.calories).reduce((a, b) => a > b ? a : b);
    final minY = 0.0;

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY * 1.2,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY > 0 ? maxY / 3 : 500,
          getDrawingHorizontalLine: (_) => FlLine(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY > 0 ? maxY / 3 : 500,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: totals.length <= 14,
              interval: 1,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= totals.length) return const Text('');
                final d = totals[i].date;
                if (d.length < 10) return const Text('');
                return Text(
                  '${d.substring(5, 7)}/${d.substring(8)}',
                  style: TextStyle(fontSize: 8, color: cs.onSurfaceVariant),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: cs.primary,
            barWidth: 2.5,
            dotData: FlDotData(
              show: totals.length <= 10,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3, color: cs.primary,
                strokeWidth: 1.5,
                strokeColor: cs.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.25),
                  cs.primary.withValues(alpha: 0.02),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroSummaryRow extends StatelessWidget {
  final MacroTotals macros;
  final int days;
  const _MacroSummaryRow(this.macros, this.days);

  @override
  Widget build(BuildContext context) {
    final total = macros.total;
    if (total <= 0) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _MacroChip('Protein', macros.protein, total, Colors.blue),
        _MacroChip('Carbs',   macros.carbs,   total, Colors.orange),
        _MacroChip('Fat',     macros.fat,      total, Colors.red),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final String label;
  final double value;
  final double total;
  final Color color;
  const _MacroChip(this.label, this.value, this.total, this.color);

  @override
  Widget build(BuildContext context) {
    final pct = total > 0 ? (value / total * 100).toStringAsFixed(0) : '0';
    return Column(
      children: [
        Text('$pct%', style: TextStyle(
            fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
      ],
    );
  }
}

// ── Grocery snapshot ──────────────────────────────────────────────────────────

class _GrocerySnapshot extends StatelessWidget {
  final AsyncValue<GrocerySpending> groceryAsync;
  const _GrocerySnapshot({required this.groceryAsync});

  @override
  Widget build(BuildContext context) {
    return groceryAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (spending) {
        if (spending.totalSpend <= 0) return const SizedBox.shrink();
        final top3 = spending.byCategory.take(3).toList();
        final cs   = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.shopping_cart_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Grocery This Month',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('\$${spending.totalSpend.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.primary)),
                  ],
                ),
                const SizedBox(height: 10),
                ...top3.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(cat.category,
                            style: const TextStyle(fontSize: 12)),
                      ),
                      Text(
                        '${cat.percentage.toStringAsFixed(0)}% · \$${cat.amount.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => context.go('/grocery'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('View full breakdown',
                          style: TextStyle(
                              fontSize: 12, color: cs.primary,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 10, color: cs.primary),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Shimmer skeleton ──────────────────────────────────────────────────────────

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final base      = isDark ? const Color(0xFF424242) : const Color(0xFFE0E0E0);
    final highlight = isDark ? const Color(0xFF616161) : const Color(0xFFF5F5F5);
    return Shimmer.fromColors(
      baseColor: base, highlightColor: highlight,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _shimmerBox(height: 32, width: 180),
            const SizedBox(height: 12),
            _shimmerBox(height: 88, width: double.infinity),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _shimmerBox(height: 110)),
              const SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 110)),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: _shimmerBox(height: 110)),
              const SizedBox(width: 10),
              Expanded(child: _shimmerBox(height: 110)),
            ]),
            const SizedBox(height: 12),
            _shimmerBox(height: 80, width: double.infinity),
            const SizedBox(height: 12),
            _shimmerBox(height: 120, width: double.infinity),
          ],
        ),
      ),
    );
  }

  static Widget _shimmerBox({required double height, double? width}) => Container(
        height: height,
        width: width,
        margin: const EdgeInsets.only(bottom: 0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
      );
}

class _ShimmerCard extends StatelessWidget {
  final double height;
  const _ShimmerCard({required this.height});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ── Error widget ──────────────────────────────────────────────────────────────

class _HomeError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const _HomeError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            Text('Couldn\'t load dashboard',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Shared card widgets (kept from original dashboard) ────────────────────────

class _StatCard extends StatelessWidget {
  final String label, todayValue, todayUnit, weekAvg, prevAvg;
  final bool up, showTrend;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,    required this.icon,     required this.color,
    required this.todayValue, required this.todayUnit,
    required this.weekAvg,  required this.prevAvg,  required this.up,
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
            Row(children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 11, color: Colors.grey.shade600,
                        fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis),
              ),
            ]),
            const SizedBox(height: 6),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(todayValue,
                  style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.bold, color: color)),
              if (todayUnit.isNotEmpty) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(todayUnit,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            Text('7d avg: $weekAvg',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            if (showTrend)
              Row(children: [
                Icon(up ? Icons.trending_up : Icons.trending_down,
                    size: 13, color: up ? Colors.green : Colors.red),
                const SizedBox(width: 3),
                Expanded(
                  child: Text('Prev: $prevAvg',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                      overflow: TextOverflow.ellipsis),
                ),
              ]),
          ],
        ),
      ),
    );
  }
}

class _MealDistributionCard extends StatelessWidget {
  final Map<String, int> distribution;
  const _MealDistributionCard({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final total = distribution.values.fold(0, (s, v) => s + v).toDouble();
    final entries = [
      ('Breakfast', 'breakfast', Colors.amber),
      ('Lunch',     'lunch',     Colors.green),
      ('Dinner',    'dinner',    Colors.deepOrange),
      ('Snack',     'snack',     Colors.purple),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.pie_chart_outline, size: 16),
              const SizedBox(width: 6),
              Text('Meal Distribution (7 days)',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 12),
            ...entries.map((e) {
              final count = distribution[e.$2] ?? 0;
              final frac  = total > 0 ? count / total : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  SizedBox(
                    width: 72,
                    child: Text(e.$1, style: const TextStyle(fontSize: 12)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac, color: e.$3,
                        backgroundColor: e.$3.withValues(alpha: 0.15),
                        minHeight: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('$count', style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold, color: e.$3)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _HealthScoreCard extends StatelessWidget {
  final HealthScoreData score, prev;
  const _HealthScoreCard({required this.score, required this.prev});

  @override
  Widget build(BuildContext context) {
    final delta    = score.total - prev.total;
    final deltaStr = '${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(1)} vs prev week';
    final components = [
      ('Nutrition', score.nutrition, Icons.restaurant,     Colors.green),
      ('Hydration', score.hydration, Icons.water_drop,     Colors.blue),
      ('Exercise',  score.exercise,  Icons.fitness_center, Colors.orange),
      ('Sleep',     score.sleep,     Icons.bedtime,        Colors.indigo),
      ('Mood',      score.mood,      Icons.mood,           Colors.pink),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.health_and_safety_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Health Score (7 days)',
                  style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${score.total.toStringAsFixed(0)}/100',
                      style: TextStyle(
                          fontSize: 20, fontWeight: FontWeight.bold,
                          color: _scoreColor(score.total))),
                  Text(deltaStr,
                      style: TextStyle(
                          fontSize: 11,
                          color: delta >= 0 ? Colors.green : Colors.red)),
                ],
              ),
            ]),
            const SizedBox(height: 14),
            ...components.map((c) {
              final pv = _prevVal(c.$1, prev);
              final pd = c.$2 - pv;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Icon(c.$3, size: 14, color: c.$4),
                  const SizedBox(width: 6),
                  SizedBox(width: 68, child: Text(c.$1, style: const TextStyle(fontSize: 12))),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: c.$2 / 20, color: c.$4,
                        backgroundColor: c.$4.withValues(alpha: 0.15),
                        minHeight: 8,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${c.$2.toStringAsFixed(0)}/20',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                  const SizedBox(width: 4),
                  if (pv > 0)
                    Text('${pd >= 0 ? '+' : ''}${pd.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 10,
                            color: pd >= 0 ? Colors.green : Colors.red)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _prevVal(String name, HealthScoreData p) {
    switch (name) {
      case 'Nutrition': return p.nutrition;
      case 'Hydration': return p.hydration;
      case 'Exercise':  return p.exercise;
      case 'Sleep':     return p.sleep;
      case 'Mood':      return p.mood;
      default:          return 0;
    }
  }

  Color _scoreColor(double v) {
    if (v >= 70) return Colors.green;
    if (v >= 40) return Colors.orange;
    return Colors.red;
  }
}

class _TopFoodsCard extends StatelessWidget {
  final List<DashboardTopFood> foods;
  const _TopFoodsCard({required this.foods});

  @override
  Widget build(BuildContext context) {
    final maxCal = foods.isEmpty ? 1.0 : foods.first.calories;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.emoji_food_beverage_outlined, size: 16),
              const SizedBox(width: 6),
              Text('Top Calorie Sources (7 days)',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 12),
            ...foods.map((f) {
              final frac = maxCal > 0 ? f.calories / maxCal : 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Expanded(flex: 3,
                    child: Text(f.name,
                        style: const TextStyle(fontSize: 12),
                        overflow: TextOverflow.ellipsis)),
                  const SizedBox(width: 8),
                  Expanded(flex: 4,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: frac, color: Colors.deepOrange,
                        backgroundColor: Colors.deepOrange.withValues(alpha: 0.15),
                        minHeight: 8,
                      ),
                    )),
                  const SizedBox(width: 8),
                  Text('${f.calories.toStringAsFixed(0)} kcal',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                ]),
              );
            }),
          ],
        ),
      ),
    );
  }
}

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
            Row(children: [
              const Icon(Icons.lightbulb_outline, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text('Personalised Insights',
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 10),
            if (insights.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Log meals, water, sleep and exercise to unlock personalised tips.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                ),
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
      'positive' => (Icons.check_circle_outline,       Colors.green),
      'warning'  => (Icons.warning_amber_outlined,     Colors.orange),
      'tip'      => (Icons.tips_and_updates_outlined,  Colors.blue),
      _          => (Icons.info_outline,               Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(insight.message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _MacrosCard extends ConsumerWidget {
  final DashboardData data;
  const _MacrosCard({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth   = ref.watch(authProvider);
    final person = ref.watch(selectedPersonProvider);
    int? age; String? gender;
    if (person == 'self') {
      age = auth.user?.age; gender = auth.user?.gender;
    } else {
      final m = auth.user?.profile.children.where((c) => c.id == person).firstOrNull;
      age = m?.age; gender = m?.gender;
    }
    final intake = getDailyIntake(age, gender);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Icon(Icons.egg_outlined, size: 16),
              const SizedBox(width: 6),
              Text("Today's Macros",
                  style: Theme.of(context).textTheme.titleSmall),
            ]),
            const SizedBox(height: 12),
            _IntakeRow('Protein', data.todayProtein, intake.protein, 'g', Colors.blue),
            _IntakeRow('Carbs',   data.todayCarbs,   intake.carbs,   'g', Colors.orange),
            _IntakeRow('Fat',     data.todayFat,     intake.fat,     'g', Colors.red),
          ],
        ),
      ),
    );
  }
}

class _IntakeRow extends StatelessWidget {
  final String label, unit;
  final double current, daily;
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
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
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

// ── Flare risk snapshot on dashboard ─────────────────────────────────────────

class _FlareRiskSnapshot extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final riskAsync = ref.watch(flareRiskPredictionProvider);
    return riskAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (risk) {
        if (risk == null) return const SizedBox.shrink();
        final color = risk.score >= 60
            ? Colors.red
            : (risk.score >= 30 ? Colors.orange : Colors.green);
        final label = risk.score >= 60
            ? 'High'
            : (risk.score >= 30 ? 'Moderate' : 'Low');
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: InkWell(
            onTap: () => context.push('/insights'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        CircularProgressIndicator(
                          value: risk.score / 100,
                          strokeWidth: 4,
                          color: color,
                          backgroundColor: color.withValues(alpha: 0.15),
                          strokeCap: StrokeCap.round,
                        ),
                        Text('${risk.score}',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: color)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shield_outlined,
                                size: 14, color: color),
                            const SizedBox(width: 4),
                            Text('Flare Risk: $label',
                                style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: color)),
                          ],
                        ),
                        if (risk.recommendations.isNotEmpty)
                          Text(risk.recommendations.first,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 12,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant
                          .withValues(alpha: 0.5)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
