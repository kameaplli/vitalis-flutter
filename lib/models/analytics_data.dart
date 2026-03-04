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

// ── Phase 3: Meal Timing ───────────────────────────────────────────────────────

class MealTimingEntry {
  final String time;      // "HH:MM"
  final int timeMinutes;  // minutes since midnight
  final String mealType;
  final double calories;

  MealTimingEntry({
    required this.time,
    required this.timeMinutes,
    required this.mealType,
    required this.calories,
  });

  factory MealTimingEntry.fromJson(Map<String, dynamic> json) {
    return MealTimingEntry(
      time: json['time'] ?? '00:00',
      timeMinutes: json['time_minutes'] ?? 0,
      mealType: json['meal_type'] ?? 'snack',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
    );
  }
}

class MealTimingDay {
  final String date;
  final List<MealTimingEntry> meals;

  MealTimingDay({required this.date, required this.meals});

  factory MealTimingDay.fromJson(Map<String, dynamic> json) {
    return MealTimingDay(
      date: json['date'] ?? '',
      meals: (json['meals'] as List<dynamic>? ?? [])
          .map((m) => MealTimingEntry.fromJson(m))
          .toList(),
    );
  }
}

// ── Phase 3: Correlations ──────────────────────────────────────────────────────

class NutritionCorrelation {
  final String type;
  final String title;
  final String highLabel;
  final double highValue;
  final String lowLabel;
  final double lowValue;
  final bool betterWhenHigh;
  final String unit;
  final String metricLabel;

  NutritionCorrelation({
    required this.type,
    required this.title,
    required this.highLabel,
    required this.highValue,
    required this.lowLabel,
    required this.lowValue,
    required this.betterWhenHigh,
    required this.unit,
    required this.metricLabel,
  });

  factory NutritionCorrelation.fromJson(Map<String, dynamic> json) {
    return NutritionCorrelation(
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      highLabel: json['high_label'] ?? '',
      highValue: (json['high_value'] as num?)?.toDouble() ?? 0,
      lowLabel: json['low_label'] ?? '',
      lowValue: (json['low_value'] as num?)?.toDouble() ?? 0,
      betterWhenHigh: json['better_when_high'] ?? true,
      unit: json['unit'] ?? '',
      metricLabel: json['metric_label'] ?? '',
    );
  }
}

// ── Root model ─────────────────────────────────────────────────────────────────

class NutritionAnalytics {
  final List<DailyNutritionTotal> dailyTotals;
  final MacroTotals macroTotals;
  final List<TopFood> topFoods;
  final int periodDays;
  final List<MealDayCalories> mealCalories;
  // Phase 3
  final List<MealTimingDay> mealTimings;
  final double avgEatingWindowHours;
  final double avgFrontLoadPct;
  final List<NutritionCorrelation> correlations;

  NutritionAnalytics({
    required this.dailyTotals,
    required this.macroTotals,
    required this.topFoods,
    required this.periodDays,
    required this.mealCalories,
    required this.mealTimings,
    required this.avgEatingWindowHours,
    required this.avgFrontLoadPct,
    required this.correlations,
  });

  factory NutritionAnalytics.fromJson(Map<String, dynamic> json) {
    // meal_calories: {date: {date, breakfast, lunch, dinner, snack}}
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
      mealTimings: (json['meal_timings'] as List<dynamic>? ?? [])
          .map((d) => MealTimingDay.fromJson(d))
          .toList(),
      avgEatingWindowHours:
          (json['avg_eating_window'] as num?)?.toDouble() ?? 0,
      avgFrontLoadPct:
          (json['avg_front_load_pct'] as num?)?.toDouble() ?? 0,
      correlations: (json['correlations'] as List<dynamic>? ?? [])
          .map((c) => NutritionCorrelation.fromJson(c))
          .toList(),
    );
  }
}
