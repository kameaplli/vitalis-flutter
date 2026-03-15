import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/health_intelligence.dart';
import '../providers/health_intelligence_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/shimmer_placeholder.dart';
import '../widgets/friendly_error.dart';

// ── Health Intelligence Screen ──────────────────────────────────────────────

class HealthIntelligenceScreen extends ConsumerStatefulWidget {
  const HealthIntelligenceScreen({super.key});

  @override
  ConsumerState<HealthIntelligenceScreen> createState() =>
      _HealthIntelligenceScreenState();
}

class _HealthIntelligenceScreenState
    extends ConsumerState<HealthIntelligenceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ringAnimCtrl;

  @override
  void initState() {
    super.initState();
    _ringAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _ringAnimCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    final personId = ref.read(selectedPersonProvider);
    ref.invalidate(dailyHealthScoreProvider(personId));
    ref.invalidate(healthAlertsProvider(personId));
    ref.invalidate(riskProfileProvider(personId));
    ref.invalidate(scoreHistoryProvider(personId));
    _ringAnimCtrl
      ..reset()
      ..forward();
  }

  @override
  Widget build(BuildContext context) {
    final personId = ref.watch(selectedPersonProvider);
    final scoreAsync = ref.watch(dailyHealthScoreProvider(personId));
    final alertsAsync = ref.watch(healthAlertsProvider(personId));
    final riskAsync = ref.watch(riskProfileProvider(personId));
    final historyAsync = ref.watch(scoreHistoryProvider(personId));

    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── 1. App Bar ──────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            title: Text('Health Score', style: text.titleLarge),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () => Navigator.of(context).pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Recompute score',
                onPressed: _refresh,
              ),
            ],
          ),

          // ── Body ────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 8),

                // ── 2. Score Ring ──────────────────────────────────────
                scoreAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const _ScoreRingSkeleton(),
                  error: (e, _) => FriendlyError(
                    error: e,
                    context: 'health score',
                    onRetry: _refresh,
                  ),
                  data: (score) => _ScoreRingSection(
                    score: score,
                    animation: _ringAnimCtrl,
                  ),
                ),

                const SizedBox(height: 24),

                // ── 3. Dimension Breakdown ────────────────────────────
                scoreAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const ShimmerList(itemCount: 8, itemHeight: 48),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (score) =>
                      _DimensionBreakdown(dimensions: score.dimensions),
                ),

                const SizedBox(height: 24),

                // ── 4. Alerts ─────────────────────────────────────────
                alertsAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const ShimmerList(itemCount: 3, itemHeight: 80),
                  error: (e, _) => FriendlyError(
                    error: e,
                    context: 'alerts',
                    onRetry: _refresh,
                  ),
                  data: (alerts) => _AlertsSection(
                    alerts: alerts,
                    personId: personId,
                  ),
                ),

                const SizedBox(height: 24),

                // ── 5. Score Trend ────────────────────────────────────
                historyAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const ShimmerList(itemCount: 1, itemHeight: 160),
                  error: (e, _) => FriendlyError(
                    error: e,
                    context: 'score history',
                    onRetry: _refresh,
                  ),
                  data: (history) => _ScoreTrendSection(history: history),
                ),

                const SizedBox(height: 24),

                // ── 6. Risk Profile ───────────────────────────────────
                riskAsync.when(
                  skipLoadingOnReload: true,
                  loading: () =>
                      const ShimmerList(itemCount: 1, itemHeight: 120),
                  error: (e, _) => FriendlyError(
                    error: e,
                    context: 'risk profile',
                    onRetry: _refresh,
                  ),
                  data: (risk) => _RiskProfileCard(risk: risk),
                ),

                const SizedBox(height: 24),

                // ── 7. Clinical Report Button ─────────────────────────
                _ClinicalReportButton(personId: personId),

                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────────────

