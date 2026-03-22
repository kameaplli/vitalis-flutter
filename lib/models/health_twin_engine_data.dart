// ── Health Twin Engine Phase 2-4 data models ────────────────────────────────

// ── Cross-Domain Correlations ───────────────────────────────────────────────

class CorrelationResult {
  final String pair;
  final String domainA;
  final String domainB;
  final String metricA;
  final String metricB;
  final double correlation;
  final double? pValue;
  final String strength; // weak, moderate, strong
  final String direction; // positive, negative
  final int dataPoints;
  final String insight;
  final String confidence;

  const CorrelationResult({
    required this.pair,
    required this.domainA,
    required this.domainB,
    required this.metricA,
    required this.metricB,
    required this.correlation,
    this.pValue,
    required this.strength,
    required this.direction,
    required this.dataPoints,
    required this.insight,
    required this.confidence,
  });

  factory CorrelationResult.fromJson(Map<String, dynamic> json) =>
      CorrelationResult(
        pair: json['pair'] as String? ?? '',
        domainA: json['domain_a'] as String? ?? '',
        domainB: json['domain_b'] as String? ?? '',
        metricA: json['metric_a'] as String? ?? '',
        metricB: json['metric_b'] as String? ?? '',
        correlation: (json['correlation'] as num?)?.toDouble() ?? 0,
        pValue: (json['p_value'] as num?)?.toDouble(),
        strength: json['strength'] as String? ?? 'weak',
        direction: json['direction'] as String? ?? 'positive',
        dataPoints: (json['data_points'] as num?)?.toInt() ?? 0,
        insight: json['insight'] as String? ?? '',
        confidence: json['confidence'] as String? ?? 'low',
      );
}

class TopInsight {
  final String title;
  final String description;
  final String strength;
  final List<String> domains;
  final bool actionable;
  final String? recommendation;

  const TopInsight({
    required this.title,
    required this.description,
    required this.strength,
    required this.domains,
    required this.actionable,
    this.recommendation,
  });

