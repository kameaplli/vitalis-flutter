class HealthScore {
  final String? id;
  final double? overallScore;
  final double dataCompleteness;
  final Map<String, DimensionScore> dimensions;
  final String? date;
  final String? granularity;

  HealthScore({
    this.id,
    this.overallScore,
    this.dataCompleteness = 0,
    this.dimensions = const {},
    this.date,
    this.granularity,
  });

  factory HealthScore.fromJson(Map<String, dynamic> json) {
    final dims = <String, DimensionScore>{};
    final rawDims = json['dimensions'] as Map<String, dynamic>? ?? {};
    rawDims.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        dims[key] = DimensionScore.fromJson(value);
      }
    });
    return HealthScore(
      id: json['id'] as String?,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      dataCompleteness:
          (json['data_completeness'] as num?)?.toDouble() ?? 0,
      dimensions: dims,
      date: json['date'] as String? ?? json['score_date'] as String?,
      granularity: json['granularity'] as String?,
    );
  }
}

class DimensionScore {
  final double? score;
  final double? rawPoints;
  final double maxPoints;
  final String dataQuality;
  final Map<String, dynamic> detail;

  DimensionScore({
    this.score,
    this.rawPoints,
    this.maxPoints = 100,
    this.dataQuality = 'none',
    this.detail = const {},
  });

  factory DimensionScore.fromJson(Map<String, dynamic> json) {
    return DimensionScore(
      score: (json['score'] as num?)?.toDouble(),
      rawPoints: (json['raw_points'] as num?)?.toDouble(),
      maxPoints: (json['max_points'] as num?)?.toDouble() ?? 100,
      dataQuality: json['data_quality'] as String? ?? 'none',
      detail: (json['detail'] as Map<String, dynamic>?) ?? const {},
    );
  }
}

class HealthAlert {
  final String id;
  final String alertType;
  final String category;
  final String metricKey;
  final double? currentValue;
  final double? thresholdValue;
  final String? unit;
  final int timeWindowDays;
  final String message;
  final String? recommendation;
  final String? evidence;
  final String? specialistType;
  final bool isRead;
  final bool isDismissed;
  final DateTime createdAt;

  HealthAlert({
    required this.id,
    required this.alertType,
    required this.category,
    required this.metricKey,
    this.currentValue,
    this.thresholdValue,
    this.unit,
    this.timeWindowDays = 7,
    required this.message,
    this.recommendation,
    this.evidence,
    this.specialistType,
    this.isRead = false,
    this.isDismissed = false,
    required this.createdAt,
  });

