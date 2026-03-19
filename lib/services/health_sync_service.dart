import 'dart:io';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';

class HealthSyncService {
  static final Health _health = Health();

  /// Health data types we want to sync from the platform.
  static const List<HealthDataType> _syncTypes = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.DISTANCE_WALKING_RUNNING,
    HealthDataType.WATER,
    HealthDataType.WORKOUT,
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.SLEEP_AWAKE,
  ];

  /// Check if health data is available on this platform.
  static bool get isAvailable => Platform.isIOS || Platform.isAndroid;

  /// Request permissions for all sync types (read-only).
  static Future<bool> requestPermissions() async {
    if (!isAvailable) return false;
    try {
      final permissions =
          _syncTypes.map((t) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _syncTypes,
        permissions: permissions,
      );
      return granted;
    } catch (e) {
      return false;
    }
  }

  /// Check if we already have permissions.
  static Future<bool> hasPermissions() async {
    if (!isAvailable) return false;
    try {
      final result = await _health.hasPermissions(
        _syncTypes,
        permissions:
            _syncTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Get the source ID string for the current platform.
  static String get platformSourceId =>
      Platform.isIOS ? 'apple_health' : 'health_connect';

  /// Perform incremental sync from the platform health store.
  /// Returns a [SyncResult] with insert/skip/replace counts.
  static Future<SyncResult> syncFromPlatform({String person = 'self'}) async {
    if (!isAvailable) {
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    final prefs = await SharedPreferences.getInstance();
    final lastSyncKey = 'health_sync_last_$person';
    final lastSyncMs = prefs.getInt(lastSyncKey) ?? 0;

    final now = DateTime.now();
    final start = lastSyncMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
        : now.subtract(const Duration(days: 30)); // First sync: last 30 days

    // Read health data from the platform store
    List<HealthDataPoint> dataPoints;
    try {
      dataPoints = await _health.getHealthDataFromTypes(
        types: _syncTypes,
        startTime: start,
        endTime: now,
      );
    } catch (e) {
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    if (dataPoints.isEmpty) {
      await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    // Remove duplicates provided by the health package
    dataPoints = _health.removeDuplicates(dataPoints);

    // Convert to canonical observation format
    final observations = dataPoints
        .map(_toCanonical)
        .where((o) => o != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (observations.isEmpty) {
      await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    // Upload in batches of 500
    int totalInserted = 0, totalSkipped = 0, totalReplaced = 0;

    for (var i = 0; i < observations.length; i += 500) {
      final batch =
          observations.sublist(i, (i + 500).clamp(0, observations.length));
      try {
        final resp = await apiClient.dio.post(
          ApiConstants.syncIngest,
          data: {
            'observations': batch,
            'person': person,
          },
        );
        if (resp.statusCode == 200) {
          totalInserted += (resp.data['inserted'] as int?) ?? 0;
          totalSkipped += (resp.data['skipped'] as int?) ?? 0;
          totalReplaced += (resp.data['replaced'] as int?) ?? 0;
        }
      } catch (e) {
        // Continue with next batch on error
      }
    }

    // Update last sync timestamp
    await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);

    return SyncResult(
      inserted: totalInserted,
      skipped: totalSkipped,
      replaced: totalReplaced,
    );
  }

  /// Map a [HealthDataPoint] to our canonical observation format.
  static Map<String, dynamic>? _toCanonical(HealthDataPoint point) {
    const typeMap = {
      HealthDataType.STEPS: 'steps',
      HealthDataType.HEART_RATE: 'heart_rate',
      HealthDataType.RESTING_HEART_RATE: 'resting_heart_rate',
      HealthDataType.HEART_RATE_VARIABILITY_SDNN: 'heart_rate_variability',
      HealthDataType.WEIGHT: 'weight',
      HealthDataType.BODY_FAT_PERCENTAGE: 'body_fat_pct',
      HealthDataType.BLOOD_OXYGEN: 'spo2',
      HealthDataType.BLOOD_GLUCOSE: 'blood_glucose',
      HealthDataType.BODY_TEMPERATURE: 'body_temperature',
      HealthDataType.BLOOD_PRESSURE_SYSTOLIC: 'blood_pressure',
      HealthDataType.BLOOD_PRESSURE_DIASTOLIC: 'blood_pressure',
      HealthDataType.ACTIVE_ENERGY_BURNED: 'active_calories',
      HealthDataType.DISTANCE_WALKING_RUNNING: 'distance',
      HealthDataType.WATER: 'water',
      HealthDataType.WORKOUT: 'workout',
      HealthDataType.SLEEP_ASLEEP: 'sleep_session',
      HealthDataType.SLEEP_DEEP: 'sleep_stage',
      HealthDataType.SLEEP_REM: 'sleep_stage',
      HealthDataType.SLEEP_LIGHT: 'sleep_stage',
      HealthDataType.SLEEP_AWAKE: 'sleep_stage',
    };

    final canonicalType = typeMap[point.type];
    if (canonicalType == null) return null;

    // Extract numeric value
    double? numericValue;
    String? textValue;
    String? jsonValue;

    if (point.value is NumericHealthValue) {
      numericValue =
          (point.value as NumericHealthValue).numericValue.toDouble();
    } else if (point.value is WorkoutHealthValue) {
      final workout = point.value as WorkoutHealthValue;
      jsonValue =
          '{"type": "${workout.workoutActivityType.name}", "calories": ${workout.totalEnergyBurned ?? 0}, "distance": ${workout.totalDistance ?? 0}}';
    } else {
      textValue = point.value.toString();
    }

    // For sleep stages, store the stage name as text value
    if (canonicalType == 'sleep_stage') {
      textValue = point.type.name; // e.g. SLEEP_DEEP, SLEEP_REM
    }

    const unitMap = {
      'steps': 'steps',
      'heart_rate': 'bpm',
      'resting_heart_rate': 'bpm',
      'heart_rate_variability': 'ms',
      'weight': 'kg',
      'body_fat_pct': '%',
      'spo2': '%',
      'blood_glucose': 'mg/dL',
      'body_temperature': 'degC',
      'blood_pressure': 'mmHg',
      'active_calories': 'kcal',
      'distance': 'm',
      'water': 'mL',
      'workout': 'min',
      'sleep_session': 'min',
      'sleep_stage': 'min',
    };

    return {
      'data_type': canonicalType,
      'effective_start': point.dateFrom.toUtc().toIso8601String(),
      'effective_end': point.dateTo.toUtc().toIso8601String(),
      'value_numeric': numericValue,
      'value_text': textValue,
      'value_json': jsonValue,
      'unit': unitMap[canonicalType] ?? '',
      'source_id': Platform.isIOS ? 'apple_health' : 'health_connect',
      'source_record_id': point.uuid,
      'time_zone': DateTime.now().timeZoneName,
      'is_manual': false,
    };
  }
}
