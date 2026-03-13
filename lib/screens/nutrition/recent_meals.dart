import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';

// ─── Frequent individual foods ───────────────────────────────────────────────

class FrequentFoodsSection extends ConsumerWidget {
  const FrequentFoodsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(recentMealsProvider);
    return mealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();

        // Count how often each individual food appears across all meal combos
        final counts = <String, int>{};
        final foodMap = <String, RecentMealItem>{};
        for (final meal in meals) {
          for (final item in meal.items) {
            counts[item.foodId] = (counts[item.foodId] ?? 0) + 1;
            foodMap[item.foodId] = item;
          }
        }
        final top = (counts.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(5)
            .map((e) => foodMap[e.key]!)
            .toList();

        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Add',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: top.map((item) {
                final label = item.foodName.length > 14
                    ? '${item.foodName.substring(0, 13)}…'
                    : item.foodName;
                return ActionChip(
                  avatar: Text(item.emoji ?? '🍽️',
                      style: const TextStyle(fontSize: 14)),
                  label: Text(label,
                      style: const TextStyle(fontSize: 12)),
                  onPressed: () => ref
                      .read(nutritionProvider.notifier)
                      .addFood(item.toFoodItem()),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

// ─── Recent meals carousel ────────────────────────────────────────────────────

class RecentMealsSection extends ConsumerWidget {
  const RecentMealsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(recentMealsProvider);
    return mealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Recent Meals',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SizedBox(
              height: 76,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) => _RecentMealChip(meal: meals[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentMealChip extends ConsumerWidget {
  final RecentMeal meal;
  const _RecentMealChip({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
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
        width: 170,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          border: Border.all(color: colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
          color: colorScheme.surfaceContainerLowest,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              meal.mealType.toUpperCase(),
              style: TextStyle(
                  fontSize: 11,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5),
            ),
            const SizedBox(height: 3),
            Expanded(
              child: Text(
                meal.display,
                style: const TextStyle(fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
