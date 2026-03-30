import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';

import '../models/health_intelligence.dart';
import '../models/health_twin_data.dart';
import '../providers/health_intelligence_provider.dart';
import '../providers/health_twin_provider.dart';
import '../providers/health_twin_engine_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/friendly_error.dart';
import 'health_twin_engine_tabs.dart';
import '../widgets/themed_spinner.dart';

// ── Health Intelligence Screen ──────────────────────────────────────────────

class HealthIntelligenceScreen extends ConsumerStatefulWidget {
  const HealthIntelligenceScreen({super.key});

  @override
  ConsumerState<HealthIntelligenceScreen> createState() =>
      _HealthIntelligenceScreenState();
}

class _HealthIntelligenceScreenState
    extends ConsumerState<HealthIntelligenceScreen>
    with TickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final AnimationController _ringAnimCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 8, vsync: this);
    _ringAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _ringAnimCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    final personId = ref.read(selectedPersonProvider);
    ref.invalidate(dailyHealthScoreProvider(personId));
    ref.invalidate(healthAlertsProvider(personId));
    ref.invalidate(riskProfileProvider(personId));
    ref.invalidate(scoreHistoryProvider(personId));
    ref.invalidate(dailyTwinProvider(personId));
    ref.invalidate(twinTrendProvider(personId));
    ref.invalidate(userGoalsProvider(personId));
    ref.invalidate(goalInsightsProvider(personId));
    ref.invalidate(weeklySummaryProvider(personId));
    ref.invalidate(crossDomainCorrelationsProvider(personId));
    ref.invalidate(engagementSummaryProvider(personId));
    ref.invalidate(healthPredictionsProvider(personId));
    ref.invalidate(familyOverviewProvider);
    _ringAnimCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Health Intelligence',
            style: theme.textTheme.titleLarge),
        leading: IconButton(
          icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 24.0, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24.0, color: theme.colorScheme.onSurface),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(text: 'Health Score'),
            Tab(text: 'Digital Twin'),
            Tab(text: 'Goals'),
            Tab(text: 'Weekly'),
            Tab(text: 'Correlations'),
            Tab(text: 'Level & XP'),
            Tab(text: 'Predictions'),
            Tab(text: 'Family'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _HealthScoreTab(ringAnim: _ringAnimCtrl, onRefresh: _refresh),
          const _DigitalTwinTab(),
          const _GoalsTab(),
          const _WeeklySummaryTab(),
          const CorrelationsTab(),
          const EngagementTab(),
          const PredictionsTab(),
          const FamilyOverviewTab(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 0 — Health Score (original screen content)
// ═════════════════════════════════════════════════════════════════════════════

class _HealthScoreTab extends ConsumerWidget {
  final AnimationController ringAnim;
  final VoidCallback onRefresh;

  const _HealthScoreTab({required this.ringAnim, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final scoreAsync = ref.watch(dailyHealthScoreProvider(personId));
    final alertsAsync = ref.watch(healthAlertsProvider(personId));
    final riskAsync = ref.watch(riskProfileProvider(personId));
    final historyAsync = ref.watch(scoreHistoryProvider(personId));

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 8),
        scoreAsync.when(
          skipLoadingOnReload: true,
          loading: () => const _ScoreRingSkeleton(),
          error: (e, _) =>
              FriendlyError(error: e, context: 'health score', onRetry: onRefresh),
          data: (score) =>
              _ScoreRingSection(score: score, animation: ringAnim),
        ),
        const SizedBox(height: 24),
        scoreAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ShimmerList(itemCount: 8, itemHeight: 48),
          error: (_, __) => const SizedBox.shrink(),
          data: (score) => _DimensionBreakdown(dimensions: score.dimensions),
        ),
        const SizedBox(height: 24),
        alertsAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ShimmerList(itemCount: 3, itemHeight: 80),
          error: (e, _) =>
              FriendlyError(error: e, context: 'alerts', onRetry: onRefresh),
          data: (alerts) =>
              _AlertsSection(alerts: alerts, personId: personId),
        ),
        const SizedBox(height: 24),
        historyAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ShimmerList(itemCount: 1, itemHeight: 160),
          error: (e, _) => FriendlyError(
              error: e, context: 'score history', onRetry: onRefresh),
          data: (history) => _ScoreTrendSection(history: history),
        ),
        const SizedBox(height: 24),
        riskAsync.when(
          skipLoadingOnReload: true,
          loading: () => const ShimmerList(itemCount: 1, itemHeight: 120),
          error: (e, _) => FriendlyError(
              error: e, context: 'risk profile', onRetry: onRefresh),
          data: (risk) => _RiskProfileCard(risk: risk),
        ),
        const SizedBox(height: 24),
        _ClinicalReportButton(personId: personId),
        const SizedBox(height: 40),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 1 — Digital Twin
// ═════════════════════════════════════════════════════════════════════════════

class _DigitalTwinTab extends ConsumerWidget {
  const _DigitalTwinTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final twinAsync = ref.watch(dailyTwinProvider(personId));
    final trendAsync = ref.watch(twinTrendProvider(personId));

    return twinAsync.when(
      skipLoadingOnReload: true,
      loading: () => const _TwinLoadingSkeleton(),
      error: (e, _) => FriendlyError(
        error: e,
        context: 'digital twin',
        onRetry: () => ref.invalidate(dailyTwinProvider(personId)),
      ),
      data: (twin) {
        if (twin == null) {
          return EmptyState(
            message:
                'No data available for today.\nLog some meals or hydration to see your Digital Twin.',
            icon: HugeIcons.strokeRoundedUserSearch01,
          );
        }
        return ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            const SizedBox(height: 12),
            _CompletenessGauge(score: twin.completenessScore),
            const SizedBox(height: 20),
            _MacroProgressSection(macros: twin.macros),
            const SizedBox(height: 20),
            _MicronutrientSummaryCard(twin: twin),
            const SizedBox(height: 20),
            if (twin.topGaps.isNotEmpty) ...[
              _NutrientGapsList(
                title: 'Top Nutrient Gaps',
                gaps: twin.topGaps,
                isExcess: false,
              ),
              const SizedBox(height: 16),
            ],
            if (twin.topExcesses.isNotEmpty) ...[
              _NutrientGapsList(
                title: 'Excessive Nutrients',
                gaps: twin.topExcesses,
                isExcess: true,
              ),
              const SizedBox(height: 16),
            ],
            _HydrationBar(twin: twin),
            const SizedBox(height: 20),
            if (twin.foodRecommendations.isNotEmpty) ...[
              _FoodRecommendationsCard(recs: twin.foodRecommendations),
              const SizedBox(height: 20),
            ],
            trendAsync.when(
              skipLoadingOnReload: true,
              loading: () => const ShimmerCard(height: 120),
              error: (_, __) => const SizedBox.shrink(),
              data: (trend) => _TwinSparkline(entries: trend),
            ),
            const SizedBox(height: 40),
          ],
        );
      },
    );
  }
}

class _TwinLoadingSkeleton extends StatelessWidget {
  const _TwinLoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Column(children: [
        ShimmerCard(height: 180),
        ShimmerCard(height: 100),
        ShimmerCard(height: 80),
        ShimmerCard(height: 120),
      ]),
    );
  }
}

// ── Completeness Gauge ───────────────────────────────────────────────────────

class _CompletenessGauge extends StatelessWidget {
  final double score;
  const _CompletenessGauge({required this.score});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pct = score.clamp(0.0, 100.0);
    final color = _scoreColor(pct);

