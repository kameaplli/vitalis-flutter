import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/friendly_error.dart';

// ── Tier Colors (kept consistent, work in both light/dark) ──────────────────

const _kOptimalColor = Color(0xFF16A34A);    // green-600
const _kSufficientColor = Color(0xFF2563EB); // blue-600
const _kSuboptimalColor = Color(0xFFD97706); // amber-600
const _kCriticalColor = Color(0xFFDC2626);   // red-600
const _kUnknownColor = Color(0xFF64748B);    // slate-500

Color _tierColor(String? tier) => switch (tier) {
      'optimal' => _kOptimalColor,
      'sufficient' => _kSufficientColor,
      'suboptimal' => _kSuboptimalColor,
      'critical' => _kCriticalColor,
      _ => _kUnknownColor,
    };

String _tierLabel(String? tier) => switch (tier) {
      'optimal' => 'OPTIMAL',
      'sufficient' => 'SUFFICIENT',
      'suboptimal' => 'NEEDS WORK',
      'critical' => 'CRITICAL',
      _ => 'UNKNOWN',
    };

IconData _pillarIcon(String pillar) => switch (pillar.toLowerCase()) {
      'cardiovascular' => Icons.favorite_rounded,
      'metabolism' => Icons.local_fire_department_rounded,
      'fitness' => Icons.fitness_center_rounded,
      'nutrients' => Icons.eco_rounded,
      'inflammation' => Icons.whatshot_rounded,
      'hormones' => Icons.psychology_rounded,
      'liver' => Icons.science_rounded,
      'kidney' => Icons.water_drop_rounded,
      'immunity' => Icons.shield_rounded,
      _ => Icons.biotech_rounded,
    };

// ── Main Screen ──────────────────────────────────────────────────────────────

class LabsDashboardScreen extends ConsumerWidget {
  const LabsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final dashAsync = ref.watch(labDashboardProvider(person));

    return Scaffold(
      body: dashAsync.when(
        loading: () => const _LoadingShimmer(),
        error: (e, st) => CustomScrollView(
          slivers: [
            _buildSliverAppBar(context),
            SliverFillRemaining(child: FriendlyError(error: e)),
          ],
        ),
        data: (dash) {
          if (dash.totalBiomarkers == 0) {
            return const _EmptyState();
          }
          return _DashboardBody(dash: dash);
        },
      ),
    );
  }
}

SliverAppBar _buildSliverAppBar(BuildContext context, {List<Widget>? actions}) {
  return SliverAppBar(
    floating: true,
    title: const Text('Blood Tests'),
    actions: actions ??
        [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.icon(
              onPressed: () => context.push('/health/labs/upload'),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Upload'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const _LabsMenuButton(),
        ],
  );
}

class _LabsMenuButton extends ConsumerWidget {
  const _LabsMenuButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert_rounded),
      onSelected: (value) async {
        if (value == 'reprocess') {
          _reprocessData(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: 'reprocess',
          child: ListTile(
            dense: true,
            leading: Icon(Icons.refresh_rounded),
            title: Text('Fix & Reprocess Data'),
            subtitle: Text('Re-classify all biomarkers', style: TextStyle(fontSize: 11)),
          ),
        ),
      ],
    );
  }

  Future<void> _reprocessData(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Reprocessing biomarker data...')),
    );
    try {
      final result = await reprocessLabResults();
      final fixed = result['fixed_results'] ?? 0;
      final total = result['total_results'] ?? 0;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Done! Fixed $fixed of $total results.')),
      );
      final person = ref.read(selectedPersonProvider);
      ref.invalidate(labDashboardProvider(person));
      ref.invalidate(labReportsProvider(person));
    } catch (e) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(content: Text('Reprocess failed: $e')),
      );
    }
  }
}

// ── Dashboard Body ───────────────────────────────────────────────────────────

class _DashboardBody extends ConsumerStatefulWidget {
  final LabDashboard dash;
  const _DashboardBody({required this.dash});

