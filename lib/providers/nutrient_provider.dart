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
