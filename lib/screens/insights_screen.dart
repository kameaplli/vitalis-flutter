import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/insight_data.dart';
import '../providers/selected_person_provider.dart';
import '../widgets/medical_disclaimer.dart';
import '../widgets/friendly_error.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final weeklyInsightProvider = FutureProvider<WeeklyInsight?>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.insightsWeekly);
    return WeeklyInsight.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final flareRiskPredictionProvider = FutureProvider<FlareRiskPrediction?>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.insightsFlareRisk);
    return FlareRiskPrediction.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

final healthReportProvider = FutureProvider.family<Map<String, dynamic>?, String>((ref, person) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.insightsHealthReport,
        queryParameters: {'person': person, 'days': 30});
    return res.data as Map<String, dynamic>;
  } catch (_) {
    return null;
  }
});

// ── Screen ───────────────────────────────────────────────────────────────────

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _questionCtrl = TextEditingController();
  bool _investigating = false;
  InvestigationResult? _investigationResult;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _questionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Report'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, size: 18), text: 'Report'),
            Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, size: 18), text: 'Weekly'),
            Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedAlert02, size: 18), text: 'Flare Risk'),
            Tab(icon: HugeIcon(icon: HugeIcons.strokeRoundedBrain, size: 18), text: 'Ask AI'),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _HealthReportTab(),
                _WeeklyTab(),
                _FlareRiskTab(),
                _AskAiTab(
                  questionCtrl: _questionCtrl,
                  investigating: _investigating,
                  result: _investigationResult,
                  onInvestigate: _investigate,
                ),
              ],
            ),
          ),
          const MedicalDisclaimer(),
        ],
      ),
    );
  }

  Future<void> _investigate() async {
    if (_questionCtrl.text.trim().isEmpty) return;
    setState(() {
      _investigating = true;
      _investigationResult = null;
    });
    try {
      final res = await apiClient.dio.post(ApiConstants.insightsInvestigate, data: {
        'question': _questionCtrl.text.trim(),
      });
      setState(() {
        _investigationResult = InvestigationResult.fromJson(res.data as Map<String, dynamic>);
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyErrorMessage(e, context: 'insights'))));
      }
    } finally {
      if (mounted) setState(() => _investigating = false);
    }
  }
}

// ── Holistic Health Report Tab ──────────────────────────────────────────────

class _HealthReportTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final person = ref.watch(selectedPersonProvider);
    final reportAsync = ref.watch(healthReportProvider(person));

    return reportAsync.when(
      loading: () => const Center(child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Analyzing your health data...', style: TextStyle(color: Colors.grey)),
        ],
      )),
      error: (e, _) => FriendlyError(error: e, context: 'health report'),
      data: (report) {
        if (report == null) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedChartLineData01, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text('Not enough data yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                SizedBox(height: 8),
                Text('Log symptoms, medications, supplements, and meals to get your holistic health report.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
              ],
            ),
          ));
        }

        final source = report['source'] ?? 'statistical';
        final insights = (report['insights'] as List<dynamic>?) ?? [];
        final correlations = (report['correlations'] as List<dynamic>?) ?? [];
        final predictions = (report['predictions'] as List<dynamic>?) ?? [];
        final recommendations = (report['recommendations'] as List<dynamic>?) ?? [];
        final summary = (report['data_summary'] as Map<String, dynamic>?) ?? {};

        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(healthReportProvider(person)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Source + Data summary
              _SourceBadge(source: source),
              const SizedBox(height: 12),
              _DataSummaryRow(summary: summary),
              const SizedBox(height: 16),

              // Insights
              if (insights.isNotEmpty) ...[
                const _SectionHeader(icon: HugeIcons.strokeRoundedBulb, title: 'Insights', color: Colors.amber),
                ...insights.map((i) => _ReportCard(
                  title: (i as Map<String, dynamic>)['title'] ?? '',
                  body: i['body'] ?? '',
                  iconName: i['icon'] as String?,
                  color: Colors.amber,
                )),
                const SizedBox(height: 12),
              ],

              // Correlations
              if (correlations.isNotEmpty) ...[
                const _SectionHeader(icon: HugeIcons.strokeRoundedExchange01, title: 'Correlations', color: Colors.deepPurple),
                ...correlations.map((c) {
                  final m = c as Map<String, dynamic>;
                  final confidence = (m['confidence'] as num?)?.toInt() ?? 0;
                  return _ReportCard(
                    title: m['title'] ?? '',
                    body: m['body'] ?? '',
                    trailing: confidence > 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.deepPurple.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('$confidence%',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.deepPurple)),
                          )
                        : null,
                    color: Colors.deepPurple,
                  );
                }),
                const SizedBox(height: 12),
              ],

              // Predictions
              if (predictions.isNotEmpty) ...[
                const _SectionHeader(icon: HugeIcons.strokeRoundedChartLineData01, title: 'Predictions', color: Colors.indigo),
                ...predictions.map((p) {
                  final m = p as Map<String, dynamic>;
                  return _ReportCard(
                    title: m['title'] ?? '',
                    body: m['body'] ?? '',
                    trailing: m['timeframe'] != null
                        ? Text(m['timeframe'], style: TextStyle(fontSize: 11, color: Colors.grey.shade500))
                        : null,
                    color: Colors.indigo,
                  );
                }),
                const SizedBox(height: 12),
              ],

              // Recommendations
              if (recommendations.isNotEmpty) ...[
                const _SectionHeader(icon: HugeIcons.strokeRoundedBulb, title: 'Recommendations', color: Colors.teal),
                ...recommendations.map((r) {
                  final m = r as Map<String, dynamic>;
                  final priority = m['priority'] ?? 'medium';
                  final pColor = priority == 'high' ? Colors.red
                      : priority == 'medium' ? Colors.orange : Colors.green;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    child: ListTile(
                      leading: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: pColor, size: 20),
                      title: Text(m['text'] ?? '', style: const TextStyle(fontSize: 13)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(priority.toString().toUpperCase(),
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: pColor)),
                      ),
                    ),
                  );
                }),
              ],

              const SizedBox(height: 20),
              Text('This is not medical advice. Consult your healthcare provider.',
                  style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center),
            ],
          ),
        );
      },
    );
  }
}

