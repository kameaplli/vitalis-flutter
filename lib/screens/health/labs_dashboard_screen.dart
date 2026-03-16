import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/friendly_error.dart';
import '../../widgets/shimmer_placeholder.dart';

// ── Tier colors ──────────────────────────────────────────────────────────────

const _kOptimalColor = Color(0xFF22C55E);
const _kSufficientColor = Color(0xFF3B82F6);
const _kSuboptimalColor = Color(0xFFF59E0B);
const _kCriticalColor = Color(0xFFEF4444);
const _kUnknownColor = Color(0xFF9CA3AF);

Color _tierColor(String? tier) => switch (tier) {
      'optimal' => _kOptimalColor,
      'sufficient' => _kSufficientColor,
      'suboptimal' => _kSuboptimalColor,
      'critical' => _kCriticalColor,
      _ => _kUnknownColor,
    };

String _tierLabel(String? tier) => switch (tier) {
      'optimal' => 'Optimal',
      'sufficient' => 'Sufficient',
      'suboptimal' => 'Suboptimal',
      'critical' => 'Critical',
      _ => 'Unknown',
    };

// ── Pillar icons ─────────────────────────────────────────────────────────────

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

Color _pillarColor(String pillar) => switch (pillar.toLowerCase()) {
      'cardiovascular' => const Color(0xFFEF4444),
      'metabolism' => const Color(0xFFF97316),
      'fitness' => const Color(0xFF8B5CF6),
      'nutrients' => const Color(0xFF22C55E),
      'inflammation' => const Color(0xFFF59E0B),
      'hormones' => const Color(0xFF06B6D4),
      'liver' => const Color(0xFF84CC16),
      'kidney' => const Color(0xFF3B82F6),
      'immunity' => const Color(0xFF6366F1),
      _ => const Color(0xFF6B7280),
    };

// ── Main Screen ──────────────────────────────────────────────────────────────

class LabsDashboardScreen extends ConsumerWidget {
  const LabsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final dashAsync = ref.watch(labDashboardProvider(person));
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blood Tests'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Reports',
            onPressed: () => _showReportsList(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/health/labs/upload'),
        icon: const Icon(Icons.upload_file_rounded),
        label: const Text('Upload'),
      ),
      body: dashAsync.when(
        loading: () => const ShimmerList(),
        error: (e, st) => FriendlyError(error: e),
        data: (dash) {
          if (dash.totalBiomarkers == 0) {
            return _EmptyState();
          }
          return CustomScrollView(
            slivers: [
              // ── Summary Banner ─────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text('${dash.totalBiomarkers}',
                              style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                          Text('biomarkers tracked',
                              style: tt.bodyLarge?.copyWith(color: cs.onSurfaceVariant)),
                        ],
                      ),
                      if (dash.latestReportDate != null) ...[
                        const SizedBox(height: 4),
                        Text('Latest report: ${dash.latestReportDate}',
                            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TierChip('${dash.optimalCount} Optimal', _kOptimalColor),
                          _TierChip('${dash.sufficientCount} Sufficient', _kSufficientColor),
                          _TierChip('${dash.suboptimalCount} Suboptimal', _kSuboptimalColor),
                          _TierChip('${dash.criticalCount} Critical', _kCriticalColor),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // ── Pillar Cards ───────────────────────────────────────
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 110,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: dash.pillars.length,
                    itemBuilder: (context, i) {
                      final pillar = dash.pillars.keys.elementAt(i);
                      final summary = dash.pillars[pillar]!;
                      return _PillarCard(pillar: pillar, summary: summary);
                    },
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 16)),

              // ── Biomarker List by Pillar ────────────────────────────
              for (final entry in dash.pillars.entries) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Icon(_pillarIcon(entry.key),
                            size: 20, color: _pillarColor(entry.key)),
                        const SizedBox(width: 8),
                        Text(entry.key,
                            style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _tierColor(entry.value.status).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_tierLabel(entry.value.status),
                              style: tt.labelSmall?.copyWith(
                                  color: _tierColor(entry.value.status),
                                  fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, i) {
                      final result = entry.value.results[i];
                      return _BiomarkerResultTile(result: result);
                    },
                    childCount: entry.value.results.length,
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  void _showReportsList(BuildContext context, WidgetRef ref) {
    final person = ref.read(selectedPersonProvider);
    final reportsAsync = ref.read(labReportsProvider(person));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(builder: (context, ref, _) {
            final reports = ref.watch(labReportsProvider(person));
            return reports.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, st) => Center(child: Text('Error: $e')),
              data: (reports) => ListView.builder(
                controller: scrollController,
                itemCount: reports.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Lab Reports',
                          style: Theme.of(context).textTheme.titleLarge),
                    );
                  }
                  final report = reports[i - 1];
                  return ListTile(
                    leading: const Icon(Icons.description_rounded),
                    title: Text(report.labProvider ?? 'Lab Report'),
                    subtitle: Text(report.testDate ?? ''),
                    trailing: Text('${report.results.length} results'),
                    onTap: () {
                      Navigator.of(context).pop();
                      // Could navigate to report detail
                    },
                  );
                },
              ),
            );
          });
        },
      ),
    );
  }
}

