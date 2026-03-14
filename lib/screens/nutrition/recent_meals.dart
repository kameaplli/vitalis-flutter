import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';

// ─── Frequent individual foods (Quick Add) ──────────────────────────────────

class FrequentFoodsSection extends ConsumerWidget {
  const FrequentFoodsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealsAsync = ref.watch(recentMealsProvider);
    final cs = Theme.of(context).colorScheme;

    return mealsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();

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
            .take(6)
            .map((e) => foodMap[e.key]!)
            .toList();

        if (top.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Quick Add',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 72,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: top.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _QuickAddChip(
                  item: top[i],
                  count: counts[top[i].foodId] ?? 0,
                  cs: cs,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    ref.read(nutritionProvider.notifier)
                        .addFood(top[i].toFoodItem());
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}

class _QuickAddChip extends StatelessWidget {
  final RecentMealItem item;
  final int count;
  final ColorScheme cs;
  final VoidCallback onTap;

  const _QuickAddChip({
    required this.item,
    required this.count,
    required this.cs,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = item.foodName.length > 12
        ? '${item.foodName.substring(0, 11)}…'
        : item.foodName;

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 88,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(item.emoji ?? '🍽️', style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(name,
                style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: cs.onSurface, letterSpacing: -0.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              Text('${count}x',
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w500,
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
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            SizedBox(
              height: 84,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (ctx, i) => _RecentMealCard(meal: meals[i]),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RecentMealCard extends ConsumerWidget {
  final RecentMeal meal;
  const _RecentMealCard({required this.meal});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;

    // Total calories
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
                  // Meal type pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      meal.mealType[0].toUpperCase() + meal.mealType.substring(1),
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: cs.onSurfaceVariant, letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(emojis, style: const TextStyle(fontSize: 12)),
                  const Spacer(),
                  Text(
                    '${totalCal.round()} kcal',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
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
            ],
          ),
        ),
      ),
    );
  }
}
