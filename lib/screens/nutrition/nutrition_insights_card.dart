import 'package:flutter/material.dart';
import '../../models/insight_data.dart';

// ─── Nutrition AI Insights card ───────────────────────────────────────────────

class NutritionInsightsCard extends StatelessWidget {
  final WeeklyInsight insight;
  const NutritionInsightsCard({super.key, required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isAi = insight.source == 'ai';
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(isAi ? Icons.auto_awesome : Icons.bar_chart,
                  size: 16, color: isAi ? Colors.purple : Colors.teal),
              const SizedBox(width: 6),
              Text(isAi ? 'AI Nutrition Insights' : 'Nutrition Analysis',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: isAi ? Colors.purple : Colors.teal)),
            ]),
            const SizedBox(height: 10),
            ...insight.insights.map((i) => InkWell(
              onTap: () => _showInsightDetail(context, i),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.insights, size: 16, color: cs.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(i.title, style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 13))),
                              Icon(Icons.chevron_right, size: 16, color: Colors.grey.shade400),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(i.body, style: const TextStyle(fontSize: 12),
                              maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            )),
            if (insight.recommendations.isNotEmpty) ...[
              const Divider(height: 16),
              ...insight.recommendations.map((r) {
                final color = r.priority == 'high' ? Colors.red
                    : (r.priority == 'medium' ? Colors.orange : Colors.green);
                return InkWell(
                  onTap: () => _showRecommendationDetail(context, r),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Icon(Icons.lightbulb_outline, size: 14, color: color),
                      const SizedBox(width: 6),
                      Expanded(child: Text(r.action,
                          style: const TextStyle(fontSize: 12))),
                      Icon(Icons.chevron_right, size: 14, color: Colors.grey.shade400),
                    ]),
                  ),
                );
              }),
            ],
          ],
        ),
      ),
    );
  }

  void _showInsightDetail(BuildContext context, InsightItem insight) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.insights, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(insight.title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold))),
                ],
              ),
              const SizedBox(height: 12),
              Text(insight.body, style: const TextStyle(fontSize: 14, height: 1.5)),
              const SizedBox(height: 16),
              // Confidence indicator
              Row(
                children: [
                  Text('Confidence: ', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ...List.generate(5, (i) => Icon(
                    i < (insight.confidence * 5).round() ? Icons.circle : Icons.circle_outlined,
                    size: 10,
                    color: i < (insight.confidence * 5).round() ? cs.primary : Colors.grey.shade300,
                  )),
                ],
              ),
              if (_getFoodTips(insight.title).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Foods that may help:', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: cs.primary)),
                const SizedBox(height: 8),
                ..._getFoodTips(insight.title).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(tip.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip.text, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  void _showRecommendationDetail(BuildContext context, Recommendation rec) {
    final color = rec.priority == 'high' ? Colors.red
        : (rec.priority == 'medium' ? Colors.orange : Colors.green);
    final priorityLabel = rec.priority == 'high' ? 'High Priority'
        : (rec.priority == 'medium' ? 'Suggested' : 'Good to Know');
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.lightbulb, color: color),
                  const SizedBox(width: 8),
                  Text('Recommendation', style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(priorityLabel, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              Text(rec.action, style: const TextStyle(fontSize: 14, height: 1.5)),
              if (_getFoodTips(rec.action).isNotEmpty) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                Text('Helpful foods:', style: TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13, color: color)),
                const SizedBox(height: 8),
                ..._getFoodTips(rec.action).map((tip) => Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    children: [
                      Text(tip.emoji, style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Expanded(child: Text(tip.text, style: const TextStyle(fontSize: 13))),
                    ],
                  ),
                )),
              ],
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  /// Context-aware food suggestions based on insight/recommendation keywords
  static List<_FoodTip> _getFoodTips(String text) {
    final lower = text.toLowerCase();
    final tips = <_FoodTip>[];

    if (lower.contains('protein')) {
      tips.addAll([
        const _FoodTip('🥚', 'Eggs — 13g protein per 100g'),
        const _FoodTip('🍗', 'Chicken breast — 31g protein per 100g'),
        const _FoodTip('🫘', 'Lentils (dal) — 9g protein per 100g cooked'),
        const _FoodTip('🥜', 'Peanuts — 26g protein per 100g'),
      ]);
    }
    if (lower.contains('fiber') || lower.contains('fibre')) {
      tips.addAll([
        const _FoodTip('🥬', 'Broccoli — 2.6g fiber per 100g'),
        const _FoodTip('🫘', 'Rajma (kidney beans) — 6.4g fiber per 100g'),
        const _FoodTip('🍎', 'Apple with skin — 2.4g fiber per apple'),
        const _FoodTip('🌾', 'Oats — 10g fiber per 100g'),
      ]);
    }
    if (lower.contains('vitamin d') || lower.contains('vit d')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — rich in Vitamin D'),
        const _FoodTip('🥛', 'Fortified milk — Vitamin D added'),
        const _FoodTip('🥚', 'Egg yolks — natural Vitamin D source'),
        const _FoodTip('☀️', '15 min sunlight exposure daily'),
      ]);
    }
    if (lower.contains('iron')) {
      tips.addAll([
        const _FoodTip('🥬', 'Spinach — 2.7mg iron per 100g'),
        const _FoodTip('🫘', 'Lentils — 3.3mg iron per 100g cooked'),
        const _FoodTip('🥩', 'Red meat — highly bioavailable iron'),
        const _FoodTip('🍊', 'Vitamin C foods help iron absorption'),
      ]);
    }
    if (lower.contains('calcium')) {
      tips.addAll([
        const _FoodTip('🥛', 'Milk — 125mg calcium per 100ml'),
        const _FoodTip('🧀', 'Paneer/cheese — calcium-rich dairy'),
        const _FoodTip('🥬', 'Kale — 150mg calcium per 100g'),
        const _FoodTip('🐟', 'Sardines with bones — excellent calcium'),
      ]);
    }
    if (lower.contains('calorie') || lower.contains('energy') || lower.contains('kcal')) {
      tips.addAll([
        const _FoodTip('📊', 'Track all meals including snacks'),
        const _FoodTip('🥗', 'Fill half your plate with vegetables'),
        const _FoodTip('💧', 'Stay hydrated — sometimes thirst mimics hunger'),
      ]);
    }
    if (lower.contains('breakfast')) {
      tips.addAll([
        const _FoodTip('🥣', 'Oatmeal with fruits — balanced start'),
        const _FoodTip('🥞', 'Dosa/idli — light, nutritious South Indian breakfast'),
        const _FoodTip('🥚', 'Eggs — protein to keep you full longer'),
      ]);
    }
    if (lower.contains('carb') || lower.contains('sugar') || lower.contains('glucose')) {
      tips.addAll([
        const _FoodTip('🌾', 'Choose whole grains over refined'),
        const _FoodTip('🍠', 'Sweet potato — complex carbs, lower GI'),
        const _FoodTip('🫘', 'Legumes — slow-releasing energy'),
      ]);
    }
    if (lower.contains('fat') && !lower.contains('breakfast')) {
      tips.addAll([
        const _FoodTip('🥑', 'Avocado — healthy monounsaturated fats'),
        const _FoodTip('🥜', 'Almonds — heart-healthy fats'),
        const _FoodTip('🐟', 'Fatty fish — omega-3 fatty acids'),
      ]);
    }

    // ── Vitamins ──────────────────────────────────────────
    if (lower.contains('vitamin a') || lower.contains('vit a') || lower.contains('retinol')) {
      tips.addAll([
        const _FoodTip('🥕', 'Carrots — 835µg vitamin A per 100g'),
        const _FoodTip('🍠', 'Sweet potato — 709µg per 100g'),
        const _FoodTip('🥬', 'Spinach — 469µg per 100g'),
        const _FoodTip('🥭', 'Mango — 54µg + beta-carotene'),
      ]);
    }
    if (lower.contains('vitamin b1') || lower.contains('vit b1') || lower.contains('thiamin')) {
      tips.addAll([
        const _FoodTip('🌻', 'Sunflower seeds — 1.5mg B1 per 100g'),
        const _FoodTip('🫘', 'Black beans — 0.4mg per 100g'),
        const _FoodTip('🌾', 'Brown rice — 0.4mg per 100g'),
        const _FoodTip('🥜', 'Peanuts — 0.6mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b2') || lower.contains('vit b2') || lower.contains('riboflavin')) {
      tips.addAll([
        const _FoodTip('🥛', 'Milk — 0.18mg B2 per 100ml'),
        const _FoodTip('🥚', 'Eggs — 0.46mg per 100g'),
        const _FoodTip('🍄', 'Mushrooms — 0.4mg per 100g'),
        const _FoodTip('🥬', 'Spinach — 0.19mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b6') || lower.contains('vit b6') || lower.contains('pyridoxine')) {
      tips.addAll([
        const _FoodTip('🍌', 'Banana — 0.4mg B6 per fruit'),
        const _FoodTip('🍗', 'Chicken — 0.5mg per 100g'),
        const _FoodTip('🥔', 'Potato — 0.3mg per 100g'),
        const _FoodTip('🌻', 'Sunflower seeds — 1.3mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin b12') || lower.contains('vit b12') || lower.contains('cobalamin')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — 2.8µg B12 per 100g'),
        const _FoodTip('🥚', 'Eggs — 0.9µg per egg'),
        const _FoodTip('🥛', 'Milk — 0.5µg per 100ml'),
        const _FoodTip('🧀', 'Paneer/cheese — 1.1µg per 100g'),
      ]);
    }
    if (lower.contains('vitamin c') || lower.contains('vit c') || lower.contains('ascorbic')) {
      tips.addAll([
        const _FoodTip('🍊', 'Orange — 53mg vitamin C per fruit'),
        const _FoodTip('🫑', 'Bell pepper — 128mg per 100g'),
        const _FoodTip('🥝', 'Kiwi — 93mg per 100g'),
        const _FoodTip('🍋', 'Lemon — 53mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin e') || lower.contains('vit e') || lower.contains('tocopherol')) {
      tips.addAll([
        const _FoodTip('🌻', 'Sunflower seeds — 35mg vit E per 100g'),
        const _FoodTip('🥜', 'Almonds — 26mg per 100g'),
        const _FoodTip('🥑', 'Avocado — 2.1mg per 100g'),
        const _FoodTip('🥬', 'Spinach — 2mg per 100g'),
      ]);
    }
    if (lower.contains('vitamin k') || lower.contains('vit k')) {
      tips.addAll([
        const _FoodTip('🥬', 'Kale — 390µg vitamin K per 100g'),
        const _FoodTip('🥦', 'Broccoli — 102µg per 100g'),
        const _FoodTip('🫛', 'Green peas — 25µg per 100g'),
        const _FoodTip('🥒', 'Cucumber — 16µg per 100g'),
      ]);
    }

    // ── Minerals ──────────────────────────────────────────
    if (lower.contains('zinc')) {
      tips.addAll([
        const _FoodTip('🥩', 'Red meat — 4.8mg zinc per 100g'),
        const _FoodTip('🌻', 'Pumpkin seeds — 7.8mg per 100g'),
        const _FoodTip('🫘', 'Chickpeas — 2.5mg per 100g'),
        const _FoodTip('🧀', 'Cheese — 3.1mg per 100g'),
      ]);
    }
    if (lower.contains('magnesium')) {
      tips.addAll([
        const _FoodTip('🌰', 'Cashews — 292mg magnesium per 100g'),
        const _FoodTip('🥬', 'Spinach — 79mg per 100g'),
        const _FoodTip('🍫', 'Dark chocolate — 228mg per 100g'),
        const _FoodTip('🍌', 'Banana — 27mg per fruit'),
      ]);
    }
    if (lower.contains('potassium')) {
      tips.addAll([
        const _FoodTip('🍌', 'Banana — 422mg potassium per fruit'),
        const _FoodTip('🥔', 'Potato — 421mg per medium'),
        const _FoodTip('🫘', 'White beans — 561mg per 100g'),
        const _FoodTip('🥑', 'Avocado — 485mg per 100g'),
      ]);
    }
    if (lower.contains('folate') || lower.contains('folic')) {
      tips.addAll([
        const _FoodTip('🥬', 'Spinach — 194µg folate per 100g'),
        const _FoodTip('🫘', 'Lentils — 181µg per 100g cooked'),
        const _FoodTip('🥦', 'Broccoli — 63µg per 100g'),
        const _FoodTip('🥑', 'Avocado — 81µg per 100g'),
      ]);
    }
    if (lower.contains('omega') || lower.contains('dha') || lower.contains('epa')) {
      tips.addAll([
        const _FoodTip('🐟', 'Salmon — 2.3g omega-3 per 100g'),
        const _FoodTip('🐟', 'Sardines — 1.5g omega-3 per 100g'),
        const _FoodTip('🌰', 'Walnuts — 2.5g ALA per 28g'),
        const _FoodTip('🌱', 'Flaxseeds — 2.4g ALA per tbsp'),
      ]);
    }

    return tips.take(4).toList();
  }
}

class _FoodTip {
  final String emoji;
  final String text;
  const _FoodTip(this.emoji, this.text);
}
