/// Blood Test Intelligence — Data models for lab reports, results, and dashboard.

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
  final String? tier; // optimal, sufficient, suboptimal, critical
  final bool isFlagged;

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
    this.optimalLow,
    this.optimalHigh,
    this.sufficientLow,
    this.sufficientHigh,
    this.standardLow,
    this.standardHigh,
    this.criticalLow,
    this.criticalHigh,
    this.evidenceGrade,
    this.source,
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

  LabDashboard({
    required this.pillars,
    required this.latestResults,
    this.optimalCount = 0,
    this.sufficientCount = 0,
    this.suboptimalCount = 0,
    this.criticalCount = 0,
    this.totalBiomarkers = 0,
    this.latestReportDate,
  });

  factory LabDashboard.fromJson(Map<String, dynamic> json) {
    final pillarsJson = json['pillars'] as Map<String, dynamic>? ?? {};
    final pillars = pillarsJson.map((k, v) =>
        MapEntry(k, PillarSummary.fromJson(v as Map<String, dynamic>)));

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
    );
  }
}

class PillarSummary {
  final String status; // worst tier
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

  BiomarkerDefinition({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.healthPillar,
    required this.unit,
    this.description,
    this.displayOrder = 0,
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
