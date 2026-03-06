class MealTypeMacros {
  final double calories, protein, carbs, fat;
  final int logCount;
  const MealTypeMacros({required this.calories, required this.protein,
      required this.carbs, required this.fat, required this.logCount});
  factory MealTypeMacros.fromJson(Map<String, dynamic> j) => MealTypeMacros(
    calories: (j['calories'] as num?)?.toDouble() ?? 0,
    protein: (j['protein'] as num?)?.toDouble() ?? 0,
    carbs: (j['carbs'] as num?)?.toDouble() ?? 0,
    fat: (j['fat'] as num?)?.toDouble() ?? 0,
    logCount: (j['log_count'] as num?)?.toInt() ?? 0,
  );
}

class MacroFood {
  final String foodName;
  final double total;
  final int occurrences;
  const MacroFood({required this.foodName, required this.total, required this.occurrences});
  factory MacroFood.fromJson(Map<String, dynamic> j) => MacroFood(
    foodName: j['food_name'] as String? ?? '',
    total: (j['total'] as num?)?.toDouble() ?? 0,
    occurrences: (j['occurrences'] as num?)?.toInt() ?? 0,
  );
}

class NutritionAnalyticsData {
  final Map<String, MealTypeMacros> byMealType;
  final Map<String, List<MacroFood>> macroFoods; // key: 'protein'|'carbs'|'fat'
  final Map<String, List<MacroFood>> mealFoods;  // key: meal type
  final MealTypeMacros totals;

  const NutritionAnalyticsData({
    required this.byMealType,
    required this.macroFoods,
    required this.mealFoods,
    required this.totals,
  });

  factory NutritionAnalyticsData.fromJson(Map<String, dynamic> j) {
    Map<String, MealTypeMacros> parseMealMap(dynamic raw) {
      final m = raw as Map<String, dynamic>? ?? {};
      return m.map((k, v) => MapEntry(k, MealTypeMacros.fromJson(v as Map<String, dynamic>)));
    }
    Map<String, List<MacroFood>> parseFoodMap(dynamic raw) {
      final m = raw as Map<String, dynamic>? ?? {};
      return m.map((k, v) => MapEntry(k, (v as List).map((e) => MacroFood.fromJson(e as Map<String, dynamic>)).toList()));
    }
    return NutritionAnalyticsData(
      byMealType: parseMealMap(j['by_meal_type']),
      macroFoods: parseFoodMap(j['macro_foods']),
      mealFoods: parseFoodMap(j['meal_foods']),
      totals: MealTypeMacros.fromJson(j['totals'] as Map<String, dynamic>? ?? {}),
    );
  }
}
