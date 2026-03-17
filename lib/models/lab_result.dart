// Blood Test Intelligence — Data models for lab reports, results, and dashboard.

class LabReport {
  final String id;
  final String? testDate;
  final String? labProvider;
  final String reportSource;
  final String? parseMethod;
  final double? parseConfidence;
  final String? notes;
  final String? originalFilename;
  final String? createdAt;
  final List<LabResult> results;

  LabReport({
    required this.id,
    this.testDate,
    this.labProvider,
    this.reportSource = 'upload_pdf',
    this.parseMethod,
    this.parseConfidence,
    this.notes,
    this.originalFilename,
    this.createdAt,
    this.results = const [],
  });

  factory LabReport.fromJson(Map<String, dynamic> json) => LabReport(
        id: json['id'] ?? '',
        testDate: json['test_date'],
        labProvider: json['lab_provider'],
        reportSource: json['report_source'] ?? 'upload_pdf',
        parseMethod: json['parse_method'],
        parseConfidence: (json['parse_confidence'] as num?)?.toDouble(),
        notes: json['notes'],
        originalFilename: json['original_filename'],
        createdAt: json['created_at'],
        results: (json['results'] as List<dynamic>?)
                ?.map((r) => LabResult.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class LabResult {
  final String id;
  final String? biomarkerId;
  final String? biomarkerCode;
  final String? biomarkerName;
  final String? category;
  final String? healthPillar;
  final double value;
  final String? unit;
  final double? normalizedValue;
  final double? referenceLow;
  final double? referenceHigh;
  final String? tier;
  final bool isFlagged;
  // v2.0 fields
  final double? previousValue;
  final String? previousTier;
  final String? trendDirection; // new, stable, rising, falling
  final bool? isImproving;
  final String? direction; // symmetric, lower_better, higher_better

  LabResult({
    required this.id,
    this.biomarkerId,
    this.biomarkerCode,
    this.biomarkerName,
    this.category,
    this.healthPillar,
    required this.value,
    this.unit,
    this.normalizedValue,
    this.referenceLow,
    this.referenceHigh,
    this.tier,
    this.isFlagged = false,
    this.previousValue,
    this.previousTier,
    this.trendDirection,
    this.isImproving,
    this.direction,
  });

  factory LabResult.fromJson(Map<String, dynamic> json) => LabResult(
        id: json['id'] ?? '',
        biomarkerId: json['biomarker_id'],
        biomarkerCode: json['biomarker_code'],
        biomarkerName: json['biomarker_name'],
        category: json['category'],
        healthPillar: json['health_pillar'],
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'],
        normalizedValue: (json['normalized_value'] as num?)?.toDouble(),
        referenceLow: (json['reference_low'] as num?)?.toDouble(),
        referenceHigh: (json['reference_high'] as num?)?.toDouble(),
        tier: json['tier'],
        isFlagged: json['is_flagged'] ?? false,
        previousValue: (json['previous_value'] as num?)?.toDouble(),
        previousTier: json['previous_tier'],
        trendDirection: json['trend_direction'],
        isImproving: json['is_improving'],
        direction: json['direction'],
      );
}

class BiomarkerInsights {
  final String whatItMeans;
  final String statusSummary;
  final List<String> actionPoints;

  BiomarkerInsights({
    required this.whatItMeans,
    required this.statusSummary,
    this.actionPoints = const [],
  });

  factory BiomarkerInsights.fromJson(Map<String, dynamic> json) =>
      BiomarkerInsights(
        whatItMeans: json['what_it_means'] ?? '',
        statusSummary: json['status_summary'] ?? '',
        actionPoints:
            (json['action_points'] as List<dynamic>?)?.cast<String>() ?? [],
      );
}

class BiomarkerHistory {
  final String code;
  final String name;
  final String unit;
  final String? canonicalUnit;
  final String? category;
  final String? healthPillar;
  final String? description;
  final double? populationAverage;
  final BiomarkerInsights? insights;
  final BiomarkerRange? ranges;
  final List<BiomarkerDataPoint> dataPoints;
  // v2.0 fields
  final String? direction;
  final String? responsiveness;
  final String? trendDirection;
  final double? trendVelocity;
  final bool? isImproving;
  final List<RelatedBiomarker> relatedBiomarkers;
  final List<NutrientConnection> nutrientConnections;

  BiomarkerHistory({
    required this.code,
    required this.name,
    required this.unit,
    this.canonicalUnit,
    this.category,
    this.healthPillar,
    this.description,
    this.populationAverage,
    this.insights,
    this.ranges,
    this.dataPoints = const [],
    this.direction,
    this.responsiveness,
    this.trendDirection,
    this.trendVelocity,
    this.isImproving,
    this.relatedBiomarkers = const [],
    this.nutrientConnections = const [],
  });

  factory BiomarkerHistory.fromJson(Map<String, dynamic> json) =>
      BiomarkerHistory(
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        unit: json['unit'] ?? '',
        canonicalUnit: json['canonical_unit'],
        category: json['category'],
        healthPillar: json['health_pillar'],
        description: json['description'],
        populationAverage:
            (json['population_average'] as num?)?.toDouble(),
        insights: json['insights'] != null
            ? BiomarkerInsights.fromJson(
                json['insights'] as Map<String, dynamic>)
            : null,
        ranges: json['ranges'] != null
            ? BiomarkerRange.fromJson(json['ranges'] as Map<String, dynamic>)
            : null,
        dataPoints: (json['data_points'] as List<dynamic>?)
                ?.map((d) =>
                    BiomarkerDataPoint.fromJson(d as Map<String, dynamic>))
                .toList() ??
            [],
        direction: json['direction'],
        responsiveness: json['responsiveness'],
        trendDirection: json['trend_direction'],
        trendVelocity: (json['trend_velocity'] as num?)?.toDouble(),
        isImproving: json['is_improving'],
        relatedBiomarkers: (json['related_biomarkers'] as List<dynamic>?)
                ?.map((r) =>
                    RelatedBiomarker.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
        nutrientConnections: (json['nutrient_connections'] as List<dynamic>?)
                ?.map((n) =>
                    NutrientConnection.fromJson(n as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class BiomarkerRange {
  final double? optimalLow, optimalHigh;
  final double? sufficientLow, sufficientHigh;
  final double? standardLow, standardHigh;
  final double? criticalLow, criticalHigh;
  final String? evidenceGrade;
  final String? source;

  BiomarkerRange({
    this.optimalLow, this.optimalHigh,
    this.sufficientLow, this.sufficientHigh,
    this.standardLow, this.standardHigh,
    this.criticalLow, this.criticalHigh,
    this.evidenceGrade, this.source,
  });

  factory BiomarkerRange.fromJson(Map<String, dynamic> json) => BiomarkerRange(
        optimalLow: (json['optimal_low'] as num?)?.toDouble(),
        optimalHigh: (json['optimal_high'] as num?)?.toDouble(),
        sufficientLow: (json['sufficient_low'] as num?)?.toDouble(),
        sufficientHigh: (json['sufficient_high'] as num?)?.toDouble(),
        standardLow: (json['standard_low'] as num?)?.toDouble(),
        standardHigh: (json['standard_high'] as num?)?.toDouble(),
        criticalLow: (json['critical_low'] as num?)?.toDouble(),
        criticalHigh: (json['critical_high'] as num?)?.toDouble(),
        evidenceGrade: json['evidence_grade'],
        source: json['source'],
      );
}

class BiomarkerDataPoint {
  final String? date;
  final double value;
  final String? tier;
  final String? labProvider;

  BiomarkerDataPoint({
    this.date,
    required this.value,
    this.tier,
    this.labProvider,
  });

  factory BiomarkerDataPoint.fromJson(Map<String, dynamic> json) =>
      BiomarkerDataPoint(
        date: json['date'],
        value: (json['value'] as num?)?.toDouble() ?? 0,
        tier: json['tier'],
        labProvider: json['lab_provider'],
      );
}

class LabDashboard {
  final Map<String, PillarSummary> pillars;
  final List<LabResult> latestResults;
  final int optimalCount;
  final int sufficientCount;
  final int suboptimalCount;
  final int criticalCount;
  final int totalBiomarkers;
  final String? latestReportDate;
  // v2.0 fields
  final List<PanicAlert> panicValues;
  final List<LabResult> improvements;
  final List<LabResult> attentionNeeded;
  final double? healthScore;
  final Map<String, double>? pillarScores;
  final double? previousOptimalPercent;

  LabDashboard({
    required this.pillars,
    required this.latestResults,
    this.optimalCount = 0,
    this.sufficientCount = 0,
    this.suboptimalCount = 0,
    this.criticalCount = 0,
    this.totalBiomarkers = 0,
    this.latestReportDate,
    this.panicValues = const [],
    this.improvements = const [],
    this.attentionNeeded = const [],
    this.healthScore,
    this.pillarScores,
    this.previousOptimalPercent,
  });

  factory LabDashboard.fromJson(Map<String, dynamic> json) {
    final pillarsJson = json['pillars'] as Map<String, dynamic>? ?? {};
    final pillars = pillarsJson.map((k, v) =>
        MapEntry(k, PillarSummary.fromJson(v as Map<String, dynamic>)));

    // Parse pillar_scores
    Map<String, double>? pillarScores;
    if (json['pillar_scores'] is Map) {
      pillarScores = (json['pillar_scores'] as Map<String, dynamic>)
          .map((k, v) => MapEntry(k, (v as num).toDouble()));
    }

    return LabDashboard(
      pillars: pillars,
      latestResults: (json['latest_results'] as List<dynamic>?)
              ?.map((r) => LabResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      optimalCount: json['optimal_count'] ?? 0,
      sufficientCount: json['sufficient_count'] ?? 0,
      suboptimalCount: json['suboptimal_count'] ?? 0,
      criticalCount: json['critical_count'] ?? 0,
      totalBiomarkers: json['total_biomarkers'] ?? 0,
      latestReportDate: json['latest_report_date'],
      panicValues: (json['panic_values'] as List<dynamic>?)
              ?.map((p) => PanicAlert.fromJson(p as Map<String, dynamic>))
              .toList() ??
          [],
      improvements: (json['improvements'] as List<dynamic>?)
              ?.map((r) => LabResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      attentionNeeded: (json['attention_needed'] as List<dynamic>?)
              ?.map((r) => LabResult.fromJson(r as Map<String, dynamic>))
              .toList() ??
          [],
      healthScore: (json['health_score'] as num?)?.toDouble(),
      pillarScores: pillarScores,
      previousOptimalPercent:
          (json['previous_optimal_percent'] as num?)?.toDouble(),
    );
  }
}

class PillarSummary {
  final String status;
  final int biomarkerCount;
  final List<LabResult> results;

  PillarSummary({
    required this.status,
    required this.biomarkerCount,
    this.results = const [],
  });

  factory PillarSummary.fromJson(Map<String, dynamic> json) => PillarSummary(
        status: json['status'] ?? 'unknown',
        biomarkerCount: json['biomarker_count'] ?? 0,
        results: (json['results'] as List<dynamic>?)
                ?.map((r) => LabResult.fromJson(r as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class BiomarkerDefinition {
  final String id;
  final String code;
  final String name;
  final String category;
  final String healthPillar;
  final String unit;
  final String? description;
  final int displayOrder;
  final String? direction;
  final String? responsiveness;
  final String? panelName;

  BiomarkerDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.healthPillar,
    required this.unit,
    this.description,
    this.displayOrder = 0,
    this.direction,
    this.responsiveness,
    this.panelName,
  });

  factory BiomarkerDefinition.fromJson(Map<String, dynamic> json) =>
      BiomarkerDefinition(
        id: json['id'] ?? '',
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        category: json['category'] ?? '',
        healthPillar: json['health_pillar'] ?? '',
        unit: json['unit'] ?? '',
        description: json['description'],
        displayOrder: json['display_order'] ?? 0,
        direction: json['direction'],
        responsiveness: json['responsiveness'],
        panelName: json['panel_name'],
      );
}

/// Parsed result from upload (before confirm)
class ParsedLabResult {
  String biomarkerCode;
  String biomarkerName;
  double value;
  String unit;
  double? referenceLow;
  double? referenceHigh;
  bool isFlagged;

  ParsedLabResult({
    required this.biomarkerCode,
    required this.biomarkerName,
    required this.value,
    required this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.isFlagged = false,
  });

  factory ParsedLabResult.fromJson(Map<String, dynamic> json) =>
      ParsedLabResult(
        biomarkerCode: json['biomarker_code'] ?? '',
        biomarkerName: json['biomarker_name'] ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] ?? '',
        referenceLow: (json['reference_low'] as num?)?.toDouble(),
        referenceHigh: (json['reference_high'] as num?)?.toDouble(),
        isFlagged: json['is_flagged'] ?? false,
      );

  Map<String, dynamic> toJson() => {
        'biomarker_code': biomarkerCode,
        'value': value,
        'unit': unit,
        'reference_low': referenceLow,
        'reference_high': referenceHigh,
        'is_flagged': isFlagged,
      };
}

// ── v2.0 New Models ─────────────────────────────────────────────────────────

class PanicAlert {
  final String code;
  final String name;
  final double value;
  final String unit;
  final String severity; // emergency, see_doctor
  final String message;

  PanicAlert({
    required this.code,
    required this.name,
    required this.value,
    required this.unit,
    required this.severity,
    required this.message,
  });

  factory PanicAlert.fromJson(Map<String, dynamic> json) => PanicAlert(
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: json['unit'] ?? '',
        severity: json['severity'] ?? 'see_doctor',
        message: json['message'] ?? '',
      );
}

class BiomarkerInsightModel {
  final String id;
  final String insightType;
  final String severity;
  final String title;
  final String body;
  final String? ruleId;
  final List<String> biomarkerCodes;
  final String? evidenceGrade;
  final bool isDismissed;
  final String? createdAt;

  BiomarkerInsightModel({
    required this.id,
    required this.insightType,
    required this.severity,
    required this.title,
    required this.body,
    this.ruleId,
    this.biomarkerCodes = const [],
    this.evidenceGrade,
    this.isDismissed = false,
    this.createdAt,
  });

  factory BiomarkerInsightModel.fromJson(Map<String, dynamic> json) =>
      BiomarkerInsightModel(
        id: json['id'] ?? '',
        insightType: json['insight_type'] ?? '',
        severity: json['severity'] ?? 'info',
        title: json['title'] ?? '',
        body: json['body'] ?? '',
        ruleId: json['rule_id'],
        biomarkerCodes:
            (json['biomarker_codes'] as List<dynamic>?)?.cast<String>() ?? [],
        evidenceGrade: json['evidence_grade'],
        isDismissed: json['is_dismissed'] ?? false,
        createdAt: json['created_at'],
      );
}

class HealthScoreSummary {
  final String id;
  final String? reportId;
  final double? overallScore;
  final Map<String, double> pillarScores;
  final double? bioAgeEstimate;
  final String? calculationVersion;
  final String? createdAt;

  HealthScoreSummary({
    required this.id,
    this.reportId,
    this.overallScore,
    this.pillarScores = const {},
    this.bioAgeEstimate,
    this.calculationVersion,
    this.createdAt,
  });

  factory HealthScoreSummary.fromJson(Map<String, dynamic> json) =>
      HealthScoreSummary(
        id: json['id'] ?? '',
        reportId: json['report_id'],
        overallScore: (json['overall_score'] as num?)?.toDouble(),
        pillarScores: (json['pillar_scores'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toDouble())) ??
            {},
        bioAgeEstimate: (json['bio_age_estimate'] as num?)?.toDouble(),
        calculationVersion: json['calculation_version'],
        createdAt: json['created_at'],
      );
}

class RelatedBiomarker {
  final String code;
  final String name;
  final String? healthPillar;

  RelatedBiomarker({
    required this.code,
    required this.name,
    this.healthPillar,
  });

  factory RelatedBiomarker.fromJson(Map<String, dynamic> json) =>
      RelatedBiomarker(
        code: json['code'] ?? '',
        name: json['name'] ?? '',
        healthPillar: json['health_pillar'],
      );
}

class NutrientConnection {
  final String biomarkerCode;
  final String nutrientTagname;
  final String? nutrientName;
  final String relationship;
  final String strength;
  final String? relevantWhen;

  NutrientConnection({
    required this.biomarkerCode,
    required this.nutrientTagname,
    this.nutrientName,
    required this.relationship,
    required this.strength,
    this.relevantWhen,
  });

  factory NutrientConnection.fromJson(Map<String, dynamic> json) =>
      NutrientConnection(
        biomarkerCode: json['biomarker_code'] ?? '',
        nutrientTagname: json['nutrient_tagname'] ?? '',
        nutrientName: json['nutrient_name'],
        relationship: json['relationship'] ?? '',
        strength: json['strength'] ?? '',
        relevantWhen: json['relevant_when'],
      );
}

class BiomarkerRecommendation {
  final String id;
  final String biomarkerCode;
  final String direction;
  final String category;
  final String title;
  final String? description;
  final String? mechanism;
  final String? evidenceGrade;
  final double? impactScore;

  BiomarkerRecommendation({
    required this.id,
    required this.biomarkerCode,
    required this.direction,
    required this.category,
    required this.title,
    this.description,
    this.mechanism,
    this.evidenceGrade,
    this.impactScore,
  });

  factory BiomarkerRecommendation.fromJson(Map<String, dynamic> json) =>
      BiomarkerRecommendation(
        id: json['id'] ?? '',
        biomarkerCode: json['biomarker_code'] ?? '',
        direction: json['direction'] ?? '',
        category: json['category'] ?? '',
        title: json['title'] ?? '',
        description: json['description'],
        mechanism: json['mechanism'],
        evidenceGrade: json['evidence_grade'],
        impactScore: (json['impact_score'] as num?)?.toDouble(),
      );
}
