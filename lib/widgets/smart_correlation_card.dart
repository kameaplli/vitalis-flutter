import 'package:flutter/material.dart';
import '../models/smart_correlation_data.dart';

/// Phase 2: Smart food correlation results display.
class SmartCorrelationCard extends StatelessWidget {
  final SmartCorrelationResult result;
  const SmartCorrelationCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Data quality banner
        _DataQualityBanner(quality: result.dataQuality, entries: result.eczemaEntries),
        const SizedBox(height: 12),

        // Bayesian trigger probabilities
        if (result.bayesianTriggers.isNotEmpty)
          _BayesianTriggersCard(triggers: result.bayesianTriggers),
        const SizedBox(height: 12),

        // Category correlations
        if (result.categoryCorrelations.isNotEmpty)
          _CategoryCorrelationsCard(correlations: result.categoryCorrelations, overallAvg: result.overallAvgItch),
        const SizedBox(height: 12),

        // Combination triggers
        if (result.combinationTriggers.isNotEmpty)
          _CombinationTriggersCard(triggers: result.combinationTriggers),
        const SizedBox(height: 12),

        // Lag analysis
        if (result.lagAnalysis.isNotEmpty)
          _LagAnalysisCard(lags: result.lagAnalysis),
        const SizedBox(height: 12),

        // Cumulative effects
        if (result.cumulativeEffects.isNotEmpty)
          _CumulativeEffectsCard(effects: result.cumulativeEffects),
        const SizedBox(height: 12),

        // Food-level correlations
        if (result.foodCorrelations.isNotEmpty)
          _FoodCorrelationsCard(correlations: result.foodCorrelations),
      ],
    );
  }
}

class _DataQualityBanner extends StatelessWidget {
  final String quality;
  final int entries;
  const _DataQualityBanner({required this.quality, required this.entries});

  @override
  Widget build(BuildContext context) {
    final color = quality == 'excellent'
        ? Colors.green
        : quality == 'good'
            ? Colors.teal
            : quality == 'moderate'
                ? Colors.orange
                : Colors.grey;
    final icon = quality == 'insufficient' ? Icons.info_outline : Icons.check_circle;
    final message = quality == 'insufficient'
        ? 'Need more data (min 15 entries). Currently $entries entries.'
        : quality == 'moderate'
            ? '$entries entries. Good start! More data = better accuracy.'
            : '$entries entries. Data quality: ${quality.toUpperCase()}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}

class _BayesianTriggersCard extends StatelessWidget {
  final List<BayesianTrigger> triggers;
  const _BayesianTriggersCard({required this.triggers});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.psychology, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Trigger Probability (Bayesian)', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('AI-updated probabilities based on your data', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...triggers.take(6).map((t) => _BayesianRow(trigger: t)),
          ],
        ),
      ),
    );
  }
}

class _BayesianRow extends StatelessWidget {
  final BayesianTrigger trigger;
  const _BayesianRow({required this.trigger});

