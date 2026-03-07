import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/insight_data.dart';

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
    _tabs = TabController(length: 3, vsync: this);
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
        title: const Text('AI Insights'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Weekly'),
            Tab(text: 'Flare Risk'),
            Tab(text: 'Ask AI'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _investigating = false);
    }
  }
}

// ── Weekly Insights Tab ──────────────────────────────────────────────────────

class _WeeklyTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(weeklyInsightProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (insight) {
        if (insight == null) {
          return const Center(child: Text('No insights yet — log more data!',
              style: TextStyle(color: Colors.grey)));
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Source badge
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: insight.source == 'ai' ? Colors.purple.withOpacity(0.1) : Colors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(insight.source == 'ai' ? Icons.auto_awesome : Icons.bar_chart,
                          size: 14, color: insight.source == 'ai' ? Colors.purple : Colors.teal),
                      const SizedBox(width: 4),
                      Text(insight.source == 'ai' ? 'AI-Powered' : 'Statistical Analysis',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                              color: insight.source == 'ai' ? Colors.purple : Colors.teal)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Insight cards
            ...insight.insights.map((i) => _InsightCard(item: i)),
            const SizedBox(height: 16),

            // Recommendations
            if (insight.recommendations.isNotEmpty) ...[
              Text('Recommendations', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...insight.recommendations.map((r) {
                final color = r.priority == 'high' ? Colors.red
                    : (r.priority == 'medium' ? Colors.orange : Colors.green);
                return Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(Icons.lightbulb_outline, color: color, size: 20),
                    title: Text(r.action, style: const TextStyle(fontSize: 13)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(r.priority.toUpperCase(),
                          style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
                    ),
                  ),
                );
              }),
            ],

            const SizedBox(height: 16),
            Text('This is not medical advice. Consult your dermatologist.',
                style: TextStyle(fontSize: 10, color: Colors.grey[500], fontStyle: FontStyle.italic),
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
                Icon(Icons.insights, size: 18, color: cs.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(item.title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                if (item.confidence > 0)
                  Text('${(item.confidence * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
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
      error: (e, _) => Center(child: Text('Error: $e')),
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
            // Big gauge
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
                        backgroundColor: Colors.grey.withOpacity(0.15),
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

            // Contributing factors
            if (risk.factors.isNotEmpty) ...[
              Text('Contributing Factors', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...risk.factors.map((f) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 36,
                      child: Text('+${f.contribution}',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color))),
                    const SizedBox(width: 8),
                    Expanded(child: Text(f.detail, style: const TextStyle(fontSize: 13))),
                  ],
                ),
              )),
            ],
            const SizedBox(height: 20),

            // Recommendations
            if (risk.recommendations.isNotEmpty) ...[
              Text('What You Can Do', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              ...risk.recommendations.map((r) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: const Icon(Icons.tips_and_updates, size: 20, color: Colors.amber),
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
        Text('Ask about your eczema triggers',
            style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 4),
        Text('Ask questions like "Why was my skin bad last Tuesday?" or "What triggers my flares?"',
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
              : const Icon(Icons.psychology),
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
                  Row(
                    children: [
                      Icon(result!.source == 'ai' ? Icons.auto_awesome : Icons.bar_chart,
                          size: 16, color: Colors.purple),
                      const SizedBox(width: 6),
                      Text(result!.source == 'ai' ? 'AI Analysis' : 'Statistical Analysis',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const Spacer(),
                      Text('${(result!.confidence * 100).toInt()}% confidence',
                          style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                    ],
                  ),
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
                        color: Colors.blue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.lightbulb, size: 16, color: Colors.blue),
                          const SizedBox(width: 8),
                          Expanded(child: Text(result!.recommendation!,
                              style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text('This is not medical advice.',
                      style: TextStyle(fontSize: 9, color: Colors.grey[500], fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}
