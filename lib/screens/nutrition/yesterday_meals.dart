import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../models/food_item.dart';
import '../../providers/food_provider.dart';
import '../../providers/nutrition_provider.dart';
import '../../providers/selected_person_provider.dart';

/// "Same as yesterday?" section — horizontal row of yesterday's meals
/// with one-tap repeat functionality.
class YesterdayMealsSection extends ConsumerWidget {
  const YesterdayMealsSection({super.key});

  static const _mealIcons = <String, List<List<dynamic>>>{
    'breakfast': HugeIcons.strokeRoundedCoffee01,
    'lunch': HugeIcons.strokeRoundedRestaurant01,
    'dinner': HugeIcons.strokeRoundedRestaurant01,
    'snack': HugeIcons.strokeRoundedApple,
  };

  static const _mealColors = <String, Color>{
    'breakfast': Colors.orange,
    'lunch': Colors.green,
    'dinner': Colors.indigo,
    'snack': Colors.pink,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final personId = ref.watch(selectedPersonProvider);
    final yesterdayAsync = ref.watch(yesterdayMealsProvider(personId));

    return yesterdayAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (meals) {
        if (meals.isEmpty) return const SizedBox.shrink();

        final cs = Theme.of(context).colorScheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.refresh_rounded, size: 18, color: cs.primary),
                const SizedBox(width: 6),
                Text(
                  'Same as yesterday?',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Horizontal scrollable cards
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meals.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (_, i) => _YesterdayMealCard(
                  meal: meals[i],
                  icon: _mealIcons[meals[i].mealType] ??
                      HugeIcons.strokeRoundedRestaurant01,
                  color: _mealColors[meals[i].mealType] ?? Colors.grey,
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

class _YesterdayMealCard extends ConsumerWidget {
  final YesterdayMeal meal;
  final List<List<dynamic>> icon;
  final Color color;

  const _YesterdayMealCard({
    required this.meal,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final mealLabel =
        meal.mealType[0].toUpperCase() + meal.mealType.substring(1);
    final itemCount = meal.items.length;

    return Material(
      color: cs.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _repeatMeal(context, ref),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 170,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border:
                Border.all(color: cs.outlineVariant.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: icon + meal type + calories
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: HugeIcon(icon: icon, color: color, size: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      mealLabel,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Calories + item count
              Text(
                '${meal.totalCalories.round()} kcal',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$itemCount item${itemCount == 1 ? '' : 's'}',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: cs.onSurfaceVariant,
                ),
              ),

              const Spacer(),

              // Repeat button
              Align(
                alignment: Alignment.centerRight,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.refresh_rounded,
                          size: 13, color: cs.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Repeat',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: cs.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _repeatMeal(BuildContext context, WidgetRef ref) {
    HapticFeedback.mediumImpact();

    // Convert yesterday's items to SelectedFood objects
    final selectedFoods = <SelectedFood>[];
    for (final item in meal.items) {
      final foodId = item['food_id'] as String? ?? '';
      final foodName = item['food_name'] as String? ?? 'Unknown';
      final quantity = (item['quantity'] as num?)?.toDouble() ?? 1.0;
      final servingSize = (item['serving_size'] as num?)?.toDouble() ?? 100.0;
      final totalCalories = (item['calories'] as num?)?.toDouble() ?? 0;
      final totalProtein = (item['protein'] as num?)?.toDouble() ?? 0;
      final totalCarbs = (item['carbs'] as num?)?.toDouble() ?? 0;
      final totalFat = (item['fat'] as num?)?.toDouble() ?? 0;
      final emoji = item['emoji'] as String?;

      final grams = quantity * servingSize;

      // Derive per-100g values from totals
      final calPer100g = grams > 0 ? totalCalories / grams * 100 : 0.0;
      final proteinPer100g = grams > 0 ? totalProtein / grams * 100 : 0.0;
      final carbsPer100g = grams > 0 ? totalCarbs / grams * 100 : 0.0;
      final fatPer100g = grams > 0 ? totalFat / grams * 100 : 0.0;

      final food = FoodItem(
        id: foodId,
        name: foodName,
        cal: calPer100g,
        protein: proteinPer100g,
        carbs: carbsPer100g,
        fat: fatPer100g,
        emoji: emoji,
        servingSize: servingSize,
      );

      selectedFoods.add(SelectedFood(food: food, grams: grams));
    }

    if (selectedFoods.isNotEmpty) {
      ref.read(nutritionProvider.notifier).loadRecentMeal(
            selectedFoods,
            meal.mealType,
          );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.refresh_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                  '${meal.mealType[0].toUpperCase()}${meal.mealType.substring(1)} loaded — tap Log Meal to save'),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }
}