  @override
  ConsumerState<_DashboardBody> createState() => _DashboardBodyState();
}

class _DashboardBodyState extends ConsumerState<_DashboardBody> {
  final Map<String, GlobalKey> _pillarKeys = {};

  @override
  void initState() {
    super.initState();
    for (final pillar in widget.dash.pillars.keys) {
      _pillarKeys[pillar] = GlobalKey();
    }
  }

  void _scrollToPillar(String pillar) {
    final key = _pillarKeys[pillar];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.0,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final person = ref.watch(selectedPersonProvider);
    final reportsAsync = ref.watch(labReportsProvider(person));
    final insightsAsync = ref.watch(labInsightsProvider(person));
    final recsAsync = ref.watch(labRecommendationsProvider(person));

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context),

        // Panic alerts (emergency / see_doctor)
        if (widget.dash.panicValues.isNotEmpty)
          SliverToBoxAdapter(child: _PanicBanner(alerts: widget.dash.panicValues)),

        // Health score + summary
        SliverToBoxAdapter(child: _ScoreSection(dash: widget.dash)),

        // Tier breakdown bar
        SliverToBoxAdapter(child: _TierBreakdownBar(dash: widget.dash)),

        // Attention Needed section
        if (widget.dash.attentionNeeded.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          SliverToBoxAdapter(child: _SectionHeader('ATTENTION NEEDED')),
          SliverToBoxAdapter(
            child: _HorizontalResultCards(
              results: widget.dash.attentionNeeded,
              accentColor: _kCriticalColor,
              icon: Icons.warning_amber_rounded,
            ),
          ),
        ],

        // Improvements section
        if (widget.dash.improvements.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          SliverToBoxAdapter(child: _SectionHeader('IMPROVING')),
          SliverToBoxAdapter(
            child: _HorizontalResultCards(
              results: widget.dash.improvements,
              accentColor: _kOptimalColor,
              icon: Icons.trending_up_rounded,
            ),
          ),
        ],

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // Insights (cross-biomarker correlations)
        SliverToBoxAdapter(
          child: insightsAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (insights) {
              final active = insights.where((i) => !i.isDismissed).toList();
              if (active.isEmpty) return const SizedBox();
              return _InsightsSection(insights: active);
            },
          ),
        ),

        // Health pillar cards
        SliverToBoxAdapter(child: _SectionHeader('HEALTH PILLARS')),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 130,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.dash.pillars.length,
              itemBuilder: (context, i) {
                final pillar = widget.dash.pillars.keys.elementAt(i);
                final summary = widget.dash.pillars[pillar]!;
                return _PillarCard(
                  pillar: pillar,
                  summary: summary,
                  score: widget.dash.pillarScores?[pillar],
                  onTap: () => _scrollToPillar(pillar),
                );
              },
            ),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // Biomarkers by pillar
        for (final entry in widget.dash.pillars.entries) ...[
          SliverToBoxAdapter(
            child: _PillarHeader(
              key: _pillarKeys[entry.key],
              pillar: entry.key,
              summary: entry.value,
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BiomarkerCard(
                  result: entry.value.results[i],
                  isLast: i == entry.value.results.length - 1),
              childCount: entry.value.results.length,
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],

        // Recommendations
        SliverToBoxAdapter(
          child: recsAsync.when(
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
            data: (recs) {
              if (recs.isEmpty) return const SizedBox();
              return _RecommendationsSection(recommendations: recs);
            },
          ),
        ),

        // Recent reports
        SliverToBoxAdapter(child: _SectionHeader('RECENT REPORTS')),
        SliverToBoxAdapter(
          child: reportsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(20),
              child: Text('Could not load reports',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ),
            data: (reports) => _ReportsSection(reports: reports),
          ),
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 40)),
      ],
    );
  }
}

// ── Panic Alert Banner ──────────────────────────────────────────────────────

class _PanicBanner extends StatelessWidget {
  final List<PanicAlert> alerts;
  const _PanicBanner({required this.alerts});

