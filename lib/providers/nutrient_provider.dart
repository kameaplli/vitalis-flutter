import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

// ─── Food Nutrient Profile ───────────────────────────────────────────────────

class FoodNutrientData {
  final String foodId;
  final String foodName;
  final String? brand;
  final double? nutrientCompleteness;
  final String? source;
  final String? ingredientsText;
  final String? allergens;
  final String? imageUrl;
  final Map<String, double> macros;
  final List<NutrientValue> nutrients;

  FoodNutrientData({
    required this.foodId,
    required this.foodName,
    this.brand,
    this.nutrientCompleteness,
    this.source,
    this.ingredientsText,
    this.allergens,
    this.imageUrl,
    required this.macros,
    required this.nutrients,
  });

  factory FoodNutrientData.fromJson(Map<String, dynamic> json) {
    final macrosMap = json['macros'] as Map<String, dynamic>? ?? {};
    final nutrientsList = json['nutrients'] as Map<String, dynamic>? ?? {};

    return FoodNutrientData(
      foodId: json['food_id'] ?? '',
      foodName: json['food_name'] ?? '',
      brand: json['brand'],
      nutrientCompleteness: (json['nutrient_completeness'] as num?)?.toDouble(),
      source: json['source'],
      ingredientsText: json['ingredients_text'],
      allergens: json['allergens'],
      imageUrl: json['image_url'],
      macros: macrosMap.map((k, v) => MapEntry(k, (v as num?)?.toDouble() ?? 0)),
      nutrients: nutrientsList.entries.map((e) {
        final data = e.value as Map<String, dynamic>;
        return NutrientValue(
          tagname: e.key,
          displayName: data['display_name'] ?? e.key,
          value: (data['value_per_100g'] as num?)?.toDouble(),
          unit: data['unit'] ?? '',
          category: data['category'] ?? '',
        );
      }).toList(),
    );
  }

  List<NutrientValue> get vitamins =>
      nutrients.where((n) => n.category == 'vitamin').toList();

  List<NutrientValue> get minerals =>
      nutrients.where((n) => n.category == 'mineral').toList();

  List<NutrientValue> get otherNutrients =>
      nutrients.where((n) => n.category != 'vitamin' && n.category != 'mineral' && n.category != 'macro').toList();
}

class NutrientValue {
  final String tagname;
  final String displayName;
  final double? value;
  final String unit;
  final String category;

  NutrientValue({
    required this.tagname,
    required this.displayName,
    this.value,
    required this.unit,
    required this.category,
  });

  bool get hasData => value != null;
}

// ─── Daily Nutrient Assessment ───────────────────────────────────────────────

class DailyNutrientAssessment {
  final String personId;
  final String date;
  final String lifeStage;
  final List<DailyNutrientItem> nutrients;
  final DailyNutrientSummary summary;

  DailyNutrientAssessment({
    required this.personId,
    required this.date,
    required this.lifeStage,
    required this.nutrients,
    required this.summary,
  });

  factory DailyNutrientAssessment.fromJson(Map<String, dynamic> json) {
    final nutrientsList = json['nutrients'] as List<dynamic>? ?? [];
    final summaryMap = json['summary'] as Map<String, dynamic>? ?? {};

    return DailyNutrientAssessment(
      personId: json['person_id'] ?? 'self',
      date: json['date'] ?? '',
      lifeStage: json['life_stage'] ?? '',
      nutrients: nutrientsList
          .map((n) => DailyNutrientItem.fromJson(n as Map<String, dynamic>))
          .toList(),
      summary: DailyNutrientSummary.fromJson(summaryMap),
    );
  }
}

class DailyNutrientItem {
  final String tagname;
  final String displayName;
  final String unit;
  final String category;
  final double consumed;
  final double? rda;
  final double? ai;
  final double? ul;
  final double? percentDri;
  final String status; // low, approaching, adequate, excessive

  DailyNutrientItem({
    required this.tagname,
    required this.displayName,
    required this.unit,
    required this.category,
    required this.consumed,
    this.rda,
    this.ai,
    this.ul,
    this.percentDri,
    required this.status,
  });

  factory DailyNutrientItem.fromJson(Map<String, dynamic> json) {
    return DailyNutrientItem(
      tagname: json['tagname'] ?? '',
      displayName: json['display_name'] ?? '',
      unit: json['unit'] ?? '',
      category: json['category'] ?? '',
      consumed: (json['consumed'] as num?)?.toDouble() ?? 0,
      rda: (json['rda'] as num?)?.toDouble(),
      ai: (json['ai'] as num?)?.toDouble(),
      ul: (json['ul'] as num?)?.toDouble(),
      percentDri: (json['percent_dri'] as num?)?.toDouble(),
      status: json['status'] ?? 'low',
    );
  }

  double? get target => rda ?? ai;
}

class DailyNutrientSummary {
  final int lowCount;
  final int approachingCount;
  final int adequateCount;
  final int excessiveCount;
  final List<Map<String, dynamic>> topConcerns;

  DailyNutrientSummary({
    required this.lowCount,
    required this.approachingCount,
    required this.adequateCount,
    required this.excessiveCount,
    required this.topConcerns,
  });

