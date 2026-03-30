import 'dart:math';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../screens/nutrition/daily_intake.dart';
import '../services/health_sync_service.dart';
import '../models/dashboard_data.dart';
import '../models/grocery_models.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/grocery_provider.dart';
import '../providers/hydration_provider.dart';
import '../widgets/friendly_error.dart';
import '../widgets/shimmer_placeholder.dart';
import '../providers/selected_person_provider.dart';
import 'insights_screen.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/help_tooltip.dart';
import '../widgets/qorehealth_icon.dart';
import '../widgets/wearable_summary_card.dart';
import '../widgets/dashboard_customize_sheet.dart';
import '../providers/dashboard_card_config_provider.dart';

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
        // Tell AppShell to restore avatar bar + bottom nav
        ref.read(welcomeOverlayProvider.notifier).state = false;
      }
    });
    // Fire-and-forget: trigger wearable sync on app open if auto-sync is on
    _maybeAutoSync();
  }

  /// Non-blocking auto-sync from platform health store on dashboard load.
  Future<void> _maybeAutoSync() async {
    try {
      if (!HealthSyncService.isAvailable) return;
      final prefs = await SharedPreferences.getInstance();
      final autoSync = prefs.getBool('health_sync_auto') ?? false;
      final connected = prefs.getBool('health_sync_connected') ?? false;
      if (!autoSync || !connected) return;
      final person = ref.read(selectedPersonProvider);
      // Fire and forget — don't await
      HealthSyncService.syncFromPlatform(person: person);
    } catch (_) {
      // Silently ignore — auto-sync is best-effort
    }
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

  Future<void> _refresh(String person) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    // Clear cache first so invalidation triggers a fresh network fetch
    await AppCache.clearDashboard(person, date: today);
    ref.invalidate(dashboardProvider((person, today)));
    ref.invalidate(grocerySpendingProvider('${person}_month'));
    ref.invalidate(hydrationHistoryProvider('${person}_1_$today'));
    ref.invalidate(todayHydrationProvider(person));
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);

    // Pre-fetch dashboard so it's ready behind the welcome screen
    final today = DateTime.now().toIso8601String().substring(0, 10);
    ref.watch(dashboardProvider((person, today)));

    // Always render the dashboard — welcome overlays on top
    return Scaffold(
      body: Stack(
        children: [
          // Dashboard underneath (pre-loaded)
          _PersonDashboardPage(
            personId: person,
            onRefresh: _refresh,
          ),

          // Welcome overlay — covers entire screen including system bars
          if (_showWelcome)
            Positioned.fill(
              child: GestureDetector(
                onVerticalDragUpdate: _onVerticalDragUpdate,
                onVerticalDragEnd: _onVerticalDragEnd,
                child: AnimatedBuilder(
                  animation: _dismissCtrl,
                  builder: (_, __) {
                    final screenH = MediaQuery.of(context).size.height;
                    final dismissProgress = _dismissCtrl.isAnimating || _dismissCtrl.isCompleted
                        ? _dismissCtrl.value
                        : (_dragOffset / -400).clamp(0.0, 1.0);
                    final scale = 1.0 - dismissProgress * 0.12;
                    final opacity = (1.0 - dismissProgress).clamp(0.0, 1.0);
                    final radius = dismissProgress * 32;

                    return Transform.translate(
                      offset: Offset(0, _dismissCtrl.isAnimating || _dismissCtrl.isCompleted
                          ? -screenH * _dismissCtrl.value
                          : _dragOffset),
                      child: Transform.scale(
                        scale: scale,
                        child: Opacity(
                          opacity: opacity,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(radius),
                            child: _WelcomeScreen(personId: person),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Zone C: Per-Person Dashboard Page ────────────────────────────────────────
// (Family selection is handled by the avatar bar in AppShell)

// ── Per-Person Dashboard Page ────────────────────────────────────────────────

class _PersonDashboardPage extends ConsumerStatefulWidget {
  final String personId;
  final Future<void> Function(String) onRefresh;

  const _PersonDashboardPage({
    required this.personId,
    required this.onRefresh,
  });

  @override
  ConsumerState<_PersonDashboardPage> createState() =>
      _PersonDashboardPageState();
}

class _PersonDashboardPageState extends ConsumerState<_PersonDashboardPage> {
  DateTime _selectedDate = DateTime.now();

  bool get _isToday {
    final now = DateTime.now();
    return _selectedDate.year == now.year &&
        _selectedDate.month == now.month &&
        _selectedDate.day == now.day;
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    final now = DateTime.now();
    // Don't allow future dates
    if (newDate.isAfter(DateTime(now.year, now.month, now.day))) return;
    setState(() => _selectedDate = newDate);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = _selectedDate.toIso8601String().substring(0, 10);
    final dashAsync = ref.watch(dashboardProvider((widget.personId, dateStr)));

    return RefreshIndicator(
      onRefresh: () async => widget.onRefresh(widget.personId),
      child: Column(
        children: [
          // ── Date navigation bar ──────────────────────────────────────
          _DateNavigationBar(
            selectedDate: _selectedDate,
            isToday: _isToday,
            onPrevious: () => _changeDate(-1),
            onNext: _isToday ? null : () => _changeDate(1),
            onTap: _pickDate,
          ),
          // ── Dashboard content ────────────────────────────────────────
          Expanded(
            child: dashAsync.when(
              skipLoadingOnReload: true,
              loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 12),
            ShimmerCard(height: 48, margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6)),  // quick actions
            ShimmerCard(height: 100),  // stat cards
            ShimmerCard(height: 100),  // stat cards row 2
            ShimmerCard(height: 60),   // hydration
            ShimmerCard(height: 120),  // macros
            ShimmerCard(height: 80),   // health score
          ],
        ),
              error: (e, _) => _HomeError(
                error: e,
                onRetry: () => widget.onRefresh(widget.personId),
              ),
              data: (data) => _HomeBody(
                data: data,
                person: widget.personId,
                isToday: _isToday,
                selectedDate: _selectedDate,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Date Navigation Bar ──────────────────────────────────────────────────────

class _DateNavigationBar extends StatelessWidget {
  final DateTime selectedDate;
  final bool isToday;
  final VoidCallback onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onTap;

  const _DateNavigationBar({
    required this.selectedDate,
    required this.isToday,
    required this.onPrevious,
    required this.onNext,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateText =
        isToday ? 'Today' : DateFormat('MMM d, y').format(selectedDate);

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 22),
            onPressed: onPrevious,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            tooltip: 'Previous day',
          ),
          GestureDetector(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                dateText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          IconButton(
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedArrowRight01,
              size: 22,
              color: isToday
                  ? theme.disabledColor
                  : theme.iconTheme.color,
            ),
            onPressed: onNext,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            splashRadius: 18,
            tooltip: isToday ? null : 'Next day',
          ),
        ],
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _HomeBody extends ConsumerStatefulWidget {
  final DashboardData data;
  final String person;
  final bool isToday;
  final DateTime selectedDate;

  const _HomeBody({
    required this.data,
    required this.person,
    required this.isToday,
    required this.selectedDate,
  });

  @override
  ConsumerState<_HomeBody> createState() => _HomeBodyState();
}

class _HomeBodyState extends ConsumerState<_HomeBody> {
  String get _dayLabel => widget.isToday
      ? "Today's"
      : "${DateFormat('MMM d').format(widget.selectedDate)} –";

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final person = widget.person;
    final groceryAsync = ref.watch(grocerySpendingProvider('${person}_month'));
    final hydrationAsync = ref.watch(todayHydrationProvider(person));
    final cardConfig = ref.watch(dashboardCardConfigProvider);
    final visibleCards = cardConfig.visibleCards;

    // Partition visible cards into runs of small tiles vs full-width cards.
    // Adjacent small tiles are grouped into a single 2-column grid sliver.
    final slivers = <Widget>[];
    var i = 0;
    while (i < visibleCards.length) {
      final type = visibleCards[i];
      if (type.isSmallTile) {
        // Collect consecutive small tiles
        final smallRun = <DashboardCardType>[];
        while (i < visibleCards.length && visibleCards[i].isSmallTile) {
          smallRun.add(visibleCards[i]);
          i++;
        }
        slivers.add(SliverToBoxAdapter(
          child: _buildSmallTileGrid(smallRun, data, hydrationAsync),
        ));
      } else {
        slivers.add(SliverToBoxAdapter(
          child: _buildFullWidthCard(type, data, person, groceryAsync, hydrationAsync),
        ));
        i++;
      }
    }

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        ...slivers,

        // ── Customize button ─────────────────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () => DashboardCustomizeSheet.show(context),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedDashboardBrowsing, size: 18),
                label: const Text('Customize Dashboard'),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ),

        const SliverToBoxAdapter(child: MedicalDisclaimer()),
        const SliverToBoxAdapter(child: SizedBox(height: 16)),
      ],
    );
  }

  /// Build a 2-column grid of small stat tiles.
  Widget _buildSmallTileGrid(
    List<DashboardCardType> tiles,
    DashboardData data,
    AsyncValue<double> hydrationAsync,
  ) {
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        DashboardCustomizeSheet.show(context);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle(context, "$_dayLabel Summary"),
            const SizedBox(height: 6),
            // Build rows of 2 tiles
            for (var r = 0; r < tiles.length; r += 2) ...[
              if (r > 0) const SizedBox(height: 8),
              Row(children: [
                Expanded(child: _buildStatTile(tiles[r], data, hydrationAsync)),
                const SizedBox(width: 10),
                if (r + 1 < tiles.length)
                  Expanded(child: _buildStatTile(tiles[r + 1], data, hydrationAsync))
                else
                  const Expanded(child: SizedBox()),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  /// Build a single stat tile widget for a given card type.
  Widget _buildStatTile(
    DashboardCardType type,
    DashboardData data,
    AsyncValue<double> hydrationAsync,
  ) {
    return switch (type) {
      DashboardCardType.calories => _StatCard(
        label: 'Calories', icon: HugeIcons.strokeRoundedFire,
        color: Colors.orange,
        todayValue: data.todayCalories.toStringAsFixed(0), todayUnit: 'kcal',
        weekAvg: '${data.weekAvgCalories.toStringAsFixed(0)} kcal',
        prevAvg: data.prevWeekAvgCalories.toStringAsFixed(0),
        up: data.weekAvgCalories >= data.prevWeekAvgCalories,
      ),
      DashboardCardType.weight => _StatCard(
        label: 'Weight', icon: HugeIcons.strokeRoundedWeightScale,
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
      ),
      DashboardCardType.meals => _StatCard(
        label: widget.isToday ? 'Meals Today' : 'Meals', icon: HugeIcons.strokeRoundedRestaurant01,
        color: Colors.green,
        todayValue: '${data.mealsCount}', todayUnit: 'meals',
        weekAvg: '${data.weekAvgMeals.toStringAsFixed(1)}/day (7d)',
        prevAvg: '${data.prevWeekAvgMeals.toStringAsFixed(1)}/day',
        up: data.weekAvgMeals >= data.prevWeekAvgMeals,
      ),
      DashboardCardType.water => _HydrationStatCard(
        hydrationAsync: hydrationAsync,
        weekAvg: data.weekAvgWater,
        prevAvg: data.prevWeekAvgWater,
      ),
      DashboardCardType.steps => _StatCard(
        label: 'Steps', icon: HugeIcons.strokeRoundedDumbbell01,
        color: const Color(0xFF22C55E),
        todayValue: data.todaySteps != null ? _formatNumber(data.todaySteps!) : '—',
        todayUnit: '',
        weekAvg: data.todayActiveCalories != null
            ? '${data.todayActiveCalories!.toStringAsFixed(0)} active kcal'
            : 'No data',
        prevAvg: '', up: true,
        showTrend: false,
      ),
      DashboardCardType.sleep => _StatCard(
        label: 'Sleep', icon: HugeIcons.strokeRoundedBed,
        color: const Color(0xFF6366F1),
        todayValue: data.todaySleepMins != null
            ? _formatSleepHours(data.todaySleepMins!) : '—',
        todayUnit: data.todaySleepMins != null ? 'hrs' : '',
        weekAvg: '', prevAvg: '', up: true,
        showTrend: false,
      ),
      DashboardCardType.heartRate => _StatCard(
        label: 'Heart Rate', icon: HugeIcons.strokeRoundedFavourite,
        color: Colors.red,
        todayValue: data.todayHeartRate != null
            ? data.todayHeartRate!.toStringAsFixed(0) : '—',
        todayUnit: data.todayHeartRate != null ? 'bpm' : '',
        weekAvg: '', prevAvg: '', up: true,
        showTrend: false,
      ),
      DashboardCardType.spo2 => _StatCard(
        label: 'SpO2', icon: HugeIcons.strokeRoundedBlood,
        color: const Color(0xFF0EA5E9),
        todayValue: data.todaySpo2 != null
            ? data.todaySpo2!.toStringAsFixed(0) : '—',
        todayUnit: data.todaySpo2 != null ? '%' : '',
        weekAvg: '', prevAvg: '', up: true,
        showTrend: false,
      ),
      DashboardCardType.exercise => _StatCard(
        label: 'Exercise', icon: HugeIcons.strokeRoundedDumbbell01,
        color: const Color(0xFFF59E0B),
        todayValue: data.todayActiveCalories != null
            ? data.todayActiveCalories!.toStringAsFixed(0) : '—',
        todayUnit: data.todayActiveCalories != null ? 'kcal' : '',
        weekAvg: 'Active calories', prevAvg: '', up: true,
        showTrend: false,
      ),
      DashboardCardType.distance => _StatCard(
        label: 'Distance', icon: HugeIcons.strokeRoundedRuler,
        color: const Color(0xFF8B5CF6),
        todayValue: data.todayDistance != null
            ? (data.todayDistance! >= 1000
                ? '${(data.todayDistance! / 1000).toStringAsFixed(1)}'
                : data.todayDistance!.toStringAsFixed(0))
            : '—',
        todayUnit: data.todayDistance != null
            ? (data.todayDistance! >= 1000 ? 'km' : 'm')
            : '',
        weekAvg: '', prevAvg: '', up: true,
        showTrend: false,
      ),
      _ => const SizedBox.shrink(), // Non-small tiles shouldn't reach here
    };
  }

  /// Build a full-width card widget.
  Widget _buildFullWidthCard(
    DashboardCardType type,
    DashboardData data,
    String person,
    AsyncValue<GrocerySpending> groceryAsync,
    AsyncValue<double> hydrationAsync,
  ) {
    final child = switch (type) {
      DashboardCardType.quickActions => _QuickActionsBar(person: person),
      DashboardCardType.hydrationQuickLog =>
        _HydrationQuickLog(person: person, hydrationAsync: hydrationAsync),
      DashboardCardType.wearableSummary => const WearableSummaryCard(),
      DashboardCardType.macros => _MacrosCard(data: data, dayLabel: _dayLabel),
      DashboardCardType.mealDistribution =>
        _MealDistributionCard(distribution: data.mealDistribution),
      DashboardCardType.healthScore => GestureDetector(
          onTap: () => GoRouter.of(context).push('/health-intelligence'),
          child: _HealthScoreCard(score: data.healthScore, prev: data.prevHealthScore),
        ),
      DashboardCardType.flareRisk => _FlareRiskSnapshot(),
      DashboardCardType.topFoods => data.topCalorieFoods.isNotEmpty
          ? _TopFoodsCard(foods: data.topCalorieFoods)
          : const SizedBox.shrink(),
      DashboardCardType.insights => _InsightsCard(insights: data.insights),
      DashboardCardType.grocerySnapshot => _GrocerySnapshot(groceryAsync: groceryAsync),
      _ => const SizedBox.shrink(), // Small tiles shouldn't reach here
    };

    // Long-press any card to open customize sheet
    return GestureDetector(
      onLongPress: () {
        HapticFeedback.mediumImpact();
        DashboardCustomizeSheet.show(context);
      },
      child: child,
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
    return '$n';
  }

  static String _formatSleepHours(double mins) {
    if (mins > 24) return (mins / 60).toStringAsFixed(1);
    return mins.toStringAsFixed(1);
  }

  static Widget _sectionTitle(BuildContext context, String text) => Text(
        text,
        style: Theme.of(context).textTheme.titleLarge,
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
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          _action(context, HugeIcons.strokeRoundedRestaurant01, 'Log Meal', cs.primary, () {
            context.go('/nutrition');
          }),
          const SizedBox(width: 10),
          _action(context, HugeIcons.strokeRoundedDroplet, 'Add Water', Colors.blue, () {
            context.go('/hydration');
          }),
          const SizedBox(width: 10),
          _action(context, HugeIcons.strokeRoundedBodyWeight, 'Log Weight', Colors.orange, () {
            context.go('/health/weight');
          }),
          const SizedBox(width: 10),
          _action(context, HugeIcons.strokeRoundedSmileDizzy, 'Log Mood', Colors.amber, () {
            context.go('/health');
          }),
        ],
      ),
    );
  }

  Widget _action(BuildContext context, List<List<dynamic>> icon, String label,
      Color color, VoidCallback onTap) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        child: Material(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ExcludeSemantics(child: HugeIcon(icon: icon, color: color, size: 20)),
                  const SizedBox(height: 6),
                  ExcludeSemantics(child: Text(label, style: TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: cs.onSurface))),
                ],
              ),
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
      icon: HugeIcons.strokeRoundedDroplet,
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
      ref.invalidate(hydrationHistoryProvider('${widget.person}_1_$today'));
      ref.invalidate(todayHydrationProvider(widget.person));
      ref.invalidate(dashboardProvider((widget.person, today)));
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
          SnackBar(content: Text(friendlyErrorMessage(e, context: 'hydration'))),
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
    final historyAsync = ref.watch(hydrationHistoryProvider('${widget.person}_1_$today'));
    final todayEntries = historyAsync.whenOrNull(
      data: (logs) => logs.where((l) => l.date == today).toList(),
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedDroplet, size: 16, color: Colors.blue.shade600),
                const SizedBox(width: 6),
                Text('Quick Hydration',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Text(todayL,
                    style: TextStyle(
                        fontSize: 12, color: Colors.blue.shade600,
                        fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _WaterBtn('50 ml', 50, cs, _logging, _log),
                  const SizedBox(width: 6),
                  _WaterBtn('100 ml', 100, cs, _logging, _log),
                  const SizedBox(width: 6),
                  _WaterBtn('200 ml', 200, cs, _logging, _log),
                  const SizedBox(width: 6),
                  SizedBox(
                    height: 36,
                    child: FilledButton.tonal(
                      onPressed: _logging ? null : _logCustom,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Custom', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ],
              ),
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
    return SizedBox(
      height: 36,
      child: FilledButton.tonal(
        onPressed: disabled ? null : () => onLog(ml),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                    HugeIcon(icon: HugeIcons.strokeRoundedShoppingCart01, size: 16),
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
                Semantics(
                  button: true,
                  label: 'View full grocery breakdown',
                  child: InkWell(
                    onTap: () => context.go('/grocery'),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('View full breakdown',
                            style: TextStyle(
                                fontSize: 12, color: cs.primary,
                                fontWeight: FontWeight.w600)),
                        const SizedBox(width: 4),
                        ExcludeSemantics(child: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 10, color: cs.primary)),
                      ],
                    ),
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

// ── Rich Welcome Screen — swipe up to dismiss, mood-driven animations ───────

class _WelcomeScreen extends ConsumerStatefulWidget {
  final String personId;
  const _WelcomeScreen({required this.personId});
  @override
  ConsumerState<_WelcomeScreen> createState() => _WelcomeScreenState();
}

// ── Brand palette (app icon: pink → orange → purple) ────────────────────────
const _wPink     = Color(0xFFE91E63);
const _wPinkDark = Color(0xFF880E4F);
const _wOrange   = Color(0xFFFF6D00);
class _WelcomeScreenState extends ConsumerState<_WelcomeScreen>
    with TickerProviderStateMixin {
  late final AnimationController _masterCtrl;
  late final AnimationController _orbCtrl;
  late final AnimationController _pulseCtrl;
  late final AnimationController _floatCtrl;

  // Staggered entrance animations
  late final Animation<double> _emojiScale;
  late final Animation<double> _greetingFade;
  late final Animation<Offset> _greetingSlide;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;
  late final Animation<double> _swipeHintFade;

  @override
  void initState() {
    super.initState();

    _masterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2200))
      ..forward();

    _orbCtrl = AnimationController(
      vsync: this, duration: const Duration(seconds: 20))
      ..repeat();

    _pulseCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1800))
      ..repeat(reverse: true);

    _floatCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2500))
      ..repeat(reverse: true);

    _emojiScale = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.0, 0.30, curve: Curves.elasticOut),
    ));

    _greetingFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.18, 0.40, curve: Curves.easeOut),
    );
    _greetingSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.18, 0.40, curve: Curves.easeOutCubic)),
    );

    _nameFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.30, 0.55, curve: Curves.easeOut),
    );
    _nameSlide = Tween(begin: const Offset(0, 0.4), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.30, 0.55, curve: Curves.easeOutCubic)),
    );

    _cardFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.50, 0.80, curve: Curves.easeOut),
    );
    _cardSlide = Tween(begin: const Offset(0, 0.25), end: Offset.zero).animate(
      CurvedAnimation(parent: _masterCtrl, curve: const Interval(0.50, 0.80, curve: Curves.easeOutCubic)),
    );

    _swipeHintFade = CurvedAnimation(
      parent: _masterCtrl,
      curve: const Interval(0.82, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _masterCtrl.dispose();
    _orbCtrl.dispose();
    _pulseCtrl.dispose();
    _floatCtrl.dispose();
    super.dispose();
  }

  // ── Mood-aware gradient tinting over brand teal ──────────────────────────

  List<Color> _gradient(String? insightType) {
    // Base: brand pink/orange (matches app icon)
    const base = [_wPinkDark, _wPink, _wOrange];
    if (insightType == 'positive') {
      // Energetic orange-pink
      return const [Color(0xFFBF360C), Color(0xFFFF6D00), Color(0xFFFF9E40)];
    } else if (insightType == 'care') {
      // Warm purple tint
      return const [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)];
    } else if (insightType == 'neutral') {
      // Pink-purple blend
      return const [Color(0xFF880E4F), Color(0xFFD81B60), Color(0xFFFF6090)];
    }
    // Time-based subtle tint
    final h = DateTime.now().hour;
    if (h < 6 || h >= 20) {
      return const [Color(0xFF4A0E2E), Color(0xFF880E4F), Color(0xFFAD1457)]; // Deep pink night
    }
    return base;
  }

  Color _accent(String? insightType) {
    switch (insightType) {
      case 'positive': return const Color(0xFFFFAB40); // warm orange
      case 'care': return const Color(0xFFCE93D8);     // soft purple
      case 'neutral': return const Color(0xFFFF80AB);   // light pink
      default: return const Color(0xFFFF80AB);
    }
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
    final gradColors = _gradient(moodInsightType);
    final accent = _accent(moodInsightType);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradColors,
        ),
      ),
      child: Stack(
        children: [
          // ── Floating orbs (onboarding style — clean, subtle) ──
          ExcludeSemantics(child: AnimatedBuilder(
            animation: _orbCtrl,
            builder: (_, __) => CustomPaint(
              size: screenSize,
              painter: _WelcomeOrbsPainter(_orbCtrl.value, accent),
            ),
          )),

          // ── Main content ──
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: _buildContent(
                  greeting: greeting, name: name,
                  moodInsight: moodInsight, moodEmoji: moodEmoji,
                  moodInsightType: moodInsightType,
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
                  animation: _pulseCtrl,
                  builder: (_, __) => Transform.translate(
                    offset: Offset(0, -6 * _pulseCtrl.value),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedArrowUp01,
                          size: 28,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Swipe up for dashboard',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.4),
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
    ),
    );
  }

  String _localGreeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  static const _moodEmojis = {
    'happy': '😊', 'excited': '🤩', 'pumped up': '🔥', 'motivated': '💪',
    'grateful': '🙏', 'loved': '💕', 'calm': '😌', 'peaceful': '🧘',
    'neutral': '😐', 'confused': '🤔', 'nervous': '😬', 'focused': '🧠',
    'horny': '😏', 'sleepy': '😴', 'tired': '🥱', 'exhausted': '😮‍💨',
    'sad': '😔', 'anxious': '😰', 'stressed': '😤', 'irritated': '😠',
    'overwhelmed': '🤯', 'lonely': '😞', 'angry': '😡', 'frustrated': '😢',
  };
  String _moodToEmoji(String mood) => _moodEmojis[mood.toLowerCase()] ?? '✨';

  Widget _buildContent({
    required String greeting, required String name,
    String? moodInsight, String? moodEmoji, String? moodInsightType,
    required Color accent, double? averageScore, String? dominantMood,
    List<String> allMoods = const [],
  }) {
    // Mood-driven emoji (prioritize mood, then time-of-day)
    final hour = DateTime.now().hour;
    String mainEmoji;
    if (dominantMood != null) {
      mainEmoji = _moodToEmoji(dominantMood);
    } else {
      mainEmoji = hour < 6 ? '🌌' : hour < 12 ? '🌅' : hour < 17 ? '☀️' : hour < 20 ? '🌇' : '🌙';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 40),

        // 1. Animated mood emoji with pulsing glow rings + floating motion
        AnimatedBuilder(
          animation: Listenable.merge([_masterCtrl, _pulseCtrl, _floatCtrl]),
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
                        width: 140, height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2 + _pulseCtrl.value * 0.15),
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
                    // Middle glow ring
                    Transform.scale(
                      scale: 1.0 + _pulseCtrl.value * 0.04,
                      child: Container(
                        width: 115, height: 115,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: accent.withValues(alpha: 0.12),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),
                    // Inner radial glow behind emoji
                    Container(
                      width: 100, height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            accent.withValues(alpha: 0.15 + _pulseCtrl.value * 0.08),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                    // Emoji — large, animated
                    Text(mainEmoji, style: const TextStyle(fontSize: 72)),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 28),

        // 2. Greeting text
        SlideTransition(
          position: _greetingSlide,
          child: FadeTransition(
            opacity: _greetingFade,
            child: Text(
              greeting,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w300,
                color: Colors.white.withValues(alpha: 0.7),
                letterSpacing: 3,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // 3. User name — large, bold, white
        SlideTransition(
          position: _nameSlide,
          child: FadeTransition(
            opacity: _nameFade,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.1,
                letterSpacing: -1,
              ),
            ),
          ),
        ),

        // 4. Mood score bar inside glass card
        if (averageScore != null) ...[
          const SizedBox(height: 24),
          SlideTransition(
            position: _cardSlide,
            child: FadeTransition(
              opacity: _cardFade,
              child: _WelcomeGlassCard(
                child: _MoodScoreBar(
                  score: averageScore,
                  accent: accent,
                  pulseCtrl: _pulseCtrl,
                ),
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),

        // 5. Mood insight in glass card
        if (moodInsight != null && moodInsight.isNotEmpty)
          SlideTransition(
            position: _cardSlide,
            child: FadeTransition(
              opacity: _cardFade,
              child: _WelcomeGlassCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (moodEmoji != null)
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(child: Text(moodEmoji, style: const TextStyle(fontSize: 22))),
                          ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _insightTitle(moodInsightType),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
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
                                    fontSize: 12,
                                    color: Colors.white.withValues(alpha: 0.6),
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
                    const SizedBox(height: 12),
                    Text(
                      moodInsight,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withValues(alpha: 0.85),
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

        // 6. Quick feature highlights (onboarding style)
        if (moodInsight == null || moodInsight.isEmpty) ...[
          const SizedBox(height: 24),
          SlideTransition(
            position: _cardSlide,
            child: FadeTransition(
              opacity: _cardFade,
              child: _WelcomeGlassCard(
                child: Column(
                  children: [
                    _WelcomeFeatureRow(icon: HugeIcons.strokeRoundedMenuRestaurant, text: 'Log meals & track nutrition'),
                    const SizedBox(height: 14),
                    _WelcomeFeatureRow(icon: HugeIcons.strokeRoundedChartLineData01, text: 'AI-powered health insights'),
                    const SizedBox(height: 14),
                    _WelcomeFeatureRow(icon: HugeIcons.strokeRoundedUserGroup, text: 'Family health dashboard'),
                  ],
                ),
              ),
            ),
          ),
        ],

        const SizedBox(height: 80), // room for swipe indicator
      ],
    );
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

// ── Glassmorphic card (matching onboarding) ─────────────────────────────────

class _WelcomeGlassCard extends StatelessWidget {
  final Widget child;
  const _WelcomeGlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: child,
    );
  }
}

// ── Feature row (matching onboarding) ───────────────────────────────────────

class _WelcomeFeatureRow extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String text;
  const _WelcomeFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: HugeIcon(icon: icon, color: Colors.white.withValues(alpha: 0.9), size: 18)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: TextStyle(
            fontSize: 14, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500,
          )),
        ),
      ],
    );
  }
}

