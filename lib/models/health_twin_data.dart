// ── Health Twin / Goals / Weekly Summary data models ─────────────────────────

class MacroStatus {
  final double consumed;
  final double target;
  final double percent;

  MacroStatus({
    required this.consumed,
    required this.target,
    required this.percent,
  });

  factory MacroStatus.fromJson(Map<String, dynamic> json) => MacroStatus(
        consumed: (json['consumed'] as num?)?.toDouble() ?? 0,
        target: (json['target'] as num?)?.toDouble() ?? 0,
        percent: (json['percent'] as num?)?.toDouble() ?? 0,
      );
}

class NutrientGap {
  final String tagname;
  final String displayName;
  final double consumed;
  final double target;
  final double percentDri;
  final String unit;

  NutrientGap({
    required this.tagname,
    required this.displayName,
    required this.consumed,
    required this.target,
    required this.percentDri,
    required this.unit,
  });

  factory NutrientGap.fromJson(Map<String, dynamic> json) => NutrientGap(
        tagname: json['tagname'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        consumed: (json['consumed'] as num?)?.toDouble() ?? 0,
        target: (json['target'] as num?)?.toDouble() ?? 0,
        percentDri: (json['percent_dri'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] as String? ?? '',
      );
}

class DailyTwin {
  final String date;
  final Map<String, MacroStatus> macros;
  final int microAdequateCount;
  final int microApproachingCount;
  final int microLowCount;
  final int microExcessiveCount;
  final int microTotalTracked;
  final double completenessScore;
  final List<NutrientGap> topGaps;
  final List<NutrientGap> topExcesses;
  final double hydrationMl;
  final double hydrationTargetMl;
  final double hydrationPercent;
  final double healthScore;
  final List<Map<String, dynamic>> foodRecommendations;

  DailyTwin({
    required this.date,
    this.macros = const {},
    this.microAdequateCount = 0,
    this.microApproachingCount = 0,
    this.microLowCount = 0,
    this.microExcessiveCount = 0,
    this.microTotalTracked = 0,
    this.completenessScore = 0,
    this.topGaps = const [],
    this.topExcesses = const [],
    this.hydrationMl = 0,
    this.hydrationTargetMl = 2000,
    this.hydrationPercent = 0,
    this.healthScore = 0,
    this.foodRecommendations = const [],
  });

  factory DailyTwin.fromJson(Map<String, dynamic> json) {
    final rawMacros = json['macros'] as Map<String, dynamic>? ?? {};
    final macros = rawMacros.map(
      (key, value) => MapEntry(
        key,
        MacroStatus.fromJson(value as Map<String, dynamic>),
      ),
    );

    final rawGaps = json['top_gaps'] as List<dynamic>? ?? [];
    final gaps = rawGaps
        .whereType<Map<String, dynamic>>()
        .map(NutrientGap.fromJson)
        .toList();

    final rawExcesses = json['top_excesses'] as List<dynamic>? ?? [];
    final excesses = rawExcesses
        .whereType<Map<String, dynamic>>()
        .map(NutrientGap.fromJson)
        .toList();

    final rawRecs = json['food_recommendations'] as List<dynamic>? ?? [];
    final recs = rawRecs.whereType<Map<String, dynamic>>().toList();

    return DailyTwin(
      date: json['date'] as String? ?? '',
      macros: macros,
      microAdequateCount: (json['micro_adequate_count'] as num?)?.toInt() ?? 0,
      microApproachingCount:
          (json['micro_approaching_count'] as num?)?.toInt() ?? 0,
      microLowCount: (json['micro_low_count'] as num?)?.toInt() ?? 0,
      microExcessiveCount:
          (json['micro_excessive_count'] as num?)?.toInt() ?? 0,
      microTotalTracked:
          (json['micro_total_tracked'] as num?)?.toInt() ?? 0,
      completenessScore:
          (json['completeness_score'] as num?)?.toDouble() ?? 0,
      topGaps: gaps,
      topExcesses: excesses,
      hydrationMl: (json['hydration_ml'] as num?)?.toDouble() ?? 0,
      hydrationTargetMl:
          (json['hydration_target_ml'] as num?)?.toDouble() ?? 2000,
      hydrationPercent:
          (json['hydration_percent'] as num?)?.toDouble() ?? 0,
      healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
      foodRecommendations: recs,
    );
  }
}

class TwinTrendEntry {
  final String date;
  final double completenessScore;
  final double healthScore;
  final double caloriesConsumed;
  final double hydrationMl;

  TwinTrendEntry({
    required this.date,
    this.completenessScore = 0,
    this.healthScore = 0,
    this.caloriesConsumed = 0,
    this.hydrationMl = 0,
  });

  factory TwinTrendEntry.fromJson(Map<String, dynamic> json) => TwinTrendEntry(
        date: json['date'] as String? ?? '',
        completenessScore:
            (json['completeness_score'] as num?)?.toDouble() ?? 0,
        healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
        caloriesConsumed:
            (json['calories_consumed'] as num?)?.toDouble() ?? 0,
        hydrationMl: (json['hydration_ml'] as num?)?.toDouble() ?? 0,
      );
}

class UserGoal {
  final String id;
  final String goalType;
  final String label;
  final double? startValue;
  final double? currentValue;
  final double? targetValue;
  final String? targetUnit;
  final String? targetDate;
  final double progressPct;
  final String trend;
  final bool isActive;
  final int priority;
  final String? notes;

  UserGoal({
    required this.id,
    required this.goalType,
    required this.label,
    this.startValue,
    this.currentValue,
    this.targetValue,
    this.targetUnit,
    this.targetDate,
    this.progressPct = 0,
    this.trend = 'on_track',
    this.isActive = true,
    this.priority = 1,
    this.notes,
  });

  factory UserGoal.fromJson(Map<String, dynamic> json) => UserGoal(
        id: json['id'] as String? ?? '',
        goalType: json['goal_type'] as String? ?? '',
        label: json['label'] as String? ?? '',
        startValue: (json['start_value'] as num?)?.toDouble(),
        currentValue: (json['current_value'] as num?)?.toDouble(),
        targetValue: (json['target_value'] as num?)?.toDouble(),
        targetUnit: json['target_unit'] as String?,
        targetDate: json['target_date'] as String?,
        progressPct: (json['progress_pct'] as num?)?.toDouble() ?? 0,
        trend: json['trend'] as String? ?? 'on_track',
        isActive: json['is_active'] as bool? ?? true,
        priority: (json['priority'] as num?)?.toInt() ?? 1,
        notes: json['notes'] as String?,
      );
}

class GoalInsight {
  final String title;
  final String body;
  final double confidence;
  final String? category;

  GoalInsight({
    required this.title,
    required this.body,
    this.confidence = 0,
    this.category,
  });

  factory GoalInsight.fromJson(Map<String, dynamic> json) => GoalInsight(
        title: json['title'] as String? ?? '',
        body: json['body'] as String? ?? '',
        confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
        category: json['category'] as String?,
      );
}

class GoalInsightsResponse {
  final String goalId;
  final String goalType;
  final Map<String, dynamic> progress;
  final List<GoalInsight> insights;
  final List<Map<String, dynamic>> recommendations;

  GoalInsightsResponse({
    required this.goalId,
    required this.goalType,
    this.progress = const {},
    this.insights = const [],
    this.recommendations = const [],
  });

  factory GoalInsightsResponse.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'] as List<dynamic>? ?? [];
    final insights = rawInsights
        .whereType<Map<String, dynamic>>()
        .map(GoalInsight.fromJson)
        .toList();

    final rawRecs = json['recommendations'] as List<dynamic>? ?? [];
    final recs = rawRecs.whereType<Map<String, dynamic>>().toList();

    return GoalInsightsResponse(
      goalId: json['goal_id'] as String? ?? '',
      goalType: json['goal_type'] as String? ?? '',
      progress:
          (json['progress'] as Map<String, dynamic>?) ?? const {},
      insights: insights,
      recommendations: recs,
    );
  }
}

class WeeklySummaryData {
  final String weekStart;
  final String weekEnd;
  final String summaryText;
  final int daysLogged;
  final double avgCompletenessScore;
  final double avgHealthScore;
  final double avgDailyCalories;
  final List<GoalInsight> insights;
  final List<Map<String, dynamic>> recommendations;
  final List<Map<String, dynamic>> correlations;
  final List<Map<String, dynamic>> goalProgress;
  final Map<String, dynamic> comparison;
  final String source;

