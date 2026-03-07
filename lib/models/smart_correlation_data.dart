/// Phase 2: Smart Food Analysis — correlation data models

class SmartCorrelationResult {
  final List<CategoryCorrelation> categoryCorrelations;
  final List<FoodCorrelation> foodCorrelations;
  final List<CombinationTrigger> combinationTriggers;
  final List<LagAnalysis> lagAnalysis;
  final List<CumulativeEffect> cumulativeEffects;
  final List<EnvironmentalInteraction> environmentalInteractions;
  final List<BayesianTrigger> bayesianTriggers;
  final String dataQuality;
  final double overallAvgItch;
  final int periodDays;
  final int eczemaEntries;
  final int nutritionEntries;

  SmartCorrelationResult({
    required this.categoryCorrelations,
    required this.foodCorrelations,
    required this.combinationTriggers,
    required this.lagAnalysis,
    required this.cumulativeEffects,
    required this.environmentalInteractions,
    required this.bayesianTriggers,
    required this.dataQuality,
    required this.overallAvgItch,
    required this.periodDays,
    required this.eczemaEntries,
    required this.nutritionEntries,
  });

  factory SmartCorrelationResult.fromJson(Map<String, dynamic> json) {
    return SmartCorrelationResult(
      categoryCorrelations: _parseList(json['category_correlations'], CategoryCorrelation.fromJson),
      foodCorrelations: _parseList(json['food_correlations'], FoodCorrelation.fromJson),
      combinationTriggers: _parseList(json['combination_triggers'], CombinationTrigger.fromJson),
      lagAnalysis: _parseList(json['lag_analysis'], LagAnalysis.fromJson),
      cumulativeEffects: _parseList(json['cumulative_effects'], CumulativeEffect.fromJson),
      environmentalInteractions: _parseList(json['environmental_interactions'], EnvironmentalInteraction.fromJson),
      bayesianTriggers: _parseList(json['bayesian_triggers'], BayesianTrigger.fromJson),
      dataQuality: json['data_quality'] as String? ?? 'insufficient',
      overallAvgItch: (json['overall_avg_itch'] as num?)?.toDouble() ?? 0,
      periodDays: json['period_days'] as int? ?? 0,
      eczemaEntries: json['eczema_entries'] as int? ?? 0,
      nutritionEntries: json['nutrition_entries'] as int? ?? 0,
    );
  }
}

List<T> _parseList<T>(dynamic list, T Function(Map<String, dynamic>) fromJson) {
  if (list == null) return [];
  return (list as List<dynamic>)
      .map((e) => fromJson(e as Map<String, dynamic>))
      .toList();
}

class CategoryCorrelation {
  final String category;
  final int daysConsumed;
  final int daysNotConsumed;
  final double avgItchWith;
  final double avgItchWithout;
  final double avgItchNextDay;
  final double riskMultiplier;
  final bool significant;

  CategoryCorrelation({
    required this.category,
    required this.daysConsumed,
    required this.daysNotConsumed,
    required this.avgItchWith,
    required this.avgItchWithout,
    required this.avgItchNextDay,
    required this.riskMultiplier,
    required this.significant,
  });

  factory CategoryCorrelation.fromJson(Map<String, dynamic> json) {
    return CategoryCorrelation(
      category: json['category'] as String? ?? '',
      daysConsumed: json['days_consumed'] as int? ?? 0,
      daysNotConsumed: json['days_not_consumed'] as int? ?? 0,
      avgItchWith: (json['avg_itch_with'] as num?)?.toDouble() ?? 0,
      avgItchWithout: (json['avg_itch_without'] as num?)?.toDouble() ?? 0,
      avgItchNextDay: (json['avg_itch_next_day'] as num?)?.toDouble() ?? 0,
      riskMultiplier: (json['risk_multiplier'] as num?)?.toDouble() ?? 0,
      significant: json['significant'] as bool? ?? false,
    );
  }

  String get displayName {
    const names = {
      'dairy': 'Dairy',
      'egg': 'Eggs',
      'peanut': 'Peanuts',
      'tree_nut': 'Tree Nuts',
      'wheat': 'Wheat/Gluten',
      'soy': 'Soy',
      'fish': 'Fish',
      'shellfish': 'Shellfish',
      'histamine': 'High Histamine',
      'histamine_liberator': 'Histamine Liberator',
      'nickel': 'High Nickel',
      'salicylate': 'High Salicylate',
      'wheat_gluten': 'Wheat/Gluten',
      'citrus': 'Citrus',
      'seafood': 'Seafood',
      'nuts': 'Nuts',
      'eggs': 'Eggs',
    };
    return names[category] ?? category[0].toUpperCase() + category.substring(1);
  }
}

class FoodCorrelation {
  final String food;
  final int timesEaten;
  final double avgItchAfter;
  final double overallAvgItch;
  final double riskMultiplier;
  final List<String> allergenCategories;
  final String trend;

  FoodCorrelation({
    required this.food,
    required this.timesEaten,
    required this.avgItchAfter,
    required this.overallAvgItch,
    required this.riskMultiplier,
    required this.allergenCategories,
    required this.trend,
  });

