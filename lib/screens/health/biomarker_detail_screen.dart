import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';

import '../../models/lab_result.dart';
import '../../providers/lab_provider.dart';
import '../../providers/selected_person_provider.dart';
import '../../core/lab_tier_helpers.dart';
import '../../widgets/friendly_error.dart';
import '../../widgets/chart_style.dart';
import 'package:hugeicons/hugeicons.dart';

class BiomarkerDetailScreen extends ConsumerWidget {
  final String biomarkerCode;
  const BiomarkerDetailScreen({super.key, required this.biomarkerCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final historyAsync = ref.watch(biomarkerHistoryProvider(
        (code: biomarkerCode, person: person)));
    final recsAsync = ref.watch(labRecommendationsProvider(person));

    return Scaffold(
      appBar: AppBar(
        title: Text(biomarkerCode),
      ),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (e, st) => FriendlyError(error: e),
        data: (history) => _DetailBody(
          history: history,
          recommendations: recsAsync.valueOrNull
              ?.where((r) => r.biomarkerCode == biomarkerCode)
              .toList() ?? [],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final BiomarkerHistory history;
  final List<BiomarkerRecommendation> recommendations;
  const _DetailBody({required this.history, this.recommendations = const []});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final latestValue =
        history.dataPoints.isNotEmpty ? history.dataPoints.last.value : null;
    final latestTier =
        history.dataPoints.isNotEmpty ? history.dataPoints.last.tier : null;
    final tierColor = getTierColor(latestTier);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Hero: Name + Latest Value ────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(history.name,
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 26,
                            fontWeight: FontWeight.w800)),
                    const SizedBox(height: 4),
                    Text(
                        '${history.category ?? ''} ${history.healthPillar != null ? "  ${history.healthPillar}" : ""}',
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              if (latestValue != null) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(_formatValue(latestValue),
                        style: TextStyle(
                            color: tierColor,
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            height: 1)),
                    const SizedBox(height: 2),
                    Text(history.unit,
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w500)),
                  ],
                ),
              ],
            ],
          ),

          if (latestTier != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: tierColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: tierColor.withValues(alpha: 0.25)),
                  ),
                  child: Text(getTierLabel(latestTier),
                      style: TextStyle(
                          color: tierColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1)),
                ),
                // Trend badge
                if (history.trendDirection != null &&
                    history.trendDirection != 'new') ...[
                  const SizedBox(width: 8),
                  _TrendBadge(
                    direction: history.trendDirection!,
                    velocity: history.trendVelocity,
                    isImproving: history.isImproving,
                  ),
                ],
              ],
            ),
          ],

          if (history.description != null) ...[
            const SizedBox(height: 16),
            Text(history.description!,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 14,
                    height: 1.5)),
          ],

          // ── Trend Summary Card ─────────────────────────────
          if (history.trendDirection != null &&
              history.trendDirection != 'new' &&
              history.dataPoints.length >= 2) ...[
            const SizedBox(height: 20),
            _TrendSummaryCard(history: history),
          ],

          // ── Population Comparison ──────────────────────────
          if (latestValue != null && history.populationAverage != null) ...[
            const SizedBox(height: 24),
            const _SectionTitle('YOUR VALUE vs POPULATION AVERAGE'),
            const SizedBox(height: 12),
            _PopulationComparison(
              yourValue: latestValue,
              populationAvg: history.populationAverage!,
              unit: history.unit,
              tier: latestTier,
              ranges: history.ranges,
            ),
          ],

          // ── Insights ───────────────────────────────────────
          if (history.insights != null) ...[
            const SizedBox(height: 24),
            const _SectionTitle('INSIGHTS'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tierColor.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  HugeIcon(
                    icon: latestTier == 'optimal'
                        ? HugeIcons.strokeRoundedCheckmarkCircle01
                        : latestTier == 'critical'
                            ? HugeIcons.strokeRoundedAlert02
                            : HugeIcons.strokeRoundedInformationCircle,
                    color: tierColor,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      history.insights!.statusSummary,
                      style: TextStyle(
                        color: tierColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('What it means',
                        style: TextStyle(
                            color: cs.onSurface,
                            fontSize: 13,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Text(history.insights!.whatItMeans,
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.5)),
                  ],
                ),
              ),
            ),
            if (history.insights!.actionPoints.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          HugeIcon(icon: HugeIcons.strokeRoundedBulb,
                              color: kSuboptimalColor, size: 18),
                          const SizedBox(width: 8),
                          Text('Action Points',
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final point in history.insights!.actionPoints)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 6),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.primary.withValues(alpha: 0.7),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(point,
                                    style: TextStyle(
                                        color: cs.onSurfaceVariant,
                                        fontSize: 13,
                                        height: 1.4)),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],

          const SizedBox(height: 24),

          // ── Range Visualization ──────────────────────────
          if (history.ranges != null) ...[
            const _SectionTitle('REFERENCE RANGES'),
            const SizedBox(height: 12),
            _LargeRangeBar(
              ranges: history.ranges!,
              currentValue: latestValue,
              unit: history.unit,
            ),
            if (history.ranges!.evidenceGrade == 'midrange') ...[
              const SizedBox(height: 12),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle,
                          size: 16,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Optimal range based on midrange of standard clinical reference. '
                          'No specific guideline-endorsed optimal exists.',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (history.ranges!.source != null) ...[
              const SizedBox(height: 8),
              Text('Source: ${history.ranges!.source}',
                  style: const TextStyle(
                      color: kOptimalColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
            ],
          ],

          const SizedBox(height: 24),

          // ── Nutrient Connections ──────────────────────────
          if (history.nutrientConnections.isNotEmpty) ...[
            const _SectionTitle('NUTRIENT CONNECTIONS'),
            const SizedBox(height: 12),
            _NutrientConnectionsCard(connections: history.nutrientConnections),
            const SizedBox(height: 24),
          ],

          // ── Related Biomarkers ─────────────────────────────
          if (history.relatedBiomarkers.isNotEmpty) ...[
            const _SectionTitle('RELATED BIOMARKERS'),
            const SizedBox(height: 12),
            _RelatedBiomarkersCard(related: history.relatedBiomarkers),
            const SizedBox(height: 24),
          ],

          // ── Recommendations ─────────────────────────────────
          if (recommendations.isNotEmpty) ...[
            const _SectionTitle('RECOMMENDATIONS'),
            const SizedBox(height: 12),
            for (final rec in recommendations)
              _RecommendationCard(rec: rec),
            const SizedBox(height: 24),
          ],

          // ── History Chart ────────────────────────────────
          if (history.dataPoints.length >= 2) ...[
            const _SectionTitle('TREND'),
            const SizedBox(height: 16),
            Card(
              margin: EdgeInsets.zero,
              child: SizedBox(
                height: 240,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 16, 16, 8),
                  child: _HistoryChart(
                    dataPoints: history.dataPoints,
                    ranges: history.ranges,
                    populationAvg: history.populationAverage,
                    unit: history.unit,
                  ),
                ),
              ),
            ),
          ] else if (history.dataPoints.length == 1) ...[
            const _SectionTitle('TREND'),
            const SizedBox(height: 8),
            Text('Upload more reports to see trends over time.',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          ],

          const SizedBox(height: 24),

          // ── All Results ──────────────────────────────────
          if (history.dataPoints.isNotEmpty) ...[
            const _SectionTitle('ALL RESULTS'),
            const SizedBox(height: 12),
            for (final dp in history.dataPoints.reversed)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: getTierColor(dp.tier),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(dp.date ?? '',
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 14,
                              fontWeight: FontWeight.w500)),
                      if (dp.labProvider != null) ...[
                        const SizedBox(width: 8),
                        Text(dp.labProvider!,
                            style: TextStyle(
                                color: cs.onSurfaceVariant, fontSize: 11)),
                      ],
                      const Spacer(),
                      Text(_formatValue(dp.value),
                          style: TextStyle(
                              color: getTierColor(dp.tier),
                              fontSize: 16,
                              fontWeight: FontWeight.w800)),
                      const SizedBox(width: 4),
                      Text(history.unit,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 11)),
                    ],
                  ),
                ),
              ),
          ],

          const SizedBox(height: 40),
        ],
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