// ── Mood score indicator bar ────────────────────────────────────────────────

class _MoodScoreBar extends StatelessWidget {
  final double score;
  final Color accent;
  final AnimationController pulseCtrl;

  const _MoodScoreBar({
    required this.score, required this.accent, required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = (score / 10).clamp(0.0, 1.0);

    return Semantics(
      label: 'Mood score: ${score.toStringAsFixed(1)} out of 10',
      child: ExcludeSemantics(child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              score.toStringAsFixed(1),
              style: TextStyle(
                fontSize: 26, fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
                color: accent,
              ),
            ),
            Text(
              ' / 10',
              style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(width: 8),
            Text('MOOD SCORE', style: TextStyle(
              fontSize: 11, color: Colors.white.withValues(alpha: 0.5),
              fontWeight: FontWeight.w600,
              letterSpacing: 1.5,
            )),
          ],
        ),
        const SizedBox(height: 10),
        AnimatedBuilder(
          animation: pulseCtrl,
          builder: (_, __) => Container(
            height: 5,
            width: 180,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: Colors.white.withValues(alpha: 0.1),
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
    )),
    );
  }
}

// ── Floating orbs painter (matching onboarding style) ───────────────────────

class _WelcomeOrbsPainter extends CustomPainter {
  final double t;
  final Color accent;
  _WelcomeOrbsPainter(this.t, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      (0.12, 0.18, 65.0, 1.0),
      (0.85, 0.25, 90.0, 0.7),
      (0.5,  0.75, 110.0, 1.3),
      (0.2,  0.6,  50.0, 0.9),
      (0.75, 0.85, 70.0, 1.1),
    ];
    for (final (x, y, radius, speed) in orbs) {
      final dx = sin(t * 2 * pi * speed) * 20;
      final dy = cos(t * 2 * pi * speed * 0.7) * 15;
      final center = Offset(x * size.width + dx, y * size.height + dy);
      final color = accent.withValues(alpha: 0.05);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_WelcomeOrbsPainter old) => true;
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
            HugeIcon(icon: HugeIcons.strokeRoundedCloud,
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
              icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh),
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
  final List<List<dynamic>> icon;
  final Color color;