Color _scoreColor(double? score) {
  if (score == null) return Colors.grey;
  if (score < 40) return const Color(0xFFEF4444);
  if (score < 70) return const Color(0xFFF59E0B);
  return const Color(0xFF10B981);
}

const _dimensionMeta = <String, ({IconData icon, String label})>{
  'nutrient_adequacy': (icon: Icons.restaurant_rounded, label: 'Nutrient Adequacy'),
  'hydration': (icon: Icons.water_drop_rounded, label: 'Hydration'),
  'macro_balance': (icon: Icons.pie_chart_rounded, label: 'Macro Balance'),
  'sleep': (icon: Icons.bedtime_rounded, label: 'Sleep'),
  'exercise': (icon: Icons.fitness_center_rounded, label: 'Exercise'),
  'consistency': (icon: Icons.event_available_rounded, label: 'Consistency'),
  'weight_stability': (icon: Icons.monitor_weight_rounded, label: 'Weight Stability'),
  'vitals': (icon: Icons.favorite_rounded, label: 'Vitals'),
};

// ── 2. Score Ring ───────────────────────────────────────────────────────────

class _ScoreRingSkeleton extends StatelessWidget {
  const _ScoreRingSkeleton();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: Center(child: CircularProgressIndicator()),
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
              Icon(Icons.data_usage_rounded,
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

    // Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);

    // Progress arc
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

// ── 3. Dimension Breakdown ──────────────────────────────────────────────────

class _DimensionBreakdown extends StatelessWidget {
  final Map<String, DimensionScore> dimensions;

  const _DimensionBreakdown({required this.dimensions});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    // Stable ordering: use the keys from _dimensionMeta first, then any extras.
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
            message: 'No dimension data yet.\nLog more health data to see your scores.',
            icon: Icons.insights_rounded,
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

  const _DimensionRow({
    required this.dimensionKey,
    required this.dim,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final meta = _dimensionMeta[dimensionKey];
    final icon = meta?.icon ?? Icons.category_rounded;
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
            Icon(icon, size: 20, color: color),
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
          Text(value, style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

String _prettify(String key) =>
    key.replaceAll('_', ' ').replaceAllMapped(
      RegExp(r'(^|\s)\w'),
      (m) => m.group(0)!.toUpperCase(),
    );

// ── 4. Alerts Section ───────────────────────────────────────────────────────

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
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                  Icon(Icons.check_circle_rounded,
                      color: const Color(0xFF10B981), size: 32),
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
                            icon: const Icon(Icons.close_rounded, size: 18),
                            onPressed: _dismiss,
                            visualDensity: VisualDensity.compact,
                            tooltip: 'Dismiss',
                          )
                        else
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        _Chip(
                          label: alert.category,
                          color: theme.colorScheme.primary,
                        ),
                        _Chip(
                          label: alert.alertType,
                          color: _severityColor,
                        ),
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
                            Icon(
                              _expanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
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

// ── 5. Score Trend ──────────────────────────────────────────────────────────

class _ScoreTrendSection extends StatelessWidget {
  final List<ScoreHistoryEntry> history;

  const _ScoreTrendSection({required this.history});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    // Calculate trend direction
    String direction = 'stable';
    IconData directionIcon = Icons.trending_flat_rounded;
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
          directionIcon = Icons.trending_up_rounded;
          directionColor = const Color(0xFF10B981);
        } else if (olderAvg - recentAvg > 3) {
          direction = 'declining';
          directionIcon = Icons.trending_down_rounded;
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
            Icon(directionIcon, color: directionColor, size: 20),
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
    // Show up to 30 bars, most recent on right
    final entries = history.reversed.take(30).toList().reversed.toList();
    const maxBarHeight = 100.0;

    return SizedBox(
      height: maxBarHeight + 24, // 24 for label space
      child: LayoutBuilder(
        builder: (context, constraints) {
          final barWidth = math.max(
            2.0,
            (constraints.maxWidth - (entries.length - 1) * 2) / entries.length,
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

// ── 6. Risk Profile Card ────────────────────────────────────────────────────

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
                // Risk level chip
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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

                // Top risks
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
                          const Icon(Icons.warning_amber_rounded,
                              size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.condition,
                                    style: text.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600)),
                                Text(r.evidence,
                                    style: text.bodySmall?.copyWith(
                                        color: theme
                                            .colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                ],

                // Strengths
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
                          const Icon(Icons.check_circle_outline_rounded,
                              size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(child: Text(s, style: text.bodyMedium)),
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

// ── 7. Clinical Report Button ───────────────────────────────────────────────

class _ClinicalReportButton extends ConsumerWidget {
  final String personId;

  const _ClinicalReportButton({required this.personId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final text = theme.textTheme;

    return Column(
      children: [
        // Generate report button
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
                    const Icon(Icons.description_rounded,
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

        // Download PDF button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => _downloadPdf(context, ref),
            icon: const Icon(Icons.picture_as_pdf_rounded),
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

// ── Shared styled card ──────────────────────────────────────────────────────

class _StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const _StyledCard({required this.child, this.padding});

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
      child: padding != null ? Padding(padding: padding!, child: child) : child,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Clinical Report Preview Screen
// ═══════════════════════════════════════════════════════════════════════════════

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
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'Download PDF',
            onPressed: () => _downloadPdf(context, ref),
          ),
        ],
      ),
      body: reportAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: FriendlyError(
            error: e,
            context: 'clinical report',
            onRetry: () => ref.invalidate(clinicalReportProvider(personId)),
          ),
        ),
        data: (report) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Period
            if (report.periodStart != null && report.periodEnd != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  'Period: ${report.periodStart} to ${report.periodEnd}',
                  style: text.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),

            // Demographics
            _ReportSection(
              title: 'Demographics',
              icon: Icons.person_rounded,
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

            // Executive Summary
            _ReportSection(
              title: 'Executive Summary',
              icon: Icons.summarize_rounded,
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

            // Nutrient Analysis
            _ReportSection(
              title: 'Nutrient Analysis',
              icon: Icons.science_rounded,
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

            // Risk Assessment
            _ReportSection(
              title: 'Risk Assessment',
              icon: Icons.shield_rounded,
              child: report.riskFlags.isEmpty
                  ? const Text('No risk flags identified.')
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: report.riskFlags.map((flag) {
                        final level = flag['level']?.toString() ?? 'info';
                        final color = level == 'high'
                            ? const Color(0xFFEF4444)
                            : level == 'moderate'
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF10B981);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(Icons.flag_rounded,
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

            // Recommended Labs
            _ReportSection(
              title: 'Recommended Labs',
              icon: Icons.biotech_rounded,
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
                            crossAxisAlignment: CrossAxisAlignment.start,
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
                                      color: theme
                                          .colorScheme.onSurfaceVariant)),
                              if (lab.normalRange.isNotEmpty)
                                Text('Normal: ${lab.normalRange}',
                                    style: text.bodySmall?.copyWith(
                                        color: theme.colorScheme
                                            .onSurfaceVariant)),
                              Text('Specialist: ${lab.specialist}',
                                  style: text.bodySmall?.copyWith(
                                      color: theme
                                          .colorScheme.onSurfaceVariant)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
            ),

            // Doctor Questions
            _ReportSection(
              title: 'Questions for Your Doctor',
              icon: Icons.help_outline_rounded,
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
                              crossAxisAlignment: CrossAxisAlignment.start,
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
                                  child: Text(report.doctorQuestions[i],
                                      style: text.bodyMedium),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
            ),

            const SizedBox(height: 24),

            // Download PDF button
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
                        const Icon(Icons.picture_as_pdf_rounded,
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
  final IconData icon;
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
            childrenPadding:
                const EdgeInsets.fromLTRB(16, 0, 16, 16),
            leading: Icon(icon, color: theme.colorScheme.primary, size: 22),
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
