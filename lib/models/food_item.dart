class FoodAllergenInfo {
  final String category;
  final String? detail;
  final String? risk;

  const FoodAllergenInfo({required this.category, this.detail, this.risk});

  factory FoodAllergenInfo.fromJson(Map<String, dynamic> json) {
    return FoodAllergenInfo(
      category: json['category'] as String? ?? '',
      detail: json['detail'] as String?,
      risk: json['risk'] as String?,
    );
  }

  String get displayName {
    const names = {
      'dairy': 'Dairy',
      'egg': 'Eggs',
      'peanut': 'Peanuts',
      'tree_nut': 'Tree Nuts',
      'wheat': 'Wheat',
      'soy': 'Soy',
      'fish': 'Fish',
      'shellfish': 'Shellfish',
      'histamine': 'Histamine',
      'histamine_liberator': 'Hist. Liberator',
      'nickel': 'Nickel',
      'salicylate': 'Salicylate',
      'dairy_aliases': 'Dairy',
    };
    return names[category] ?? category;
  }

  String get emoji {
    const emojis = {
      'dairy': '🥛',
      'dairy_aliases': '🥛',
      'egg': '🥚',
      'peanut': '🥜',
      'tree_nut': '🌰',
      'wheat': '🌾',
      'soy': '🫘',
      'fish': '🐟',
      'shellfish': '🦐',
      'histamine': '⚠️',
      'histamine_liberator': '⚠️',
      'nickel': '🔩',
      'salicylate': '💊',
    };
    return emojis[category] ?? '⚠️';
  }
}

class FoodItem {
  final String id;
  final String name;
  final String? displayName;
  final String? brand;
  final String? brandDisplay;
  final double? cal;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;
  final String? emoji;
  final String? unit;
  final double? servingSize;
  final String? source;
  final double? nutrientCompleteness;
  final String? ingredientsText;
  final String? imageUrl;
  final List<FoodAllergenInfo> allergens;

  FoodItem({
    required this.id,
    required this.name,
    this.displayName,
    this.brand,
    this.brandDisplay,
    this.cal,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    this.emoji,
    this.unit,
    this.servingSize,
    this.source,
    this.nutrientCompleteness,
    this.ingredientsText,
    this.imageUrl,
    this.allergens = const [],
  });

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      displayName: json['display_name'],
      brand: json['brand'],
      brandDisplay: json['brand_display'],
      cal: (json['cal'] as num?)?.toDouble(),
      protein: (json['protein'] as num?)?.toDouble(),
      carbs: (json['carbs'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      emoji: json['emoji'],
      unit: json['unit'],
      servingSize: (json['serving_size'] as num?)?.toDouble(),
      source: json['source'],
      nutrientCompleteness: (json['nutrient_completeness'] as num?)?.toDouble(),
      ingredientsText: json['ingredients_text'],
      imageUrl: json['image_url'],
      allergens: (json['allergens'] as List<dynamic>?)
              ?.map((a) => FoodAllergenInfo.fromJson(a as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  /// Clean display title: use display_name if available, otherwise name
  String get title => displayName ?? name;

  /// Whether this food has brand info to show
  bool get hasBrand => brand != null && brand!.isNotEmpty;

  /// Formatted brand for display
  String get brandLabel => brandDisplay ?? brand ?? '';

  double get caloriesPerServing {
    if (cal == null || servingSize == null) return 0;
    return (cal! / 100) * servingSize!;
  }

  /// Unique allergen categories (de-duped, e.g. dairy + dairy_aliases → just Dairy)
  List<FoodAllergenInfo> get uniqueAllergens {
    final seen = <String>{};
    final result = <FoodAllergenInfo>[];
    for (final a in allergens) {
      final key = a.displayName;
      if (seen.add(key)) result.add(a);
    }
    return result;
  }
}

// ─── Recent Meal models (used by /api/foods/frequent) ─────────────────────────

class RecentMealItem {
  final String foodId;
  final String foodName;
  final double grams;
  final double? calPer100g;
  final double? proteinPer100g;
  final double? carbsPer100g;
  final double? fatPer100g;
  final double servingSize;
  final String? emoji;

  RecentMealItem({
    required this.foodId,
    required this.foodName,
    required this.grams,
    this.calPer100g,
    this.proteinPer100g,
    this.carbsPer100g,
    this.fatPer100g,
    this.servingSize = 100,
    this.emoji,
  });

  factory RecentMealItem.fromJson(Map<String, dynamic> json) => RecentMealItem(
        foodId: json['food_id'] ?? '',
        foodName: json['food_name'] ?? '',
        grams: (json['grams'] as num?)?.toDouble() ?? 100,
        calPer100g: (json['cal_per_100g'] as num?)?.toDouble(),
        proteinPer100g: (json['protein_per_100g'] as num?)?.toDouble(),
        carbsPer100g: (json['carbs_per_100g'] as num?)?.toDouble(),
        fatPer100g: (json['fat_per_100g'] as num?)?.toDouble(),
        servingSize: (json['serving_size'] as num?)?.toDouble() ?? 100,
        emoji: json['emoji'],
      );

  FoodItem toFoodItem() => FoodItem(
        id: foodId,
        name: foodName,
        cal: calPer100g,
        protein: proteinPer100g,
        carbs: carbsPer100g,
        fat: fatPer100g,
        emoji: emoji,
        servingSize: servingSize,
      );
}

class RecentMeal {
  final String id;
  final String mealType;
  final String display;
  final List<RecentMealItem> items;

  RecentMeal({
    required this.id,
    required this.mealType,
    required this.display,
    required this.items,
  });

  factory RecentMeal.fromJson(Map<String, dynamic> json) => RecentMeal(
        id: json['id'] ?? '',
        mealType: json['meal_type'] ?? 'lunch',
        display: json['display'] ?? '',
        items: (json['items'] as List<dynamic>? ?? [])
            .map((i) => RecentMealItem.fromJson(i))
            .toList(),
      );
}

// ─── Food Category ─────────────────────────────────────────────────────────────

class FoodCategory {
  final String id;
  final String name;
  final String? emoji;
  final List<FoodItem> items;

  FoodCategory({
    required this.id,
    required this.name,
    this.emoji,
    required this.items,
  });

  factory FoodCategory.fromJson(Map<String, dynamic> json) {
    return FoodCategory(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'],
      items: (json['items'] as List<dynamic>? ?? [])
          .map((i) => FoodItem.fromJson(i))
          .toList(),
    );
  }
}
