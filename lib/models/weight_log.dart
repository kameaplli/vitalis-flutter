class WeightLog {
  final String id;
  final String date;
  final String time;
  final double weight;
  final String unit;
  final String? notes;
  final String person;

  WeightLog({
    required this.id,
    required this.date,
    required this.time,
    required this.weight,
    required this.unit,
    this.notes,
    required this.person,
  });

  factory WeightLog.fromJson(Map<String, dynamic> json) {
    return WeightLog(
      id: json['id'] ?? '',
      date: json['date'] ?? '',
      time: json['time'] ?? '',
      weight: (json['weight'] as num?)?.toDouble() ?? 0,
      unit: json['unit'] ?? 'kg',
      notes: json['notes'],
      person: json['person'] ?? 'Me',
    );
  }
}
