import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';

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
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
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
                Icon(Icons.lightbulb_outline, size: 16, color: cs.primary),
                const SizedBox(width: 4),
                Text('Suggested for $mealLabel',
                    style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 88,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
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
    // Calculate total calories for the meal
    double totalCal = 0;
    for (final item in meal.items) {
      final cal = item.calPer100g ?? 0;
      totalCal += (cal / 100) * item.grams;
    }
    final emojis = meal.items
        .take(3)
        .map((i) => i.emoji ?? '🍽️')
        .join(' ');

    return InkWell(
      onTap: () {
        ref.read(nutritionProvider.notifier).loadRecentMeal(
          meal.items
              .map((item) =>
                  SelectedFood(food: item.toFoodItem(), grams: item.grams))
              .toList(),
          meal.mealType,
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 190,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              cs.primaryContainer.withOpacity(0.3),
              cs.primaryContainer.withOpacity(0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: cs.primaryContainer),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(emojis, style: const TextStyle(fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${meal.count}x',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: cs.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Expanded(
              child: Text(
                meal.display,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: cs.onSurface),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              '${totalCal.round()} kcal',
              style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
