import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../widgets/friendly_error.dart';

// ── Design Tokens ────────────────────────────────────────────────────────────

const _kOptimalColor = Color(0xFF00E676);
const _kSufficientColor = Color(0xFF448AFF);
const _kSuboptimalColor = Color(0xFFFFAB00);
const _kCriticalColor = Color(0xFFFF5252);
const _kUnknownColor = Color(0xFF78909C);

const _kDarkBg = Color(0xFF0F1923);
const _kCardBg = Color(0xFF1A2732);
const _kCardBorder = Color(0xFF2A3A48);
const _kTextPrimary = Color(0xFFF5F5F5);
const _kTextSecondary = Color(0xFF90A4AE);

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

Color _pillarAccent(String pillar) => switch (pillar.toLowerCase()) {
      'cardiovascular' => const Color(0xFFFF5252),
      'metabolism' => const Color(0xFFFF6D00),
      'fitness' => const Color(0xFFB388FF),
      'nutrients' => const Color(0xFF69F0AE),
      'inflammation' => const Color(0xFFFFD740),
      'hormones' => const Color(0xFF40C4FF),
      'liver' => const Color(0xFFB2FF59),
      'kidney' => const Color(0xFF448AFF),
      'immunity' => const Color(0xFF7C4DFF),
      _ => const Color(0xFF90A4AE),
    };

// ── Main Screen ──────────────────────────────────────────────────────────────

class LabsDashboardScreen extends ConsumerWidget {
  const LabsDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final dashAsync = ref.watch(labDashboardProvider(person));

    return Theme(
      data: _buildDarkTheme(context),
      child: Builder(builder: (context) {
        return Scaffold(
          backgroundColor: _kDarkBg,
          appBar: AppBar(
            backgroundColor: _kDarkBg,
            surfaceTintColor: Colors.transparent,
            title: const Text('Blood Tests',
                style: TextStyle(
                    color: _kTextPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    letterSpacing: 0.5)),
            iconTheme: const IconThemeData(color: _kTextPrimary),
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
            backgroundColor: _kOptimalColor,
            foregroundColor: _kDarkBg,
            icon: const Icon(Icons.add_rounded, size: 22),
            label: const Text('Upload Report',
                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5)),
          ),
          body: dashAsync.when(
            loading: () => const _DarkShimmer(),
            error: (e, st) => FriendlyError(error: e),
            data: (dash) {
              if (dash.totalBiomarkers == 0) {
                return const _EmptyState();
              }
              return _DashboardBody(dash: dash);
            },
          ),
        );
      }),
    );
  }

  void _showReportsList(BuildContext context, WidgetRef ref) {
    final person = ref.read(selectedPersonProvider);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _kCardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        expand: false,
        builder: (context, scrollController) {
          return Consumer(builder: (context, ref, _) {
            final reports = ref.watch(labReportsProvider(person));
            return reports.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: _kOptimalColor)),
              error: (e, st) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(color: _kTextSecondary))),
              data: (reports) => ListView.builder(
                controller: scrollController,
                itemCount: reports.length + 1,
                itemBuilder: (context, i) {
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              color: _kOptimalColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text('Lab Reports',
                              style: TextStyle(
                                  color: _kTextPrimary,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                    );
                  }
                  final report = reports[i - 1];
                  return Container(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: _kDarkBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kCardBorder),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 4),
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: _kOptimalColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.description_rounded,
                            color: _kOptimalColor, size: 20),
                      ),
                      title: Text(
                          report.labProvider ?? 'Lab Report',
                          style: const TextStyle(
                              color: _kTextPrimary,
                              fontWeight: FontWeight.w600)),
                      subtitle: Text(report.testDate ?? '',
                          style: const TextStyle(color: _kTextSecondary)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kOptimalColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${report.results.length} results',
                            style: const TextStyle(
                                color: _kOptimalColor,
                                fontWeight: FontWeight.w600,
                                fontSize: 12)),
                      ),
                      onTap: () => Navigator.of(context).pop(),
                    ),
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

ThemeData _buildDarkTheme(BuildContext context) {
  return ThemeData.dark().copyWith(
    scaffoldBackgroundColor: _kDarkBg,
    colorScheme: const ColorScheme.dark(
      surface: _kDarkBg,
      primary: _kOptimalColor,
    ),
  );
}

// ── Dashboard Body ───────────────────────────────────────────────────────────

class _DashboardBody extends StatelessWidget {
  final LabDashboard dash;
  const _DashboardBody({required this.dash});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // ── Score Ring + Summary ────────────────────────────
        SliverToBoxAdapter(child: _ScoreSection(dash: dash)),