class _SourceBadge extends StatelessWidget {
  final String source;
  const _SourceBadge({required this.source});

  @override
  Widget build(BuildContext context) {
    final isAi = source == 'ai';
    final color = isAi ? Colors.purple : Colors.teal;
    return Row(children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: isAi ? HugeIcons.strokeRoundedStars : HugeIcons.strokeRoundedChartColumn, size: 14, color: color),
            const SizedBox(width: 4),
            Text(isAi ? 'AI-Powered Report' : 'Statistical Report',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    ]);
  }
}

class _DataSummaryRow extends StatelessWidget {
  final Map<String, dynamic> summary;
  const _DataSummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    if (summary.isEmpty) return const SizedBox.shrink();
    final items = <_SummaryItem>[
      if ((summary['weight_entries'] ?? 0) > 0)
        _SummaryItem(HugeIcons.strokeRoundedBodyWeight, '${summary['weight_entries']}', 'Weight'),
      if ((summary['symptom_entries'] ?? 0) > 0)
        _SummaryItem(HugeIcons.strokeRoundedThermometer, '${summary['symptom_entries']}', 'Symptoms'),
      if ((summary['nutrition_entries'] ?? 0) > 0)
        _SummaryItem(HugeIcons.strokeRoundedRestaurant01, '${summary['nutrition_entries']}', 'Meals'),
      if ((summary['active_medications'] ?? 0) > 0)
        _SummaryItem(HugeIcons.strokeRoundedMedicine01, '${summary['active_medications']}', 'Meds'),
      if ((summary['active_supplements'] ?? 0) > 0)
        _SummaryItem(HugeIcons.strokeRoundedTestTube01, '${summary['active_supplements']}', 'Supps'),
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final it = items[i];
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    HugeIcon(icon: it.icon, size: 14, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Text(it.value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  ],
                ),
                Text(it.label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryItem {
  final List<List<dynamic>> icon;
  final String value;
  final String label;
  const _SummaryItem(this.icon, this.value, this.label);
}

class _SectionHeader extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        HugeIcon(icon: icon, size: 18, color: color),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final String title;
  final String body;
  final String? iconName;
  final Widget? trailing;
  final Color color;
  const _ReportCard({required this.title, required this.body, this.iconName, this.trailing, required this.color});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                width: 4, height: 16,
                decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 8),
              Expanded(child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13))),
              if (trailing != null) trailing!,
            ]),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

// ── Weekly Insights Tab ──────────────────────────────────────────────────────