  WeeklySummaryData({
    required this.weekStart,
    required this.weekEnd,
    this.summaryText = '',
    this.daysLogged = 0,
    this.avgCompletenessScore = 0,
    this.avgHealthScore = 0,
    this.avgDailyCalories = 0,
    this.insights = const [],
    this.recommendations = const [],
    this.correlations = const [],
    this.goalProgress = const [],
    this.comparison = const {},
    this.source = 'statistical',
  });

  factory WeeklySummaryData.fromJson(Map<String, dynamic> json) {
    final rawInsights = json['insights'] as List<dynamic>? ?? [];
    final insights = rawInsights
        .whereType<Map<String, dynamic>>()
        .map(GoalInsight.fromJson)
        .toList();

    final rawRecs = json['recommendations'] as List<dynamic>? ?? [];
    final recs = rawRecs.whereType<Map<String, dynamic>>().toList();

    final rawCorr = json['correlations'] as List<dynamic>? ?? [];
    final corr = rawCorr.whereType<Map<String, dynamic>>().toList();

    final rawGoalProg = json['goal_progress'] as List<dynamic>? ?? [];
    final goalProg = rawGoalProg.whereType<Map<String, dynamic>>().toList();

    return WeeklySummaryData(
      weekStart: json['week_start'] as String? ?? '',
      weekEnd: json['week_end'] as String? ?? '',
      summaryText: json['summary_text'] as String? ?? '',
      daysLogged: (json['days_logged'] as num?)?.toInt() ?? 0,
      avgCompletenessScore:
          (json['avg_completeness_score'] as num?)?.toDouble() ?? 0,
      avgHealthScore:
          (json['avg_health_score'] as num?)?.toDouble() ?? 0,
      avgDailyCalories:
          (json['avg_daily_calories'] as num?)?.toDouble() ?? 0,
      insights: insights,
      recommendations: recs,
      correlations: corr,
      goalProgress: goalProg,
      comparison:
          (json['comparison'] as Map<String, dynamic>?) ?? const {},
      source: json['source'] as String? ?? 'statistical',
    );
  }
}
