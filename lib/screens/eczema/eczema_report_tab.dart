import 'package:flutter/material.dart';
import '../../models/eczema_log.dart';
import '../../models/easi_models.dart';
import '../../models/environment_data.dart';
import '../../models/smart_correlation_data.dart';
import '../../providers/eczema_provider.dart';
import '../../widgets/eczema_body_map.dart';
import '../../widgets/environment_card.dart' hide FlareRiskGauge;
import '../../widgets/smart_correlation_card.dart';
import '../../widgets/calendar_heatmap.dart';
import '../../widgets/flare_risk_gauge.dart';
import '../../widgets/trigger_radar_chart.dart';
import '../../widgets/causation_chain.dart';
import '../../widgets/what_if_simulator.dart';
import '../../widgets/swipeable_insight_cards.dart';
import 'eczema_helpers.dart';
import 'package:hugeicons/hugeicons.dart';

// ─── Report content widget ────────────────────────────────────────────────────

class ReportContent extends StatelessWidget {
  final EczemaHeatmapData heatData;
  final List<EczemaLogSummary> logs;
  final int days;
  final FoodCorrelationData? foodCorrelation;
  final VoidCallback onExportPdf;
  final EnvironmentCorrelation? envCorrelation;
  final SmartCorrelationResult? smartCorrelation;

  const ReportContent({
    super.key,
    required this.heatData,
    required this.logs,
    required this.days,
    this.foodCorrelation,
    required this.onExportPdf,
    this.envCorrelation,
    this.smartCorrelation,
  });

  static Color _itchColor(double avgItch) {
    if (avgItch <= 0) return const Color(0xFF9E9E9E);
    if (avgItch <= 2) return const Color(0xFF66BB6A);
    if (avgItch <= 4) return const Color(0xFFFDD835);
    if (avgItch <= 6) return const Color(0xFFFF9800);
    if (avgItch <= 8) return const Color(0xFFF4511E);
    return const Color(0xFFB71C1C);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Compute stats
    final itchValues = logs
        .where((l) => l.itchSeverity != null)
        .map((l) => l.itchSeverity!)
        .toList();
    final avgItch = itchValues.isEmpty
        ? 0.0
        : itchValues.reduce((a, b) => a + b) / itchValues.length;
    final maxItch = itchValues.isEmpty
        ? 0
        : itchValues.reduce((a, b) => a > b ? a : b);
    final sleepDisrupted = logs.where((l) => l.sleepDisrupted == true).length;
    final easiScores = logs.map((l) => l.easiScore).toList();
    final avgEasi = easiScores.isEmpty
        ? 0.0
        : easiScores.reduce((a, b) => a + b) / easiScores.length;

    // Compute per-zone itch averages
    final zoneItchSum = <String, double>{};
    final zoneItchCount = <String, int>{};
    for (final log in logs) {
      final itch = log.itchSeverity ?? 0;
      for (final zoneId in log.parsedAreas.keys) {
        zoneItchSum[zoneId] = (zoneItchSum[zoneId] ?? 0) + itch;
        zoneItchCount[zoneId] = (zoneItchCount[zoneId] ?? 0) + 1;
      }
    }
    final zoneAvgItch = <String, double>{};
    for (final id in zoneItchSum.keys) {
      zoneAvgItch[id] = zoneItchSum[id]! / zoneItchCount[id]!;
    }

    // Sort zones by avg itch descending
    final sortedZones = zoneAvgItch.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Heatmap Body Map ──────────────────────────────────
          Card(
            clipBehavior: Clip.hardEdge,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                children: [
                  Row(children: [
                    const SizedBox(width: 8),
                    Text('Itch Severity Heatmap',
                        style: Theme.of(context).textTheme.titleSmall),
                    const Spacer(),
                    Text('Last $days days',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(width: 8),
                  ]),
                  const SizedBox(height: 4),
                  EczemaBodyMap(
                    heatData: heatData.regionIntensity,
                    readOnly: true,
                  ),
                ],
              ),
            ),
          ),

