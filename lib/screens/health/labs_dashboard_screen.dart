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
      // Refresh dashboard
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

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        _buildSliverAppBar(context),

        // Score ring + summary
        SliverToBoxAdapter(child: _ScoreSection(dash: widget.dash)),

        // Tier breakdown bar
        SliverToBoxAdapter(child: _TierBreakdownBar(dash: widget.dash)),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

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

// ── Reports Section ──────────────────────────────────────────────────────────

class _ReportsSection extends ConsumerWidget {
  final List<LabReport> reports;
  const _ReportsSection({required this.reports});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    if (reports.isEmpty) {
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
    final cs = Theme.of(context).colorScheme;
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
                if (dash.latestReportDate != null)
                  Text('Latest: ${dash.latestReportDate}',
                      style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
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
          // Stacked bar
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
          // Legend chips
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
  final VoidCallback onTap;
  const _PillarCard({required this.pillar, required this.summary, required this.onTap});

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
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(_pillarIcon(pillar), color: tierColor, size: 20),
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
          border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.2)),
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
                // Name
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
                      Text(_tierLabel(result.tier),
                          style: TextStyle(
                              color: tierColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5)),
                    ],
                  ),
                ),
                // Value + unit (original from report)
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

  String _formatValue(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    if (value < 10) return value.toStringAsFixed(2);
    if (value < 100) return value.toStringAsFixed(1);
    return value.toInt().toString();
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
            // Gradient bar
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
            // Dot marker
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

    // Background track
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
