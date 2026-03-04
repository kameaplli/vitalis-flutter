class DailyNutritionTotal {
  final String date;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  DailyNutritionTotal({
    required this.date,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  factory DailyNutritionTotal.fromJson(Map<String, dynamic> json) {
    return DailyNutritionTotal(
      date: json['date'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MacroTotals {
  final double protein;
  final double carbs;
  final double fat;

  MacroTotals({required this.protein, required this.carbs, required this.fat});

  factory MacroTotals.fromJson(Map<String, dynamic> json) {
    return MacroTotals(
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
    );
  }

  double get total => protein + carbs + fat;
}

class TopFood {
  final String name;
  final double calories;
  final int count;
  final double protein;
  final double carbs;
  final double fat;

  TopFood({
    required this.name,
    required this.calories,
    required this.count,
    this.protein = 0,
    this.carbs = 0,
    this.fat = 0,
  });

  factory TopFood.fromJson(Map<String, dynamic> json) {
    return TopFood(
      name: json['name'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      count: json['count'] ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MealDayCalories {
  final String date;
  final double breakfast;
  final double lunch;
  final double dinner;
  final double snack;

  MealDayCalories({
    required this.date,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snack,
  });

  double get total => breakfast + lunch + dinner + snack;
}

class NutritionAnalytics {
  final List<DailyNutritionTotal> dailyTotals;
  final MacroTotals macroTotals;
  final List<TopFood> topFoods;
  final int periodDays;
  final List<MealDayCalories> mealCalories;

  NutritionAnalytics({
    required this.dailyTotals,
    required this.macroTotals,
    required this.topFoods,
    required this.periodDays,
    required this.mealCalories,
  });

  factory NutritionAnalytics.fromJson(Map<String, dynamic> json) {
    // meal_calories from backend: {date: {date, breakfast, lunch, dinner, snack}}
    final mealMap = json['meal_calories'] as Map<String, dynamic>? ?? {};
    final mealList = mealMap.values.map((v) {
      final day = v as Map<String, dynamic>;
      return MealDayCalories(
        date: day['date'] ?? '',
        breakfast: (day['breakfast'] as num?)?.toDouble() ?? 0,
        lunch: (day['lunch'] as num?)?.toDouble() ?? 0,
        dinner: (day['dinner'] as num?)?.toDouble() ?? 0,
        snack: (day['snack'] as num?)?.toDouble() ?? 0,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    return NutritionAnalytics(
      dailyTotals: (json['daily_totals'] as List<dynamic>? ?? [])
          .map((d) => DailyNutritionTotal.fromJson(d))
          .toList(),
      macroTotals: MacroTotals.fromJson(json['macro_totals'] ?? {}),
      topFoods: (json['top_foods'] as List<dynamic>? ?? [])
          .map((f) => TopFood.fromJson(f))
          .toList(),
      periodDays: json['period_days'] ?? 30,
      mealCalories: mealList,
    );
  }
}