          // ── Itch Severity Legend ─────────────────────────────
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Itch Severity Scale',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (final entry in [
                        (0.0, 'None'),
                        (2.0, 'Mild'),
                        (4.0, 'Moderate'),
                        (6.0, 'Significant'),
                        (8.0, 'Severe'),
                        (10.0, 'Extreme'),
                      ])
                        Expanded(
                          child: Column(children: [
                            Container(
                              height: 8,
                              margin: const EdgeInsets.symmetric(horizontal: 1),
                              decoration: BoxDecoration(
                                color: _itchColor(entry.$1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(entry.$2,
                                style: const TextStyle(fontSize: 11),
                                textAlign: TextAlign.center),
                          ]),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // ── Key Stats ──────────────────────────────────────
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: StatCard(
              label: 'Entries',
              value: '${logs.length}',
              color: cs.primary,
            )),
            const SizedBox(width: 8),
            Expanded(child: StatCard(
              label: 'Avg Itch',
              value: avgItch.toStringAsFixed(1),
              color: _itchColor(avgItch),
            )),
            const SizedBox(width: 8),
            Expanded(child: StatCard(
              label: 'Peak Itch',
              value: '$maxItch/10',
              color: _itchColor(maxItch.toDouble()),
            )),
            const SizedBox(width: 8),
            Expanded(child: StatCard(
              label: 'Sleep',
              value: '$sleepDisrupted',
              subtitle: 'disrupted',
              color: sleepDisrupted > 0 ? Colors.indigo : Colors.green,
            )),
          ]),

          // ── Avg EASI ────────────────────────────────────────
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Text('Avg EASI Score',
                    style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: easiColor(avgEasi).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: easiColor(avgEasi).withValues(alpha: 0.5)),
                  ),
                  child: Text(
                    '${avgEasi.toStringAsFixed(1)} — ${easiLabel(avgEasi)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: easiColor(avgEasi),
                    ),
                  ),
                ),
              ]),
            ),
          ),

          // ── Most Affected Areas (color-coded by itch) ──────
          if (sortedZones.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Most Affected Areas',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text('Color shows average itch severity for each zone',
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            ...sortedZones.take(12).map((e) {
              final region = findRegion(e.key);
              final label = region?.label ?? e.key;
              final avgI = e.value;
              final count = zoneItchCount[e.key] ?? 0;
              final color = _itchColor(avgI);
              final pct = logs.isEmpty ? 0 : (count / logs.length * 100).round();

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  // Color indicator
                  Container(
                    width: 12, height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 110,
                    child: Text(label,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                  ),
                  // Itch bar
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (avgI / 10.0).clamp(0.0, 1.0),
                        minHeight: 10,
                        backgroundColor: color.withValues(alpha: 0.10),
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 85,
                    child: Text(
                      '${avgI.toStringAsFixed(1)}/10 · $pct%',
                      style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              );
            }),
          ],

          // ── Food Correlation Insights ──────────────────────
          if (foodCorrelation != null && foodCorrelation!.badFoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedRestaurant01, size: 18, color: Colors.red),
                    const SizedBox(width: 6),
                    Text('Suspected Trigger Foods',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Colors.red.shade700)),
                  ]),
                  const SizedBox(height: 4),
                  Text(
                    'Foods correlated with higher itch scores (eaten 0–2 days before flares)',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  ...foodCorrelation!.badFoods.take(3).map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: Colors.red.shade400,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(f.foodName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text(
                            'Avg itch ${f.avgItchWith}/10 when eaten vs ${f.avgItchWithout}/10 without  ·  ${f.timesEaten}× eaten',
                            style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                          ),
                        ]),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text('+${f.correlationScore}',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold,
                                color: Colors.red.shade700)),
                      ),
                    ]),
                  )),
                ]),
              ),
            ),

            if (foodCorrelation!.goodFoods.isNotEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedLeaf01, size: 18, color: Colors.green),
                      const SizedBox(width: 6),
                      Text('Foods with Lower Itch',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: Colors.green.shade700)),
                    ]),
                    const SizedBox(height: 8),
                    ...foodCorrelation!.goodFoods.take(3).map((f) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Container(
                          width: 10, height: 10,
                          decoration: BoxDecoration(
                            color: Colors.green.shade400,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f.foodName,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                        Text(
                          '${f.avgItchWith}/10 vs ${f.avgItchWithout}/10',
                          style: TextStyle(fontSize: 11, color: Colors.green.shade600),
                        ),
                      ]),
                    )),
                  ]),
                ),
              ),
          ],

          // ── Phase 1: Environmental Triggers ──────────────────
          const SizedBox(height: 16),
          if (envCorrelation != null)
            EnvironmentCorrelationCard(correlation: envCorrelation!)
          else
            const EmptyAnalysisCard(
              icon: HugeIcons.strokeRoundedCloud,
              title: 'Environmental Triggers',
              message: 'Save eczema logs to auto-capture weather data. '
                  'Location permission is needed to track temperature, '
                  'humidity, pollen, and air quality alongside your flares.',
            ),

          // ── Phase 2: Smart Food Correlation ──────────────────
          const SizedBox(height: 16),
          if (smartCorrelation != null)
            SmartCorrelationCard(result: smartCorrelation!)
          else
            const EmptyAnalysisCard(
              icon: HugeIcons.strokeRoundedBrain,
              title: 'Smart Food Analysis',
              message: 'Log both eczema and nutrition data to unlock '
                  'AI-powered food trigger analysis with Bayesian '
                  'probabilities, lag detection, and combination triggers.',
            ),

          // ── Phase 6: Calendar Heatmap ──────────────────────
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 18, color: cs.primary),
                    const SizedBox(width: 6),
                    Text('Severity Calendar',
                        style: Theme.of(context).textTheme.titleSmall),
                  ]),
                  const SizedBox(height: 4),
                  Text('Daily itch severity over the last $days days',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 10),
                  CalendarHeatmap(
                    data: {
                      for (final log in logs)
                        if (log.itchSeverity != null)
                          log.logDate: log.itchSeverity!.toDouble(),
                    },
                    days: days,
                  ),
                ],
              ),
            ),
          ),

          // ── Phase 6: Flare Risk Gauge ──────────────────────
          if (envCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  Text('Flare Risk Score',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  Center(child: FlareRiskGauge(score: envCorrelation!.flareRiskScore)),
                  const SizedBox(height: 8),
                  if (envCorrelation!.topTrigger != null)
                    Text('Top trigger: ${envCorrelation!.topTrigger}',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                ]),
              ),
            ),
          ],

          // ── Phase 6: Trigger Profile Radar ─────────────────
          if (smartCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  Text('Trigger Profile',
                      style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text('Which categories contribute most to your flares',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                  const SizedBox(height: 12),
                  Center(child: TriggerRadarChart(
                    food: _triggerAxisValue(smartCorrelation!.categoryCorrelations),
                    environment: envCorrelation != null
                        ? (envCorrelation!.flareRiskScore / 100).clamp(0.0, 1.0)
                        : 0,
                    products: 0, // would need product correlation data
                    stress: _stressAxisValue(logs),
                    sleep: _sleepAxisValue(logs),
                  )),
                ]),
              ),
            ),
          ],

          // ── Phase 6: Causation Chain ────────────────────────
          if (logs.length >= 2 && foodCorrelation != null && foodCorrelation!.badFoods.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedActivity01, size: 18, color: Colors.deepPurple),
                      const SizedBox(width: 6),
                      Text('Recent Causation Chain',
                          style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Text('Suspected food triggers leading to flares',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    CausationChainTimeline(events: _buildCausationEvents(logs, foodCorrelation!)),
                  ],
                ),
              ),
            ),
          ],

          // ── Phase 6: What-If Simulator ─────────────────────
          if (smartCorrelation != null && smartCorrelation!.bayesianTriggers.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedTestTube01, size: 18, color: Colors.indigo),
                      const SizedBox(width: 6),
                      Text('What-If Simulator',
                          style: Theme.of(context).textTheme.titleSmall),
                    ]),
                    const SizedBox(height: 4),
                    Text('See how avoiding triggers might help',
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    WhatIfSimulator(
                      currentAvgItch: avgItch,
                      scenarios: _buildWhatIfScenarios(smartCorrelation!, avgItch),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Phase 6: Swipeable Insight Cards ───────────────
          if (smartCorrelation != null || envCorrelation != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Insights', style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(height: 8),
                    SwipeableInsightCards(
                      insights: _buildSwipeInsights(
                        smartCorrelation, envCorrelation, avgItch, logs.length,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          // ── Export button ──────────────────────────────────
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedFile01),
              label: const Text('Export PDF Report'),
              onPressed: onExportPdf,
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 6 helper methods ──────────────────────────────────────────────────

  static double _triggerAxisValue(List<CategoryCorrelation> cats) {
    if (cats.isEmpty) return 0;
    final maxRisk = cats.map((c) => c.riskMultiplier).reduce((a, b) => a > b ? a : b);
    return (maxRisk / 3).clamp(0.0, 1.0); // normalize: 3x = full
  }

  static double _stressAxisValue(List<EczemaLogSummary> logs) {
    final stressLogs = logs.where((l) => l.stressLevel != null && l.stressLevel! > 0).toList();
    if (stressLogs.isEmpty) return 0;
    final avg = stressLogs.map((l) => l.stressLevel!).reduce((a, b) => a + b) / stressLogs.length;
    return (avg / 10).clamp(0.0, 1.0);
  }

  static double _sleepAxisValue(List<EczemaLogSummary> logs) {
    final disrupted = logs.where((l) => l.sleepDisrupted == true).length;
    if (logs.isEmpty) return 0;
    return (disrupted / logs.length).clamp(0.0, 1.0);
  }

  static List<CausationEvent> _buildCausationEvents(
      List<EczemaLogSummary> logs, FoodCorrelationData foodData) {
    final events = <CausationEvent>[];
    // Take last 5 logs and create a simplified chain
    final recent = logs.take(5).toList();
    for (final log in recent.reversed) {
      final date = DateTime.tryParse(log.logDate) ?? DateTime.now();
      final itch = log.itchSeverity ?? 0;
      final triggers = <String>[];
      if (log.dairyConsumed == true) triggers.add('DAIRY');
      if (log.eggsConsumed == true) triggers.add('EGGS');
      if (log.nutsConsumed == true) triggers.add('NUTS');
      if (log.wheatConsumed == true) triggers.add('WHEAT');

      if (triggers.isNotEmpty || itch >= 5) {
        events.add(CausationEvent(
          dateTime: date,
          title: itch >= 5 ? 'Flare: Itch $itch/10' : 'Triggers logged',
          subtitle: triggers.isEmpty ? 'No specific triggers flagged' : triggers.join(', '),
          tags: triggers,
          isFlare: itch >= 5,
          severity: itch.toDouble(),
        ));
      }
    }
    return events;
  }

  static List<WhatIfScenario> _buildWhatIfScenarios(
      SmartCorrelationResult smart, double currentAvg) {
    final scenarios = <WhatIfScenario>[];
    for (final trigger in smart.bayesianTriggers.take(4)) {
      if (trigger.posteriorProbability > 0.2) {
        final reduction = currentAvg * trigger.posteriorProbability * 0.5;
        scenarios.add(WhatIfScenario(
          label: 'Avoid ${trigger.displayName}',
          description: '${(trigger.posteriorProbability * 100).toInt()}% trigger probability',
          predictedItch: (currentAvg - reduction).clamp(0.0, 10.0),
          icon: HugeIcons.strokeRoundedRestaurant01,
        ));
      }
    }
    // Add sleep/stress scenarios
    if (currentAvg > 3) {
      scenarios.add(WhatIfScenario(
        label: 'Improve sleep quality',
        description: 'Get 7+ hours consistently',
        predictedItch: (currentAvg * 0.85).clamp(0.0, 10.0),
        icon: HugeIcons.strokeRoundedBed,
      ));
    }
    return scenarios;
  }

  static List<SwipeableInsight> _buildSwipeInsights(
      SmartCorrelationResult? smart, EnvironmentCorrelation? env,
      double avgItch, int logCount) {
    final insights = <SwipeableInsight>[];

    if (smart != null) {
      for (final cat in smart.categoryCorrelations.where((c) => c.significant).take(3)) {
        insights.add(SwipeableInsight(
          title: '${cat.displayName} increases itch ${cat.riskMultiplier.toStringAsFixed(1)}x',
          body: 'Avg itch ${cat.avgItchWith.toStringAsFixed(1)}/10 with ${cat.displayName} '
              'vs ${cat.avgItchWithout.toStringAsFixed(1)}/10 without.',
          icon: HugeIcons.strokeRoundedRestaurant01,
          color: Colors.red,
        ));
      }
      for (final bt in smart.bayesianTriggers.where((b) => b.confidence == 'confirmed').take(2)) {
        insights.add(SwipeableInsight(
          title: '${bt.displayName}: confirmed trigger',
          body: '${(bt.posteriorProbability * 100).toInt()}% probability based on ${bt.timesConsumed} observations.',
          icon: HugeIcons.strokeRoundedCheckmarkCircle01,
          color: Colors.deepOrange,
        ));
      }
    }

    if (env != null) {
      for (final f in env.factors.where((f) => f.significant).take(2)) {
        insights.add(SwipeableInsight(
          title: '${f.factor} affects your skin ${f.riskMultiplier.toStringAsFixed(1)}x',
          body: 'Itch is ${f.avgItchBad.toStringAsFixed(1)}/10 in bad conditions '
              'vs ${f.avgItchNormal.toStringAsFixed(1)}/10 normally.',
          icon: HugeIcons.strokeRoundedCloud,
          color: Colors.blue,
        ));
      }
    }

    if (logCount >= 7) {
      insights.add(SwipeableInsight(
        title: '$logCount entries logged!',
        body: "Your data is getting powerful. Keep logging for more accurate insights.",
        icon: HugeIcons.strokeRoundedChartIncrease,
        color: Colors.green,
      ));
    }

    if (insights.isEmpty) {
      insights.add(const SwipeableInsight(
        title: 'Keep logging!',
        body: 'More data means better insights. Try to log daily for the best results.',
        icon: HugeIcons.strokeRoundedEdit01,
      ));
    }

    return insights;
  }
}

// ─── Stat card for report ───────────────────────────────────────────────────

class EmptyAnalysisCard extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final String message;
  const EmptyAnalysisCard({super.key, required this.icon, required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                HugeIcon(icon: icon, color: cs.onSurfaceVariant, size: 20),
                const SizedBox(width: 8),
                Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedInformationCircle, size: 16, color: cs.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
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

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? subtitle;
  final Color color;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        child: Column(children: [
          Text(value,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color)),
          if (subtitle != null)
            Text(subtitle!,
                style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7))),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
