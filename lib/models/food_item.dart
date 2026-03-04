class FoodItem {
  final String id;
  final String name;
  final double? cal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final String? emoji;
  final String? unit;
  final double? servingSize;

  FoodItem({
    required this.id,
    required this.name,
    this.cal,
    this.protein,
    this.carbs,
    this.fat,
    this.emoji,
    this.unit,
    this.servingSize,
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      cal: (json['cal'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      emoji: json['emoji'],
      unit: json['unit'],
      servingSize: (json['serving_size'] as num?)?.toDouble(),
    );
  }

  double get caloriesPerServing {
    if (cal == null || servingSize == null) return 0;
    return (cal! / 100) * servingSize!;
  }
}

// ─── Recent Meal models (used by /api/foods/frequent) ─────────────────────────

class RecentMealItem {
  final String foodId;
  final String foodName;
  final double grams;
  final double? calPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double servingSize;
  final String? emoji;

  RecentMealItem({
    required this.foodId,
    required this.foodName,
    required this.grams,
    this.calPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.servingSize = 100,
    this.emoji,
  });

  factory RecentMealItem.fromJson(Map<String, dynamic> json) => RecentMealItem(
        foodId: json['food_id'] ?? '',
        foodName: json['food_name'] ?? '',
        grams: (json['grams'] as num?)?.toDouble() ?? 100,
        calPer100g: (json['cal_per_100g'] as num?)?.toDouble(),
        proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (json['fat_per_100g'] as num?)?.toDouble(),
        servingSize: (json['serving_size'] as num?)?.toDouble() ?? 100,
        emoji: json['emoji'],
      );

  FoodItem toFoodItem() => FoodItem(
        id: foodId,
        name: foodName,
        cal: calPer100g,
        protein: proteinPer100g,
        carbs: carbsPer100g,
        fat: fatPer100g,
        emoji: emoji,
        servingSize: servingSize,
      );
}

class RecentMeal {
  final String id;
  final String mealType;
  final String display;
  final List<RecentMealItem> items;

  RecentMeal({
    required this.id,
    required this.mealType,
    required this.display,
    required this.items,
  });

  factory RecentMeal.fromJson(Map<String, dynamic> json) => RecentMeal(
        id: json['id'] ?? '',
        mealType: json['meal_type'] ?? 'lunch',
        display: json['display'] ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => RecentMealItem.fromJson(i))
            .toList(),
      );
}

// ─── Food Category ─────────────────────────────────────────────────────────────

class FoodCategory {
  final String id;
  final String name;
  final String? emoji;
  final List<FoodItem> items;

  FoodCategory({
    required this.id,
    required this.name,
    this.emoji,
    required this.items,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => FoodItem.fromJson(i))
          .toList(),
    );
  }
}