  factory TopInsight.fromJson(Map<String, dynamic> json) => TopInsight(
        title: json['title'] as String? ?? '',
        description: json['description'] as String? ?? '',
        strength: json['strength'] as String? ?? '',
        domains: (json['domains'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
        actionable: json['actionable'] as bool? ?? false,
        recommendation: json['recommendation'] as String?,
      );
}

class CrossDomainCorrelations {
  final int periodDays;
  final int dataPoints;
  final List<CorrelationResult> correlations;
  final List<TopInsight> topInsights;
  final Map<String, dynamic> domainSummary;

  const CrossDomainCorrelations({
    required this.periodDays,
    required this.dataPoints,
    required this.correlations,
    required this.topInsights,
    required this.domainSummary,
  });

  factory CrossDomainCorrelations.fromJson(Map<String, dynamic> json) {
    final rawCorr = json['correlations'] as List<dynamic>? ?? [];
    final rawInsights = json['top_insights'] as List<dynamic>? ?? [];
    return CrossDomainCorrelations(
      periodDays: (json['period_days'] as num?)?.toInt() ?? 30,
      dataPoints: (json['data_points'] as num?)?.toInt() ?? 0,
      correlations: rawCorr
          .whereType<Map<String, dynamic>>()
          .map(CorrelationResult.fromJson)
          .toList(),
      topInsights: rawInsights
          .whereType<Map<String, dynamic>>()
          .map(TopInsight.fromJson)
          .toList(),
      domainSummary:
          json['domain_summary'] as Map<String, dynamic>? ?? const {},
    );
  }
}

// ── Health Level ────────────────────────────────────────────────────────────

class HealthLevel {
  final int level;
  final String name;
  final String color;
  final String icon;
  final double score7dAvg;
  final Map<String, dynamic>? nextLevel;
  final double progressToNext;
  final int daysAtLevel;

  const HealthLevel({
    required this.level,
    required this.name,
    required this.color,
    required this.icon,
    required this.score7dAvg,
    this.nextLevel,
    required this.progressToNext,
    required this.daysAtLevel,
  });

  factory HealthLevel.fromJson(Map<String, dynamic> json) => HealthLevel(
        level: (json['level'] as num?)?.toInt() ?? 1,
        name: json['name'] as String? ?? 'Beginner',
        color: json['color'] as String? ?? '#9E9E9E',
        icon: json['icon'] as String? ?? '',
        score7dAvg: (json['score_7d_avg'] as num?)?.toDouble() ?? 0,
        nextLevel: json['next_level'] as Map<String, dynamic>?,
        progressToNext:
            (json['progress_to_next'] as num?)?.toDouble() ?? 0,
        daysAtLevel: (json['days_at_level'] as num?)?.toInt() ?? 0,
      );
}

// ── Streaks ─────────────────────────────────────────────────────────────────

class StreakInfo {
  final int current;
  final int best;
  final String? lastDate;

  const StreakInfo({
    required this.current,
    required this.best,
    this.lastDate,
  });

  factory StreakInfo.fromJson(Map<String, dynamic> json) => StreakInfo(
        current: (json['current'] as num?)?.toInt() ?? 0,
        best: (json['best'] as num?)?.toInt() ?? 0,
        lastDate: json['last_logged'] as String? ??
            json['last_exercised'] as String?,
      );
}

class HealthStreaks {
  final StreakInfo logging;
  final StreakInfo completeness;
  final StreakInfo hydration;
  final StreakInfo exercise;

  const HealthStreaks({
    required this.logging,
    required this.completeness,
    required this.hydration,
    required this.exercise,
  });

  factory HealthStreaks.fromJson(Map<String, dynamic> json) => HealthStreaks(
        logging: StreakInfo.fromJson(
            json['logging_streak'] as Map<String, dynamic>? ?? {}),
        completeness: StreakInfo.fromJson(
            json['completeness_streak'] as Map<String, dynamic>? ?? {}),
        hydration: StreakInfo.fromJson(
            json['hydration_streak'] as Map<String, dynamic>? ?? {}),
        exercise: StreakInfo.fromJson(
            json['exercise_streak'] as Map<String, dynamic>? ?? {}),
      );
}

// ── Achievements ────────────────────────────────────────────────────────────

class Achievement {
  final String id;
  final String name;
  final String description;
  final String icon;
  final String category;
  final bool unlocked;
  final String? unlockedDate;
  final double? progress;
  final int? current;
  final int? target;

  const Achievement({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.category,
    required this.unlocked,
    this.unlockedDate,
    this.progress,
    this.current,
    this.target,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        icon: json['icon'] as String? ?? '',
        category: json['category'] as String? ?? '',
        unlocked: json['unlocked'] as bool? ?? false,
        unlockedDate: json['unlocked_date'] as String?,
        progress: (json['progress'] as num?)?.toDouble(),
        current: (json['current'] as num?)?.toInt(),
        target: (json['target'] as num?)?.toInt(),
      );
}

class AchievementsData {
  final int totalUnlocked;
  final int totalAvailable;
  final Map<String, dynamic> categories;
  final List<Achievement> achievements;
  final List<Achievement> recentlyUnlocked;

  const AchievementsData({
    required this.totalUnlocked,
    required this.totalAvailable,
    required this.categories,
    required this.achievements,
    required this.recentlyUnlocked,
  });

  factory AchievementsData.fromJson(Map<String, dynamic> json) {
    final rawAch = json['achievements'] as List<dynamic>? ?? [];
    final rawRecent = json['recently_unlocked'] as List<dynamic>? ?? [];
    return AchievementsData(
      totalUnlocked: (json['total_unlocked'] as num?)?.toInt() ?? 0,
      totalAvailable: (json['total_available'] as num?)?.toInt() ?? 0,
      categories:
          json['categories'] as Map<String, dynamic>? ?? const {},
      achievements: rawAch
          .whereType<Map<String, dynamic>>()
          .map(Achievement.fromJson)
          .toList(),
      recentlyUnlocked: rawRecent
          .whereType<Map<String, dynamic>>()
          .map(Achievement.fromJson)
          .toList(),
    );
  }
}

// ── Engagement Summary ──────────────────────────────────────────────────────

class EngagementSummary {
  final HealthLevel healthLevel;
  final HealthStreaks streaks;
  final Map<String, dynamic> achievementsSummary;
  final Map<String, dynamic> xp;
  final List<Map<String, dynamic>> milestones;

  const EngagementSummary({
    required this.healthLevel,
    required this.streaks,
    required this.achievementsSummary,
    required this.xp,
    required this.milestones,
  });

  factory EngagementSummary.fromJson(Map<String, dynamic> json) {
    final rawMilestones = json['milestones'] as List<dynamic>? ?? [];
    return EngagementSummary(
      healthLevel: HealthLevel.fromJson(
          json['health_level'] as Map<String, dynamic>? ?? {}),
      streaks: HealthStreaks.fromJson(
          json['streaks'] as Map<String, dynamic>? ?? {}),
      achievementsSummary:
          json['achievements_summary'] as Map<String, dynamic>? ?? {},
      xp: json['xp'] as Map<String, dynamic>? ?? {},
      milestones:
          rawMilestones.whereType<Map<String, dynamic>>().toList(),
    );
  }
}

// ── Predictions ─────────────────────────────────────────────────────────────

class HealthPrediction {
  final String metric;
  final double? current;
  final String trend;
  final double? trendRate;
  final Map<String, dynamic> predictions;
  final String confidence;
  final String insight;
  final Map<String, dynamic>? goal;
  final List<Map<String, dynamic>>? persistentGaps;

  const HealthPrediction({
    required this.metric,
    this.current,
    required this.trend,
    this.trendRate,
    required this.predictions,
    required this.confidence,
    required this.insight,
    this.goal,
    this.persistentGaps,
  });

  factory HealthPrediction.fromJson(Map<String, dynamic> json) =>
      HealthPrediction(
        metric: json['metric'] as String? ?? '',
        current: (json['current'] as num?)?.toDouble(),
        trend: json['trend'] as String? ?? 'stable',
        trendRate: (json['trend_rate'] as num?)?.toDouble(),
        predictions:
            json['predictions'] as Map<String, dynamic>? ?? const {},
        confidence: json['confidence'] as String? ?? 'low',
        insight: json['insight'] as String? ?? '',
        goal: json['goal'] as Map<String, dynamic>?,
        persistentGaps:
            (json['persistent_gaps'] as List<dynamic>?)
                ?.whereType<Map<String, dynamic>>()
                .toList(),
      );
}

class PredictionsData {
  final String generatedAt;
  final String dataQuality;
  final List<HealthPrediction> predictions;
  final List<Map<String, dynamic>> riskFlags;

  const PredictionsData({
    required this.generatedAt,
    required this.dataQuality,
    required this.predictions,
    required this.riskFlags,
  });

  factory PredictionsData.fromJson(Map<String, dynamic> json) {
    final rawPreds = json['predictions'] as List<dynamic>? ?? [];
    final rawFlags = json['risk_flags'] as List<dynamic>? ?? [];
    return PredictionsData(
      generatedAt: json['generated_at'] as String? ?? '',
      dataQuality: json['data_quality'] as String? ?? 'insufficient',
      predictions: rawPreds
          .whereType<Map<String, dynamic>>()
          .map(HealthPrediction.fromJson)
          .toList(),
      riskFlags: rawFlags.whereType<Map<String, dynamic>>().toList(),
    );
  }
}

class WhatIfScenario {
  final String id;
  final String title;
  final String? description;
  final Map<String, dynamic> predictedImpact;
  final String difficulty;
  final List<String>? foodSuggestions;

  const WhatIfScenario({
    required this.id,
    required this.title,
    this.description,
    required this.predictedImpact,
    required this.difficulty,
    this.foodSuggestions,
  });

  factory WhatIfScenario.fromJson(Map<String, dynamic> json) =>
      WhatIfScenario(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        description: json['description'] as String?,
        predictedImpact:
            json['predicted_impact'] as Map<String, dynamic>? ?? {},
        difficulty: json['difficulty'] as String? ?? 'moderate',
        foodSuggestions: (json['food_suggestions'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
      );
}

// ── Lab Feedback ────────────────────────────────────────────────────────────

class LabNutrientFeedback {
  final String biomarker;
  final String biomarkerCode;
  final double? latestValue;
  final double? previousValue;
  final String? unit;
  final String trend;
  final String? classification;
  final List<Map<String, dynamic>> relatedNutrients;
  final String insight;
  final String? recommendation;
  final String confidence;

  const LabNutrientFeedback({
    required this.biomarker,
    required this.biomarkerCode,
    this.latestValue,
    this.previousValue,
    this.unit,
    required this.trend,
    this.classification,
    required this.relatedNutrients,
    required this.insight,
    this.recommendation,
    required this.confidence,
  });

  factory LabNutrientFeedback.fromJson(Map<String, dynamic> json) {
    final rawNutrients =
        json['related_nutrients'] as List<dynamic>? ?? [];
    return LabNutrientFeedback(
      biomarker: json['biomarker'] as String? ?? '',
      biomarkerCode: json['biomarker_code'] as String? ?? '',
      latestValue: (json['latest_value'] as num?)?.toDouble(),
      previousValue: (json['previous_value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      trend: json['trend'] as String? ?? 'no_comparison',
      classification: json['classification'] as String?,
      relatedNutrients:
          rawNutrients.whereType<Map<String, dynamic>>().toList(),
      insight: json['insight'] as String? ?? '',
      recommendation: json['recommendation'] as String?,
      confidence: json['confidence'] as String? ?? 'low',
    );
  }
}

class LabFeedbackData {
  final bool hasLabData;
  final int labReportsCount;
  final String? latestReportDate;
  final List<LabNutrientFeedback> feedback;
  final List<Map<String, dynamic>> validatedImprovements;
  final List<Map<String, dynamic>> actionItems;

  const LabFeedbackData({
    required this.hasLabData,
    required this.labReportsCount,
    this.latestReportDate,
    required this.feedback,
    required this.validatedImprovements,
    required this.actionItems,
  });

  factory LabFeedbackData.fromJson(Map<String, dynamic> json) {
    final rawFb = json['feedback'] as List<dynamic>? ?? [];
    final rawImprovements =
        json['validated_improvements'] as List<dynamic>? ?? [];
    final rawActions = json['action_items'] as List<dynamic>? ?? [];
    return LabFeedbackData(
      hasLabData: json['has_lab_data'] as bool? ?? false,
      labReportsCount:
          (json['lab_reports_count'] as num?)?.toInt() ?? 0,
      latestReportDate: json['latest_report_date'] as String?,
      feedback: rawFb
          .whereType<Map<String, dynamic>>()
          .map(LabNutrientFeedback.fromJson)
          .toList(),
      validatedImprovements:
          rawImprovements.whereType<Map<String, dynamic>>().toList(),
      actionItems:
          rawActions.whereType<Map<String, dynamic>>().toList(),
    );
  }
}

// ── Family Overview ─────────────────────────────────────────────────────────

class FamilyMemberOverview {
  final String personId;
  final String name;
  final String? avatarUrl;
  final String relationship;
  final int? age;
  final Map<String, dynamic>? twinSnapshot;
  final List<Map<String, dynamic>> topGaps;
  final List<Map<String, dynamic>> activeGoals;
  final int activeAlerts;
  final int loggingStreak;
  final String status; // good, attention_needed, critical, no_data
  final String? statusReason;

  const FamilyMemberOverview({
    required this.personId,
    required this.name,
    this.avatarUrl,
    required this.relationship,
    this.age,
    this.twinSnapshot,
    required this.topGaps,
    required this.activeGoals,
    required this.activeAlerts,
    required this.loggingStreak,
    required this.status,
    this.statusReason,
  });

  factory FamilyMemberOverview.fromJson(Map<String, dynamic> json) {
    final rawGaps = json['top_gaps'] as List<dynamic>? ?? [];
    final rawGoals = json['active_goals'] as List<dynamic>? ?? [];
    return FamilyMemberOverview(
      personId: json['person_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      avatarUrl: json['avatar_url'] as String?,
      relationship: json['relationship'] as String? ?? '',
      age: (json['age'] as num?)?.toInt(),
      twinSnapshot: json['twin_snapshot'] as Map<String, dynamic>?,
      topGaps: rawGaps.whereType<Map<String, dynamic>>().toList(),
      activeGoals: rawGoals.whereType<Map<String, dynamic>>().toList(),
      activeAlerts: (json['active_alerts'] as num?)?.toInt() ?? 0,
      loggingStreak: (json['logging_streak'] as num?)?.toInt() ?? 0,
      status: json['status'] as String? ?? 'no_data',
      statusReason: json['status_reason'] as String?,
    );
  }
}

class FamilyOverviewData {
  final String date;
  final List<FamilyMemberOverview> members;
  final Map<String, dynamic> familySummary;
  final List<Map<String, dynamic>> familyAlerts;

  const FamilyOverviewData({
    required this.date,
    required this.members,
    required this.familySummary,
    required this.familyAlerts,
  });

  factory FamilyOverviewData.fromJson(Map<String, dynamic> json) {
    final rawMembers = json['members'] as List<dynamic>? ?? [];
    final rawAlerts = json['family_alerts'] as List<dynamic>? ?? [];
    return FamilyOverviewData(
      date: json['date'] as String? ?? '',
      members: rawMembers
          .whereType<Map<String, dynamic>>()
          .map(FamilyMemberOverview.fromJson)
          .toList(),
      familySummary:
          json['family_summary'] as Map<String, dynamic>? ?? {},
      familyAlerts:
          rawAlerts.whereType<Map<String, dynamic>>().toList(),
    );
  }
}