// ── Trend Badge ─────────────────────────────────────────────────────────────

class _TrendBadge extends StatelessWidget {
  final String direction;
  final double? velocity;
  final bool? isImproving;
  const _TrendBadge({required this.direction, this.velocity, this.isImproving});

  @override
  Widget build(BuildContext context) {
    final List<List<dynamic>> icon;
    final Color color;
    final String label;

    switch (direction) {
      case 'rising':
        icon = HugeIcons.strokeRoundedChartIncrease;
        color = isImproving == true ? kOptimalColor : kCriticalColor;
        label = isImproving == true ? 'Improving' : 'Rising';
        break;
      case 'falling':
        icon = HugeIcons.strokeRoundedChartDecrease;
        color = isImproving == true ? kOptimalColor : kCriticalColor;
        label = isImproving == true ? 'Improving' : 'Declining';
        break;
      case 'stable':
        icon = HugeIcons.strokeRoundedMinusSign;
        color = kSufficientColor;
        label = 'Stable';
        break;
      default:
        return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, color: color, size: 16),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Trend Summary Card ──────────────────────────────────────────────────────

class _TrendSummaryCard extends StatelessWidget {
  final BiomarkerHistory history;
  const _TrendSummaryCard({required this.history});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = history.isImproving == true
        ? kOptimalColor
        : history.isImproving == false
            ? kCriticalColor
            : kSufficientColor;

    final dirLabel = switch (history.direction) {
      'lower_better' => 'Lower is better',
      'higher_better' => 'Higher is better',
      _ => 'Balance matters',
    };

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, color: color, size: 20),
                const SizedBox(width: 8),
                Text('Trend Analysis',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _TrendInfoChip(
                  label: 'Direction',
                  value: history.trendDirection ?? 'stable',
                  color: color,
                ),
                const SizedBox(width: 8),
                if (history.responsiveness != null)
                  _TrendInfoChip(
                    label: 'Response',
                    value: history.responsiveness!,
                    color: cs.primary,
                  ),
                const SizedBox(width: 8),
                _TrendInfoChip(
                  label: 'Type',
                  value: dirLabel,
                  color: cs.onSurfaceVariant,
                ),
              ],
            ),
            if (history.trendVelocity != null) ...[
              const SizedBox(height: 8),
              Text(
                'Rate of change: ${history.trendVelocity!.toStringAsFixed(1)}% per report',
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TrendInfoChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _TrendInfoChip({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

// ── Nutrient Connections Card ───────────────────────────────────────────────

class _NutrientConnectionsCard extends StatelessWidget {
  final List<NutrientConnection> connections;
  const _NutrientConnectionsCard({required this.connections});

  List<List<dynamic>> _relationshipIcon(String rel) => switch (rel) {
        'increases' => HugeIcons.strokeRoundedArrowUp01,
        'decreases' => HugeIcons.strokeRoundedArrowDown01,
        'supports' => HugeIcons.strokeRoundedFavourite,
        _ => HugeIcons.strokeRoundedLink01,
      };

  Color _strengthColor(String strength) => switch (strength) {
        'strong' => kOptimalColor,
        'moderate' => kSufficientColor,
        'weak' => kUnknownTierColor,
        _ => kUnknownTierColor,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedLeaf01, color: kOptimalColor, size: 18),
                const SizedBox(width: 8),
                Text('Nutrients that affect this biomarker',
                    style: TextStyle(
                        color: cs.onSurface,
                        fontSize: 13,
                        fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 12),
            for (final conn in connections)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    HugeIcon(icon: _relationshipIcon(conn.relationship),
                        color: _strengthColor(conn.strength), size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(conn.nutrientName ?? conn.nutrientTagname,
                              style: TextStyle(
                                  color: cs.onSurface,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600)),
                          Text('${conn.relationship} | ${conn.strength} evidence',
                              style: TextStyle(
                                  color: cs.onSurfaceVariant, fontSize: 11)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _strengthColor(conn.strength).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(conn.strength.toUpperCase(),
                          style: TextStyle(
                              color: _strengthColor(conn.strength),
                              fontSize: 9,
                              fontWeight: FontWeight.w700)),
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

// ── Related Biomarkers Card ──────────────────────────────────────────────────

class _RelatedBiomarkersCard extends StatelessWidget {
  final List<RelatedBiomarker> related;
  const _RelatedBiomarkersCard({required this.related});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: related.map((r) => GestureDetector(
        onTap: () => context.push('/health/labs/biomarker/${r.code}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: cs.surfaceContainerLow,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedMicroscope, color: cs.primary, size: 16),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.name,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 12,
                          fontWeight: FontWeight.w600)),
                  if (r.healthPillar != null)
                    Text(r.healthPillar!,
                        style: TextStyle(
                            color: cs.onSurfaceVariant, fontSize: 10)),
                ],
              ),
              const SizedBox(width: 4),
              HugeIcon(icon: HugeIcons.strokeRoundedArrowRight01,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5), size: 16),
            ],
          ),
        ),
      )).toList(),
    );
  }
}