  @override
  Widget build(BuildContext context) {
    final prob = trigger.posteriorProbability;
    final color = prob > 0.6 ? Colors.red : (prob > 0.3 ? Colors.orange : Colors.green);
    final confLabel = trigger.confidence == 'confirmed'
        ? 'CONFIRMED'
        : trigger.confidence == 'likely_safe'
            ? 'LIKELY SAFE'
            : trigger.confidence == 'possible'
                ? 'POSSIBLE'
                : 'TRACKING';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 90,
                child: Text(trigger.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: prob.clamp(0, 1),
                    minHeight: 8,
                    backgroundColor: Colors.grey.withOpacity(0.15),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 40,
                child: Text('${(prob * 100).toStringAsFixed(0)}%', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
              ),
            ],
          ),
          Row(
            children: [
              const SizedBox(width: 90),
              Text(
                'Eaten ${trigger.timesConsumed}x, flare ${trigger.timesFlareAfter}x ($confLabel)',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryCorrelationsCard extends StatelessWidget {
  final List<CategoryCorrelation> correlations;
  final double overallAvg;
  const _CategoryCorrelationsCard({required this.correlations, required this.overallAvg});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.category, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Category Correlations', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...correlations.where((c) => c.daysConsumed >= 3).take(8).map(
              (c) => _CategoryRow(correlation: c, overallAvg: overallAvg),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final CategoryCorrelation correlation;
  final double overallAvg;
  const _CategoryRow({required this.correlation, required this.overallAvg});

  @override
  Widget build(BuildContext context) {
    final isTrigger = correlation.significant && correlation.riskMultiplier >= 1.5;
    final isSafe = correlation.riskMultiplier < 0.8;
    final color = isTrigger ? Colors.red : (isSafe ? Colors.green : Colors.grey);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isTrigger ? Icons.warning : (isSafe ? Icons.check_circle : Icons.remove_circle_outline),
            size: 14,
            color: color,
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: Text(correlation.displayName, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Row(
              children: [
                Text('${correlation.avgItchWith.toStringAsFixed(1)}', style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
                Text(' vs ', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                Text('${correlation.avgItchWithout.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${correlation.riskMultiplier.toStringAsFixed(1)}x',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _CombinationTriggersCard extends StatelessWidget {
  final List<CombinationTrigger> triggers;
  const _CombinationTriggersCard({required this.triggers});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.merge_type, color: Colors.deepOrange, size: 20),
                const SizedBox(width: 8),
                Text('Combination Triggers', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('These food categories are worse together', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...triggers.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.deepOrange.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_catName(t.categoryA)} + ${_catName(t.categoryB)}',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Combined: itch ${t.avgItchCombined.toStringAsFixed(1)} | '
                      '${_catName(t.categoryA)} alone: ${t.avgItchAOnly.toStringAsFixed(1)} | '
                      '${_catName(t.categoryB)} alone: ${t.avgItchBOnly.toStringAsFixed(1)}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    ),
                    Text(
                      'Interaction score: +${t.interactionScore.toStringAsFixed(1)} (${t.combinedDays} days observed)',
                      style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _catName(String c) {
    const names = {'dairy': 'Dairy', 'egg': 'Eggs', 'histamine': 'Histamine', 'nuts': 'Nuts', 'wheat': 'Wheat', 'soy': 'Soy', 'nickel': 'Nickel', 'salicylate': 'Salicylate'};
    return names[c] ?? c;
  }
}

class _LagAnalysisCard extends StatelessWidget {
  final List<LagAnalysis> lags;
  const _LagAnalysisCard({required this.lags});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.schedule, color: cs.tertiary, size: 20),
                const SizedBox(width: 8),
                Text('Reaction Timing', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('How long after eating do you react?', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...lags.map((l) {
              final lagStr = l.bestLagDays == 0 ? 'Same day' : '${l.bestLagDays} day${l.bestLagDays > 1 ? 's' : ''} later';
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    SizedBox(width: 100, child: Text(_catName(l.category), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                    Icon(Icons.arrow_forward, size: 14, color: cs.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(lagStr, style: TextStyle(fontSize: 12, color: cs.tertiary, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('r=${l.bestCorrelation.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _catName(String c) {
    const names = {'dairy': 'Dairy', 'egg': 'Eggs', 'histamine': 'Histamine', 'nuts': 'Nuts', 'wheat': 'Wheat'};
    return names[c] ?? c;
  }
}

class _CumulativeEffectsCard extends StatelessWidget {
  final List<CumulativeEffect> effects;
  const _CumulativeEffectsCard({required this.effects});

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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.stacked_line_chart, color: Colors.purple, size: 20),
                const SizedBox(width: 8),
                Text('Cumulative Exposure', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 4),
            Text('Eating the same trigger multiple days in a row', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
            const SizedBox(height: 12),
            ...effects.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(width: 90, child: Text(_catName(e.category), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500))),
                  Expanded(
                    child: Text(
                      'Once: ${e.singleDayAvgItch.toStringAsFixed(1)} | Consecutive: ${e.consecutiveDaysAvgItch.toStringAsFixed(1)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${e.cumulativeMultiplier.toStringAsFixed(1)}x',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  String _catName(String c) {
    const names = {'dairy': 'Dairy', 'egg': 'Eggs', 'histamine': 'Histamine', 'nuts': 'Nuts'};
    return names[c] ?? c;
  }
}

class _FoodCorrelationsCard extends StatelessWidget {
  final List<FoodCorrelation> correlations;
  const _FoodCorrelationsCard({required this.correlations});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final triggers = correlations.where((c) => c.trend == 'trigger').toList();
    final safe = correlations.where((c) => c.trend == 'safe').toList();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: cs.surfaceContainerLow,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant, color: cs.primary, size: 20),
                const SizedBox(width: 8),
                Text('Individual Foods', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ],
            ),
            if (triggers.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('TRIGGER FOODS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.red[700], letterSpacing: 1)),
              const SizedBox(height: 6),
              ...triggers.take(5).map((f) => _FoodRow(food: f, color: Colors.red)),
            ],
            if (safe.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('SAFE FOODS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green[700], letterSpacing: 1)),
              const SizedBox(height: 6),
              ...safe.take(5).map((f) => _FoodRow(food: f, color: Colors.green)),
            ],
          ],
        ),
      ),
    );
  }
}

class _FoodRow extends StatelessWidget {
  final FoodCorrelation food;
  final Color color;
  const _FoodRow({required this.food, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(food.food, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis),
          ),
          Text('${food.timesEaten}x', style: TextStyle(fontSize: 11, color: Colors.grey[500])),
          const SizedBox(width: 8),
          Text(
            '${food.riskMultiplier.toStringAsFixed(1)}x',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
          ),
          if (food.allergenCategories.isNotEmpty) ...[
            const SizedBox(width: 4),
            ...food.allergenCategories.take(2).map((c) => Container(
              margin: const EdgeInsets.only(left: 2),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(c, style: const TextStyle(fontSize: 11, color: Colors.orange)),
            )),
          ],
        ],
      ),
    );
  }
}