  @override
  Widget build(BuildContext context) {
    final emergencies = alerts.where((a) => a.severity == 'emergency').toList();
    final seeDoctor = alerts.where((a) => a.severity == 'see_doctor').toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        children: [
          for (final alert in emergencies)
            _AlertCard(
              alert: alert,
              borderColor: _kCriticalColor,
              icon: Icons.emergency_rounded,
              iconColor: _kCriticalColor,
              label: 'EMERGENCY',
            ),
          for (final alert in seeDoctor)
            _AlertCard(
              alert: alert,
              borderColor: _kSuboptimalColor,
              icon: Icons.local_hospital_rounded,
              iconColor: _kSuboptimalColor,
              label: 'SEE DOCTOR',
            ),
        ],
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  final PanicAlert alert;
  final Color borderColor;
  final IconData icon;
  final Color iconColor;
  final String label;

  const _AlertCard({
    required this.alert,
    required this.borderColor,
    required this.icon,
    required this.iconColor,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: borderColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.4), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.15),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: iconColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                    const SizedBox(width: 8),
                    Text('${alert.name} (${alert.code})',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(alert.message,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.8),
                        fontSize: 12,
                        height: 1.3)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: cs.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(text,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.5)),
        ],
      ),
    );
  }
}

// ── Horizontal Result Cards (Attention / Improvements) ──────────────────────

