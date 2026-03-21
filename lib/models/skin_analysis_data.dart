// Skin Intelligence — AI analysis data models.

class SkinAnalysis {
  final String id;
  final String photoId;
  final double overallSeverity;
  final double? easiScore;
  final double? confidence;
  final SkinComponents components;
  final double? affectedAreaPct;
  final String? bodyRegion;
  final List<SkinCondition> conditions;
  final String? patternType;
  final String? description;
  final List<String> recommendations;
  final String? modelUsed;
  final String? analyzedAt;
  final String disclaimer;
  final SkinComparison? comparison;

  SkinAnalysis({
    required this.id,
    required this.photoId,
    required this.overallSeverity,
    this.easiScore,
    this.confidence,
    required this.components,
    this.affectedAreaPct,
    this.bodyRegion,
    required this.conditions,
    this.patternType,
    this.description,
    required this.recommendations,
    this.modelUsed,
    this.analyzedAt,
    required this.disclaimer,
    this.comparison,
  });

  factory SkinAnalysis.fromJson(Map<String, dynamic> j) {
    final comps = j['components'] as Map<String, dynamic>? ?? {};
    final conds = (j['conditions'] as List? ?? [])
        .map((c) => SkinCondition.fromJson(c as Map<String, dynamic>))
        .toList();
    final recs = (j['recommendations'] as List? ?? [])
        .map((r) => r.toString())
        .toList();

    return SkinAnalysis(
      id: j['id'] ?? '',
      photoId: j['photo_id'] ?? '',
      overallSeverity: (j['overall_severity'] ?? 0).toDouble(),
      easiScore: (j['easi_score'] as num?)?.toDouble(),
      confidence: (j['confidence'] as num?)?.toDouble(),
      components: SkinComponents.fromJson(comps),
      affectedAreaPct: (j['affected_area_pct'] as num?)?.toDouble(),
      bodyRegion: j['body_region'],
      conditions: conds,
      patternType: j['pattern_type'],
      description: j['description'],
      recommendations: recs,
      modelUsed: j['model_used'],
      analyzedAt: j['analyzed_at'],
      disclaimer: j['disclaimer'] ?? '',
      comparison: j['comparison'] != null
          ? SkinComparison.fromJson(j['comparison'] as Map<String, dynamic>)
          : null,
    );
  }

  String get severityLabel {
    if (overallSeverity <= 0) return 'Clear';
    if (overallSeverity <= 2) return 'Minimal';
    if (overallSeverity <= 4) return 'Mild';
    if (overallSeverity <= 6) return 'Moderate';
    if (overallSeverity <= 8) return 'Severe';
    return 'Very Severe';
  }

  int get severityColorValue {
    if (overallSeverity <= 0) return 0xFF22C55E; // green
    if (overallSeverity <= 2) return 0xFF84CC16; // lime
    if (overallSeverity <= 4) return 0xFFEAB308; // yellow
    if (overallSeverity <= 6) return 0xFFF97316; // orange
    if (overallSeverity <= 8) return 0xFFEF4444; // red
    return 0xFFDC2626; // dark red
  }
}

class SkinComponents {
  final double erythema;
  final double edema;
  final double excoriation;
  final double lichenification;
  final double dryness;
  final double oozing;

  SkinComponents({
    required this.erythema,
    required this.edema,
    required this.excoriation,
    required this.lichenification,
    required this.dryness,
    required this.oozing,
  });

  factory SkinComponents.fromJson(Map<String, dynamic> j) => SkinComponents(
        erythema: (j['erythema'] ?? 0).toDouble(),
        edema: (j['edema'] ?? 0).toDouble(),
        excoriation: (j['excoriation'] ?? 0).toDouble(),
        lichenification: (j['lichenification'] ?? 0).toDouble(),
        dryness: (j['dryness'] ?? 0).toDouble(),
        oozing: (j['oozing'] ?? 0).toDouble(),
      );

  List<MapEntry<String, double>> get entries => [
        MapEntry('Redness', erythema),
        MapEntry('Swelling', edema),
        MapEntry('Scratching', excoriation),
        MapEntry('Thickening', lichenification),
        MapEntry('Dryness', dryness),
        MapEntry('Oozing', oozing),
      ];
}

class SkinCondition {
  final String name;
  final double confidence;

  SkinCondition({required this.name, required this.confidence});

  factory SkinCondition.fromJson(Map<String, dynamic> j) => SkinCondition(
        name: j['name'] ?? 'Unknown',
        confidence: (j['confidence'] ?? 0).toDouble(),
      );
}

class SkinComparison {
  final String comparedToId;
  final double changeScore;
  final String changeSummary;

  SkinComparison({
    required this.comparedToId,
    required this.changeScore,
    required this.changeSummary,
  });

  factory SkinComparison.fromJson(Map<String, dynamic> j) => SkinComparison(
        comparedToId: j['compared_to_id'] ?? '',
        changeScore: (j['change_score'] ?? 0).toDouble(),
        changeSummary: j['change_summary'] ?? '',
      );

  String get changeLabel {
    if (changeScore <= -5) return 'Significant Improvement';
    if (changeScore <= -2) return 'Improvement';
    if (changeScore < 2) return 'Stable';
    if (changeScore < 5) return 'Worsening';
    return 'Significant Worsening';
  }
}

class SkinTrend {
  final String trend;
  final double? currentSeverity;
  final double? avgSeverityRecent;
  final double? avgSeverityOlder;
  final double changePct;
  final int totalAnalyses;
  final List<SkinTrendPoint> dataPoints;

  SkinTrend({
    required this.trend,
    this.currentSeverity,
    this.avgSeverityRecent,
    this.avgSeverityOlder,
    required this.changePct,
    required this.totalAnalyses,
    required this.dataPoints,
  });

  factory SkinTrend.fromJson(Map<String, dynamic> j) {
    final pts = (j['data_points'] as List? ?? [])
        .map((p) => SkinTrendPoint.fromJson(p as Map<String, dynamic>))
        .toList();
    return SkinTrend(
      trend: j['trend'] ?? 'no_data',
      currentSeverity: (j['current_severity'] as num?)?.toDouble(),
      avgSeverityRecent: (j['avg_severity_recent'] as num?)?.toDouble(),
      avgSeverityOlder: (j['avg_severity_older'] as num?)?.toDouble(),
      changePct: (j['change_pct'] ?? 0).toDouble(),
      totalAnalyses: j['total_analyses'] ?? 0,
      dataPoints: pts,
    );
  }
}

class SkinTrendPoint {
  final String? date;
  final double severity;
  final double? easiScore;
  final String? photoId;

  SkinTrendPoint({this.date, required this.severity, this.easiScore, this.photoId});

  factory SkinTrendPoint.fromJson(Map<String, dynamic> j) => SkinTrendPoint(
        date: j['date'],
        severity: (j['severity'] ?? 0).toDouble(),
        easiScore: (j['easi_score'] as num?)?.toDouble(),
        photoId: j['photo_id'],
      );
}