        // ── Tier Breakdown Bar ─────────────────────────────
        SliverToBoxAdapter(child: _TierBreakdownBar(dash: dash)),

        const SliverToBoxAdapter(child: SizedBox(height: 20)),

        // ── Health Pillars ─────────────────────────────────
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: _kOptimalColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 10),
                const Text('HEALTH PILLARS',
                    style: TextStyle(
                        color: _kTextSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
        ),

        SliverToBoxAdapter(
          child: SizedBox(
            height: 130,
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

        const SliverToBoxAdapter(child: SizedBox(height: 24)),

        // ── Biomarkers by Pillar ───────────────────────────
        for (final entry in dash.pillars.entries) ...[
          SliverToBoxAdapter(
            child: _PillarHeader(
                pillar: entry.key, summary: entry.value),
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

        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }
}

// ── Score Ring Section ───────────────────────────────────────────────────────

class _ScoreSection extends StatelessWidget {
  final LabDashboard dash;
  const _ScoreSection({required this.dash});

  @override
  Widget build(BuildContext context) {
    final total = dash.totalBiomarkers;
    final optimalPercent = total > 0 ? dash.optimalCount / total : 0.0;
    final goodPercent = total > 0
        ? (dash.optimalCount + dash.sufficientCount) / total
        : 0.0;
    final score = (goodPercent * 100).round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Row(
        children: [
          // Score Ring
          SizedBox(
            width: 120,
            height: 120,
            child: CustomPaint(
              painter: _ScoreRingPainter(
                optimalPercent: optimalPercent,
                goodPercent: goodPercent,
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$score',
                        style: const TextStyle(
                            color: _kTextPrimary,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const Text('SCORE',
                        style: TextStyle(
                            color: _kTextSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.5)),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(width: 24),

          // Summary stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dash.totalBiomarkers} Biomarkers',
                    style: const TextStyle(
                        color: _kTextPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                if (dash.latestReportDate != null)
                  Text('Last tested ${dash.latestReportDate}',
                      style: const TextStyle(
                          color: _kTextSecondary, fontSize: 13)),
                const SizedBox(height: 12),
                // Mini tier stats
                Row(
                  children: [
                    _MiniStat(
                        '${dash.optimalCount}', 'Optimal', _kOptimalColor),
                    const SizedBox(width: 16),
                    _MiniStat('${dash.sufficientCount}', 'Good',
                        _kSufficientColor),
                    const SizedBox(width: 16),
                    _MiniStat(
                        '${dash.suboptimalCount + dash.criticalCount}',
                        'Flagged',
                        dash.criticalCount > 0
                            ? _kCriticalColor
                            : _kSuboptimalColor),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _MiniStat(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.w800)),
        Text(label,
            style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 10,
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

// ── Score Ring Painter ───────────────────────────────────────────────────────

class _ScoreRingPainter extends CustomPainter {
  final double optimalPercent;
  final double goodPercent;

  _ScoreRingPainter({required this.optimalPercent, required this.goodPercent});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;
    const strokeWidth = 10.0;
    const startAngle = -math.pi / 2;

    // Background ring
    final bgPaint = Paint()
      ..color = _kCardBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    // Good (sufficient + optimal) arc
    if (goodPercent > 0) {
      final goodPaint = Paint()
        ..color = _kSufficientColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        goodPercent * 2 * math.pi,
        false,
        goodPaint,
      );
    }

    // Optimal arc (on top)
    if (optimalPercent > 0) {
      final optPaint = Paint()
        ..color = _kOptimalColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        optimalPercent * 2 * math.pi,
        false,
        optPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter old) =>
      old.optimalPercent != optimalPercent || old.goodPercent != goodPercent;
}

// ── Tier Breakdown Bar ───────────────────────────────────────────────────────

class _TierBreakdownBar extends StatelessWidget {
  final LabDashboard dash;
  const _TierBreakdownBar({required this.dash});

  @override
  Widget build(BuildContext context) {
    final total = dash.totalBiomarkers;
    if (total == 0) return const SizedBox();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kCardBorder),
      ),
      child: Column(
        children: [
          // Stacked bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  if (dash.optimalCount > 0)
                    Expanded(
                        flex: dash.optimalCount,
                        child: Container(color: _kOptimalColor)),
                  if (dash.sufficientCount > 0)
                    Expanded(
                        flex: dash.sufficientCount,
                        child: Container(color: _kSufficientColor)),
                  if (dash.suboptimalCount > 0)
                    Expanded(
                        flex: dash.suboptimalCount,
                        child: Container(color: _kSuboptimalColor)),
                  if (dash.criticalCount > 0)
                    Expanded(
                        flex: dash.criticalCount,
                        child: Container(color: _kCriticalColor)),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TierLegendItem('Optimal', dash.optimalCount, _kOptimalColor),
              _TierLegendItem(
                  'Sufficient', dash.sufficientCount, _kSufficientColor),
              _TierLegendItem(
                  'Needs Work', dash.suboptimalCount, _kSuboptimalColor),
              _TierLegendItem(
                  'Critical', dash.criticalCount, _kCriticalColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _TierLegendItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;
  const _TierLegendItem(this.label, this.count, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                  shape: BoxShape.circle, color: color),
            ),
            const SizedBox(width: 4),
            Text('$count',
                style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w800)),
          ],
        ),
        Text(label,
            style: const TextStyle(
                color: _kTextSecondary,
                fontSize: 9,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ── Pillar Card ──────────────────────────────────────────────────────────────

class _PillarCard extends StatelessWidget {
  final String pillar;
  final PillarSummary summary;
  const _PillarCard({required this.pillar, required this.summary});

  @override
  Widget build(BuildContext context) {
    final accent = _pillarAccent(pillar);
    final tierColor = _tierColor(summary.status);

    return Container(
      width: 140,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.25)),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_pillarIcon(pillar), size: 20, color: accent),
              ),
              const Spacer(),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tierColor,
                  boxShadow: [
                    BoxShadow(
                        color: tierColor.withValues(alpha: 0.5),
                        blurRadius: 6),
                  ],
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(pillar,
              style: const TextStyle(
                  color: _kTextPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text('${summary.biomarkerCount} markers',
              style: const TextStyle(
                  color: _kTextSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// ── Pillar Header ────────────────────────────────────────────────────────────

class _PillarHeader extends StatelessWidget {
  final String pillar;
  final PillarSummary summary;
  const _PillarHeader({required this.pillar, required this.summary});

  @override
  Widget build(BuildContext context) {
    final accent = _pillarAccent(pillar);
    final tierColor = _tierColor(summary.status);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Row(
        children: [
          Icon(_pillarIcon(pillar), size: 18, color: accent),
          const SizedBox(width: 8),
          Text(pillar.toUpperCase(),
              style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: tierColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: tierColor.withValues(alpha: 0.3)),
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
    final tierColor = _tierColor(result.tier);

    return GestureDetector(
      onTap: () {
        if (result.biomarkerCode != null) {
          context.push('/health/labs/biomarker/${result.biomarkerCode}');
        }
      },
      child: Container(
        margin: EdgeInsets.fromLTRB(20, 0, 20, isLast ? 0 : 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kCardBorder),
        ),
        child: Column(
          children: [
            // Top row: name + value
            Row(
              children: [
                // Tier dot with glow
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tierColor,
                    boxShadow: [
                      BoxShadow(
                          color: tierColor.withValues(alpha: 0.5),
                          blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      result.biomarkerName ?? result.biomarkerCode ?? '',
                      style: const TextStyle(
                          color: _kTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ),
                Text(
                  _formatValue(result.value),
                  style: TextStyle(
                      color: tierColor,
                      fontSize: 20,
                      fontWeight: FontWeight.w800),
                ),
                const SizedBox(width: 4),
                Text(result.unit ?? '',
                    style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500)),
                const SizedBox(width: 6),
                Icon(Icons.chevron_right_rounded,
                    size: 18, color: _kTextSecondary.withValues(alpha: 0.5)),
              ],
            ),

            const SizedBox(height: 10),

            // Range bar with value marker
            _WhoopRangeBar(result: result),

            const SizedBox(height: 6),

            // Tier label + reference range
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(_tierLabel(result.tier),
                      style: TextStyle(
                          color: tierColor,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8)),
                ),
                const Spacer(),
                if (result.referenceLow != null || result.referenceHigh != null)
                  Text(
                    _referenceText(result),
                    style: const TextStyle(
                        color: _kTextSecondary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500),
                  ),
              ],
            ),
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

  String _referenceText(LabResult r) {
    if (r.referenceLow != null && r.referenceHigh != null) {
      return 'Ref: ${_fmt(r.referenceLow!)} - ${_fmt(r.referenceHigh!)}';
    }
    if (r.referenceLow != null) return 'Ref: > ${_fmt(r.referenceLow!)}';
    if (r.referenceHigh != null) return 'Ref: < ${_fmt(r.referenceHigh!)}';
    return '';
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
  }
}

// ── Whoop-Style Range Bar ────────────────────────────────────────────────────

class _WhoopRangeBar extends StatelessWidget {
  final LabResult result;
  const _WhoopRangeBar({required this.result});

  @override
  Widget build(BuildContext context) {
    final tierColor = _tierColor(result.tier);

    // Calculate position on bar (0.0 to 1.0)
    double position = 0.5; // default center
    if (result.referenceLow != null && result.referenceHigh != null) {
      final low = result.referenceLow!;
      final high = result.referenceHigh!;
      final range = high - low;
      if (range > 0) {
        // Map value: ref_low = 0.2, ref_high = 0.8 (middle 60% is normal range)
        final normalized = (result.value - low) / range;
        position = 0.2 + normalized * 0.6;
        position = position.clamp(0.02, 0.98);
      }
    } else if (result.referenceHigh != null) {
      position = (result.value / result.referenceHigh! * 0.7).clamp(0.02, 0.98);
    } else if (result.referenceLow != null) {
      final ratio = result.value / result.referenceLow!;
      position = (0.1 + (ratio - 0.5) * 0.6).clamp(0.02, 0.98);
    }

    return SizedBox(
      height: 20,
      child: LayoutBuilder(builder: (context, constraints) {
        final barWidth = constraints.maxWidth;
        final markerX = position * barWidth;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            // Background gradient bar
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CustomPaint(
                  painter: _GradientBarPainter(),
                ),
              ),
            ),

            // Value marker (triangle + line)
            Positioned(
              left: markerX - 6,
              top: 0,
              bottom: 0,
              child: SizedBox(
                width: 12,
                child: Column(
                  children: [
                    // Triangle marker
                    CustomPaint(
                      size: const Size(12, 7),
                      painter: _TriangleMarkerPainter(color: tierColor),
                    ),
                    // Vertical line
                    Expanded(
                      child: Container(
                        width: 2,
                        decoration: BoxDecoration(
                          color: tierColor,
                          borderRadius: BorderRadius.circular(1),
                          boxShadow: [
                            BoxShadow(
                                color: tierColor.withValues(alpha: 0.6),
                                blurRadius: 4),
                          ],
                        ),
                      ),
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

class _GradientBarPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final gradient = LinearGradient(
      colors: [
        _kCriticalColor.withValues(alpha: 0.6),
        _kSuboptimalColor.withValues(alpha: 0.5),
        _kSufficientColor.withValues(alpha: 0.4),
        _kOptimalColor.withValues(alpha: 0.5),
        _kOptimalColor.withValues(alpha: 0.5),
        _kSufficientColor.withValues(alpha: 0.4),
        _kSuboptimalColor.withValues(alpha: 0.5),
        _kCriticalColor.withValues(alpha: 0.6),
      ],
      stops: const [0.0, 0.15, 0.25, 0.4, 0.6, 0.75, 0.85, 1.0],
    );
    final paint = Paint()..shader = gradient.createShader(rect);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _TriangleMarkerPainter extends CustomPainter {
  final Color color;
  _TriangleMarkerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TriangleMarkerPainter old) =>
      old.color != color;
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kOptimalColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.biotech_rounded,
                  size: 40, color: _kOptimalColor),
            ),
            const SizedBox(height: 24),
            const Text('No Lab Results Yet',
                style: TextStyle(
                    color: _kTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text(
              'Upload a blood test report or enter\nyour results manually to get started.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _kTextSecondary,
                  fontSize: 14,
                  height: 1.5),
            ),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => context.push('/health/labs/upload'),
              icon: const Icon(Icons.upload_file_rounded),
              label: const Text('Upload Report'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _kOptimalColor,
                side: const BorderSide(color: _kOptimalColor),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Dark Shimmer ─────────────────────────────────────────────────────────────

class _DarkShimmer extends StatelessWidget {
  const _DarkShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Score area shimmer
          Row(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: _kCardBg,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                        height: 24,
                        width: 160,
                        decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(6))),
                    const SizedBox(height: 8),
                    Container(
                        height: 16,
                        width: 120,
                        decoration: BoxDecoration(
                            color: _kCardBg,
                            borderRadius: BorderRadius.circular(6))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Cards shimmer
          for (int i = 0; i < 4; i++) ...[
            Container(
              height: 90,
              decoration: BoxDecoration(
                color: _kCardBg,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}