  factory FoodCorrelation.fromJson(Map<String, dynamic> json) {
    return FoodCorrelation(
      food: json['food'] as String? ?? '',
      timesEaten: json['times_eaten'] as int? ?? 0,
      avgItchAfter: (json['avg_itch_after'] as num?)?.toDouble() ?? 0,
      overallAvgItch: (json['overall_avg_itch'] as num?)?.toDouble() ?? 0,
      riskMultiplier: (json['risk_multiplier'] as num?)?.toDouble() ?? 0,
      allergenCategories: (json['allergen_categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      trend: json['trend'] as String? ?? 'neutral',
    );
  }
}

class CombinationTrigger {
  final String categoryA;
  final String categoryB;
  final double avgItchCombined;
  final double avgItchAOnly;
  final double avgItchBOnly;
  final double interactionScore;
  final int combinedDays;

  CombinationTrigger({
    required this.categoryA,
    required this.categoryB,
    required this.avgItchCombined,
    required this.avgItchAOnly,
    required this.avgItchBOnly,
    required this.interactionScore,
    required this.combinedDays,
  });

  factory CombinationTrigger.fromJson(Map<String, dynamic> json) {
    return CombinationTrigger(
      categoryA: json['category_a'] as String? ?? '',
      categoryB: json['category_b'] as String? ?? '',
      avgItchCombined: (json['avg_itch_combined'] as num?)?.toDouble() ?? 0,
      avgItchAOnly: (json['avg_itch_a_only'] as num?)?.toDouble() ?? 0,
      avgItchBOnly: (json['avg_itch_b_only'] as num?)?.toDouble() ?? 0,
      interactionScore: (json['interaction_score'] as num?)?.toDouble() ?? 0,
      combinedDays: json['combined_days'] as int? ?? 0,
    );
  }
}

class LagAnalysis {
  final String category;
  final int bestLagDays;
  final double bestCorrelation;

  LagAnalysis({
    required this.category,
    required this.bestLagDays,
    required this.bestCorrelation,
  });

  factory LagAnalysis.fromJson(Map<String, dynamic> json) {
    return LagAnalysis(
      category: json['category'] as String? ?? '',
      bestLagDays: json['best_lag_days'] as int? ?? 0,
      bestCorrelation: (json['best_correlation'] as num?)?.toDouble() ?? 0,
    );
  }
}

class CumulativeEffect {
  final String category;
  final double singleDayAvgItch;
  final double consecutiveDaysAvgItch;
  final double cumulativeMultiplier;
  final int singleDayCount;
  final int consecutiveCount;

  CumulativeEffect({
    required this.category,
    required this.singleDayAvgItch,
    required this.consecutiveDaysAvgItch,
    required this.cumulativeMultiplier,
    required this.singleDayCount,
    required this.consecutiveCount,
  });

  factory CumulativeEffect.fromJson(Map<String, dynamic> json) {
    return CumulativeEffect(
      category: json['category'] as String? ?? '',
      singleDayAvgItch: (json['single_day_avg_itch'] as num?)?.toDouble() ?? 0,
      consecutiveDaysAvgItch: (json['consecutive_days_avg_itch'] as num?)?.toDouble() ?? 0,
      cumulativeMultiplier: (json['cumulative_multiplier'] as num?)?.toDouble() ?? 0,
      singleDayCount: json['single_day_count'] as int? ?? 0,
      consecutiveCount: json['consecutive_count'] as int? ?? 0,
    );
  }
}

class EnvironmentalInteraction {
  final String category;
  final String envFactor;
  final double avgItchBadEnv;
  final double avgItchNormalEnv;
  final double interactionMultiplier;
  final String detail;

  EnvironmentalInteraction({
    required this.category,
    required this.envFactor,
    required this.avgItchBadEnv,
    required this.avgItchNormalEnv,
    required this.interactionMultiplier,
    required this.detail,
  });

  factory EnvironmentalInteraction.fromJson(Map<String, dynamic> json) {
    return EnvironmentalInteraction(
      category: json['category'] as String? ?? '',
      envFactor: json['env_factor'] as String? ?? '',
      avgItchBadEnv: (json['avg_itch_bad_env'] as num?)?.toDouble() ?? 0,
      avgItchNormalEnv: (json['avg_itch_normal_env'] as num?)?.toDouble() ?? 0,
      interactionMultiplier: (json['interaction_multiplier'] as num?)?.toDouble() ?? 0,
      detail: json['detail'] as String? ?? '',
    );
  }
}

class BayesianTrigger {
  final String category;
  final double priorProbability;
  final double posteriorProbability;
  final int timesConsumed;
  final int timesFlareAfter;
  final double flareRate;
  final String confidence;

  BayesianTrigger({
    required this.category,
    required this.priorProbability,
    required this.posteriorProbability,
    required this.timesConsumed,
    required this.timesFlareAfter,
    required this.flareRate,
    required this.confidence,
  });

  factory BayesianTrigger.fromJson(Map<String, dynamic> json) {
    return BayesianTrigger(
      category: json['category'] as String? ?? '',
      priorProbability: (json['prior_probability'] as num?)?.toDouble() ?? 0,
      posteriorProbability: (json['posterior_probability'] as num?)?.toDouble() ?? 0,
      timesConsumed: json['times_consumed'] as int? ?? 0,
      timesFlareAfter: json['times_flare_after'] as int? ?? 0,
      flareRate: (json['flare_rate'] as num?)?.toDouble() ?? 0,
      confidence: json['confidence'] as String? ?? 'insufficient',
    );
  }

  String get displayName {
    const names = {
      'dairy': 'Dairy',
      'egg': 'Eggs',
      'peanut': 'Peanuts',
      'tree_nut': 'Tree Nuts',
      'wheat': 'Wheat/Gluten',
      'soy': 'Soy',
      'histamine': 'High Histamine',
      'nickel': 'High Nickel',
      'salicylate': 'High Salicylate',
      'nuts': 'Nuts',
    };
    return names[category] ?? category[0].toUpperCase() + category.substring(1);
  }
}