class _HorizontalResultCards extends StatelessWidget {
  final List<LabResult> results;
  final Color accentColor;
  final IconData icon;
  const _HorizontalResultCards({
    required this.results,
    required this.accentColor,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 90,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: results.length,
        itemBuilder: (context, i) {
          final r = results[i];
          final tierColor = _tierColor(r.tier);
          return GestureDetector(
            onTap: () {
              final code = r.biomarkerCode ?? '';
              if (code.isNotEmpty) context.push('/health/labs/biomarker/$code');
            },
            child: Container(
              width: 160,
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(icon, color: accentColor, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(r.biomarkerName ?? r.biomarkerCode ?? '',
                            style: TextStyle(
                                color: cs.onSurface,
                                fontSize: 12,
                                fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(_formatValue(r.value),
                          style: TextStyle(
                              color: tierColor,
                              fontSize: 20,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(r.unit ?? '',
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 10)),
                      ),
                      const Spacer(),
                      if (r.trendDirection != null && r.trendDirection != 'new')
                        _TrendArrow(
                          direction: r.trendDirection!,
                          isImproving: r.isImproving,
                          size: 18,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Trend Arrow Widget ──────────────────────────────────────────────────────

class _TrendArrow extends StatelessWidget {
  final String direction; // rising, falling, stable, new
  final bool? isImproving;
  final double size;
  const _TrendArrow({required this.direction, this.isImproving, this.size = 16});

  @override
  Widget build(BuildContext context) {
    final IconData icon;
    final Color color;

    switch (direction) {
      case 'rising':
        icon = Icons.trending_up_rounded;
        color = isImproving == true ? _kOptimalColor : _kCriticalColor;
        break;
      case 'falling':
        icon = Icons.trending_down_rounded;
        color = isImproving == true ? _kOptimalColor : _kCriticalColor;
        break;
      case 'stable':
        icon = Icons.trending_flat_rounded;
        color = _kSufficientColor;
        break;
      default:
        return const SizedBox.shrink();
    }

    return Icon(icon, color: color, size: size);
  }
}

// ── Insights Section ────────────────────────────────────────────────────────

class _InsightsSection extends ConsumerWidget {
  final List<BiomarkerInsightModel> insights;
  const _InsightsSection({required this.insights});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('INSIGHTS'),
          for (final insight in insights)
            _InsightCard(insight: insight, ref: ref),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final BiomarkerInsightModel insight;
  final WidgetRef ref;
  const _InsightCard({required this.insight, required this.ref});

  Color _severityColor() => switch (insight.severity) {
        'critical' => _kCriticalColor,
        'warning' => _kSuboptimalColor,
        'info' => _kSufficientColor,
        _ => _kUnknownColor,
      };

  IconData _severityIcon() => switch (insight.severity) {
        'critical' => Icons.error_rounded,
        'warning' => Icons.warning_amber_rounded,
        'info' => Icons.lightbulb_rounded,
        _ => Icons.info_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = _severityColor();

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_severityIcon(), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(insight.title,
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              if (insight.evidenceGrade != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(insight.evidenceGrade!.toUpperCase(),
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () async {
                  await dismissInsight(insight.id);
                  final person = ref.read(selectedPersonProvider);
                  ref.invalidate(labInsightsProvider(person));
                },
                child: Icon(Icons.close_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(insight.body,
              style: TextStyle(
                  color: cs.onSurfaceVariant,
                  fontSize: 13,
                  height: 1.4)),
          if (insight.biomarkerCodes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: insight.biomarkerCodes
                  .map((code) => GestureDetector(
                        onTap: () => context.push('/health/labs/biomarker/$code'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: cs.primaryContainer.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(code,
                              style: TextStyle(
                                  color: cs.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recommendations Section ──────────────────────────────────────────────────

class _RecommendationsSection extends StatelessWidget {
  final List<BiomarkerRecommendation> recommendations;
  const _RecommendationsSection({required this.recommendations});

  IconData _categoryIcon(String category) => switch (category) {
        'diet' => Icons.restaurant_rounded,
        'supplement' => Icons.medication_rounded,
        'lifestyle' => Icons.self_improvement_rounded,
        'exercise' => Icons.fitness_center_rounded,
        'medical' => Icons.local_hospital_rounded,
        _ => Icons.lightbulb_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader('RECOMMENDATIONS'),
          for (final rec in recommendations.take(6))
            Container(
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cs.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(_categoryIcon(rec.category),
                        color: cs.primary, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(rec.title,
                                  style: TextStyle(
                                      color: cs.onSurface,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                            ),
                            if (rec.impactScore != null)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _kOptimalColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    'Impact ${(rec.impactScore! * 10).round()}/10',
                                    style: const TextStyle(
                                        color: _kOptimalColor,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700)),
                              ),
                          ],
                        ),
                        if (rec.description != null) ...[
                          const SizedBox(height: 4),
                          Text(rec.description!,
                              style: TextStyle(
                                  color: cs.onSurfaceVariant,
                                  fontSize: 12,
                                  height: 1.4),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: cs.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(rec.category.toUpperCase(),
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5)),
                            ),
                            const SizedBox(width: 6),
                            Text(rec.biomarkerCode,
                                style: TextStyle(
                                    color: cs.primary,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600)),
                            if (rec.evidenceGrade != null) ...[
                              const SizedBox(width: 6),
                              Text(rec.evidenceGrade!,
                                  style: TextStyle(
                                      color: cs.onSurfaceVariant,
                                      fontSize: 10)),
                            ],
                          ],
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

// ── Reports Section ──────────────────────────────────────────────────────────

class _ReportsSection extends ConsumerWidget {
  final List<LabReport> reports;
  const _ReportsSection({required this.reports});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (reports.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Text('No reports uploaded yet',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        for (int i = 0; i < reports.length; i++)
          _ReportTile(report: reports[i], ref: ref),
      ],
    );
  }
}

class _ReportTile extends StatelessWidget {
  final LabReport report;
  final WidgetRef ref;
  const _ReportTile({required this.report, required this.ref});

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Report?'),
        content: Text(
          'This will permanently delete the ${report.labProvider ?? "lab"} report'
          '${report.testDate != null ? " from ${report.testDate}" : ""}'
          ' and all its results.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete',
                style: TextStyle(color: _kCriticalColor, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _deleteReport(BuildContext context) async {
    try {
      await apiClient.dio.delete(ApiConstants.labReport(report.id));
      final person = ref.read(selectedPersonProvider);
      ref.invalidate(labDashboardProvider(person));
      ref.invalidate(labReportsProvider(person));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report deleted')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: _kCriticalColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Dismissible(
      key: ValueKey(report.id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => _deleteReport(context),
      background: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        decoration: BoxDecoration(
          color: _kCriticalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Delete',
                style: TextStyle(
                    color: _kCriticalColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(width: 8),
            Icon(Icons.delete_rounded, color: _kCriticalColor, size: 22),
          ],
        ),
      ),
      child: Card(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.description_rounded,
                color: cs.onPrimaryContainer, size: 20),
          ),
          title: Text(report.labProvider ?? 'Lab Report',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          subtitle: Row(
            children: [
              Text(report.testDate ?? '',
                  style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
              if (report.parseMethod != null) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(report.parseMethod!.toUpperCase(),
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5)),
                ),
              ],
            ],
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: (report.results.isEmpty ? _kCriticalColor : _kOptimalColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${report.results.length} results',
              style: TextStyle(
                color: report.results.isEmpty ? _kCriticalColor : _kOptimalColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Score Section ────────────────────────────────────────────────────────────

class _ScoreSection extends StatelessWidget {
  final LabDashboard dash;
  const _ScoreSection({required this.dash});

  @override
  Widget build(BuildContext context) {
    final total = dash.totalBiomarkers;
    final optimalPercent = total > 0 ? dash.optimalCount / total : 0.0;
    final cs = Theme.of(context).colorScheme;
    final hasScore = dash.healthScore != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          // Score ring
          SizedBox(
            width: 100,
            height: 100,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                optimalPercent: optimalPercent,
                sufficientPercent: total > 0 ? dash.sufficientCount / total : 0,
                suboptimalPercent: total > 0 ? dash.suboptimalCount / total : 0,
                criticalPercent: total > 0 ? dash.criticalCount / total : 0,
                bgColor: cs.surfaceContainerHighest,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (hasScore) ...[
                      Text('${dash.healthScore!.round()}',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 26,
                              fontWeight: FontWeight.w800)),
                      Text('Health',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 10,
                              fontWeight: FontWeight.w500)),
                    ] else ...[
                      Text('${(optimalPercent * 100).round()}%',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 24,
                              fontWeight: FontWeight.w800)),
                      Text('Optimal',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          // Summary text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$total Biomarkers Tracked',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (hasScore)
                  Text('${(optimalPercent * 100).round()}% in optimal range',
                      style: TextStyle(
                          color: _kOptimalColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                if (dash.previousOptimalPercent != null) ...[
                  const SizedBox(height: 2),
                  _OptimalTrendChip(
                    current: optimalPercent,
                    previous: dash.previousOptimalPercent!,
                  ),
                ],
                if (dash.latestReportDate != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('Latest: ${dash.latestReportDate}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 12)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OptimalTrendChip extends StatelessWidget {
  final double current;
  final double previous;
  const _OptimalTrendChip({required this.current, required this.previous});

  @override
  Widget build(BuildContext context) {
    if (previous.abs() < 0.0001) return const SizedBox.shrink(); // avoid division by zero
    final pctChange = ((current - previous) / previous) * 100;
    if (pctChange.abs() < 0.5) return const SizedBox.shrink(); // <0.5% is noise

    final isUp = pctChange > 0;
    final color = isUp ? _kOptimalColor : _kCriticalColor;
    final icon = isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded;
    final displayPct = pctChange.abs().round().clamp(0, 999); // cap display at 999%

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        Text('$displayPct% vs previous',
            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

// ── Tier Breakdown Bar ───────────────────────────────────────────────────────

class _TierBreakdownBar extends StatelessWidget {
  final LabDashboard dash;
  const _TierBreakdownBar({required this.dash});

  @override
  Widget build(BuildContext context) {
    final total = dash.totalBiomarkers;
    if (total == 0) return const SizedBox();

    final cs = Theme.of(context).colorScheme;
    final segments = [
      (dash.optimalCount, _kOptimalColor, 'Optimal'),
      (dash.sufficientCount, _kSufficientColor, 'Sufficient'),
      (dash.suboptimalCount, _kSuboptimalColor, 'Needs Work'),
      (dash.criticalCount, _kCriticalColor, 'Critical'),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 10,
              child: Row(
                children: [
                  for (final (count, color, _) in segments)
                    if (count > 0)
                      Expanded(
                        flex: count,
                        child: Container(color: color),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: [
              for (final (count, color, label) in segments)
                if (count > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text('$count $label',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Pillar Card ──────────────────────────────────────────────────────────────

class _PillarCard extends StatelessWidget {
  final String pillar;
  final PillarSummary summary;
  final double? score;
  final VoidCallback onTap;
  const _PillarCard({
    required this.pillar,
    required this.summary,
    this.score,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierColor = _tierColor(summary.status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(_pillarIcon(pillar), color: tierColor, size: 18),
                ),
                if (score != null) ...[
                  const Spacer(),
                  Text('${score!.round()}',
                      style: TextStyle(
                          color: tierColor,
                          fontSize: 16,
                          fontWeight: FontWeight.w800)),
                ],
              ],
            ),
            const Spacer(),
            Text(pillar,
                style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${summary.biomarkerCount} markers',
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                    maxLines: 1,
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

// ── Pillar Header ────────────────────────────────────────────────────────────

class _PillarHeader extends StatelessWidget {
  final String pillar;
  final PillarSummary summary;
  const _PillarHeader({super.key, required this.pillar, required this.summary});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierColor = _tierColor(summary.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(_pillarIcon(pillar), color: tierColor, size: 22),
          const SizedBox(width: 10),
          Text(pillar,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_tierLabel(summary.status),
                style: TextStyle(
                    color: tierColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8)),
          ),
        ],
      ),
    );
  }
}

// ── Biomarker Card ───────────────────────────────────────────────────────────

class _BiomarkerCard extends StatelessWidget {
  final LabResult result;
  final bool isLast;
  const _BiomarkerCard({required this.result, this.isLast = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierColor = _tierColor(result.tier);
    final code = result.biomarkerCode ?? '';

    // Urgency border for critical/suboptimal
    final borderColor = result.tier == 'critical'
        ? _kCriticalColor.withValues(alpha: 0.4)
        : result.tier == 'suboptimal'
            ? _kSuboptimalColor.withValues(alpha: 0.3)
            : cs.outlineVariant.withValues(alpha: 0.2);

    return GestureDetector(
      onTap: () {
        if (code.isNotEmpty) {
          context.push('/health/labs/biomarker/$code');
        }
      },
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cs.surfaceContainerLow,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: result.tier == 'critical' ? 1.5 : 1),
        ),
        child: Column(
          children: [
            Row(
              children: [
                // Tier indicator dot
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tierColor,
                  ),
                ),
                const SizedBox(width: 10),
                // Name + tier + trend
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(result.biomarkerName ?? code,
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Text(_tierLabel(result.tier),
                              style: TextStyle(
                                  color: tierColor,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5)),
                          if (result.trendDirection != null &&
                              result.trendDirection != 'new') ...[
                            const SizedBox(width: 6),
                            _TrendArrow(
                              direction: result.trendDirection!,
                              isImproving: result.isImproving,
                              size: 14,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                // Value + unit + previous
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatValue(result.value),
                        style: TextStyle(
                            color: tierColor,
                            fontSize: 20,
                            fontWeight: FontWeight.w800)),
                    Text(result.unit ?? '',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 10,
                            fontWeight: FontWeight.w500)),
                    // Previous value comparison
                    if (result.previousValue != null)
                      _PreviousValueChip(
                        current: result.value,
                        previous: result.previousValue!,
                        isImproving: result.isImproving,
                      ),
                  ],
                ),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 20),
              ],
            ),
            // Range bar
            const SizedBox(height: 10),
            _WhoopRangeBar(result: result),
          ],
        ),
      ),
    );
  }
}

class _PreviousValueChip extends StatelessWidget {
  final double current;
  final double previous;
  final bool? isImproving;
  const _PreviousValueChip({
    required this.current,
    required this.previous,
    this.isImproving,
  });

  @override
  Widget build(BuildContext context) {
    final diff = current - previous;
    if (diff.abs() < 0.001) return const SizedBox.shrink();

    final isUp = diff > 0;
    final color = isImproving == true
        ? _kOptimalColor
        : isImproving == false
            ? _kCriticalColor
            : _kUnknownColor;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            color: color,
            size: 10,
          ),
          Text(
            _formatValue(diff.abs()),
            style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Range Bar (compact, for card) ────────────────────────────────────────────

class _WhoopRangeBar extends StatelessWidget {
  final LabResult result;
  const _WhoopRangeBar({required this.result});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 14,
      child: LayoutBuilder(builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        double position = 0.5;

        if (result.referenceLow != null && result.referenceHigh != null) {
          final low = result.referenceLow!;
          final high = result.referenceHigh!;
          final range = high - low;
          if (range > 0) {
            final normalized = (result.value - low) / range;
            position = 0.15 + normalized * 0.7;
            position = position.clamp(0.02, 0.98);
          }
        }

        final markerX = position * barWidth;
        final tierColor = _tierColor(result.tier);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 3,
              height: 6,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: CustomPaint(
                  painter: _GradientBarPainter(),
                ),
              ),
            ),
            Positioned(
              left: markerX - 5,
              top: 1,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tierColor,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.4),
                      blurRadius: 4,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }),
    );
  }
}

// ── Gradient Bar Painter ─────────────────────────────────────────────────────

class _GradientBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        _kCriticalColor.withValues(alpha: 0.35),
        _kSuboptimalColor.withValues(alpha: 0.30),
        _kSufficientColor.withValues(alpha: 0.25),
        _kOptimalColor.withValues(alpha: 0.35),
        _kOptimalColor.withValues(alpha: 0.35),
        _kSufficientColor.withValues(alpha: 0.25),
        _kSuboptimalColor.withValues(alpha: 0.30),
        _kCriticalColor.withValues(alpha: 0.35),
      ],
      stops: const [0.0, 0.15, 0.25, 0.4, 0.6, 0.75, 0.85, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(3));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── Score Ring Painter ────────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double optimalPercent;
  final double sufficientPercent;
  final double suboptimalPercent;
  final double criticalPercent;
  final Color bgColor;

  _ScoreRingPainter({
    required this.optimalPercent,
    required this.sufficientPercent,
    required this.suboptimalPercent,
    required this.criticalPercent,
    required this.bgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;
    const gap = 0.04;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = bgColor,
    );

    final segments = [
      (optimalPercent, _kOptimalColor),
      (sufficientPercent, _kSufficientColor),
      (suboptimalPercent, _kSuboptimalColor),
      (criticalPercent, _kCriticalColor),
    ];

    double currentAngle = startAngle;
    for (final (pct, color) in segments) {
      if (pct <= 0) continue;
      final sweep = pct * 2 * math.pi - gap;
      if (sweep <= 0) continue;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        currentAngle,
        sweep,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..color = color,
      );
      currentAngle += pct * 2 * math.pi;
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.optimalPercent != optimalPercent;
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomScrollView(
      slivers: [
        _buildSliverAppBar(context),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.biotech_rounded,
                      size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 20),
                  Text('No Blood Tests Yet',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your lab report PDF to track biomarkers '
                    'and get personalized insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => context.push('/health/labs/upload'),
                    icon: const Icon(Icons.upload_file_rounded),
                    label: const Text('Upload Lab Report'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Loading Shimmer ──────────────────────────────────────────────────────────

class _LoadingShimmer extends StatelessWidget {
  const _LoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator(strokeWidth: 2));
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _formatValue(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  if (value < 10) return value.toStringAsFixed(2);
  if (value < 100) return value.toStringAsFixed(1);
  return value.toInt().toString();
}
