import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/nutrition_utils.dart';
import '../models/dashboard_data.dart';
import '../models/grocery_models.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/finance_provider.dart';
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

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  // Session-level flag: welcome shows only once per app launch
  static bool _welcomeShownThisSession = false;
  bool _showWelcome = !_welcomeShownThisSession;

  // Swipe-up dismiss animation
  late final AnimationController _dismissCtrl;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _dismissCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 400));
    _dismissCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        _welcomeShownThisSession = true;
        setState(() => _showWelcome = false);
      }
    });
  }

  @override
  void dispose() {
    _dismissCtrl.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (d.delta.dy < 0) {
      // Swiping up
      setState(() {
        _dragOffset += d.delta.dy;
        _dragOffset = _dragOffset.clamp(-400.0, 0.0);
      });
    }
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    // If dragged up >120px or fast fling velocity, dismiss
    if (_dragOffset < -120 || d.velocity.pixelsPerSecond.dy < -500) {
      _dismissCtrl.forward();
    } else {
      // Snap back
      setState(() => _dragOffset = 0);
    }
  }

  void _refresh(String person) {
    ref.invalidate(dashboardProvider(person));
    ref.invalidate(grocerySpendingProvider('$person:month'));
    final today = DateTime.now().toIso8601String().substring(0, 10);
    ref.invalidate(hydrationHistoryProvider('$person:1:$today'));
    ref.invalidate(todayHydrationProvider(person));
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);

    // Pre-fetch dashboard so it's ready behind the welcome screen
    ref.watch(dashboardProvider(person));

    if (!_showWelcome) {
      return Scaffold(
        body: _PersonDashboardPage(
          personId: person,
          onRefresh: _refresh,
        ),
      );
    }

    // Welcome screen — swipe up to dismiss
    final screenH = MediaQuery.of(context).size.height;
    final dismissProgress = _dismissCtrl.isAnimating || _dismissCtrl.isCompleted
        ? _dismissCtrl.value
        : (_dragOffset / -400).clamp(0.0, 1.0);

    return Scaffold(
      body: GestureDetector(
        onVerticalDragUpdate: _onVerticalDragUpdate,
        onVerticalDragEnd: _onVerticalDragEnd,
        child: AnimatedBuilder(
          animation: _dismissCtrl,
          builder: (_, __) => Transform.translate(
            offset: Offset(0, _dismissCtrl.isAnimating || _dismissCtrl.isCompleted
                ? -screenH * _dismissCtrl.value
                : _dragOffset),
            child: Opacity(
              opacity: (1.0 - dismissProgress * 0.6).clamp(0.0, 1.0),
              child: _WelcomeScreen(personId: person),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Zone C: Per-Person Dashboard Page ────────────────────────────────────────
// (Family selection is handled by the avatar bar in AppShell)

// ── Per-Person Dashboard Page ────────────────────────────────────────────────

class _PersonDashboardPage extends ConsumerWidget {
  final String personId;
  final void Function(String) onRefresh;

  const _PersonDashboardPage({
    required this.personId,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashAsync = ref.watch(dashboardProvider(personId));

    return RefreshIndicator(
      onRefresh: () async => onRefresh(personId),
      child: dashAsync.when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _HomeError(
          error: e,
          onRetry: () => onRefresh(personId),
        ),
        data: (data) => _HomeBody(
          data: data,
          person: personId,
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerWidget {
  final DashboardData data;
  final String person;

  const _HomeBody({
    required this.data,
    required this.person,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groceryAsync = ref.watch(grocerySpendingProvider('$person:month'));
    final hydrationAsync = ref.watch(todayHydrationProvider(person));

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        // ── Quick actions bar ─────────────────────────────────────────────
        SliverToBoxAdapter(child: _QuickActionsBar(person: person)),

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

        // ── Macros card ───────────────────────────────────────────────────
        SliverToBoxAdapter(child: _MacrosCard(data: data)),

        // ── Meal distribution ─────────────────────────────────────────────
        SliverToBoxAdapter(child: _MealDistributionCard(distribution: data.mealDistribution)),

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

        // ── Finance snapshot ─────────────────────────────────────────────
        const SliverToBoxAdapter(child: _FinanceSnapshot()),

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

// ── Quick actions bar ─────────────────────────────────────────────────────────

class _QuickActionsBar extends StatelessWidget {
  final String person;
  const _QuickActionsBar({required this.person});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          _action(context, Icons.restaurant, 'Log Meal', cs.primary, () {
            context.go('/nutrition');
          }),
          const SizedBox(width: 10),
          _action(context, Icons.water_drop, 'Add Water', Colors.blue, () {
            context.go('/hydration');
          }),
          const SizedBox(width: 10),
          _action(context, Icons.monitor_weight, 'Log Weight', Colors.orange, () {
            context.go('/weight');
          }),
          const SizedBox(width: 10),
          _action(context, Icons.sentiment_satisfied, 'Log Mood', Colors.amber, () {
            context.go('/health');
          }),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, IconData icon, String label,
      Color color, VoidCallback onTap) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: color),
                const SizedBox(height: 4),
                Text(label, style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w600, color: color)),
              ],
            ),
          ),
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
      ref.invalidate(hydrationHistoryProvider('${widget.person}:1:$today'));
      ref.invalidate(todayHydrationProvider(widget.person));
      ref.invalidate(dashboardProvider(widget.person));
      ref.invalidate(familySnapshotProvider);
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

    // Watch today's entries for timeline display
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final historyAsync = ref.watch(hydrationHistoryProvider('${widget.person}:1:$today'));
    final todayEntries = historyAsync.whenOrNull(
      data: (logs) => logs.where((l) => l.date == today).toList(),
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
            // Timeline of today's entries
            if (todayEntries != null && todayEntries.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 8),
              SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: todayEntries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final e = todayEntries[i];
                    final qty = e.quantity >= 1000
                        ? '${(e.quantity / 1000).toStringAsFixed(1)}L'
                        : '${e.quantity.toInt()}ml';
                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${e.time} · $qty',
                        style: TextStyle(fontSize: 11, color: Colors.blue.shade700),
                      ),
                    );
                  },
                ),
              ),
            ],
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

// ── Finance snapshot ─────────────────────────────────────────────────────────

class _FinanceSnapshot extends ConsumerWidget {
  const _FinanceSnapshot();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spendingAsync = ref.watch(financeSpendingProvider('month'));
    return spendingAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (spending) {
        if (spending.totalSpend <= 0) return const SizedBox.shrink();
        final top3 = spending.byCategory.take(3).toList();
        final cs = Theme.of(context).colorScheme;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.account_balance_wallet_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('Finance This Month',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('\$${spending.totalSpend.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: cs.primary)),
                  ],
                ),
                if (spending.essentialSpend > 0 || spending.discretionarySpend > 0) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _SpendChip(
                          label: 'Essential',
                          amount: spending.essentialSpend,
                          color: cs.primary),
                      const SizedBox(width: 12),
                      _SpendChip(
                          label: 'Discretionary',
                          amount: spending.discretionarySpend,
                          color: cs.tertiary),
                    ],
                  ),
                ],
                const SizedBox(height: 10),
                ...top3.map((cat) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          cat.category.replaceAll('_', ' '),
                          style: const TextStyle(fontSize: 12),
                        ),
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
                  onTap: () => context.go('/finance'),
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

class _SpendChip extends StatelessWidget {
  final String label;
  final double amount;
  final Color color;
  const _SpendChip({required this.label, required this.amount, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text('$label \$${amount.toStringAsFixed(0)}',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
      ],
    );
  }
}

// ── Rich Welcome Screen — swipe up to dismiss, mood-driven animations ───────

class _WelcomeScreen extends ConsumerStatefulWidget {
  final String personId;
  const _WelcomeScreen({required this.personId});
  @override
  ConsumerState<_WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<_WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _masterCtrl;
  late final AnimationController _floatCtrl;
  late final AnimationController _particleCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _shimmerCtrl;
  late final AnimationController _orbCtrl;

  // Staggered entrance animations
  late final Animation<double> _emojiScale;
  late final Animation<double> _greetingFade;
  late final Animation<Offset> _greetingSlide;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _insightFade;
  late final Animation<Offset> _insightSlide;
  late final Animation<double> _swipeHintFade;

  // Particles & orbs for background
  late final List<_Particle> _particles;
  late final List<_FloatingOrb> _orbs;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400))
      ..forward();

    _floatCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);

    _particleCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 6000))
      ..repeat();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _shimmerCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 3000))
      ..repeat();

    _orbCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 12000))
      ..repeat();

    // Generate particles — more of them, varied
    final rng = Random();
    _particles = List.generate(24, (i) => _Particle(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      size: rng.nextDouble() * 5 + 1.5,
      speed: rng.nextDouble() * 0.4 + 0.15,
      opacity: rng.nextDouble() * 0.45 + 0.08,
    ));

    // Floating orbs — large, colorful, slow
    _orbs = List.generate(5, (i) => _FloatingOrb(
      x: rng.nextDouble(),
      y: rng.nextDouble(),
      radius: rng.nextDouble() * 60 + 40,
      speed: rng.nextDouble() * 0.15 + 0.05,
      phase: rng.nextDouble() * 2 * pi,
    ));

    _emojiScale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.25, curve: Curves.elasticOut),
    ));

    _greetingFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.15, 0.38, curve: Curves.easeOut),
    );
    _greetingSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.15, 0.38, curve: Curves.easeOut)),
    );

    _nameFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.28, 0.52, curve: Curves.easeOut),
    );
    _nameSlide = Tween(begin: const Offset(0, 0.5), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.28, 0.52, curve: Curves.easeOut)),
    );

    _insightFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.48, 0.78, curve: Curves.easeOut),
    );
    _insightSlide = Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.48, 0.78, curve: Curves.easeOut)),
    );

    _swipeHintFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.80, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _floatCtrl.dispose();
    _particleCtrl.dispose();
    _pulseCtrl.dispose();
    _shimmerCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  // ── Mood-driven color theming ──────────────────────────────────────────

  /// Returns vibrant gradient based on mood + time of day
  List<Color> _moodGradient(String? insightType, String? dominantMood) {
    final h = DateTime.now().hour;
    // Mood-driven gradients (override time-based when mood data exists)
    if (insightType == 'positive') {
      // Energetic, vibrant — greens and teals
      return h < 17
          ? [const Color(0xFF00C853), const Color(0xFF1DE9B6), const Color(0xFF00E5FF)]
          : [const Color(0xFF004D40), const Color(0xFF00695C), const Color(0xFF00897B)];
    } else if (insightType == 'care') {
      // Warm, comforting — sunset oranges and pinks
      return h < 17
          ? [const Color(0xFFFF6F00), const Color(0xFFFF8F00), const Color(0xFFFFAB40)]
          : [const Color(0xFF4A148C), const Color(0xFF6A1B9A), const Color(0xFF8E24AA)];
    } else if (insightType == 'neutral') {
      // Calm, balanced — soft blues
      return h < 17
          ? [const Color(0xFF1565C0), const Color(0xFF42A5F5), const Color(0xFF80D8FF)]
          : [const Color(0xFF0D47A1), const Color(0xFF1565C0), const Color(0xFF1E88E5)];
    }
    // Default: time-based
    if (h < 6) {
      return [const Color(0xFF0D0D2B), const Color(0xFF1A1A4E), const Color(0xFF2D1B69)];
    } else if (h < 12) {
      return [const Color(0xFFFF8F00), const Color(0xFFFFB300), const Color(0xFFFFD54F)];
    } else if (h < 17) {
      return [const Color(0xFF0288D1), const Color(0xFF29B6F6), const Color(0xFF81D4FA)];
    } else if (h < 20) {
      return [const Color(0xFFAD1457), const Color(0xFFD81B60), const Color(0xFFF06292)];
    } else {
      return [const Color(0xFF0D0D2B), const Color(0xFF1A0A3E), const Color(0xFF2D1B69)];
    }
  }

  Color _moodAccent(String? insightType) {
    switch (insightType) {
      case 'positive': return const Color(0xFF69F0AE);
      case 'care': return const Color(0xFFFFAB91);
      case 'neutral': return const Color(0xFF80DEEA);
      default: return const Color(0xFFB39DDB);
    }
  }

  bool _isDarkPeriod() {
    final h = DateTime.now().hour;
    return h < 6 || h >= 18;
  }

  @override
  Widget build(BuildContext context) {
    final welcomeAsync = ref.watch(welcomeProvider(widget.personId));
    final auth = ref.watch(authProvider);
    final fallbackName = (auth.user?.name ?? '').split(' ').first;
    final screenSize = MediaQuery.of(context).size;

    return welcomeAsync.when(
      loading: () => _buildScreen(
        greeting: _localGreeting(), name: fallbackName.isNotEmpty ? fallbackName : 'there',
        moodInsight: null, moodEmoji: null, moodInsightType: null,
        dominantMood: null, averageScore: null, screenSize: screenSize,
      ),
      error: (_, __) => _buildScreen(
        greeting: _localGreeting(), name: fallbackName.isNotEmpty ? fallbackName : 'there',
        moodInsight: null, moodEmoji: null, moodInsightType: null,
        dominantMood: null, averageScore: null, screenSize: screenSize,
      ),
      data: (welcome) => _buildScreen(
        greeting: welcome.greeting,
        name: welcome.name.isNotEmpty ? welcome.name : (fallbackName.isNotEmpty ? fallbackName : 'there'),
        moodInsight: welcome.moodSummary.insight,
        moodEmoji: welcome.moodSummary.emoji,
        moodInsightType: welcome.moodSummary.insightType,
        dominantMood: welcome.moodSummary.dominantMood,
        allMoods: welcome.moodSummary.allMoods,
        averageScore: welcome.moodSummary.averageScore,
        screenSize: screenSize,
      ),
    );
  }

  Widget _buildScreen({
    required String greeting, required String name,
    String? moodInsight, String? moodEmoji, String? moodInsightType,
    String? dominantMood, List<String> allMoods = const [],
    double? averageScore, required Size screenSize,
  }) {
    final gradColors = _moodGradient(moodInsightType, dominantMood);
    final isDark = _isDarkPeriod() || moodInsightType == 'care';
    final accent = _moodAccent(moodInsightType);

    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // ── Animated gradient overlay that breathes ──
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -0.5 + _pulseCtrl.value * 1.0,
                    -0.3 + _pulseCtrl.value * 0.6,
                  ),
                  radius: 1.2 + _pulseCtrl.value * 0.3,
                  colors: [
                    accent.withValues(alpha: 0.15 + _pulseCtrl.value * 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // ── Floating orbs (large, dreamy, slow) ──
          AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) => CustomPaint(
              size: screenSize,
              painter: _OrbPainter(
                orbs: _orbs,
                progress: _orbCtrl.value,
                accentColor: accent,
                isDark: isDark,
              ),
            ),
          ),

          // ── Particles — energetic, rising ──
          AnimatedBuilder(
            animation: _particleCtrl,
            builder: (_, __) => CustomPaint(
              size: screenSize,
              painter: _ParticlePainter(
                particles: _particles,
                progress: _particleCtrl.value,
                color: isDark ? Colors.white : accent,
              ),
            ),
          ),

          // ── Shimmering light streak ──
          AnimatedBuilder(
            animation: _shimmerCtrl,
            builder: (_, __) => CustomPaint(
              size: screenSize,
              painter: _ShimmerPainter(
                progress: _shimmerCtrl.value,
                color: accent.withValues(alpha: 0.12),
              ),
            ),
          ),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _buildContent(
                  greeting: greeting, name: name,
                  moodInsight: moodInsight, moodEmoji: moodEmoji,
                  moodInsightType: moodInsightType, isDark: isDark,
                  accent: accent, averageScore: averageScore,
                  dominantMood: dominantMood, allMoods: allMoods,
                ),
              ),
            ),
          ),

          // ── Swipe up indicator at bottom ──
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _swipeHintFade,
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: _floatCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -8 * _floatCtrl.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.keyboard_arrow_up_rounded,
                          size: 32,
                          color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Swipe up for dashboard',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.4),
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _localGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Widget _buildContent({
    required String greeting, required String name,
    String? moodInsight, String? moodEmoji, String? moodInsightType,
    required bool isDark, required Color accent,
    double? averageScore, String? dominantMood,
    List<String> allMoods = const [],
  }) {
    final hour = DateTime.now().hour;
    // Mood-driven emoji (prioritize mood over time)
    String mainEmoji;
    if (dominantMood != null) {
      mainEmoji = _moodToEmoji(dominantMood);
    } else {
      mainEmoji = hour < 6 ? '🌌' : hour < 12 ? '🌅' : hour < 17 ? '☀️' : hour < 20 ? '🌇' : '🌙';
    }

    final textCol = isDark ? Colors.white : const Color(0xFF1a1a2e);
    final subCol = isDark ? Colors.white70 : const Color(0xFF37474F);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),

        // 1. Large emoji with pulsing glow ring
        AnimatedBuilder(
          animation: Listenable.merge([_masterCtrl, _floatCtrl, _pulseCtrl]),
          builder: (_, __) {
            final pulseScale = 1.0 + _pulseCtrl.value * 0.08;
            return Transform.translate(
              offset: Offset(0, -14 * _floatCtrl.value),
              child: Transform.scale(
                scale: _emojiScale.value,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Outer glow ring — pulsing
                    Transform.scale(
                      scale: pulseScale,
                      child: Container(
                        width: 130, height: 130,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.25 + _pulseCtrl.value * 0.15),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withValues(alpha: 0.2 + _pulseCtrl.value * 0.15),
                              blurRadius: 50 + _pulseCtrl.value * 20,
                              spreadRadius: 10 + _pulseCtrl.value * 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Inner glow ring
                    Container(
                      width: 110, height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: accent.withValues(alpha: 0.15),
                          width: 1.5,
                        ),
                      ),
                    ),
                    // Emoji
                    Text(mainEmoji, style: const TextStyle(fontSize: 72)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 28),

        // 2. Greeting — with shimmer effect
        SlideTransition(
          position: _greetingSlide,
          child: FadeTransition(
            opacity: _greetingFade,
            child: Text(
              greeting,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w300,
                color: subCol,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 3. User's name — massive, gradient, bold
        SlideTransition(
          position: _nameSlide,
          child: FadeTransition(
            opacity: _nameFade,
            child: ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: isDark
                    ? [accent, Colors.white, accent]
                    : [accent.withValues(alpha: 0.8), const Color(0xFF2D2B55), accent],
              ).createShader(bounds),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              ),
            ),
          ),
        ),

        // 4. Mood score bar (if score available)
        if (averageScore != null) ...[
          const SizedBox(height: 20),
          SlideTransition(
            position: _insightSlide,
            child: FadeTransition(
              opacity: _insightFade,
              child: _MoodScoreBar(
                score: averageScore,
                accent: accent,
                isDark: isDark,
                pulseCtrl: _pulseCtrl,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),

        // 5. Mood insight card — frosted glass with accent glow
        if (moodInsight != null && moodInsight.isNotEmpty)
          SlideTransition(
            position: _insightSlide,
            child: FadeTransition(
              opacity: _insightFade,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.2),
                      blurRadius: 30,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.1)
                            : Colors.white.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (moodEmoji != null)
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: accent.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(moodEmoji, style: const TextStyle(fontSize: 28)),
                                ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _insightTitle(moodInsightType),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        color: accent,
                                        letterSpacing: 2.0,
                                      ),
                                    ),
                                    if (dominantMood != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        allMoods.length > 1
                                            ? 'Feeling ${allMoods.map((m) => m.toLowerCase()).join(', ')}'
                                            : 'Feeling ${dominantMood.toLowerCase()}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: textCol.withValues(alpha: 0.6),
                                          fontWeight: FontWeight.w500,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            moodInsight,
                            style: TextStyle(
                              fontSize: 16,
                              color: textCol,
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 80), // room for swipe indicator
      ],
    );
  }

  String _moodToEmoji(String mood) {
    switch (mood.toLowerCase()) {
      case 'happy': return '😊';
      case 'excited': return '🤩';
      case 'pumped up': return '🔥';
      case 'motivated': return '💪';
      case 'grateful': return '🙏';
      case 'loved': return '💕';
      case 'calm': return '😌';
      case 'peaceful': return '🧘';
      case 'neutral': return '😐';
      case 'confused': return '🤔';
      case 'nervous': return '😬';
      case 'focused': return '🧠';
      case 'horny': return '😏';
      case 'sleepy': return '😴';
      case 'tired': return '🥱';
      case 'exhausted': return '😮‍💨';
      case 'sad': return '😔';
      case 'anxious': return '😰';
      case 'stressed': return '😤';
      case 'irritated': return '😠';
      case 'overwhelmed': return '🤯';
      case 'lonely': return '😞';
      case 'angry': return '😡';
      case 'frustrated': return '😢';
      default: return '✨';
    }
  }

  String _insightTitle(String? type) {
    switch (type) {
      case 'positive': return 'FEELING GREAT';
      case 'care': return 'GENTLE REMINDER';
      case 'neutral': return 'MOOD CHECK-IN';
      case 'tip': return 'WELLNESS TIP';
      default: return 'YOUR MOOD';
    }
  }
}

// ── Mood score indicator bar ────────────────────────────────────────────────

class _MoodScoreBar extends StatelessWidget {
  final double score;
  final Color accent;
  final bool isDark;
  final AnimationController pulseCtrl;

  const _MoodScoreBar({
    required this.score, required this.accent,
    required this.isDark, required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final textCol = isDark ? Colors.white : const Color(0xFF1a1a2e);
    final fraction = (score / 10).clamp(0.0, 1.0);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '${score.toStringAsFixed(1)}',
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.w800,
                color: accent,
              ),
            ),
            Text(
              ' / 10',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w400,
                color: textCol.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text('mood score', style: TextStyle(
              fontSize: 12, color: textCol.withValues(alpha: 0.4),
              letterSpacing: 1,
            )),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) => Container(
            height: 6,
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fraction,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    colors: [accent, accent.withValues(alpha: 0.6)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withValues(alpha: 0.3 + pulseCtrl.value * 0.2),
                      blurRadius: 8 + pulseCtrl.value * 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Particle & orb data models ──────────────────────────────────────────────

class _Particle {
  final double x, y, size, speed, opacity;
  const _Particle({
    required this.x, required this.y, required this.size,
    required this.speed, required this.opacity,
  });
}

class _FloatingOrb {
  final double x, y, radius, speed, phase;
  const _FloatingOrb({
    required this.x, required this.y, required this.radius,
    required this.speed, required this.phase,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final double progress;
  final Color color;

  _ParticlePainter({required this.particles, required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      // Rising motion — particles float upward
      final dy = ((p.y - progress * p.speed) % 1.0) * size.height;
      final dx = p.x * size.width + sin(progress * 2 * pi + p.x * 12) * 25;
      // Twinkling effect
      final twinkle = (sin(progress * 4 * pi + p.x * 20) * 0.5 + 0.5);
      final paint = Paint()..color = color.withValues(alpha: p.opacity * twinkle);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
      // Add tiny glow around larger particles
      if (p.size > 4) {
        final glowPaint = Paint()..color = color.withValues(alpha: p.opacity * twinkle * 0.3);
        canvas.drawCircle(Offset(dx, dy), p.size * 2.5, glowPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => old.progress != progress;
}

class _OrbPainter extends CustomPainter {
  final List<_FloatingOrb> orbs;
  final double progress;
  final Color accentColor;
  final bool isDark;

  _OrbPainter({required this.orbs, required this.progress,
               required this.accentColor, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    for (final orb in orbs) {
      final dx = orb.x * size.width + sin(progress * 2 * pi * orb.speed + orb.phase) * 80;
      final dy = orb.y * size.height + cos(progress * 2 * pi * orb.speed + orb.phase * 1.3) * 60;

      final gradient = RadialGradient(
        colors: [
          accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
          accentColor.withValues(alpha: 0.0),
        ],
      );
      final rect = Rect.fromCircle(center: Offset(dx, dy), radius: orb.radius);
      final paint = Paint()..shader = gradient.createShader(rect);
      canvas.drawCircle(Offset(dx, dy), orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => old.progress != progress;
}

class _ShimmerPainter extends CustomPainter {
  final double progress;
  final Color color;

  _ShimmerPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Diagonal light streak sweeping across
    final x = (progress * 2 - 0.5) * size.width;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Colors.transparent, color, Colors.transparent],
        stops: const [0.3, 0.5, 0.7],
      ).createShader(Rect.fromLTWH(x - 100, 0, 200, size.height));
    canvas.drawRect(
      Rect.fromLTWH(x - 100, 0, 200, size.height),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _ShimmerPainter old) => old.progress != progress;
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
