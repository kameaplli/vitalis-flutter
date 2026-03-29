import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';
import 'package:hugeicons/hugeicons.dart';

// ─── Meal suggestions for selected meal type ─────────────────────────────────

class MealSuggestionsSection extends ConsumerWidget {
  final String mealType;
  const MealSuggestionsSection({super.key, required this.mealType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suggestionsAsync = ref.watch(mealSuggestionsProvider);
    return suggestionsAsync.when(
      loading: () => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 8),
          Text('Loading suggestions...',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: Colors.grey.shade500)),
        ]),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (suggestions) {
        final allMeals = suggestions[mealType];
        if (allMeals == null || allMeals.isEmpty) return const SizedBox.shrink();
        final meals = allMeals.take(3).toList();

        final cs = Theme.of(context).colorScheme;
        final mealLabel = mealType[0].toUpperCase() + mealType.substring(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedBulb, size: 16, color: cs.primary),
                const SizedBox(width: 6),
                Text('Suggested for $mealLabel',
                    style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 92,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) =>
                    _SuggestionCard(meal: meals[i]),
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }
}

class _SuggestionCard extends ConsumerWidget {
  final RecentMeal meal;
  const _SuggestionCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    double totalCal = 0;
    for (final item in meal.items) {
      final cal = item.calPer100g ?? 0;
      totalCal += (cal / 100) * item.grams;
    }
    final emojis = meal.items.take(3).map((i) => i.emoji ?? '🍽️').join(' ');

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(nutritionProvider.notifier).loadRecentMeal(
            meal.items
                .map((item) =>
                    SelectedFood(food: item.toFoodItem(), grams: item.grams))
                .toList(),
            meal.mealType,
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(emojis, style: const TextStyle(fontSize: 14)),
                  const Spacer(),
                  // Frequency badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${meal.count}x',
                      style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: Text(
                  meal.display,
                  style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w500,
                    color: cs.onSurface, height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${totalCal.round()} kcal',
                style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