  factory HealthAlert.fromJson(Map<String, dynamic> json) {
    return HealthAlert(
      id: json['id'] as String,
      alertType: json['alert_type'] as String,
      category: json['category'] as String,
      metricKey: json['metric_key'] as String,
      currentValue: (json['current_value'] as num?)?.toDouble(),
      thresholdValue: (json['threshold_value'] as num?)?.toDouble(),
      unit: json['unit'] as String?,
      timeWindowDays: json['time_window_days'] as int? ?? 7,
      message: json['message'] as String,
      recommendation: json['recommendation'] as String?,
      evidence: json['evidence'] as String?,
      specialistType: json['specialist_type'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      isDismissed: json['is_dismissed'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class RiskProfile {
  final String riskLevel;
  final Map<String, int> activeAlertCounts;
  final List<RiskItem> topRisks;
  final List<String> strengths;
  final ScoreTrend scoreTrend;

  RiskProfile({
    required this.riskLevel,
    this.activeAlertCounts = const {},
    this.topRisks = const [],
    this.strengths = const [],
    required this.scoreTrend,
  });

  factory RiskProfile.fromJson(Map<String, dynamic> json) {
    final rawCounts =
        json['active_alert_counts'] as Map<String, dynamic>? ?? {};
    final counts = rawCounts.map(
      (key, value) => MapEntry(key, (value as num).toInt()),
    );

    final rawRisks = json['top_risks'] as List<dynamic>? ?? [];
    final risks = rawRisks
        .whereType<Map<String, dynamic>>()
        .map(RiskItem.fromJson)
        .toList();

    final rawStrengths = json['strengths'] as List<dynamic>? ?? [];
    final strengths =
        rawStrengths.map((e) => e.toString()).toList();

    return RiskProfile(
      riskLevel: json['risk_level'] as String? ?? 'low',
      activeAlertCounts: counts,
      topRisks: risks,
      strengths: strengths,
      scoreTrend: ScoreTrend.fromJson(
        json['score_trend'] as Map<String, dynamic>? ?? {},
      ),
    );
  }
}

class RiskItem {
  final String condition;
  final String severity;
  final String evidence;
  final List<String> actions;

  RiskItem({
    required this.condition,
    required this.severity,
    required this.evidence,
    this.actions = const [],
  });

  factory RiskItem.fromJson(Map<String, dynamic> json) {
    final rawActions = json['actions'] as List<dynamic>? ?? [];
    return RiskItem(
      condition: json['condition'] as String,
      severity: json['severity'] as String,
      evidence: json['evidence'] as String,
      actions: rawActions.map((e) => e.toString()).toList(),
    );
  }
}

class ScoreTrend {
  final double? current;
  final double? avg7d;
  final double? avg30d;
  final String direction;

  ScoreTrend({
    this.current,
    this.avg7d,
    this.avg30d,
    this.direction = 'stable',
  });

  factory ScoreTrend.fromJson(Map<String, dynamic> json) {
    return ScoreTrend(
      current: (json['current'] as num?)?.toDouble(),
      avg7d: (json['avg_7d'] as num?)?.toDouble(),
      avg30d: (json['avg_30d'] as num?)?.toDouble(),
      direction: json['direction'] as String? ?? 'stable',
    );
  }
}

class ClinicalReport {
  final String id;
  final Map<String, dynamic> demographics;
  final double? overallScore;
  final Map<String, dynamic> dimensionScores;
  final Map<String, dynamic> nutrientSummary;
  final List<Map<String, dynamic>> riskFlags;
  final Map<String, dynamic> trendData;
  final List<RecommendedLab> recommendedLabs;
  final List<String> doctorQuestions;
  final String? periodStart;
  final String? periodEnd;

  ClinicalReport({
    required this.id,
    this.demographics = const {},
    this.overallScore,
    this.dimensionScores = const {},
    this.nutrientSummary = const {},
    this.riskFlags = const [],
    this.trendData = const {},
    this.recommendedLabs = const [],
    this.doctorQuestions = const [],
    this.periodStart,
    this.periodEnd,
  });

  factory ClinicalReport.fromJson(Map<String, dynamic> json) {
    final rawFlags = json['risk_flags'] as List<dynamic>? ?? [];
    final flags = rawFlags
        .whereType<Map<String, dynamic>>()
        .toList();

    final rawLabs = json['recommended_labs'] as List<dynamic>? ?? [];
    final labs = rawLabs
        .whereType<Map<String, dynamic>>()
        .map(RecommendedLab.fromJson)
        .toList();

    final rawQuestions = json['doctor_questions'] as List<dynamic>? ?? [];
    final questions =
        rawQuestions.map((e) => e.toString()).toList();

    // Backend sends scores nested: {scores: {avg_score, dimension_averages}}
    final scores = json['scores'] as Map<String, dynamic>? ?? const {};

    return ClinicalReport(
      id: (json['report_id'] ?? json['id'] ?? '') as String,
      demographics:
          (json['demographics'] as Map<String, dynamic>?) ?? const {},
      overallScore: (scores['avg_score'] as num?)?.toDouble()
          ?? (json['overall_score'] as num?)?.toDouble(),
      dimensionScores:
          (scores['dimension_averages'] as Map<String, dynamic>?)
          ?? (json['dimension_scores'] as Map<String, dynamic>?)
          ?? const {},
      nutrientSummary:
          (json['nutrient_summary'] as Map<String, dynamic>?) ?? const {},
      riskFlags: flags,
      trendData:
          (json['trend_data'] as Map<String, dynamic>?) ?? const {},
      recommendedLabs: labs,
      doctorQuestions: questions,
      periodStart: json['period_start'] as String?,
      periodEnd: json['period_end'] as String?,
    );
  }
}

class RecommendedLab {
  final String test;
  final String reason;
  final String normalRange;
  final String priority;
  final String specialist;

  RecommendedLab({
    required this.test,
    required this.reason,
    required this.normalRange,
    required this.priority,
    required this.specialist,
  });

  factory RecommendedLab.fromJson(Map<String, dynamic> json) {
    return RecommendedLab(
      test: json['test'] as String,
      reason: json['reason'] as String,
      normalRange: json['normal_range'] as String? ?? '',
      priority: json['priority'] as String? ?? 'routine',
      specialist: json['specialist'] as String? ?? 'general',
    );
  }
}

class ScoreHistoryEntry {
  final String date;
  final double? overallScore;
  final double? nutrientAdequacy;
  final double? hydration;
  final double? macroBalance;
  final double? sleep;
  final double? exercise;
  final double? consistency;
  final double? dataCompleteness;

  ScoreHistoryEntry({
    required this.date,
    this.overallScore,
    this.nutrientAdequacy,
    this.hydration,
    this.macroBalance,
    this.sleep,
    this.exercise,
    this.consistency,
    this.dataCompleteness,
  });

  factory ScoreHistoryEntry.fromJson(Map<String, dynamic> json) {
    return ScoreHistoryEntry(
      date: json['date'] as String,
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      nutrientAdequacy:
          (json['nutrient_adequacy'] as num?)?.toDouble(),
      hydration: (json['hydration'] as num?)?.toDouble(),
      macroBalance: (json['macro_balance'] as num?)?.toDouble(),
      sleep: (json['sleep'] as num?)?.toDouble(),
      exercise: (json['exercise'] as num?)?.toDouble(),
      consistency: (json['consistency'] as num?)?.toDouble(),
      dataCompleteness:
          (json['data_completeness'] as num?)?.toDouble(),
    );
  }
}
