class HydrationLog {
  final String id;
  final String date;
  final String time;
  final String beverageType;
  final double quantity;
  final double? calories;
  final double? sugar;
  final double? caffeine;
  final String? notes;

  HydrationLog({
    required this.id,
    required this.date,
    required this.time,
    required this.beverageType,
    required this.quantity,
    this.calories,
    this.sugar,
    this.caffeine,
    this.notes,
  });

  factory HydrationLog.fromJson(Map<String, dynamic> json) {
    return HydrationLog(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      beverageType: json['beverage_type'] ?? '',
      quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
      calories: (json['calories'] as num?)?.toDouble(),
      sugar: (json['sugar'] as num?)?.toDouble(),
      caffeine: (json['caffeine'] as num?)?.toDouble(),
      notes: json['notes'],
    );
  }
}

class BeveragePreset {
  final String id;
  final String name;
  final String emoji;
  final double defaultQuantity;
  final double caloriesPer100ml;

  BeveragePreset({
    required this.id,
    required this.name,
    required this.emoji,
    required this.defaultQuantity,
    required this.caloriesPer100ml,
  });

  factory BeveragePreset.fromJson(Map<String, dynamic> json) {
    return BeveragePreset(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      emoji: json['emoji'] ?? '💧',
      defaultQuantity: (json['default_quantity'] as num?)?.toDouble() ?? 250,
      caloriesPer100ml: (json['calories_per_100ml'] as num?)?.toDouble() ?? 0,
    );
  }
}
