import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../core/lab_tier_helpers.dart';
import '../../widgets/friendly_error.dart';
import '../../widgets/radial_spoke_chart.dart';

List<List<dynamic>> _pillarIcon(String pillar) => switch (pillar.toLowerCase()) {
      'cardiovascular' => HugeIcons.strokeRoundedFavourite,
      'metabolism' => HugeIcons.strokeRoundedFire,
      'fitness' => HugeIcons.strokeRoundedDumbbell01,
      'nutrients' => HugeIcons.strokeRoundedLeaf01,
      'inflammation' => HugeIcons.strokeRoundedFire,
      'hormones' => HugeIcons.strokeRoundedAiBrain01,
      'liver' => HugeIcons.strokeRoundedTestTube01,
      'kidney' => HugeIcons.strokeRoundedDroplet,
      'immunity' => HugeIcons.strokeRoundedShield01,
      _ => HugeIcons.strokeRoundedMicroscope,
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
    title: const Text('Decode'),
    actions: actions ??
        [
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FilledButton.icon(
              onPressed: () => context.push('/health/labs/upload'),
              icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18, color: Theme.of(context).colorScheme.onPrimary),
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
      icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreVertical, size: 24, color: Theme.of(context).colorScheme.onSurface),
      onSelected: (value) async {
        if (value == 'reprocess') {
          _reprocessData(context, ref);
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'reprocess',
          child: ListTile(
            dense: true,
            leading: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 24, color: Theme.of(context).colorScheme.onSurface),
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
  final _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _pendingQuery = '';

  /// Flattened list of all biomarkers for search
  List<LabResult> get _allBiomarkers {
    final results = <LabResult>[];
    for (final ps in widget.dash.pillars.values) {
      results.addAll(ps.results);
    }
    return results;
  }

  List<LabResult> get _searchResults {
    if (_searchQuery.isEmpty) return [];
    final q = _searchQuery.toLowerCase();
    return _allBiomarkers.where((r) {
      final name = (r.biomarkerName ?? '').toLowerCase();
      final code = (r.biomarkerCode ?? '').toLowerCase();
      final pillar = (r.healthPillar ?? '').toLowerCase();
      return name.contains(q) || code.contains(q) || pillar.contains(q);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    for (final pillar in widget.dash.pillars.keys) {
      _pillarKeys[pillar] = GlobalKey();
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
    final cs = Theme.of(context).colorScheme;

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context),

        // ── Normal dashboard content (hidden during search) ─────────────
        if (_searchQuery.isEmpty) ...[

        // Panic alerts (emergency / see_doctor)
        if (widget.dash.panicValues.isNotEmpty)
          SliverToBoxAdapter(child: _PanicBanner(alerts: widget.dash.panicValues)),

        // Health score + summary
        SliverToBoxAdapter(child: _ScoreSection(dash: widget.dash)),

        // Tier breakdown bar
        SliverToBoxAdapter(child: _TierBreakdownBar(dash: widget.dash)),

        ], // end if (_searchQuery.isEmpty) for score section

        // ── Full-width biomarker search ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) {
                final trimmed = v.trim();
                _pendingQuery = trimmed;
                if (trimmed.isEmpty) {
                  // Clear immediately for instant feedback
                  setState(() => _searchQuery = '');
                } else {
                  // Debounce: wait 300ms before updating results
                  Future.delayed(const Duration(milliseconds: 300), () {
                    if (mounted && _pendingQuery == trimmed) {
                      setState(() => _searchQuery = trimmed);
                    }
                  });
                }
              },
              decoration: InputDecoration(
                hintText: 'Search biomarkers...',
                prefixIcon: HugeIcon(icon: HugeIcons.strokeRoundedSearch01, size: 22, color: cs.onSurfaceVariant),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 20, color: cs.onSurfaceVariant),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // ── Search results (shown when query is non-empty) ──────────────
        if (_searchQuery.isNotEmpty) ...[
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) {
                final results = _searchResults;
                if (results.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('No biomarkers found',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ),
                  );
                }
                return _BiomarkerCard(
                  result: results[i],
                  isLast: i == results.length - 1,
                );
              },
              childCount: _searchResults.isEmpty ? 1 : _searchResults.length,
            ),
          ),
        ],

        // ── Normal dashboard content continued (hidden during search) ───
        if (_searchQuery.isEmpty) ...[

        // Attention Needed section
        if (widget.dash.attentionNeeded.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
          const SliverToBoxAdapter(child: _SectionHeader('ATTENTION NEEDED')),
          SliverToBoxAdapter(
            child: _HorizontalResultCards(
              results: widget.dash.attentionNeeded,
              accentColor: kCriticalColor,
              icon: HugeIcons.strokeRoundedAlert02,
            ),
          ),
        ],

        // Improvements section
        if (widget.dash.improvements.isNotEmpty) ...[
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
          const SliverToBoxAdapter(child: _SectionHeader('IMPROVING')),
          SliverToBoxAdapter(
            child: _HorizontalResultCards(
              results: widget.dash.improvements,
              accentColor: kOptimalColor,
              icon: HugeIcons.strokeRoundedChartIncrease,
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
        const SliverToBoxAdapter(child: _SectionHeader('HEALTH PILLARS')),
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
        const SliverToBoxAdapter(child: _SectionHeader('RECENT REPORTS')),
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

        ], // end if (_searchQuery.isEmpty)
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
              borderColor: kCriticalColor,
              icon: HugeIcons.strokeRoundedAmbulance,
              iconColor: kCriticalColor,
              label: 'EMERGENCY',
            ),
          for (final alert in seeDoctor)
            _AlertCard(
              alert: alert,
              borderColor: kSuboptimalColor,
              icon: HugeIcons.strokeRoundedHospital01,
              iconColor: kSuboptimalColor,
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
  final List<List<dynamic>> icon;
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
    final isEmergency = label == 'EMERGENCY';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            borderColor.withValues(alpha: 0.12),
            borderColor.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withValues(alpha: 0.18),
              border: Border.all(color: iconColor.withValues(alpha: 0.3), width: 1),
            ),
            child: HugeIcon(icon: icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: iconColor.withValues(alpha: isEmergency ? 0.9 : 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(label,
                          style: TextStyle(
                              color: isEmergency ? Colors.white : iconColor,
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8)),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${alert.value} ${alert.unit}',
                        style: TextStyle(
                          color: iconColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${alert.name} (${alert.code})',
                  style: TextStyle(
                    color: cs.onSurface,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(alert.message,
                    style: TextStyle(
                        color: cs.onSurface.withValues(alpha: 0.75),
                        fontSize: 12,
                        height: 1.4)),
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
  final List<List<dynamic>> icon;
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
          final tierColor = getTierColor(r.tier);
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
                      HugeIcon(icon: icon, color: accentColor, size: 16),
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
    final List<List<dynamic>> icon;
    final Color color;

    switch (direction) {
      case 'rising':
        icon = HugeIcons.strokeRoundedChartIncrease;
        color = isImproving == true ? kOptimalColor : kCriticalColor;
        break;
      case 'falling':
        icon = HugeIcons.strokeRoundedChartDecrease;
        color = isImproving == true ? kOptimalColor : kCriticalColor;
        break;
      case 'stable':
        icon = HugeIcons.strokeRoundedMinusSign;
        color = kSufficientColor;
        break;
      default:
        return const SizedBox.shrink();
    }

    return HugeIcon(icon: icon, color: color, size: size);
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
          const _SectionHeader('INSIGHTS'),
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
        'critical' => kCriticalColor,
        'warning' => kSuboptimalColor,
        'info' => kSufficientColor,
        _ => kUnknownTierColor,
      };

  List<List<dynamic>> _severityIcon() => switch (insight.severity) {
        'critical' => HugeIcons.strokeRoundedAlert01,
        'warning' => HugeIcons.strokeRoundedAlert02,
        'info' => HugeIcons.strokeRoundedBulb,
        _ => HugeIcons.strokeRoundedInformationCircle,
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
              HugeIcon(icon: _severityIcon(), color: color, size: 18),
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
                child: HugeIcon(icon: HugeIcons.strokeRoundedCancel01,
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

  List<List<dynamic>> _categoryIcon(String category) => switch (category) {
        'diet' => HugeIcons.strokeRoundedRestaurant01,
        'supplement' => HugeIcons.strokeRoundedMedicine01,
        'lifestyle' => HugeIcons.strokeRoundedWellness,
        'exercise' => HugeIcons.strokeRoundedDumbbell01,
        'medical' => HugeIcons.strokeRoundedHospital01,
        _ => HugeIcons.strokeRoundedBulb,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader('RECOMMENDATIONS'),
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
                    child: HugeIcon(icon: _categoryIcon(rec.category),
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
                                  color: kOptimalColor.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                    'Impact ${(rec.impactScore! * 10).round()}/10',
                                    style: const TextStyle(
                                        color: kOptimalColor,
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
            child: const Text('Delete',
                style: TextStyle(color: kCriticalColor, fontWeight: FontWeight.w700)),
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
            backgroundColor: kCriticalColor,
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
          color: kCriticalColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Delete',
                style: TextStyle(
                    color: kCriticalColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 14)),
            const SizedBox(width: 8),
            HugeIcon(icon: HugeIcons.strokeRoundedDelete01, color: kCriticalColor, size: 22),
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
            child: HugeIcon(icon: HugeIcons.strokeRoundedFile01,
                color: cs.onPrimaryContainer, size: 20),
          ),
          title: Text(report.labProvider ?? 'Report',
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
              color: (report.results.isEmpty ? kCriticalColor : kOptimalColor)
                  .withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${report.results.length} results',
              style: TextStyle(
                color: report.results.isEmpty ? kCriticalColor : kOptimalColor,
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

    // Build spokes from health pillars — each pillar gets a unique brand color
    final spokes = <SpokeData>[];
    var colorIdx = 0;
    for (final entry in dash.pillars.entries) {
      final pillar = entry.key;
      final summary = entry.value;
      final score = dash.pillarScores?[pillar];
      final spokeValue = score != null ? (score / 100).clamp(0.0, 1.0) : _tierToValue(summary.status);

      spokes.add(SpokeData(
        key: pillar,
        label: pillar,
        detail: '${summary.biomarkerCount} markers  ·  ${getTierLabel(summary.status)}',
        value: spokeValue,
        color: ChartColors.at(colorIdx),
        subtitle: score != null ? '${score.round()}/100' : null,
      ));
      colorIdx++;
    }

    // Center text
    final centerTitle = hasScore ? '${dash.healthScore!.round()}' : '${(optimalPercent * 100).round()}%';
    final centerSub = hasScore ? 'Health Score' : 'Optimal';

    return Column(
      children: [
        const SizedBox(height: 8),
        // Radial spoke chart
        if (spokes.isNotEmpty)
          Center(
            child: RadialSpokeChart(
              spokes: spokes,
              size: MediaQuery.of(context).size.width * 0.78,
              centerTitle: centerTitle,
              centerSubtitle: centerSub,
              centerColor: hasScore ? _scoreColor(dash.healthScore!) : kOptimalColor,
            ),
          )
        else
          // Fallback for no pillars
          _ScoreRingFallback(
            optimalPercent: optimalPercent,
            dash: dash,
          ),

        // Summary row below chart
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$total Biomarkers',
                  style: TextStyle(
                      color: cs.onSurface,
                      fontSize: 15,
                      fontWeight: FontWeight.w700)),
              if (dash.previousOptimalPercent != null) ...[
                const SizedBox(width: 12),
                _OptimalTrendChip(
                  current: optimalPercent,
                  previous: dash.previousOptimalPercent!,
                ),
              ],
            ],
          ),
        ),
        if (dash.latestReportDate != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text('Latest: ${dash.latestReportDate}',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 12)),
          ),
      ],
    );
  }

  static double _tierToValue(String? tier) => switch (tier) {
        'optimal' => 0.95,
        'sufficient' => 0.7,
        'suboptimal' => 0.45,
        'critical' => 0.25,
        _ => 0.15,
      };

  static Color _scoreColor(double score) {
    if (score >= 80) return kOptimalColor;
    if (score >= 60) return kSufficientColor;
    if (score >= 40) return kSuboptimalColor;
    return kCriticalColor;
  }
}

/// Fallback score ring when no pillar data (used only when spokes unavailable)
class _ScoreRingFallback extends StatelessWidget {
  final double optimalPercent;
  final LabDashboard dash;
  const _ScoreRingFallback({required this.optimalPercent, required this.dash});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = dash.totalBiomarkers;
    return SizedBox(
      width: 100, height: 100,
      child: CustomPaint(
        painter: _ScoreRingPainter(
          optimalPercent: optimalPercent,
          sufficientPercent: total > 0 ? dash.sufficientCount / total : 0,
          suboptimalPercent: total > 0 ? dash.suboptimalCount / total : 0,
          criticalPercent: total > 0 ? dash.criticalCount / total : 0,
          bgColor: cs.surfaceContainerHighest,
        ),
        child: Center(
          child: Text('${(optimalPercent * 100).round()}%',
              style: TextStyle(color: cs.onSurface, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
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
    final color = isUp ? kOptimalColor : kCriticalColor;
    final icon = isUp ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01;
    final displayPct = pctChange.abs().round().clamp(0, 999); // cap display at 999%

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, color: color, size: 14),
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
      (dash.optimalCount, kOptimalColor, 'Optimal'),
      (dash.sufficientCount, kSufficientColor, 'Sufficient'),
      (dash.suboptimalCount, kSuboptimalColor, 'Needs Work'),
      (dash.criticalCount, kCriticalColor, 'Critical'),
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
    final tierColor = getTierColor(summary.status);

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
                  child: HugeIcon(icon: _pillarIcon(pillar), color: tierColor, size: 18),
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
    final tierColor = getTierColor(summary.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          HugeIcon(icon: _pillarIcon(pillar), color: tierColor, size: 22),
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
            child: Text(getTierLabel(summary.status),
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
    final tierColor = getTierColor(result.tier);
    final code = result.biomarkerCode ?? '';

    // Urgency border for critical/suboptimal
    final borderColor = result.tier == 'critical'
        ? kCriticalColor.withValues(alpha: 0.4)
        : result.tier == 'suboptimal'
            ? kSuboptimalColor.withValues(alpha: 0.3)
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
                          Text(getTierLabel(result.tier),
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
                HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
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
        ? kOptimalColor
        : isImproving == false
            ? kCriticalColor
            : kUnknownTierColor;

    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(
            icon: isUp ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
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
        final tierColor = getTierColor(result.tier);

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
        kCriticalColor.withValues(alpha: 0.35),
        kSuboptimalColor.withValues(alpha: 0.30),
        kSufficientColor.withValues(alpha: 0.25),
        kOptimalColor.withValues(alpha: 0.35),
        kOptimalColor.withValues(alpha: 0.35),
        kSufficientColor.withValues(alpha: 0.25),
        kSuboptimalColor.withValues(alpha: 0.30),
        kCriticalColor.withValues(alpha: 0.35),
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
      (optimalPercent, kOptimalColor),
      (sufficientPercent, kSufficientColor),
      (suboptimalPercent, kSuboptimalColor),
      (criticalPercent, kCriticalColor),
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
                  HugeIcon(icon: HugeIcons.strokeRoundedMicroscope,
                      size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 20),
                  Text('No Results Yet',
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 20,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(
                    'Upload your report to decode your biomarkers '
                    'and unlock personalized insights.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 14,
                        height: 1.5),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () => context.push('/health/labs/upload'),
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedUpload01, size: 20),
                    label: const Text('Upload Report'),
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
