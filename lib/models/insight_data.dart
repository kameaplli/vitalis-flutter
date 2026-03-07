/// Phase 5: AI Insights data models

class WeeklyInsight {
  final List<InsightItem> insights;
  final List<Recommendation> recommendations;
  final String source; // "ai" or "statistical"

  WeeklyInsight({
    required this.insights,
    required this.recommendations,
    required this.source,
  });

  factory WeeklyInsight.fromJson(Map<String, dynamic> json) {
    return WeeklyInsight(
      insights: (json['insights'] as List<dynamic>?)
              ?.map((i) => InsightItem.fromJson(i as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => Recommendation.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      source: json['source'] as String? ?? 'statistical',
    );
  }
}

class InsightItem {
  final String title;
  final String body;
  final double confidence;

  InsightItem({required this.title, required this.body, this.confidence = 0.5});

  factory InsightItem.fromJson(Map<String, dynamic> json) {
    return InsightItem(
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
    );
  }
}

class Recommendation {
  final String action;
  final String priority;

  Recommendation({required this.action, this.priority = 'medium'});

  factory Recommendation.fromJson(Map<String, dynamic> json) {
    return Recommendation(
      action: json['action'] as String? ?? '',
      priority: json['priority'] as String? ?? 'medium',
    );
  }
}

class FlareRiskPrediction {
  final int score;
  final String level;
  final List<RiskFactor> factors;
  final List<String> recommendations;

  FlareRiskPrediction({
    required this.score,
    required this.level,
    required this.factors,
    required this.recommendations,
  });

  factory FlareRiskPrediction.fromJson(Map<String, dynamic> json) {
    return FlareRiskPrediction(
      score: json['score'] as int? ?? 0,
      level: json['level'] as String? ?? 'low',
      factors: (json['factors'] as List<dynamic>?)
              ?.map((f) => RiskFactor.fromJson(f as Map<String, dynamic>))
              .toList() ??
          [],
      recommendations: (json['recommendations'] as List<dynamic>?)
              ?.map((r) => r.toString())
              .toList() ??
          [],
    );
  }
}

class RiskFactor {
  final String factor;
  final int contribution;
  final String detail;

  RiskFactor({required this.factor, required this.contribution, required this.detail});

  factory RiskFactor.fromJson(Map<String, dynamic> json) {
    return RiskFactor(
      factor: json['factor'] as String? ?? '',
      contribution: json['contribution'] as int? ?? 0,
      detail: json['detail'] as String? ?? '',
    );
  }
}

class InvestigationResult {
  final String answer;
  final List<String> likelyTriggers;
  final double confidence;
  final String? recommendation;
  final String source;

  InvestigationResult({
    required this.answer,
    this.likelyTriggers = const [],
    this.confidence = 0.5,
    this.recommendation,
    required this.source,
  });

  factory InvestigationResult.fromJson(Map<String, dynamic> json) {
    return InvestigationResult(
      answer: json['answer'] as String? ?? '',
      likelyTriggers: (json['likely_triggers'] as List<dynamic>?)
              ?.map((t) => t.toString())
              .toList() ??
          [],
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.5,
      recommendation: json['recommendation'] as String?,
      source: json['source'] as String? ?? 'statistical',
    );
  }
}