class _WeeklyTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyInsightProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'weekly insights'),
      data: (insight) {
        if (insight == null) {
          return const Center(child: Text('No insights yet — log more data!',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _SourceBadge(source: insight.source),
            const SizedBox(height: 16),
            ...insight.insights.map((i) => _InsightCard(item: i)),
            const SizedBox(height: 16),
            if (insight.recommendations.isNotEmpty) ...[
              Text('Recommendations', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...insight.recommendations.map((r) {
                final color = r.priority == 'high' ? Colors.red
                    : (r.priority == 'medium' ? Colors.orange : Colors.green);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: HugeIcon(icon: HugeIcons.strokeRoundedBulb, color: color, size: 20),
                    title: Text(r.action, style: const TextStyle(fontSize: 13)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(r.priority.toUpperCase(),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ),
                );
              }),
            ],
            const SizedBox(height: 16),
            Text('This is not medical advice. Consult your dermatologist.',
                style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic),
                textAlign: TextAlign.center),
          ],
        );
      },
    );
  }
}

class _InsightCard extends StatelessWidget {
  final InsightItem item;
  const _InsightCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedIdea01, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                if (item.confidence > 0)
                  Text('${(item.confidence * 100).toInt()}%',
                      style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            Text(item.body, style: const TextStyle(fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

// ── Flare Risk Tab ───────────────────────────────────────────────────────────

class _FlareRiskTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(flareRiskPredictionProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => FriendlyError(error: e, context: 'flare risk'),
      data: (risk) {
        if (risk == null) {
          return const Center(child: Text('Unable to predict flare risk — need more data',
              style: TextStyle(color: Colors.grey)));
        }
        final color = risk.score >= 60 ? Colors.red
            : (risk.score >= 30 ? Colors.orange : Colors.green);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: SizedBox(
                width: 160, height: 160,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: risk.score / 100,
                        strokeWidth: 14,
                        backgroundColor: Colors.grey.withValues(alpha: 0.15),
                        valueColor: AlwaysStoppedAnimation(color),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${risk.score}',
                            style: TextStyle(fontSize: 42, fontWeight: FontWeight.bold, color: color)),
                        Text(risk.level.toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            if (risk.factors.isNotEmpty) ...[
              Text('Contributing Factors', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...risk.factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  SizedBox(width: 36,
                    child: Text('+${f.contribution}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: color))),
                  const SizedBox(width: 8),
                  Expanded(child: Text(f.detail, style: const TextStyle(fontSize: 13))),
                ]),
              )),
            ],
            const SizedBox(height: 20),
            if (risk.recommendations.isNotEmpty) ...[
              Text('What You Can Do', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...risk.recommendations.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: HugeIcon(icon: HugeIcons.strokeRoundedBulb, size: 20, color: Colors.amber),
                  title: Text(r, style: const TextStyle(fontSize: 13)),
                ),
              )),
            ],
          ],
        );
      },
    );
  }
}

// ── Ask AI Tab ───────────────────────────────────────────────────────────────

class _AskAiTab extends StatelessWidget {
  final TextEditingController questionCtrl;
  final bool investigating;
  final InvestigationResult? result;
  final VoidCallback onInvestigate;

  const _AskAiTab({
    required this.questionCtrl,
    required this.investigating,
    required this.result,
    required this.onInvestigate,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Ask about your health',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('Ask questions like "Why did my weight increase?" or "Are my supplements helping?"',
            style: TextStyle(fontSize: 12, color: Colors.grey[600])),
        const SizedBox(height: 12),
        TextField(
          controller: questionCtrl,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Type your question...',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          icon: investigating
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : HugeIcon(icon: HugeIcons.strokeRoundedBrain),
          label: Text(investigating ? 'Analyzing...' : 'Investigate'),
          onPressed: investigating ? null : onInvestigate,
        ),
        if (result != null) ...[
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    HugeIcon(icon: result!.source == 'ai' ? HugeIcons.strokeRoundedStars : HugeIcons.strokeRoundedChartColumn,
                        size: 16, color: Colors.purple),
                    const SizedBox(width: 6),
                    Text(result!.source == 'ai' ? 'AI Analysis' : 'Statistical Analysis',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const Spacer(),
                    Text('${(result!.confidence * 100).toInt()}% confidence',
                        style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ]),
                  const SizedBox(height: 12),
                  Text(result!.answer, style: const TextStyle(fontSize: 13)),
                  if (result!.likelyTriggers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      children: result!.likelyTriggers.map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 11)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      )).toList(),
                    ),
                  ],
                  if (result!.recommendation != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedBulb, size: 16, color: Colors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(result!.recommendation!,
                            style: const TextStyle(fontSize: 12))),
                      ]),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('This is not medical advice.',
                      style: TextStyle(fontSize: 11, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
