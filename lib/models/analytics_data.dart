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

  TopFood({required this.name, required this.calories, required this.count});

  factory TopFood.fromJson(Map<String, dynamic> json) {
    return TopFood(
      name: json['name'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      count: json['count'] ?? 0,
    );
  }
}

class NutritionAnalytics {
  final List<DailyNutritionTotal> dailyTotals;
  final MacroTotals macroTotals;
  final List<TopFood> topFoods;
  final int periodDays;

  NutritionAnalytics({
    required this.dailyTotals,
    required this.macroTotals,
    required this.topFoods,
    required this.periodDays,
  });

  factory NutritionAnalytics.fromJson(Map<String, dynamic> json) {
    return NutritionAnalytics(
      dailyTotals: (json['daily_totals'] as List<dynamic>? ?? [])
          .map((d) => DailyNutritionTotal.fromJson(d))
          .toList(),
      macroTotals: MacroTotals.fromJson(json['macro_totals'] ?? {}),
      topFoods: (json['top_foods'] as List<dynamic>? ?? [])
          .map((f) => TopFood.fromJson(f))
          .toList(),
      periodDays: json['period_days'] ?? 30,
    );
  }
}