    return Center(
      child: SizedBox(
        width: 160,
        height: 160,
        child: CustomPaint(
          painter: _ArcGaugePainter(
            progress: pct / 100,
            color: color,
            trackColor:
                theme.colorScheme.surfaceContainerHighest.withAlpha(80),
          ),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  pct.round().toString(),
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                    fontSize: 40,
                  ),
                ),
                Text(
                  'Completeness',
                  style: text.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _ArcGaugePainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const strokeWidth = 12.0;
    const startAngle = -math.pi * 0.75;
    const sweepAngle = math.pi * 1.5;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      trackPaint,
    );

    if (progress > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: startAngle,
          endAngle: startAngle + sweepAngle,
          colors: [color.withAlpha(180), color],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle * progress.clamp(0.0, 1.0),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ArcGaugePainter old) =>
      old.progress != progress || old.color != color;
}

// ── Macro Progress Section ───────────────────────────────────────────────────

class _MacroProgressSection extends StatelessWidget {
  final Map<String, MacroStatus> macros;
  const _MacroProgressSection({required this.macros});

  static const _macroMeta = <String, ({List<List<dynamic>> icon, Color color, String label})>{
    'calories': (icon: HugeIcons.strokeRoundedFire, color: Color(0xFFEF4444), label: 'Calories'),
    'protein': (icon: HugeIcons.strokeRoundedEggs, color: Color(0xFF8B5CF6), label: 'Protein'),
    'carbs': (icon: HugeIcons.strokeRoundedCorn, color: Color(0xFFF59E0B), label: 'Carbs'),
    'fat': (icon: HugeIcons.strokeRoundedDroplet, color: Color(0xFF3B82F6), label: 'Fat'),
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final orderedKeys = ['calories', 'protein', 'carbs', 'fat'];

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Macronutrients', style: text.titleSmall),
            const SizedBox(height: 12),
            for (final key in orderedKeys)
              if (macros.containsKey(key))
                _MacroRow(
                  macroKey: key,
                  status: macros[key]!,
                  meta: _macroMeta[key]!,
                ),
          ],
        ),
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String macroKey;
  final MacroStatus status;
  final ({List<List<dynamic>> icon, Color color, String label}) meta;