// ── Widgets ──────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.biotech_rounded, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 16),
          Text('No lab results yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: cs.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text('Upload a lab report PDF or enter results manually',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final String label;
  final Color color;
  const _TierChip(this.label, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Text(label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: color, fontWeight: FontWeight.w600)),
      );
}

class _PillarCard extends StatelessWidget {
  final String pillar;
  final PillarSummary summary;
  const _PillarCard({required this.pillar, required this.summary});

  @override
  Widget build(BuildContext context) {
    final color = _pillarColor(pillar);
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_pillarIcon(pillar), size: 24, color: color),
          const Spacer(),
          Text(pillar,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Row(
            children: [
              Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _tierColor(summary.status)),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text('${summary.biomarkerCount} markers',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BiomarkerResultTile extends StatelessWidget {
  final LabResult result;
  const _BiomarkerResultTile({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final tierColor = _tierColor(result.tier);

    return InkWell(
      onTap: () {
        if (result.biomarkerCode != null) {
          context.push('/health/labs/biomarker/${result.biomarkerCode}');
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Tier indicator
            Container(
              width: 4, height: 40,
              decoration: BoxDecoration(
                color: tierColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 12),

            // Name + value
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(result.biomarkerName ?? result.biomarkerCode ?? '',
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  // Range bar
                  _MiniRangeBar(result: result),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Value + unit
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${result.value}',
                    style: tt.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold, color: tierColor)),
                Text(result.unit ?? '',
                    style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              ],
            ),

            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Compact horizontal range bar showing where the value falls.
class _MiniRangeBar extends StatelessWidget {
  final LabResult result;
  const _MiniRangeBar({required this.result});

  @override
  Widget build(BuildContext context) {
    // Simplified range bar — just colored segments
    return SizedBox(
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: Row(
          children: [
            Expanded(flex: 1, child: Container(color: _kCriticalColor.withValues(alpha: 0.3))),
            Expanded(flex: 1, child: Container(color: _kSuboptimalColor.withValues(alpha: 0.3))),
            Expanded(flex: 1, child: Container(color: _kSufficientColor.withValues(alpha: 0.3))),
            Expanded(flex: 2, child: Container(color: _kOptimalColor.withValues(alpha: 0.3))),
            Expanded(flex: 1, child: Container(color: _kSufficientColor.withValues(alpha: 0.3))),
            Expanded(flex: 1, child: Container(color: _kSuboptimalColor.withValues(alpha: 0.3))),
            Expanded(flex: 1, child: Container(color: _kCriticalColor.withValues(alpha: 0.3))),
          ],
        ),
      ),
    );
  }
}
