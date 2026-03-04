class NutritionEntry {
  final String id;
  final String date;
  final String time;
  final String? meal;
  final String person;
  final String personId;
  final String description;
  final double calories;

  NutritionEntry({
    required this.id,
    required this.date,
    required this.time,
    this.meal,
    required this.person,
    required this.personId,
    required this.description,
    required this.calories,
  });

  factory NutritionEntry.fromJson(Map<String, dynamic> json) {
    return NutritionEntry(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      meal: json['meal'],
      person: json['person'] ?? 'Me',
      personId: json['person_id'] ?? 'self',
      description: json['description'] ?? '',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
    );
  }
}

class NutritionLogItem {
  final String? foodId;
  final String? foodName;
  final double quantity;

  NutritionLogItem({this.foodId, this.foodName, required this.quantity});

  factory NutritionLogItem.fromJson(Map<String, dynamic> json) {
    return NutritionLogItem(
      foodId: json['food_id'],
      foodName: json['food_name'],
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1,
    );
  }
}