  const _MacroRow({
    required this.macroKey,
    required this.status,
    required this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pct = (status.percent / 100).clamp(0.0, 1.0);
    final unit = macroKey == 'calories' ? 'kcal' : 'g';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: meta.icon, size: 16, color: meta.color),
              const SizedBox(width: 8),
              Text(meta.label, style: text.bodyMedium),
              const Spacer(),
              Text(
                '${status.consumed.round()} / ${status.target.round()} $unit',
                style: text.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${status.percent.round()}%',
                style: text.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: meta.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 6,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              valueColor: AlwaysStoppedAnimation(
                pct > 1.0 ? const Color(0xFFEF4444) : meta.color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Micronutrient Summary Card ───────────────────────────────────────────────

class _MicronutrientSummaryCard extends StatelessWidget {
  final DailyTwin twin;
  const _MicronutrientSummaryCard({required this.twin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedTestTube01, size: 18),
                const SizedBox(width: 8),
                Text('Micronutrient Status', style: text.titleSmall),
                const Spacer(),
                Text(
                  '${twin.microTotalTracked} tracked',
                  style: text.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _StatusBadge(
                  label: '${twin.microAdequateCount} Adequate',
                  color: const Color(0xFF10B981),
                ),
                _StatusBadge(
                  label: '${twin.microApproachingCount} Approaching',
                  color: const Color(0xFFF59E0B),
                ),
                _StatusBadge(
                  label: '${twin.microLowCount} Low',
                  color: const Color(0xFFEF4444),
                ),
                if (twin.microExcessiveCount > 0)
                  _StatusBadge(
                    label: '${twin.microExcessiveCount} Excessive',
                    color: const Color(0xFFFF6B00),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

// ── Nutrient Gaps List ───────────────────────────────────────────────────────

class _NutrientGapsList extends StatelessWidget {
  final String title;
  final List<NutrientGap> gaps;
  final bool isExcess;

  const _NutrientGapsList({
    required this.title,
    required this.gaps,
    required this.isExcess,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: isExcess
                  ? HugeIcons.strokeRoundedAlert02
                  : HugeIcons.strokeRoundedChartDecrease,
              size: 18,
              color: isExcess
                  ? const Color(0xFFFF6B00)
                  : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 8),
            Text(title, style: text.titleSmall),
          ],
        ),
        const SizedBox(height: 8),
        _StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (var i = 0; i < gaps.length; i++) ...[
                  if (i > 0)
                    Divider(
                        height: 1,
                        color: theme.dividerColor.withAlpha(30)),
                  _NutrientGapRow(gap: gaps[i], isExcess: isExcess),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NutrientGapRow extends StatelessWidget {
  final NutrientGap gap;
  final bool isExcess;

  const _NutrientGapRow({required this.gap, required this.isExcess});

  Color get _barColor {
    if (isExcess) return const Color(0xFFFF6B00);
    if (gap.percentDri < 30) return const Color(0xFFEF4444);
    if (gap.percentDri < 60) return const Color(0xFFF59E0B);
    if (gap.percentDri < 80) return const Color(0xFFEAB308);
    return const Color(0xFF10B981);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pct = isExcess
        ? (gap.percentDri / 100).clamp(0.0, 2.0) / 2.0
        : (gap.percentDri / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(gap.displayName, style: text.bodyMedium),
              ),
              Text(
                '${gap.consumed.toStringAsFixed(1)} / ${gap.target.toStringAsFixed(1)} ${gap.unit}',
                style: text.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 5,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              valueColor: AlwaysStoppedAnimation(_barColor),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Hydration Bar ────────────────────────────────────────────────────────────

class _HydrationBar extends StatelessWidget {
  final DailyTwin twin;
  const _HydrationBar({required this.twin});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pct = (twin.hydrationPercent / 100).clamp(0.0, 1.0);

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedDroplet,
                    size: 18, color: Color(0xFF3B82F6)),
                const SizedBox(width: 8),
                Text('Hydration', style: text.titleSmall),
                const Spacer(),
                Text(
                  '${twin.hydrationMl.round()} / ${twin.hydrationTargetMl.round()} ml',
                  style: text.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${twin.hydrationPercent.round()}%',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 8,
                backgroundColor:
                    theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                valueColor:
                    const AlwaysStoppedAnimation(Color(0xFF3B82F6)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Food Recommendations Card ────────────────────────────────────────────────

class _FoodRecommendationsCard extends StatelessWidget {
  final List<Map<String, dynamic>> recs;
  const _FoodRecommendationsCard({required this.recs});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Suggested Foods', style: text.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            for (final rec in recs)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedAdd01,
                        size: 16, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rec['food_name']?.toString() ?? rec.toString(),
                            style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600),
                          ),
                          if (rec['reason'] != null)
                            Text(
                              rec['reason'].toString(),
                              style: text.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}

// ── Twin Sparkline ───────────────────────────────────────────────────────────

class _TwinSparkline extends StatelessWidget {
  final List<TwinTrendEntry> entries;
  const _TwinSparkline({required this.entries});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    if (entries.length < 2) {
      return const SizedBox.shrink();
    }

    final spots = <FlSpot>[];
    for (var i = 0; i < entries.length; i++) {
      spots.add(FlSpot(i.toDouble(), entries[i].completenessScore));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('30-Day Completeness Trend', style: text.titleSmall),
        const SizedBox(height: 8),
        _StyledCard(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
            child: SizedBox(
              height: 100,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 0,
                  maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: theme.colorScheme.primary,
                      barWidth: 2.5,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: theme.colorScheme.primary.withAlpha(30),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (spots) => spots.map((s) {
                        final idx = s.x.toInt();
                        final date = idx < entries.length
                            ? entries[idx].date
                            : '';
                        return LineTooltipItem(
                          '$date\n${s.y.round()}%',
                          TextStyle(
                            color: theme.colorScheme.onSurface,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 2 — Goals
// ═════════════════════════════════════════════════════════════════════════════

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final goalsAsync = ref.watch(userGoalsProvider(personId));
    final insightsAsync = ref.watch(goalInsightsProvider(personId));

    return goalsAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(itemCount: 3, itemHeight: 100),
      ),
      error: (e, _) => FriendlyError(
        error: e,
        context: 'goals',
        onRetry: () => ref.invalidate(userGoalsProvider(personId)),
      ),
      data: (goals) {
        if (goals.isEmpty) {
          return _GoalsEmptyState(personId: personId);
        }

        final insightsMap = <String, GoalInsightsResponse>{};
        final insightsData = insightsAsync.valueOrNull ?? [];
        for (final gi in insightsData) {
          insightsMap[gi.goalId] = gi;
        }

        return Stack(
          children: [
            ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
              itemCount: goals.length,
              itemBuilder: (context, index) => _GoalCard(
                goal: goals[index],
                insights: insightsMap[goals[index].id],
                personId: personId,
              ),
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                onPressed: () => _showGoalSetup(context, ref, personId),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
                label: const Text('Add Goal'),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showGoalSetup(BuildContext context, WidgetRef ref, String personId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _GoalSetupSheet(personId: personId),
    );
  }
}

class _GoalsEmptyState extends StatelessWidget {
  final String personId;
  const _GoalsEmptyState({required this.personId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedFlag01,
                size: 64,
                color: theme.colorScheme.outline.withAlpha(120)),
            const SizedBox(height: 20),
            Text(
              'Set Your First Goal',
              style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Track weight loss, nutrition targets, hydration goals, and more.',
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) => _GoalSetupSheet(personId: personId),
                );
              },
              icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
              label: const Text('Create Goal'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Goal Card ────────────────────────────────────────────────────────────────

class _GoalCard extends StatefulWidget {
  final UserGoal goal;
  final GoalInsightsResponse? insights;
  final String personId;

  const _GoalCard({
    required this.goal,
    this.insights,
    required this.personId,
  });

  @override
  State<_GoalCard> createState() => _GoalCardState();
}

class _GoalCardState extends State<_GoalCard> {
  bool _expanded = false;

  Color get _trendColor {
    switch (widget.goal.trend) {
      case 'on_track':
        return const Color(0xFF10B981);
      case 'behind':
        return const Color(0xFFEF4444);
      case 'ahead':
        return const Color(0xFF3B82F6);
      case 'achieved':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFFF59E0B);
    }
  }

  String get _trendLabel {
    switch (widget.goal.trend) {
      case 'on_track':
        return 'On Track';
      case 'behind':
        return 'Behind';
      case 'ahead':
        return 'Ahead';
      case 'achieved':
        return 'Achieved';
      default:
        return widget.goal.trend;
    }
  }

  List<List<dynamic>> get _goalIcon {
    switch (widget.goal.goalType) {
      case 'weight_loss':
      case 'weight_gain':
        return HugeIcons.strokeRoundedBodyWeight;
      case 'calories':
        return HugeIcons.strokeRoundedFire;
      case 'protein':
        return HugeIcons.strokeRoundedEggs;
      case 'hydration':
        return HugeIcons.strokeRoundedDroplet;
      case 'exercise':
        return HugeIcons.strokeRoundedDumbbell01;
      case 'sleep':
        return HugeIcons.strokeRoundedBed;
      case 'nutrient':
        return HugeIcons.strokeRoundedTestTube01;
      default:
        return HugeIcons.strokeRoundedFlag01;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final goal = widget.goal;
    final pct = (goal.progressPct / 100).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _StyledCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(icon: _goalIcon,
                        size: 22, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        goal.label,
                        style: text.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _trendColor.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _trendColor.withAlpha(60)),
                      ),
                      child: Text(
                        _trendLabel,
                        style: text.labelSmall?.copyWith(
                          color: _trendColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Progress bar
                Row(
                  children: [
                    if (goal.startValue != null)
                      Text(
                        goal.startValue!.toStringAsFixed(0),
                        style: text.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: theme
                              .colorScheme.surfaceContainerHighest
                              .withAlpha(80),
                          valueColor: AlwaysStoppedAnimation(_trendColor),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (goal.targetValue != null)
                      Text(
                        '${goal.targetValue!.toStringAsFixed(0)}${goal.targetUnit != null ? " ${goal.targetUnit}" : ""}',
                        style: text.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${goal.progressPct.round()}% complete',
                      style: text.labelMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: _trendColor,
                      ),
                    ),
                    if (goal.targetDate != null)
                      Text(
                        'Target: ${goal.targetDate}',
                        style: text.labelSmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
                if (_expanded && widget.insights != null) ...[
                  const SizedBox(height: 12),
                  Divider(color: theme.dividerColor.withAlpha(40)),
                  const SizedBox(height: 8),
                  for (final insight in widget.insights!.insights)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedBulb,
                              size: 16, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(insight.title,
                                    style: text.bodySmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                Text(insight.body,
                                    style: text.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  for (final rec in widget.insights!.recommendations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                              size: 16,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              rec['text']?.toString() ?? rec.toString(),
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (_expanded && widget.insights == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'No insights available yet.',
                    style: text.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Goal Setup Sheet ─────────────────────────────────────────────────────────

class _GoalSetupSheet extends ConsumerStatefulWidget {
  final String personId;
  const _GoalSetupSheet({required this.personId});

  @override
  ConsumerState<_GoalSetupSheet> createState() => _GoalSetupSheetState();
}

class _GoalSetupSheetState extends ConsumerState<_GoalSetupSheet> {
  String? _selectedCategory;
  String? _selectedType;
  final _targetCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  DateTime? _targetDate;
  bool _saving = false;

  // ── Domain-specific goal definitions ──────────────────────────────────────
  static const _categories = <String, _GoalCategory>{
    'weight': _GoalCategory(
      icon: HugeIcons.strokeRoundedBodyWeight,
      color: Color(0xFFF97316),
      label: 'Weight',
      types: [
        _GoalTypeDef(key: 'weight_loss', label: 'Lose Weight', unit: 'kg', defaultTarget: 70,
            hint: 'Target weight', description: 'Set your target weight in kg'),
        _GoalTypeDef(key: 'weight_gain', label: 'Gain Weight', unit: 'kg', defaultTarget: 80,
            hint: 'Target weight', description: 'Set your target weight in kg'),
      ],
    ),
    'nutrition': _GoalCategory(
      icon: HugeIcons.strokeRoundedRestaurant01,
      color: Color(0xFF10B981),
      label: 'Nutrition',
      types: [
        _GoalTypeDef(key: 'calories', label: 'Daily Calories', unit: 'kcal', defaultTarget: 2000,
            hint: '2000', description: 'Daily calorie intake target',
            presets: [1500, 1800, 2000, 2200, 2500]),
        _GoalTypeDef(key: 'protein', label: 'Daily Protein', unit: 'g', defaultTarget: 80,
            hint: '80', description: 'Daily protein intake in grams',
            presets: [50, 80, 100, 120, 150]),
        _GoalTypeDef(key: 'nutrient_balance', label: 'Nutrient Score', unit: '%', defaultTarget: 80,
            hint: '80', description: 'Target DRI completeness percentage',
            presets: [60, 70, 80, 90]),
      ],
    ),
    'exercise': _GoalCategory(
      icon: HugeIcons.strokeRoundedDumbbell01,
      color: Color(0xFFEF4444),
      label: 'Exercise',
      types: [
        _GoalTypeDef(key: 'exercise', label: 'Daily Active Minutes', unit: 'min/day', defaultTarget: 30,
            hint: '30', description: 'Average minutes of exercise per day',
            presets: [15, 30, 45, 60]),
        _GoalTypeDef(key: 'exercise_freq', label: 'Workout Days / Week', unit: 'days/wk', defaultTarget: 4,
            hint: '4', description: 'How many days per week to exercise',
            presets: [3, 4, 5, 6]),
        _GoalTypeDef(key: 'steps', label: 'Daily Steps', unit: 'steps', defaultTarget: 10000,
            hint: '10000', description: 'Daily step count target',
            presets: [5000, 7500, 10000, 12000, 15000]),
      ],
    ),
    'sleep': _GoalCategory(
      icon: HugeIcons.strokeRoundedBed,
      color: Color(0xFF8B5CF6),
      label: 'Sleep',
      types: [
        _GoalTypeDef(key: 'better_sleep', label: 'Sleep Duration', unit: 'hours', defaultTarget: 8,
            hint: '8', description: 'Target hours of sleep per night',
            presets: [7, 7.5, 8, 8.5, 9]),
        _GoalTypeDef(key: 'sleep_quality', label: 'Sleep Quality', unit: '/5', defaultTarget: 4,
            hint: '4', description: 'Target sleep quality rating (1-5)',
            presets: [3, 3.5, 4, 4.5, 5]),
      ],
    ),
    'hydration': _GoalCategory(
      icon: HugeIcons.strokeRoundedDroplet,
      color: Color(0xFF3B82F6),
      label: 'Hydration',
      types: [
        _GoalTypeDef(key: 'hydration', label: 'Daily Water Intake', unit: 'ml', defaultTarget: 2500,
            hint: '2500', description: 'Daily fluid intake in millilitres',
            presets: [1500, 2000, 2500, 3000, 3500]),
      ],
    ),
    'wellbeing': _GoalCategory(
      icon: HugeIcons.strokeRoundedYoga01,
      color: Color(0xFFF59E0B),
      label: 'Wellbeing',
      types: [
        _GoalTypeDef(key: 'mood_improvement', label: 'Mood Score', unit: '/10', defaultTarget: 7,
            hint: '7', description: 'Target average mood score (1-10)',
            presets: [5, 6, 7, 8]),
        _GoalTypeDef(key: 'more_energy', label: 'Energy Level', unit: '/5', defaultTarget: 4,
            hint: '4', description: 'Target average energy level (1-5)',
            presets: [3, 3.5, 4, 4.5, 5]),
        _GoalTypeDef(key: 'skin_health', label: 'Skin Severity', unit: '/10', defaultTarget: 3,
            hint: '3', description: 'Target eczema severity (lower is better)',
            presets: [2, 3, 4, 5]),
      ],
    ),
  };

  _GoalTypeDef? get _typeDef {
    if (_selectedCategory == null || _selectedType == null) return null;
    final cat = _categories[_selectedCategory];
    if (cat == null) return null;
    return cat.types.where((t) => t.key == _selectedType).firstOrNull;
  }

  @override
  void dispose() {
    _targetCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _selectType(_GoalTypeDef def) {
    setState(() {
      _selectedType = def.key;
      _targetCtrl.text = def.defaultTarget.toString();
    });
  }

  Future<void> _save() async {
    final def = _typeDef;
    if (def == null || _targetCtrl.text.isEmpty) return;
    setState(() => _saving = true);

    try {
      final body = <String, dynamic>{
        'goal_type': def.key,
        'target_value': double.tryParse(_targetCtrl.text) ?? 0,
        'target_unit': def.unit,
      };
      if (_notesCtrl.text.isNotEmpty) body['notes'] = _notesCtrl.text;
      if (_targetDate != null) {
        body['target_date'] = _targetDate!.toIso8601String().substring(0, 10);
      }
      if (widget.personId != 'self') {
        body['family_member_id'] = widget.personId;
      }

      await apiClient.dio.post(ApiConstants.healthGoals, data: body);
      ref.invalidate(userGoalsProvider(widget.personId));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create goal: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final text = theme.textTheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (context, scrollCtrl) => ListView(
        controller: scrollCtrl,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withAlpha(60),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Create a Goal', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            _selectedCategory == null
                ? 'Choose a category to get started'
                : _selectedType == null
                    ? 'Select a specific goal'
                    : 'Set your target',
            style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 20),

          // ── Step 1: Category Selection ──────────────────────────────────
          const _SectionLabel(label: 'Category', step: 1),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.entries.map((e) {
              final selected = _selectedCategory == e.key;
              final cat = e.value;
              return _CategoryChip(
                icon: cat.icon,
                label: cat.label,
                color: cat.color,
                selected: selected,
                onTap: () => setState(() {
                  _selectedCategory = e.key;
                  _selectedType = null;
                  _targetCtrl.clear();
                }),
              );
            }).toList(),
          ),

          // ── Step 2: Type Selection (shown after category) ──────────────
          if (_selectedCategory != null) ...[
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Goal', step: 2),
            const SizedBox(height: 10),
            ..._categories[_selectedCategory]!.types.map((def) {
              final selected = _selectedType == def.key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: selected
                      ? _categories[_selectedCategory]!.color.withAlpha(25)
                      : cs.surfaceContainerHighest.withAlpha(120),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _selectType(def),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          if (selected)
                            HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                                color: _categories[_selectedCategory]!.color, size: 22)
                          else
                            HugeIcon(icon: HugeIcons.strokeRoundedCircle,
                                color: cs.outline, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(def.label,
                                    style: text.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                const SizedBox(height: 2),
                                Text(def.description,
                                    style: text.bodySmall?.copyWith(
                                        color: cs.onSurfaceVariant)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(def.unit,
                                style: text.labelSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],

          // ── Step 3: Target Configuration (shown after type) ────────────
          if (_typeDef != null) ...[
            const SizedBox(height: 24),
            const _SectionLabel(label: 'Target', step: 3),
            const SizedBox(height: 10),

            // Quick-pick presets
            if (_typeDef!.presets != null) ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _typeDef!.presets!.map((v) {
                  final isSelected = _targetCtrl.text == v.toString();
                  return ChoiceChip(
                    label: Text('$v ${_typeDef!.unit}'),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _targetCtrl.text = v.toString()),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),
            ],

            // Custom value input
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _targetCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: _typeDef!.label,
                      hintText: _typeDef!.hint,
                      suffixText: _typeDef!.unit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Target date picker
            Material(
              color: cs.surfaceContainerHighest.withAlpha(120),
              borderRadius: BorderRadius.circular(12),
              child: ListTile(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                leading: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01,
                    color: cs.primary),
                title: Text(
                  _targetDate != null
                      ? 'By ${DateFormat.yMMMd().format(_targetDate!)}'
                      : 'Set a deadline (optional)',
                  style: text.bodyMedium,
                ),
                trailing: _targetDate != null
                    ? IconButton(
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18),
                        onPressed: () =>
                            setState(() => _targetDate = null),
                      )
                    : null,
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate:
                        DateTime.now().add(const Duration(days: 30)),
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365 * 2)),
                  );
                  if (picked != null) {
                    setState(() => _targetDate = picked);
                  }
                },
              ),
            ),
            const SizedBox(height: 12),

            // Notes
            TextField(
              controller: _notesCtrl,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                hintText: 'Any extra context for this goal...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),

            // Save button
            FilledButton.icon(
              onPressed: _targetCtrl.text.isNotEmpty && !_saving
                  ? _save
                  : null,
              icon: _saving
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01),
              label: Text(_saving ? 'Saving...' : 'Create Goal'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 52),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Helper widgets & data classes for Goal Setup ─────────────────────────────

class _GoalCategory {
  final List<List<dynamic>> icon;
  final Color color;
  final String label;
  final List<_GoalTypeDef> types;
  const _GoalCategory({
    required this.icon, required this.color,
    required this.label, required this.types,
  });
}

class _GoalTypeDef {
  final String key;
  final String label;
  final String unit;
  final num defaultTarget;
  final String hint;
  final String description;
  final List<num>? presets;
  const _GoalTypeDef({
    required this.key, required this.label, required this.unit,
    required this.defaultTarget, required this.hint,
    required this.description, this.presets,
  });
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final int step;
  const _SectionLabel({required this.label, required this.step});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Row(
      children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: cs.primary, shape: BoxShape.circle,
          ),
          child: Center(
            child: Text('$step',
                style: text.labelSmall?.copyWith(
                    color: cs.onPrimary, fontWeight: FontWeight.w700)),
          ),
        ),
        const SizedBox(width: 10),
        Text(label,
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.icon, required this.label, required this.color,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(30) : cs.surfaceContainerHighest.withAlpha(120),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 18, color: selected ? color : cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600,
                  color: selected ? color : cs.onSurfaceVariant,
                )),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// TAB 3 — Weekly Summary
// ═════════════════════════════════════════════════════════════════════════════

class _WeeklySummaryTab extends ConsumerStatefulWidget {
  const _WeeklySummaryTab();

  @override
  ConsumerState<_WeeklySummaryTab> createState() => _WeeklySummaryTabState();
}

class _WeeklySummaryTabState extends ConsumerState<_WeeklySummaryTab> {
  bool _showHistory = false;

  @override
  Widget build(BuildContext context) {
    final personId = ref.watch(selectedPersonProvider);
    final summaryAsync = ref.watch(weeklySummaryProvider(personId));

    if (_showHistory) {
      return _WeeklyHistoryView(
        personId: personId,
        onBack: () => setState(() => _showHistory = false),
      );
    }

    return summaryAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Padding(
        padding: EdgeInsets.all(16),
        child: ShimmerList(itemCount: 4, itemHeight: 100),
      ),
      error: (e, _) => FriendlyError(
        error: e,
        context: 'weekly summary',
        onRetry: () => ref.invalidate(weeklySummaryProvider(personId)),
      ),
      data: (summary) {
        if (summary == null) {
          return const EmptyState(
            message:
                'Your first weekly summary will appear\nafter a week of logging.',
            icon: HugeIcons.strokeRoundedCalendar01,
          );
        }
        return _WeeklySummaryBody(
          summary: summary,
          onShowHistory: () => setState(() => _showHistory = true),
        );
      },
    );
  }
}

class _WeeklySummaryBody extends StatelessWidget {
  final WeeklySummaryData summary;
  final VoidCallback onShowHistory;

  const _WeeklySummaryBody({
    required this.summary,
    required this.onShowHistory,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        const SizedBox(height: 12),

        // Period header
        _StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedCalendar01,
                    color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${summary.weekStart} - ${summary.weekEnd}',
                          style: text.titleSmall),
                      if (summary.source != 'statistical')
                        Text('AI-generated',
                            style: text.labelSmall?.copyWith(
                                color: theme.colorScheme.primary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Summary text
        if (summary.summaryText.isNotEmpty)
          _StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(summary.summaryText,
                  style: text.bodyMedium?.copyWith(height: 1.5)),
            ),
          ),
        const SizedBox(height: 16),

        // Key metrics row
        Row(
          children: [
            Expanded(
              child: _MetricTile(
                label: 'Days Logged',
                value: '${summary.daysLogged}/7',
                icon: HugeIcons.strokeRoundedCalendar01,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: 'Avg Score',
                value: summary.avgHealthScore.round().toString(),
                icon: HugeIcons.strokeRoundedFavourite,
                color: _scoreColor(summary.avgHealthScore),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MetricTile(
                label: 'Avg Cal',
                value: summary.avgDailyCalories.round().toString(),
                icon: HugeIcons.strokeRoundedFire,
                color: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Comparison to previous week
        if (summary.comparison.isNotEmpty) ...[
          _ComparisonCard(comparison: summary.comparison),
          const SizedBox(height: 16),
        ],

        // Insights
        if (summary.insights.isNotEmpty) ...[
          Text('Insights', style: text.titleSmall),
          const SizedBox(height: 8),
          for (final insight in summary.insights)
            _InsightCard(insight: insight),
          const SizedBox(height: 16),
        ],

        // Correlations
        if (summary.correlations.isNotEmpty) ...[
          Text('Correlations', style: text.titleSmall),
          const SizedBox(height: 8),
          _StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final corr in summary.correlations)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedLink01,
                              size: 16,
                              color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              corr['description']?.toString() ??
                                  corr.toString(),
                              style: text.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Recommendations
        if (summary.recommendations.isNotEmpty) ...[
          Text('Recommendations', style: text.titleSmall),
          const SizedBox(height: 8),
          for (final rec in summary.recommendations)
            _RecommendationTile(rec: rec),
          const SizedBox(height: 16),
        ],

        // Goal progress
        if (summary.goalProgress.isNotEmpty) ...[
          Text('Goal Progress', style: text.titleSmall),
          const SizedBox(height: 8),
          _StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (final gp in summary.goalProgress)
                    _GoalProgressRow(data: gp),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Previous weeks link
        TextButton.icon(
          onPressed: onShowHistory,
          icon: HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18),
          label: const Text('Previous Weeks'),
        ),
        const SizedBox(height: 40),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final List<List<dynamic>> icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            HugeIcon(icon: icon, size: 20, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            Text(
              label,
              style: text.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ComparisonCard extends StatelessWidget {
  final Map<String, dynamic> comparison;
  const _ComparisonCard({required this.comparison});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return _StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('vs. Previous Week', style: text.titleSmall),
            const SizedBox(height: 12),
            for (final entry in comparison.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_prettify(entry.key),
                          style: text.bodySmall),
                    ),
                    _DeltaChip(value: entry.value),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DeltaChip extends StatelessWidget {
  final dynamic value;
  const _DeltaChip({required this.value});

  @override
  Widget build(BuildContext context) {
    final num v = value is num ? value : 0;
    final isPositive = v > 0;
    final color =
        isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final icon = isPositive
        ? HugeIcons.strokeRoundedArrowUp01
        : HugeIcons.strokeRoundedArrowDown01;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 14, color: color),
        const SizedBox(width: 2),
        Text(
          v is double ? v.toStringAsFixed(1) : v.toString(),
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatefulWidget {
  final GoalInsight insight;
  const _InsightCard({required this.insight});

  @override
  State<_InsightCard> createState() => _InsightCardState();
}

class _InsightCardState extends State<_InsightCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final confidence = widget.insight.confidence;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _StyledCard(
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => setState(() => _expanded = !_expanded),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedBulb,
                        size: 18, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(widget.insight.title,
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ),
                    if (confidence > 0)
                      _ConfidenceDot(confidence: confidence),
                    HugeIcon(
                      icon: _expanded
                          ? HugeIcons.strokeRoundedArrowUp01
                          : HugeIcons.strokeRoundedArrowDown01,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ],
                ),
                if (_expanded) ...[
                  const SizedBox(height: 8),
                  Text(
                    widget.insight.body,
                    style: text.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfidenceDot extends StatelessWidget {
  final double confidence;
  const _ConfidenceDot({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final color = confidence > 0.7
        ? const Color(0xFF10B981)
        : confidence > 0.4
            ? const Color(0xFFF59E0B)
            : const Color(0xFFEF4444);

    return Tooltip(
      message: 'Confidence: ${(confidence * 100).round()}%',
      child: Container(
        width: 8,
        height: 8,
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}

class _RecommendationTile extends StatelessWidget {
  final Map<String, dynamic> rec;
  const _RecommendationTile({required this.rec});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final priority = rec['priority']?.toString() ?? 'medium';
    final color = priority == 'high'
        ? const Color(0xFFEF4444)
        : priority == 'medium'
            ? const Color(0xFFF59E0B)
            : theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _StyledCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  rec['text']?.toString() ??
                      rec['description']?.toString() ??
                      rec.toString(),
                  style: text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalProgressRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _GoalProgressRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final pct =
        ((data['progress_pct'] as num?)?.toDouble() ?? 0) / 100;
    final label = data['label']?.toString() ?? data['goal_type']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: text.bodySmall)),
              Text('${(pct * 100).round()}%',
                  style: text.labelSmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withAlpha(80),
              valueColor:
                  AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Weekly History View ──────────────────────────────────────────────────────

class _WeeklyHistoryView extends ConsumerWidget {
  final String personId;
  final VoidCallback onBack;

  const _WeeklyHistoryView({required this.personId, required this.onBack});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final historyAsync = ref.watch(weeklySummaryHistoryProvider(personId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
          child: Row(
            children: [
              IconButton(
                icon: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, size: 20),
                onPressed: onBack,
              ),
              Text('Previous Weeks', style: text.titleSmall),
            ],
          ),
        ),
        Expanded(
          child: historyAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: ShimmerList(itemCount: 4, itemHeight: 80),
            ),
            error: (e, _) => FriendlyError(
              error: e,
              context: 'weekly history',
              onRetry: () =>
                  ref.invalidate(weeklySummaryHistoryProvider(personId)),
            ),
            data: (weeks) {
              if (weeks.isEmpty) {
                return const EmptyState(
                  message: 'No weekly summaries yet.',
                  icon: HugeIcons.strokeRoundedClock01,
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: weeks.length,
                itemBuilder: (context, index) {
                  final w = weeks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _StyledCard(
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor:
                              _scoreColor(w.avgHealthScore).withAlpha(30),
                          child: Text(
                            w.avgHealthScore.round().toString(),
                            style: text.labelLarge?.copyWith(
                              color: _scoreColor(w.avgHealthScore),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          '${w.weekStart} - ${w.weekEnd}',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          '${w.daysLogged}/7 days logged',
                          style: text.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        trailing: HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01, size: 20),
                        onTap: () => _showWeekDetail(context, w),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _showWeekDetail(BuildContext context, WeeklySummaryData week) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollCtrl) {
          final text = Theme.of(context).textTheme;
          return ListView(
            controller: scrollCtrl,
            padding: const EdgeInsets.all(24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant
                        .withAlpha(60),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text('${week.weekStart} - ${week.weekEnd}',
                  style: text.titleLarge),
              const SizedBox(height: 16),
              if (week.summaryText.isNotEmpty) ...[
                Text(week.summaryText,
                    style: text.bodyMedium?.copyWith(height: 1.5)),
                const SizedBox(height: 16),
              ],
              _DetailTile(
                label: 'Days Logged',
                value: '${week.daysLogged}/7',
              ),
              _DetailTile(
                label: 'Avg Health Score',
                value: week.avgHealthScore.round().toString(),
              ),
              _DetailTile(
                label: 'Avg Completeness',
                value: '${week.avgCompletenessScore.round()}%',
              ),
              _DetailTile(
                label: 'Avg Daily Calories',
                value: '${week.avgDailyCalories.round()} kcal',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Shared helpers (preserved from original)
// ═════════════════════════════════════════════════════════════════════════════

Color _scoreColor(double? score) {
  if (score == null) return Colors.grey;
  if (score < 40) return const Color(0xFFEF4444);
  if (score < 70) return const Color(0xFFF59E0B);
  return const Color(0xFF10B981);
}

const _dimensionMeta = <String, ({List<List<dynamic>> icon, String label})>{
  'nutrient_adequacy': (icon: HugeIcons.strokeRoundedRestaurant01, label: 'Nutrient Adequacy'),
  'hydration': (icon: HugeIcons.strokeRoundedDroplet, label: 'Hydration'),
  'macro_balance': (icon: HugeIcons.strokeRoundedPieChart, label: 'Macro Balance'),
  'sleep': (icon: HugeIcons.strokeRoundedBed, label: 'Sleep'),
  'exercise': (icon: HugeIcons.strokeRoundedDumbbell01, label: 'Exercise'),
  'consistency': (icon: HugeIcons.strokeRoundedCalendar01, label: 'Consistency'),
  'weight_stability': (icon: HugeIcons.strokeRoundedBodyWeight, label: 'Weight Stability'),
  'vitals': (icon: HugeIcons.strokeRoundedFavourite, label: 'Vitals'),
};

String _prettify(String key) =>
    key.replaceAll('_', ' ').replaceAllMapped(
      RegExp(r'(^|\s)\w'),
      (m) => m.group(0)!.toUpperCase(),
    );

// ── Score Ring (preserved from original) ─────────────────────────────────────

class _ScoreRingSkeleton extends StatelessWidget {
  const _ScoreRingSkeleton();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: const ThemedSpinner(),
    );
  }
}

class _ScoreRingSection extends StatelessWidget {
  final HealthScore score;
  final AnimationController animation;

  const _ScoreRingSection({required this.score, required this.animation});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final overall = score.overallScore;
    final color = _scoreColor(overall);
    final pct = ((score.dataCompleteness) * 100).round();

    return Column(
      children: [
        const SizedBox(height: 16),
        SizedBox(
          width: 200,
          height: 200,
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _RingPainter(
                  progress: (overall ?? 0) / 100 * animation.value,
                  color: color,
                  trackColor:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                ),
                child: child,
              );
            },
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    overall != null ? overall.round().toString() : '--',
                    style: text.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                      fontSize: 48,
                    ),
                  ),
                  Text(
                    'out of 100',
                    style: text.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest.withAlpha(60),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: 6),
              Text(
                'Data: $pct% complete',
                style: text.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;

  _RingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 12;
    const strokeWidth = 14.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final arcPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: 3 * math.pi / 2,
          colors: [color.withAlpha(180), color],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        arcPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

// ── Dimension Breakdown (preserved) ──────────────────────────────────────────

class _DimensionBreakdown extends StatelessWidget {
  final Map<String, DimensionScore> dimensions;
  const _DimensionBreakdown({required this.dimensions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    final orderedKeys = <String>[
      for (final k in _dimensionMeta.keys)
        if (dimensions.containsKey(k)) k,
      for (final k in dimensions.keys)
        if (!_dimensionMeta.containsKey(k)) k,
    ];

    if (orderedKeys.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Dimensions', style: text.titleMedium),
          const SizedBox(height: 12),
          const EmptyState(
            message:
                'No dimension data yet.\nLog more health data to see your scores.',
            icon: HugeIcons.strokeRoundedIdea01,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Dimensions', style: text.titleMedium),
        const SizedBox(height: 12),
        _StyledCard(
          child: Column(
            children: [
              for (var i = 0; i < orderedKeys.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    color: theme.dividerColor.withAlpha(30),
                  ),
                _DimensionRow(
                  dimensionKey: orderedKeys[i],
                  dim: dimensions[orderedKeys[i]]!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final String dimensionKey;
  final DimensionScore dim;

  const _DimensionRow({required this.dimensionKey, required this.dim});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final meta = _dimensionMeta[dimensionKey];
    final icon = meta?.icon ?? HugeIcons.strokeRoundedMenu01;
    final label = meta?.label ?? _prettify(dimensionKey);
    final score = dim.score;
    final color = _scoreColor(score);

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showDimensionDetail(context, label, dim),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            HugeIcon(icon: icon, size: 20, color: color),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: Text(label, style: text.bodyMedium),
            ),
            Expanded(
              flex: 4,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: ((score ?? 0) / 100).clamp(0.0, 1.0),
                  minHeight: 8,
                  backgroundColor:
                      theme.colorScheme.surfaceContainerHighest.withAlpha(80),
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 34,
              child: Text(
                score != null ? score.round().toString() : '--',
                textAlign: TextAlign.right,
                style: text.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDimensionDetail(
      BuildContext context, String label, DimensionScore dim) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final color = _scoreColor(dim.score);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.45,
        minChildSize: 0.3,
        maxChildSize: 0.7,
        expand: false,
        builder: (context, scrollCtrl) => ListView(
          controller: scrollCtrl,
          padding: const EdgeInsets.all(24),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withAlpha(60),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(label, style: text.titleLarge),
            const SizedBox(height: 16),
            Row(
              children: [
                Text(
                  dim.score != null ? dim.score!.round().toString() : '--',
                  style: text.displaySmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(width: 8),
                Text('/ 100', style: text.titleMedium),
              ],
            ),
            const SizedBox(height: 12),
            _DetailTile(
              label: 'Data Quality',
              value: dim.dataQuality.toUpperCase(),
            ),
            _DetailTile(
              label: 'Raw Points',
              value: dim.rawPoints != null
                  ? '${dim.rawPoints!.toStringAsFixed(1)} / ${dim.maxPoints.toStringAsFixed(0)}'
                  : '--',
            ),
            if (dim.detail.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('Details', style: text.titleSmall),
              const SizedBox(height: 8),
              for (final entry in dim.detail.entries)
                _DetailTile(
                  label: _prettify(entry.key),
                  value: entry.value.toString(),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  final String label;
  final String value;

  const _DetailTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text.bodyMedium),
          Text(value,
              style:
                  text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Alerts Section (preserved) ───────────────────────────────────────────────

class _AlertsSection extends ConsumerWidget {
  final List<HealthAlert> alerts;
  final String personId;

  const _AlertsSection({required this.alerts, required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final active = alerts.where((a) => !a.isDismissed).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Alerts', style: text.titleMedium),
            if (active.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: theme.colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${active.length}',
                  style: text.labelSmall
                      ?.copyWith(color: theme.colorScheme.onError),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        if (active.isEmpty)
          _StyledCard(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      color: Color(0xFF10B981), size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      'No active alerts. Keep up the good work!',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ...active.map((alert) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _AlertCard(alert: alert, personId: personId),
              )),
      ],
    );
  }
}

class _AlertCard extends ConsumerStatefulWidget {
  final HealthAlert alert;
  final String personId;

  const _AlertCard({required this.alert, required this.personId});

  @override
  ConsumerState<_AlertCard> createState() => _AlertCardState();
}

class _AlertCardState extends ConsumerState<_AlertCard> {
  bool _expanded = false;
  bool _dismissing = false;

  Color get _severityColor {
    switch (widget.alert.alertType.toLowerCase()) {
      case 'critical':
        return const Color(0xFFEF4444);
      case 'warning':
        return const Color(0xFFF59E0B);
      default:
        return const Color(0xFF10B981);
    }
  }

  Future<void> _dismiss() async {
    setState(() => _dismissing = true);
    try {
      await apiClient.dio.put(
        ApiConstants.healthAlertDismiss(widget.alert.id),
      );
      ref.invalidate(healthAlertsProvider(widget.personId));
    } catch (_) {
      if (mounted) setState(() => _dismissing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final alert = widget.alert;

    return _StyledCard(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: _severityColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            alert.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                        ),
                        if (!_dismissing)
                          IconButton(
                            icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 18),
                            onPressed: _dismiss,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Dismiss',
                          )
                        else
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _Chip(
                            label: alert.category,
                            color: theme.colorScheme.primary),
                        _Chip(label: alert.alertType, color: _severityColor),
                      ],
                    ),
                    if (alert.recommendation != null &&
                        alert.recommendation!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () =>
                            setState(() => _expanded = !_expanded),
                        child: Row(
                          children: [
                            HugeIcon(
                              icon: _expanded
                                  ? HugeIcons.strokeRoundedArrowUp01
                                  : HugeIcons.strokeRoundedArrowDown01,
                              size: 18,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Recommendation',
                              style: text.labelMedium?.copyWith(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_expanded) ...[
                        const SizedBox(height: 6),
                        Text(
                          alert.recommendation!,
                          style: text.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}

// ── Score Trend (preserved) ──────────────────────────────────────────────────

class _ScoreTrendSection extends StatelessWidget {
  final List<ScoreHistoryEntry> history;

  const _ScoreTrendSection({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    String direction = 'stable';
    List<List<dynamic>> directionIcon = HugeIcons.strokeRoundedMinusSign;
    Color directionColor = const Color(0xFFF59E0B);

    if (history.length >= 2) {
      final recent = history
          .take((history.length / 3).ceil().clamp(1, 10))
          .where((e) => e.overallScore != null)
          .map((e) => e.overallScore!)
          .toList();
      final older = history
          .skip(history.length ~/ 2)
          .where((e) => e.overallScore != null)
          .map((e) => e.overallScore!)
          .toList();

      if (recent.isNotEmpty && older.isNotEmpty) {
        final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
        final olderAvg = older.reduce((a, b) => a + b) / older.length;
        if (recentAvg - olderAvg > 3) {
          direction = 'improving';
          directionIcon = HugeIcons.strokeRoundedChartIncrease;
          directionColor = const Color(0xFF10B981);
        } else if (olderAvg - recentAvg > 3) {
          direction = 'declining';
          directionIcon = HugeIcons.strokeRoundedChartDecrease;
          directionColor = const Color(0xFFEF4444);
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('30-Day Trend', style: text.titleMedium),
            const Spacer(),
            HugeIcon(icon: directionIcon, color: directionColor, size: 20),
            const SizedBox(width: 4),
            Text(
              direction,
              style: text.labelMedium?.copyWith(
                color: directionColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _StyledCard(
          child: history.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Not enough data for trend.\nLog daily to see your chart.',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                  child: _TrendBarChart(history: history),
                ),
        ),
      ],
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  final List<ScoreHistoryEntry> history;

  const _TrendBarChart({required this.history});

  @override
  Widget build(BuildContext context) {
    final entries = history.reversed.take(30).toList().reversed.toList();
    const maxBarHeight = 100.0;

    return SizedBox(
      height: maxBarHeight + 24,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = math.max(
            2.0,
            (constraints.maxWidth - (entries.length - 1) * 2) /
                entries.length,
          );

          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < entries.length; i++) ...[
                if (i > 0) const SizedBox(width: 2),
                Tooltip(
                  message:
                      '${entries[i].date}: ${entries[i].overallScore?.round() ?? "--"}',
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: barWidth.clamp(3.0, 14.0),
                        height: entries[i].overallScore != null
                            ? (entries[i].overallScore! / 100 * maxBarHeight)
                                .clamp(2.0, maxBarHeight)
                            : 2.0,
                        decoration: BoxDecoration(
                          color: _scoreColor(entries[i].overallScore),
                          borderRadius: BorderRadius.circular(
                            barWidth > 6 ? 4 : 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ── Risk Profile Card (preserved) ────────────────────────────────────────────

class _RiskProfileCard extends StatelessWidget {
  final RiskProfile risk;

  const _RiskProfileCard({required this.risk});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    Color riskColor;
    switch (risk.riskLevel.toLowerCase()) {
      case 'high':
        riskColor = const Color(0xFFEF4444);
        break;
      case 'moderate':
        riskColor = const Color(0xFFF59E0B);
        break;
      default:
        riskColor = const Color(0xFF10B981);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Risk Assessment', style: text.titleMedium),
        const SizedBox(height: 12),
        _StyledCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: riskColor.withAlpha(25),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: riskColor.withAlpha(80)),
                  ),
                  child: Text(
                    '${risk.riskLevel.toUpperCase()} RISK',
                    style: text.labelMedium?.copyWith(
                      color: riskColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (risk.topRisks.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Top Risks',
                      style: text.titleSmall
                          ?.copyWith(color: const Color(0xFFEF4444))),
                  const SizedBox(height: 8),
                  for (final r in risk.topRisks)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedAlert02,
                              size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(r.condition,
                                    style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                Text(r.evidence,
                                    style: text.bodySmall?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
                if (risk.strengths.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('Strengths',
                      style: text.titleSmall
                          ?.copyWith(color: const Color(0xFF10B981))),
                  const SizedBox(height: 8),
                  for (final s in risk.strengths)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                              size: 16,
                              color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(s, style: text.bodyMedium)),
                        ],
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Clinical Report Button (preserved) ───────────────────────────────────────

class _ClinicalReportButton extends ConsumerWidget {
  final String personId;

  const _ClinicalReportButton({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0D9488).withAlpha(40),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => _openClinicalReport(context, ref),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedFile01,
                        color: Colors.white, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      'Generate Clinical Report',
                      style: text.titleSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _downloadPdf(context, ref),
            icon: HugeIcon(icon: HugeIcons.strokeRoundedFile01),
            label: const Text('Download PDF Report'),
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              side: BorderSide(color: theme.colorScheme.primary),
            ),
          ),
        ),
      ],
    );
  }

  void _openClinicalReport(BuildContext context, WidgetRef ref) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _ClinicalReportPreview(personId: personId),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating PDF report...')),
    );
    try {
      final params = <String, dynamic>{'period_days': 30};
      if (personId != 'self') params['family_member_id'] = personId;
      await apiClient.dio.get(
        ApiConstants.healthClinicalReportPdf,
        queryParameters: params,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('PDF report downloaded.')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
    }
  }
}

// ── Shared styled card ───────────────────────────────────────────────────────

class _StyledCard extends StatelessWidget {
  final Widget child;

  const _StyledCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Clinical Report Preview Screen (preserved)
// ═════════════════════════════════════════════════════════════════════════════

class _ClinicalReportPreview extends ConsumerWidget {
  final String personId;

  const _ClinicalReportPreview({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(clinicalReportProvider(personId));
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clinical Report'),
        actions: [
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedFile01),
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context, ref),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const ThemedSpinner(),
        error: (e, _) => Center(
          child: FriendlyError(
            error: e,
            context: 'clinical report',
            onRetry: () =>
                ref.invalidate(clinicalReportProvider(personId)),
          ),
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (report.periodStart != null && report.periodEnd != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Period: ${report.periodStart} to ${report.periodEnd}',
                  style: text.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            _ReportSection(
              title: 'Demographics',
              icon: HugeIcons.strokeRoundedUser,
              child: report.demographics.isEmpty
                  ? const Text('No demographic data.')
                  : Column(
                      children: report.demographics.entries
                          .map((e) => _DetailTile(
                                label: _prettify(e.key),
                                value: e.value.toString(),
                              ))
                          .toList(),
                    ),
            ),
            _ReportSection(
              title: 'Executive Summary',
              icon: HugeIcons.strokeRoundedNote01,
              initiallyExpanded: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text('Overall Score: ',
                          style: text.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      Text(
                        report.overallScore != null
                            ? report.overallScore!.round().toString()
                            : '--',
                        style: text.titleMedium?.copyWith(
                          color: _scoreColor(report.overallScore),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(' / 100', style: text.bodySmall),
                    ],
                  ),
                  if (report.dimensionScores.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final entry in report.dimensionScores.entries)
                      _DetailTile(
                        label: _prettify(entry.key),
                        value: entry.value is num
                            ? (entry.value as num).round().toString()
                            : entry.value.toString(),
                      ),
                  ],
                ],
              ),
            ),
            _ReportSection(
              title: 'Nutrient Analysis',
              icon: HugeIcons.strokeRoundedTestTube01,
              child: report.nutrientSummary.isEmpty
                  ? const Text('No nutrient data available.')
                  : Column(
                      children: report.nutrientSummary.entries
                          .map((e) => _DetailTile(
                                label: _prettify(e.key),
                                value: e.value.toString(),
                              ))
                          .toList(),
                    ),
            ),
            _ReportSection(
              title: 'Risk Assessment',
              icon: HugeIcons.strokeRoundedShield01,
              child: report.riskFlags.isEmpty
                  ? const Text('No risk flags identified.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: report.riskFlags.map((flag) {
                        final level =
                            flag['level']?.toString() ?? 'info';
                        final color = level == 'high'
                            ? const Color(0xFFEF4444)
                            : level == 'moderate'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              HugeIcon(icon: HugeIcons.strokeRoundedFlag01,
                                  size: 16, color: color),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  flag['message']?.toString() ??
                                      flag.toString(),
                                  style: text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _ReportSection(
              title: 'Recommended Labs',
              icon: HugeIcons.strokeRoundedMicroscope,
              child: report.recommendedLabs.isEmpty
                  ? const Text('No labs recommended at this time.')
                  : Column(
                      children: report.recommendedLabs.map((lab) {
                        final priorityColor = lab.priority == 'urgent'
                            ? const Color(0xFFEF4444)
                            : lab.priority == 'important'
                                ? const Color(0xFFF59E0B)
                                : theme.colorScheme.onSurfaceVariant;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(lab.test,
                                        style: text.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600)),
                                  ),
                                  _Chip(
                                      label: lab.priority,
                                      color: priorityColor),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(lab.reason,
                                  style: text.bodySmall?.copyWith(
                                      color: theme.colorScheme
                                          .onSurfaceVariant)),
                              if (lab.normalRange.isNotEmpty)
                                Text('Normal: ${lab.normalRange}',
                                    style: text.bodySmall?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant)),
                              Text('Specialist: ${lab.specialist}',
                                  style: text.bodySmall?.copyWith(
                                      color: theme.colorScheme
                                          .onSurfaceVariant)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),
            _ReportSection(
              title: 'Questions for Your Doctor',
              icon: HugeIcons.strokeRoundedHelpCircle,
              child: report.doctorQuestions.isEmpty
                  ? const Text('No questions generated.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var i = 0;
                            i < report.doctorQuestions.length;
                            i++)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${i + 1}.',
                                  style: text.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                      report.doctorQuestions[i],
                                      style: text.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0D9488), Color(0xFF14B8A6)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => _downloadPdf(context, ref),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedFile01,
                            color: Colors.white),
                        const SizedBox(width: 12),
                        Text(
                          'Download PDF',
                          style: text.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Future<void> _downloadPdf(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Generating PDF report...')),
    );
    try {
      final params = <String, dynamic>{'period_days': 30};
      if (personId != 'self') params['family_member_id'] = personId;
      await apiClient.dio.get(
        ApiConstants.healthClinicalReportPdf,
        queryParameters: params,
      );
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(content: Text('PDF report downloaded.')),
        );
    } catch (e) {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('Failed to download PDF: $e')),
        );
    }
  }
}

class _ReportSection extends StatelessWidget {
  final String title;
  final List<List<dynamic>> icon;
  final Widget child;
  final bool initiallyExpanded;

  const _ReportSection({
    required this.title,
    required this.icon,
    required this.child,
    this.initiallyExpanded = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _StyledCard(
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            initiallyExpanded: initiallyExpanded,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading:
                HugeIcon(icon: icon, color: theme.colorScheme.primary, size: 22),
            title: Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            children: [child],
          ),
        ),
      ),
    );
  }
}