  factory DailyNutrientSummary.fromJson(Map<String, dynamic> json) {
    return DailyNutrientSummary(
      lowCount: json['low_count'] ?? 0,
      approachingCount: json['approaching_count'] ?? 0,
      adequateCount: json['adequate_count'] ?? 0,
      excessiveCount: json['excessive_count'] ?? 0,
      topConcerns: (json['top_concerns'] as List<dynamic>? ?? [])
          .map((e) => e as Map<String, dynamic>)
          .toList(),
    );
  }
}

// ─── Period Nutrient Assessment (multi-day aggregation) ─────────────────────

class PeriodNutrientData {
  final String personId;
  final String lifeStage;
  final int days;
  final List<PeriodNutrientItem> vitamins;
  final List<PeriodNutrientItem> minerals;
  final List<PeriodNutrientItem> consumedLess;
  final List<PeriodNutrientItem> consumedMore;
  final PeriodNutrientSummary summary;

  PeriodNutrientData({
    required this.personId,
    required this.lifeStage,
    required this.days,
    required this.vitamins,
    required this.minerals,
    required this.consumedLess,
    required this.consumedMore,
    required this.summary,
  });

  factory PeriodNutrientData.fromJson(Map<String, dynamic> json) {
    List<PeriodNutrientItem> parseList(String key) =>
        (json[key] as List<dynamic>? ?? [])
            .map((e) => PeriodNutrientItem.fromJson(e as Map<String, dynamic>))
            .toList();

    return PeriodNutrientData(
      personId: json['person_id'] ?? 'self',
      lifeStage: json['life_stage'] ?? '',
      days: json['days'] ?? 1,
      vitamins: parseList('vitamins'),
      minerals: parseList('minerals'),
      consumedLess: parseList('consumed_less'),
      consumedMore: parseList('consumed_more'),
      summary: PeriodNutrientSummary.fromJson(
          json['summary'] as Map<String, dynamic>? ?? {}),
    );
  }
}

class PeriodNutrientItem {
  final String tagname;
  final String displayName;
  final String? shortName;
  final String category;
  final double avgDaily;
  final double total;
  final double? target;
  final double? ul;
  final double? percentDri;
  final String status;
  final String unit;

  PeriodNutrientItem({
    required this.tagname,
    required this.displayName,
    this.shortName,
    required this.category,
    required this.avgDaily,
    required this.total,
    this.target,
    this.ul,
    this.percentDri,
    required this.status,
    required this.unit,
  });

  factory PeriodNutrientItem.fromJson(Map<String, dynamic> json) {
    return PeriodNutrientItem(
      tagname: json['tagname'] ?? '',
      displayName: json['display_name'] ?? '',
      shortName: json['short_name'],
      category: json['category'] ?? '',
      avgDaily: (json['avg_daily'] as num?)?.toDouble() ?? 0,
      total: (json['total'] as num?)?.toDouble() ?? 0,
      target: (json['target'] as num?)?.toDouble(),
      ul: (json['ul'] as num?)?.toDouble(),
      percentDri: (json['percent_dri'] as num?)?.toDouble(),
      status: json['status'] ?? 'no_data',
      unit: json['unit'] ?? '',
    );
  }
}

class PeriodNutrientSummary {
  final int lowCount;
  final int approachingCount;
  final int adequateCount;
  final int excessiveCount;
  final int totalTracked;
  final int daysWithData;
  final int periodDays;

  PeriodNutrientSummary({
    required this.lowCount,
    required this.approachingCount,
    required this.adequateCount,
    required this.excessiveCount,
    required this.totalTracked,
    required this.daysWithData,
    required this.periodDays,
  });

  factory PeriodNutrientSummary.fromJson(Map<String, dynamic> json) {
    return PeriodNutrientSummary(
      lowCount: json['low_count'] ?? 0,
      approachingCount: json['approaching_count'] ?? 0,
      adequateCount: json['adequate_count'] ?? 0,
      excessiveCount: json['excessive_count'] ?? 0,
      totalTracked: json['total_tracked'] ?? 0,
      daysWithData: json['days_with_data'] ?? 0,
      periodDays: json['period_days'] ?? 1,
    );
  }
}

// ─── Providers ───────────────────────────────────────────────────────────────

/// Fetch nutrient profile for a specific food item.
final foodNutrientProvider =
    FutureProvider.family<FoodNutrientData?, String>((ref, foodId) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.foodNutrients(foodId));
    return FoodNutrientData.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Fetch daily nutrient assessment for a person on a date.
/// Key format: "personId|YYYY-MM-DD"
final dailyNutrientProvider =
    FutureProvider.family<DailyNutrientAssessment?, String>((ref, key) async {
  try {
    final parts = key.split('|');
    final person = parts[0];
    final date = parts.length > 1 ? parts[1] : null;
    final res = await apiClient.dio.get(
      ApiConstants.nutrientsDaily,
      queryParameters: {
        'person': person,
        if (date != null) 'date': date,
      },
    );
    return DailyNutrientAssessment.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});

/// Fetch multi-day nutrient aggregation.
/// Key format: "personId:days" (e.g. "self:7", "self:30")
final periodNutrientProvider =
    FutureProvider.family<PeriodNutrientData?, String>((ref, key) async {
  try {
    final parts = key.split(':');
    final person = parts[0];
    final days = parts.length > 1 ? int.tryParse(parts[1]) ?? 1 : 1;
    final res = await apiClient.dio.get(
      ApiConstants.nutrientsPeriod,
      queryParameters: {'person': person, 'days': days},
    );
    return PeriodNutrientData.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});
