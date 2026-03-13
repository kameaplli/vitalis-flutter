/// Full info card data for progressive disclosure Level 2.
class FoodDetail {
  final String id;
  final String name;
  final String? brand;
  final String? brandDisplay;
  final String? emoji;
  final double? cal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final double? servingSize;
  final String? unit;
  final String? source;
  final double? nutrientCompleteness;
  final String? nutriscore;
  final int? novaGroup;
  final String? ingredientsText;
  final List<dynamic> allergens;
  final String? imageUrl;
  final String? groupId;
  final List<MicronutrientValue> micronutrients;
  final List<SourceVariant> sourceVariants;

  const FoodDetail({
    required this.id,
    required this.name,
    this.brand,
    this.brandDisplay,
    this.emoji,
    this.cal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.servingSize,
    this.unit,
    this.source,
    this.nutrientCompleteness,
    this.nutriscore,
    this.novaGroup,
    this.ingredientsText,
    this.allergens = const [],
    this.imageUrl,
    this.groupId,
    this.micronutrients = const [],
    this.sourceVariants = const [],
  });

  factory FoodDetail.fromJson(Map<String, dynamic> json) {
    return FoodDetail(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      brand: json['brand'],
      brandDisplay: json['brand_display'],
      emoji: json['emoji'],
      cal: (json['cal'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      servingSize: (json['serving_size'] as num?)?.toDouble(),
      unit: json['unit'],
      source: json['source'],
      nutrientCompleteness: (json['nutrient_completeness'] as num?)?.toDouble(),
      nutriscore: json['nutriscore'],
      novaGroup: (json['nova_group'] as num?)?.toInt(),
      ingredientsText: json['ingredients_text'],
      allergens: json['allergens'] as List<dynamic>? ?? const [],
      imageUrl: json['image_url'],
      groupId: json['group_id'],
      micronutrients: (json['micronutrients'] as List<dynamic>? ?? [])
          .map((m) => MicronutrientValue.fromJson(m))
          .toList(),
      sourceVariants: (json['source_variants'] as List<dynamic>? ?? [])
          .map((s) => SourceVariant.fromJson(s))
          .toList(),
    );
  }

  /// Top micronutrients for highlight display (max 5).
  List<MicronutrientValue> get topMicronutrients =>
      micronutrients.where((m) => m.value != null && m.value! > 0).take(5).toList();

  /// Calories from macros for donut chart.
  double get calFromProtein => (protein ?? 0) * 4;
  double get calFromCarbs => (carbs ?? 0) * 4;
  double get calFromFat => (fat ?? 0) * 9;
}

class MicronutrientValue {
  final String tagname;
  final String name;
  final double? value;
  final String unit;
  final String? category;

  const MicronutrientValue({
    required this.tagname,
    required this.name,
    this.value,
    required this.unit,
    this.category,
  });

  factory MicronutrientValue.fromJson(Map<String, dynamic> json) {
    return MicronutrientValue(
      tagname: json['tagname'] ?? '',
      name: json['name'] ?? '',
      value: (json['value'] as num?)?.toDouble(),
      unit: json['unit'] ?? '',
      category: json['category'],
    );
  }

  bool get hasData => value != null;
}

class SourceVariant {
  final String id;
  final String? source;
  final String? name;
  final double? cal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? servingSize;
  final double? nutrientCompleteness;

  const SourceVariant({
    required this.id,
    this.source,
    this.name,
    this.cal,
    this.protein,
    this.carbs,
    this.fat,
    this.servingSize,
    this.nutrientCompleteness,
  });

  factory SourceVariant.fromJson(Map<String, dynamic> json) {
    return SourceVariant(
      id: json['id'] ?? '',
      source: json['source'],
      name: json['name'],
      cal: (json['cal'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      servingSize: (json['serving_size'] as num?)?.toDouble(),
      nutrientCompleteness: (json['nutrient_completeness'] as num?)?.toDouble(),
    );
  }

  String get sourceLabel {
    const labels = {
      'usda_foundation': 'USDA Foundation',
      'usda_sr': 'USDA SR',
      'usda_branded': 'USDA Branded',
      'off': 'OpenFoodFacts',
      'cnf': 'CNF',
      'custom': 'Custom',
    };
    return labels[source] ?? source ?? 'Unknown';
  }
}
