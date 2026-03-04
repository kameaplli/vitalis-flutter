class HealthScoreData {
  final double total;
  final double nutrition;
  final double hydration;
  final double exercise;
  final double sleep;
  final double mood;

  const HealthScoreData({
    required this.total,
    required this.nutrition,
    required this.hydration,
    required this.exercise,
    required this.sleep,
    required this.mood,
  });

  factory HealthScoreData.fromJson(Map<String, dynamic> json) => HealthScoreData(
        total: (json['total'] as num?)?.toDouble() ?? 0,
        nutrition: (json['nutrition'] as num?)?.toDouble() ?? 0,
        hydration: (json['hydration'] as num?)?.toDouble() ?? 0,
        exercise: (json['exercise'] as num?)?.toDouble() ?? 0,
        sleep: (json['sleep'] as num?)?.toDouble() ?? 0,
        mood: (json['mood'] as num?)?.toDouble() ?? 0,
      );

  static const zero = HealthScoreData(
      total: 0, nutrition: 0, hydration: 0, exercise: 0, sleep: 0, mood: 0);
}

class DashboardTopFood {
  final String name;
  final double calories;
  final int count;

  const DashboardTopFood(
      {required this.name, required this.calories, required this.count});

  factory DashboardTopFood.fromJson(Map<String, dynamic> json) =>
      DashboardTopFood(
        name: json['name'] ?? '',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        count: json['count'] ?? 0,
      );
}

class DashboardInsight {
  final String type; // 'positive' | 'warning' | 'tip' | 'info'
  final String message;

  const DashboardInsight({required this.type, required this.message});

  factory DashboardInsight.fromJson(Map<String, dynamic> json) =>
      DashboardInsight(
        type: json['type'] ?? 'info',
        message: json['message'] ?? '',
      );
}

class DashboardData {
  // today
  final double todayCalories;
  final double yesterdayCalories;
  final int mealsCount;
  final double todayWater;
  final double yesterdayWater;
  final double? currentWeight;
  final double? previousWeight;
  // weekly averages
  final double weekAvgCalories;
  final double prevWeekAvgCalories;
  final double weekAvgWater;
  final double prevWeekAvgWater;
  final double weekAvgMeals;
  final double prevWeekAvgMeals;
  // today macros
  final double todayProtein;
  final double todayCarbs;
  final double todayFat;
  // extras
  final Map<String, int> mealDistribution;
  final List<DashboardTopFood> topCalorieFoods;
  final HealthScoreData healthScore;
  final HealthScoreData prevHealthScore;
  final List<DashboardInsight> insights;

  const DashboardData({
    required this.todayCalories,
    required this.yesterdayCalories,
    required this.mealsCount,
    required this.todayWater,
    required this.yesterdayWater,
    this.currentWeight,
    this.previousWeight,
    required this.weekAvgCalories,
    required this.prevWeekAvgCalories,
    required this.weekAvgWater,
    required this.prevWeekAvgWater,
    required this.weekAvgMeals,
    required this.prevWeekAvgMeals,
    required this.todayProtein,
    required this.todayCarbs,
    required this.todayFat,
    required this.mealDistribution,
    required this.topCalorieFoods,
    required this.healthScore,
    required this.prevHealthScore,
    required this.insights,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        todayCalories: (json['today_calories'] as num?)?.toDouble() ?? 0,
        yesterdayCalories:
            (json['yesterday_calories'] as num?)?.toDouble() ?? 0,
        mealsCount: json['meals_count'] ?? 0,
        todayWater: (json['today_water'] as num?)?.toDouble() ?? 0,
        yesterdayWater: (json['yesterday_water'] as num?)?.toDouble() ?? 0,
        currentWeight: (json['current_weight'] as num?)?.toDouble(),
        previousWeight: (json['previous_weight'] as num?)?.toDouble(),
        weekAvgCalories:
            (json['week_avg_calories'] as num?)?.toDouble() ?? 0,
        prevWeekAvgCalories:
            (json['prev_week_avg_calories'] as num?)?.toDouble() ?? 0,
        weekAvgWater: (json['week_avg_water'] as num?)?.toDouble() ?? 0,
        prevWeekAvgWater:
            (json['prev_week_avg_water'] as num?)?.toDouble() ?? 0,
        weekAvgMeals: (json['week_avg_meals'] as num?)?.toDouble() ?? 0,
        prevWeekAvgMeals:
            (json['prev_week_avg_meals'] as num?)?.toDouble() ?? 0,
        todayProtein: (json['today_protein'] as num?)?.toDouble() ?? 0,
        todayCarbs: (json['today_carbs'] as num?)?.toDouble() ?? 0,
        todayFat: (json['today_fat'] as num?)?.toDouble() ?? 0,
        mealDistribution: (json['meal_distribution'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
            {},
        topCalorieFoods: (json['top_calorie_foods'] as List<dynamic>? ?? [])
            .map((f) => DashboardTopFood.fromJson(f))
            .toList(),
        healthScore: json['health_score'] != null
            ? HealthScoreData.fromJson(json['health_score'])
            : HealthScoreData.zero,
        prevHealthScore: json['prev_health_score'] != null
            ? HealthScoreData.fromJson(json['prev_health_score'])
            : HealthScoreData.zero,
        insights: (json['insights'] as List<dynamic>? ?? [])
            .map((i) => DashboardInsight.fromJson(i))
            .toList(),
      );

  double? get weightChange {
    if (currentWeight == null || previousWeight == null) return null;
    return currentWeight! - previousWeight!;
  }
}