// ── Recommendation Card ─────────────────────────────────────────────────────

class _RecommendationCard extends StatelessWidget {
  final BiomarkerRecommendation rec;
  const _RecommendationCard({required this.rec});

  List<List<dynamic>> _categoryIcon(String category) => switch (category) {
        'diet' => HugeIcons.strokeRoundedRestaurant01,
        'supplement' => HugeIcons.strokeRoundedMedicine01,
        'lifestyle' => HugeIcons.strokeRoundedYoga01,
        'exercise' => HugeIcons.strokeRoundedDumbbell01,
        'medical' => HugeIcons.strokeRoundedHospital01,
        _ => HugeIcons.strokeRoundedBulb,
      };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: cs.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: HugeIcon(icon: _categoryIcon(rec.category),
                      color: cs.primary, size: 16),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(rec.title,
                      style: TextStyle(
                          color: cs.onSurface,
                          fontSize: 14,
                          fontWeight: FontWeight.w700)),
                ),
                if (rec.impactScore != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kOptimalColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text('${(rec.impactScore! * 10).round()}/10',
                        style: const TextStyle(
                            color: kOptimalColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (rec.description != null) ...[
              const SizedBox(height: 8),
              Text(rec.description!,
                  style: TextStyle(
                      color: cs.onSurfaceVariant,
                      fontSize: 13,
                      height: 1.4)),
            ],
            if (rec.mechanism != null) ...[
              const SizedBox(height: 6),
              Text('How: ${rec.mechanism}',
                  style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                      height: 1.3)),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                if (rec.evidenceGrade != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(rec.evidenceGrade!,
                        style: TextStyle(
                            color: cs.onSurfaceVariant,
                            fontSize: 9,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section Title ────────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: cs.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(text,
            style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5)),
      ],
    );
  }
}

// ── Population Comparison Card ───────────────────────────────────────────────

class _PopulationComparison extends StatelessWidget {
  final double yourValue;
  final double populationAvg;
  final String unit;
  final String? tier;
  final BiomarkerRange? ranges;

  const _PopulationComparison({
    required this.yourValue,
    required this.populationAvg,
    required this.unit,
    this.tier,
    this.ranges,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierColor = getTierColor(tier);
    final diff = yourValue - populationAvg;
    final diffPercent = populationAvg != 0 ? (diff / populationAvg * 100) : 0.0;
    final isAbove = diff > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _ComparisonBar(
              yourValue: yourValue,
              populationAvg: populationAvg,
              ranges: ranges,
              tierColor: tierColor,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Your Value',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(_fmt(yourValue),
                          style: TextStyle(
                              color: tierColor,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text(unit,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 10)),
                    ],
                  ),
                ),
                Container(
                  width: 1,
                  height: 50,
                  color: cs.outlineVariant.withValues(alpha: 0.3),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Population Avg',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Text(_fmt(populationAvg),
                          style: TextStyle(
                              color: cs.onSurface,
                              fontSize: 22,
                              fontWeight: FontWeight.w800)),
                      Text(unit,
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 10)),
                    ],
                  ),
                ),
                Expanded(
                  child: Column(
                    children: [
                      Text('Difference',
                          style: TextStyle(
                              color: cs.onSurfaceVariant,
                              fontSize: 11,
                              fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          HugeIcon(icon: 
                            isAbove ? HugeIcons.strokeRoundedArrowUp01 : HugeIcons.strokeRoundedArrowDown01,
                            color: tierColor,
                            size: 16,
                          ),
                          Text('${diffPercent.abs().toStringAsFixed(0)}%',
                              style: TextStyle(
                                  color: tierColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800)),
                        ],
                      ),
                      Text(isAbove ? 'above avg' : 'below avg',
                          style: TextStyle(
                              color: cs.onSurfaceVariant, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    if (v < 10) return v.toStringAsFixed(2);
    if (v < 100) return v.toStringAsFixed(1);
    return v.toInt().toString();
  }
}

// ── Comparison Bar ───────────────────────────────────────────────────────────

class _ComparisonBar extends StatelessWidget {
  final double yourValue;
  final double populationAvg;
  final BiomarkerRange? ranges;
  final Color tierColor;

  const _ComparisonBar({
    required this.yourValue,
    required this.populationAvg,
    this.ranges,
    required this.tierColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: 40,
      child: LayoutBuilder(builder: (context, constraints) {
        final barWidth = constraints.maxWidth;

        double low = ranges?.standardLow ?? (populationAvg * 0.5);
        double high = ranges?.standardHigh ?? (populationAvg * 1.5);
        final range = high - low;
        if (range <= 0) return const SizedBox();

        double yourPos = ((yourValue - low) / range * 0.7 + 0.15).clamp(0.02, 0.98);
        double avgPos = ((populationAvg - low) / range * 0.7 + 0.15).clamp(0.02, 0.98);

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 16,
              height: 8,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: CustomPaint(
                  painter: _GradientBarPainter(),
                ),
              ),
            ),
            Positioned(
              left: avgPos * barWidth - 6,
              top: 26,
              child: Column(
                children: [
                  CustomPaint(
                    size: const Size(12, 8),
                    painter: _TrianglePainter(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 2),
                  Text('Avg', style: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 9, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Positioned(
              left: yourPos * barWidth - 7,
              top: 9,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: tierColor,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: tierColor.withValues(alpha: 0.4),
                      blurRadius: 6,
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

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _TrianglePainter old) => old.color != color;
}

// ── Large Range Bar ──────────────────────────────────────────────────────────

class _LargeRangeBar extends StatelessWidget {
  final BiomarkerRange ranges;
  final double? currentValue;
  final String unit;

  const _LargeRangeBar({
    required this.ranges,
    this.currentValue,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 28,
              child: LayoutBuilder(builder: (context, constraints) {
                final barWidth = constraints.maxWidth;
                double position = 0.5;

                if (currentValue != null &&
                    ranges.standardLow != null &&
                    ranges.standardHigh != null) {
                  final low = ranges.standardLow!;
                  final high = ranges.standardHigh!;
                  final range = high - low;
                  if (range > 0) {
                    final normalized = (currentValue! - low) / range;
                    position = 0.15 + normalized * 0.7;
                    position = position.clamp(0.02, 0.98);
                  }
                }

                final markerX = position * barWidth;
                final tierColor = currentValue != null ? _classifyValue(currentValue!) : kUnknownTierColor;

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 10,
                      height: 8,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: CustomPaint(
                          painter: _GradientBarPainter(),
                        ),
                      ),
                    ),
                    if (currentValue != null)
                      Positioned(
                        left: markerX - 7,
                        top: 7,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tierColor,
                            border: Border.all(color: Colors.white, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: tierColor.withValues(alpha: 0.4),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                );
              }),
            ),

            const SizedBox(height: 16),

            _RangeRow('Optimal', ranges.optimalLow, ranges.optimalHigh,
                unit, kOptimalColor),
            _RangeRow('Sufficient', ranges.sufficientLow,
                ranges.sufficientHigh, unit, kSufficientColor),
            _RangeRow('Standard', ranges.standardLow, ranges.standardHigh,
                unit, kSuboptimalColor),
          ],
        ),
      ),
    );
  }

  Color _classifyValue(double value) {
    if (_inRange(value, ranges.optimalLow, ranges.optimalHigh)) return kOptimalColor;
    if (_inRange(value, ranges.sufficientLow, ranges.sufficientHigh)) return kSufficientColor;
    if (_inRange(value, ranges.standardLow, ranges.standardHigh)) return kSuboptimalColor;
    return kCriticalColor;
  }

  bool _inRange(double v, double? low, double? high) {
    if (low == null && high == null) return false;
    if (low != null && v < low) return false;
    if (high != null && v > high) return false;
    return true;
  }
}

class _RangeRow extends StatelessWidget {
  final String label;
  final double? low;
  final double? high;
  final String unit;
  final Color color;

  const _RangeRow(this.label, this.low, this.high, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final range = low != null && high != null
        ? '${_fmt(low!)} - ${_fmt(high!)} $unit'
        : low != null
            ? '> ${_fmt(low!)} $unit'
            : high != null
                ? '< ${_fmt(high!)} $unit'
                : '--';
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 80,
            child: Text(label,
                style: TextStyle(
                    color: cs.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Text(range,
              style: TextStyle(
                  color: cs.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(1);
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
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    canvas.drawRRect(rrect, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ── History Chart ────────────────────────────────────────────────────────────

class _HistoryChart extends StatelessWidget {
  final List<BiomarkerDataPoint> dataPoints;
  final BiomarkerRange? ranges;
  final double? populationAvg;
  final String unit;

  const _HistoryChart({
    required this.dataPoints,
    this.ranges,
    this.populationAvg,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final spots = <FlSpot>[];
    for (int i = 0; i < dataPoints.length; i++) {
      spots.add(FlSpot(i.toDouble(), dataPoints[i].value));
    }

    final values = dataPoints.map((d) => d.value).toList();
    double minY = values.reduce((a, b) => a < b ? a : b) * 0.85;
    double maxY = values.reduce((a, b) => a > b ? a : b) * 1.15;

    if (populationAvg != null) {
      if (populationAvg! < minY) minY = populationAvg! * 0.85;
      if (populationAvg! > maxY) maxY = populationAvg! * 1.15;
    }

    final rangeAnnotations = <HorizontalRangeAnnotation>[];
    if (ranges != null) {
      if (ranges!.optimalLow != null && ranges!.optimalHigh != null) {
        rangeAnnotations.add(HorizontalRangeAnnotation(
          y1: ranges!.optimalLow!.clamp(minY, maxY),
          y2: ranges!.optimalHigh!.clamp(minY, maxY),
          color: kOptimalColor.withValues(alpha: 0.08),
        ));
      }
    }

    final extraLines = <HorizontalLine>[];
    if (populationAvg != null) {
      extraLines.add(HorizontalLine(
        y: populationAvg!,
        color: cs.onSurfaceVariant.withValues(alpha: 0.3),
        strokeWidth: 1,
        dashArray: [6, 4],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topRight,
          style: TextStyle(
            color: cs.onSurfaceVariant,
            fontSize: 9,
            fontWeight: FontWeight.w600,
          ),
          labelResolver: (_) => 'Avg',
        ),
      ));
    }

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: ChartStyle.grid,
        extraLinesData: ExtraLinesData(horizontalLines: extraLines),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 50,
              getTitlesWidget: (value, meta) => Text(
                value.toStringAsFixed(1),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i < 0 || i >= dataPoints.length) return const SizedBox();
                final dp = dataPoints[i];
                final label = dp.date != null && dp.date!.length >= 10
                    ? dp.date!.substring(5, 10)
                    : '';
                return Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(label,
                      style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant)),
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: ChartStyle.border,
        rangeAnnotations: RangeAnnotations(
          horizontalRangeAnnotations: rangeAnnotations,
        ),
        lineBarsData: [
          ChartStyle.dataLine(
            spots,
            dotPainterFn: (spot, percent, barData, index) {
              final isLast = index == spots.length - 1;
              final tier = index < dataPoints.length
                  ? dataPoints[index].tier
                  : null;
              if (isLast) {
                // Glowing latest dot colored by tier
                return ChartStyle.dotPainter(spot, percent, barData, index,
                    overrideColor: getTierColor(tier));
              }
              return FlDotCirclePainter(
                radius: ChartStyle.historicalDotRadius,
                color: getTierColor(tier),
                strokeWidth: 1.5,
                strokeColor: cs.surface,
              );
            },
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => cs.surfaceContainerHighest,
            tooltipRoundedRadius: 10,
            getTooltipItems: (touchedSpots) => touchedSpots.map((spot) {
              final i = spot.spotIndex;
              final dp = dataPoints[i];
              return LineTooltipItem(
                '${dp.value} $unit\n${dp.date ?? ''}',
                TextStyle(color: cs.onSurface, fontSize: 12),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}
