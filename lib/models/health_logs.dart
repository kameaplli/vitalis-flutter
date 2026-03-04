class SymptomLog {
  final String id;
  final String date;
  final String time;
  final String symptomType;
  final int? severity;
  final double? durationHours;
  final String? notes;

  SymptomLog({required this.id, required this.date, required this.time,
      required this.symptomType, this.severity, this.durationHours, this.notes});

  factory SymptomLog.fromJson(Map<String, dynamic> json) => SymptomLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    symptomType: json['symptom_type'] ?? '',
    severity: json['severity'],
    durationHours: (json['duration_hours'] as num?)?.toDouble(),
    notes: json['notes'],
  );
}

class MedicationLog {
  final String id;
  final String medicationName;
  final String? dosage;
  final String? frequency;
  final String? purpose;
  final String? startDate;
  final String? endDate;
  final bool isActive;
  final String? notes;

  MedicationLog({required this.id, required this.medicationName, this.dosage,
      this.frequency, this.purpose, this.startDate, this.endDate,
      required this.isActive, this.notes});

  factory MedicationLog.fromJson(Map<String, dynamic> json) => MedicationLog(
    id: json['id'] ?? '',
    medicationName: json['medication_name'] ?? '',
    dosage: json['dosage'],
    frequency: json['frequency'],
    purpose: json['purpose'],
    startDate: json['start_date'],
    endDate: json['end_date'],
    isActive: json['is_active'] ?? true,
    notes: json['notes'],
  );
}

class VitalSignLog {
  final String id;
  final String date;
  final String time;
  final int? bpSystolic;
  final int? bpDiastolic;
  final int? heartRate;
  final double? bloodGlucose;
  final double? bodyTemperature;
  final double? oxygenSaturation;
  final String? notes;

  VitalSignLog({required this.id, required this.date, required this.time,
      this.bpSystolic, this.bpDiastolic, this.heartRate, this.bloodGlucose,
      this.bodyTemperature, this.oxygenSaturation, this.notes});

  factory VitalSignLog.fromJson(Map<String, dynamic> json) => VitalSignLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    bpSystolic: json['blood_pressure_systolic'],
    bpDiastolic: json['blood_pressure_diastolic'],
    heartRate: json['heart_rate'],
    bloodGlucose: (json['blood_glucose'] as num?)?.toDouble(),
    bodyTemperature: (json['body_temperature'] as num?)?.toDouble(),
    oxygenSaturation: (json['oxygen_saturation'] as num?)?.toDouble(),
    notes: json['notes'],
  );
}

class SleepLog {
  final String id;
  final String sleepDate;
  final String? bedtime;
  final String? wakeTime;
  final double? durationHours;
  final int? quality;
  final String? notes;

  SleepLog({required this.id, required this.sleepDate, this.bedtime,
      this.wakeTime, this.durationHours, this.quality, this.notes});

  factory SleepLog.fromJson(Map<String, dynamic> json) => SleepLog(
    id: json['id'] ?? '',
    sleepDate: json['sleep_date'] ?? '',
    bedtime: json['bedtime'],
    wakeTime: json['wake_time'],
    durationHours: (json['duration_hours'] as num?)?.toDouble(),
    quality: json['quality'],
    notes: json['notes'],
  );
}

class ExerciseLog {
  final String id;
  final String date;
  final String time;
  final String exerciseType;
  final int? durationMinutes;
  final String? intensity;
  final int? caloriesBurned;
  final String? notes;

  ExerciseLog({required this.id, required this.date, required this.time,
      required this.exerciseType, this.durationMinutes, this.intensity,
      this.caloriesBurned, this.notes});

  factory ExerciseLog.fromJson(Map<String, dynamic> json) => ExerciseLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    exerciseType: json['exercise_type'] ?? '',
    durationMinutes: json['duration_minutes'],
    intensity: json['intensity'],
    caloriesBurned: json['calories_burned'],
    notes: json['notes'],
  );
}

class MoodLog {
  final String id;
  final String date;
  final String time;
  final String mood;
  final int? score;
  final int? energyLevel;
  final int? stressLevel;
  final String? notes;

  MoodLog({required this.id, required this.date, required this.time,
      required this.mood, this.score, this.energyLevel, this.stressLevel, this.notes});

  factory MoodLog.fromJson(Map<String, dynamic> json) => MoodLog(
    id: json['id'] ?? '',
    date: json['date'] ?? '',
    time: json['time'] ?? '',
    mood: json['mood'] ?? '',
    score: json['score'],
    energyLevel: json['energy_level'],
    stressLevel: json['stress_level'],
    notes: json['notes'],
  );
}