  const _StatCard({
    required this.label,    required this.icon,     required this.color,
    required this.todayValue, required this.todayUnit,
    required this.weekAvg,  required this.prevAvg,  required this.up,
    this.showTrend = true,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label: $todayValue $todayUnit. 7-day average: $weekAvg.${showTrend ? ' Trend ${up ? 'up' : 'down'}, previous: $prevAvg.' : ''}',
      child: ExcludeSemantics(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  HugeIcon(icon: icon, color: color, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(label.toUpperCase(),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey.shade500,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8),
                        overflow: TextOverflow.ellipsis),
                  ),
                ]),
                const SizedBox(height: 6),
                Row(crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic, children: [
                  Text(todayValue,
                      style: TextStyle(
                          fontSize: 26, fontWeight: FontWeight.w800,
                          letterSpacing: -0.5, color: color)),
                  if (todayUnit.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Text(todayUnit,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                            color: Colors.grey.shade500)),
                  ],
                ]),
                const SizedBox(height: 6),
                Text('7d avg: $weekAvg',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                        color: Colors.grey.shade500),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                if (showTrend)
                  Row(children: [
                    HugeIcon(icon: up ? HugeIcons.strokeRoundedChartIncrease : HugeIcons.strokeRoundedChartDecrease,
                        size: 14, color: up ? Colors.green : Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text('Prev: $prevAvg',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                              color: Colors.grey.shade500),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
              ],
            ),
          ),
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
              HugeIcon(icon: HugeIcons.strokeRoundedPieChart, size: 16),
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
    final deltaStr = '${delta >= 0 ? "+" : ""}${delta.toStringAsFixed(1)} vs prev week';
    final components = [
      ('Nutrition', score.nutrition, HugeIcons.strokeRoundedRestaurant01,  Colors.green),
      ('Hydration', score.hydration, HugeIcons.strokeRoundedDroplet,      Colors.blue),
      ('Exercise',  score.exercise,  HugeIcons.strokeRoundedDumbbell01,   Colors.orange),
      ('Sleep',     score.sleep,     HugeIcons.strokeRoundedBed,          Colors.indigo),
      ('Mood',      score.mood,      HugeIcons.strokeRoundedSmileDizzy,   Colors.pink),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              HugeIcon(icon: HugeIcons.strokeRoundedHealth, size: 16),
              const SizedBox(width: 6),
              Text('Health Score (7 days)',
                  style: Theme.of(context).textTheme.titleSmall),
              const HelpTooltip(
                message: 'Health Score combines your nutrition, hydration, exercise, sleep, and mood data into an overall wellness score out of 100.',
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${score.total.toStringAsFixed(0)}/100',
                      style: TextStyle(
                          fontSize: 22, fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
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
                  HugeIcon(icon: c.$3, size: 14, color: c.$4),
                  const SizedBox(width: 6),
                  SizedBox(width: 68, child: Text(c.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
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
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                  const SizedBox(width: 4),
                  if (pv > 0)
                    Text('${pd >= 0 ? '+' : ''}${pd.toStringAsFixed(0)}',
                        style: TextStyle(
                            fontSize: 11,
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
              HugeIcon(icon: HugeIcons.strokeRoundedCoffee02, size: 16),
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
              HugeIcon(icon: HugeIcons.strokeRoundedBulb, size: 16, color: Colors.amber),
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
      'positive' => (HugeIcons.strokeRoundedCheckmarkCircle01,       Colors.green),
      'warning'  => (HugeIcons.strokeRoundedAlert02,     Colors.orange),
      'tip'      => (HugeIcons.strokeRoundedBulb,  Colors.blue),
      _          => (HugeIcons.strokeRoundedInformationCircle,               Colors.grey),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HugeIcon(icon: icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(insight.message, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _MacrosCard extends ConsumerWidget {
  final DashboardData data;
  final String dayLabel;
  const _MacrosCard({required this.data, required this.dayLabel});

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
    final intake = dailyIntake(age, gender);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              HugeIcon(icon: HugeIcons.strokeRoundedEggs, size: 16),
              const SizedBox(width: 6),
              Text("$dayLabel Macros",
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
    return Semantics(
      label: '$label: ${current.toStringAsFixed(0)} of ${daily.toStringAsFixed(0)} $unit, ${(pct * 100).toStringAsFixed(0)} percent',
      child: ExcludeSemantics(
        child: Padding(
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
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
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
        ),
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
        return Semantics(
          button: true,
          label: 'Flare Risk: $label, score ${risk.score} out of 100.${risk.recommendations.isNotEmpty ? ' ${risk.recommendations.first}' : ''} Tap to view insights.',
          child: ExcludeSemantics(
            child: Card(
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
                                HugeIcon(icon: HugeIcons.strokeRoundedShield01,
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
                      HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                          size: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant
                              .withValues(alpha: 0.5)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
