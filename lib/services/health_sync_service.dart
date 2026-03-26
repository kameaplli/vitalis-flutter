import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';
import 'notification_service.dart';

class SyncDiagnostics {
  final int totalPoints;
  final Map<String, int> typeResults;
  final Map<String, String> typeErrors;
  final DateTime queryStart;
  final DateTime queryEnd;
  SyncDiagnostics({
    required this.totalPoints,
    required this.typeResults,
    required this.typeErrors,
    required this.queryStart,
    required this.queryEnd,
  });
}

class HealthSyncService {
  static final Health _health = Health();
  static bool _configured = false;
  static bool _syncInProgress = false;
  static SyncDiagnostics? _lastSyncDiagnostics;

  /// Get the last sync diagnostics (for debugging in the UI).
  static SyncDiagnostics? get lastDiagnostics => _lastSyncDiagnostics;

  /// Health data types we want to sync from the platform.
  /// Platform-conditional: DISTANCE_WALKING_RUNNING is iOS-only (not available
  /// on Google Health Connect).
  static List<HealthDataType> get _syncTypes => [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.RESTING_HEART_RATE,
    if (Platform.isIOS) HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.WEIGHT,
    HealthDataType.BODY_FAT_PERCENTAGE,
    HealthDataType.BLOOD_OXYGEN,
    HealthDataType.BLOOD_GLUCOSE,
    HealthDataType.BODY_TEMPERATURE,
    HealthDataType.BLOOD_PRESSURE_SYSTOLIC,
    HealthDataType.BLOOD_PRESSURE_DIASTOLIC,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    if (Platform.isIOS) HealthDataType.DISTANCE_WALKING_RUNNING,
    if (Platform.isAndroid) HealthDataType.DISTANCE_DELTA,
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

  /// Must be called before any health operations.
  static Future<void> _ensureConfigured() async {
    if (_configured) return;
    try {
      await _health.configure();
      _configured = true;
      debugPrint('HealthSync: configured successfully');
    } catch (e) {
      debugPrint('HealthSync: configure() failed: $e');
    }
  }

  /// Check if Health Connect is available on this Android device.
  static Future<bool> isHealthConnectAvailable() async {
    if (!Platform.isAndroid) return Platform.isIOS;
    try {
      final status = await _health.getHealthConnectSdkStatus();
      debugPrint('HealthSync: HC SDK status = $status');
      return status == HealthConnectSdkStatus.sdkAvailable;
    } catch (e) {
      debugPrint('HealthSync: HC availability check failed: $e');
      return false;
    }
  }

  /// Request permissions for all sync types (read-only).
  /// Tries all types first, then falls back to core types if that fails.
  static Future<bool> requestPermissions() async {
    if (!isAvailable) return false;
    await _ensureConfigured();

    // First try all types
    try {
      final permissions =
          _syncTypes.map((t) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        _syncTypes,
        permissions: permissions,
      );
      debugPrint('HealthSync: requestAuthorization(all) = $granted');
      if (granted) return true;
    } catch (e) {
      debugPrint('HealthSync: requestAuthorization(all) error: $e');
    }

    // Fallback: try with just core types that are most likely supported
    const coreTypes = [
      HealthDataType.STEPS,
      HealthDataType.HEART_RATE,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WEIGHT,
    ];
    try {
      final permissions =
          coreTypes.map((t) => HealthDataAccess.READ).toList();
      final granted = await _health.requestAuthorization(
        coreTypes,
        permissions: permissions,
      );
      debugPrint('HealthSync: requestAuthorization(core) = $granted');
      return granted;
    } catch (e) {
      debugPrint('HealthSync: requestAuthorization(core) error: $e');
      return false;
    }
  }

  /// Check if we already have permissions.
  static Future<bool> hasPermissions() async {
    if (!isAvailable) return false;
    await _ensureConfigured();
    try {
      final result = await _health.hasPermissions(
        _syncTypes,
        permissions:
            _syncTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      debugPrint('HealthSync: hasPermissions = $result');
      return result ?? false;
    } catch (e) {
      debugPrint('HealthSync: hasPermissions error: $e');
      return false;
    }
  }

  /// Try to read health data as a definitive permission test.
  /// Returns true if we can read data (even if there are 0 points — no error means access works).
  static Future<bool> canReadData() async {
    if (!isAvailable) return false;
    await _ensureConfigured();
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 7));
      // Try getTotalStepsInInterval first — simpler and more reliable
      final steps = await _health.getTotalStepsInInterval(start, now);
      debugPrint('HealthSync: canReadData — steps in last 7 days: $steps');
      // Also try getHealthDataFromTypes to verify full read access
      final points = await _health.getHealthDataFromTypes(
        types: [HealthDataType.STEPS],
        startTime: start,
        endTime: now,
      );
      debugPrint('HealthSync: canReadData = true (${points.length} STEPS points)');
      return true;
    } catch (e) {
      debugPrint('HealthSync: canReadData = false (error: $e)');
      return false;
    }
  }

  /// Get the source ID string for the current platform.
  static String get platformSourceId =>
      Platform.isIOS ? 'apple_health' : 'health_connect';

  /// Perform incremental sync from the platform health store.
  /// Returns a [SyncResult] with insert/skip/replace counts.
  /// Set [throwOnError] to true to propagate errors instead of swallowing them.
  static Future<SyncResult> syncFromPlatform({
    String person = 'self',
    bool throwOnError = false,
  }) async {
    if (!isAvailable) {
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    // Prevent concurrent syncs (dashboard auto-sync + manual trigger + etc.)
    if (_syncInProgress) {
      debugPrint('HealthSync: sync already in progress, skipping');
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }
    _syncInProgress = true;

    try {
      return await _doSync(person: person, throwOnError: throwOnError);
    } finally {
      _syncInProgress = false;
    }
  }

  static Future<SyncResult> _doSync({
    String person = 'self',
    bool throwOnError = false,
  }) async {
    await _ensureConfigured();

    // Show ongoing notification so user knows sync is running
    try { await NotificationService.showSyncStarted(); } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final lastSyncKey = 'health_sync_last_$person';
    final lastSyncMs = prefs.getInt(lastSyncKey) ?? 0;

    final now = DateTime.now();
    final start = lastSyncMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(lastSyncMs)
        : now.subtract(const Duration(days: 30)); // First sync: last 30 days

    // Read health data — try each type individually to avoid one bad type
    // killing the entire read
    List<HealthDataPoint> dataPoints = [];
    final typeResults = <String, int>{};
    final typeErrors = <String, String>{};
    for (final type in _syncTypes) {
      try {
        final points = await _health.getHealthDataFromTypes(
          types: [type],
          startTime: start,
          endTime: now,
        );
        if (points.isNotEmpty) {
          typeResults[type.name] = points.length;
        }
        dataPoints.addAll(points);
      } catch (e) {
        typeErrors[type.name] = e.toString();
        debugPrint('HealthSync: getHealthData($type) error: $e');
        if (throwOnError) rethrow;
        // Skip this type and continue with others
      }
    }
    debugPrint('HealthSync: read ${dataPoints.length} data points total');
    debugPrint('HealthSync: by type: $typeResults');
    if (typeErrors.isNotEmpty) {
      debugPrint('HealthSync: errors: $typeErrors');
    }
    // Store diagnostic info for the UI
    _lastSyncDiagnostics = SyncDiagnostics(
      totalPoints: dataPoints.length,
      typeResults: typeResults,
      typeErrors: typeErrors,
      queryStart: start,
      queryEnd: now,
    );

    // If raw data points are empty, try aggregate APIs as fallback.
    // Some Samsung devices only expose aggregates through Health Connect.
    if (dataPoints.isEmpty) {
      debugPrint('HealthSync: raw data empty, trying aggregate fallback...');
      final aggObservations = await _readAggregateData(start, now);
      if (aggObservations.isNotEmpty) {
        debugPrint('HealthSync: aggregate fallback got ${aggObservations.length} observations');
        // Update diagnostics
        _lastSyncDiagnostics = SyncDiagnostics(
          totalPoints: aggObservations.length,
          typeResults: {'aggregate_fallback': aggObservations.length},
          typeErrors: typeErrors,
          queryStart: start,
          queryEnd: now,
        );
        // Upload aggregates directly
        int totalInserted = 0, totalSkipped = 0, totalReplaced = 0;
        for (var i = 0; i < aggObservations.length; i += 25) {
          final batch = aggObservations.sublist(
              i, (i + 25).clamp(0, aggObservations.length));
          final result = await _uploadBatchWithRetry(batch, person);
          totalInserted += result.$1;
          totalSkipped += result.$2;
          totalReplaced += result.$3;
        }
        await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
        final r = SyncResult(
            inserted: totalInserted, skipped: totalSkipped, replaced: totalReplaced);
        try { await NotificationService.showSyncComplete(inserted: totalInserted, total: aggObservations.length); } catch (_) {}
        return r;
      }
      await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
      try { await NotificationService.showSyncComplete(); } catch (_) {}
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    // Remove duplicates provided by the health package
    dataPoints = _health.removeDuplicates(dataPoints);

    // Remove overlapping step data points: Samsung Health Connect often
    // returns both a daily summary (spanning 24h) AND individual step events
    // within that day. The summary already includes the individual events,
    // so keeping both causes double-counting (e.g., 2952 + 6 + 29 = 2987
    // instead of the correct 2952).
    dataPoints = _deduplicateOverlappingSteps(dataPoints);

    // Convert to canonical observation format
    final observations = dataPoints
        .map(_toCanonical)
        .where((o) => o != null)
        .cast<Map<String, dynamic>>()
        .toList();

    if (observations.isEmpty) {
      await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);
      try { await NotificationService.showSyncComplete(); } catch (_) {}
      return SyncResult(inserted: 0, skipped: 0, replaced: 0);
    }

    debugPrint('HealthSync: uploading ${observations.length} observations');

    // Upload in batches of 25 — smaller batches avoid Railway 503 timeouts
    // from the per-observation supersession queries + cache refresh.
    int totalInserted = 0, totalSkipped = 0, totalReplaced = 0;
    int consecutiveFailures = 0;

    for (var i = 0; i < observations.length; i += 25) {
      final batch =
          observations.sublist(i, (i + 25).clamp(0, observations.length));
      try {
        final result = await _uploadBatchWithRetry(batch, person);
        if (result.$1 > 0 || result.$2 > 0 || result.$3 > 0) {
          consecutiveFailures = 0; // batch succeeded
        } else {
          consecutiveFailures++;
        }
        totalInserted += result.$1;
        totalSkipped += result.$2;
        totalReplaced += result.$3;
      } catch (e) {
        debugPrint('HealthSync: upload batch error: $e');
        consecutiveFailures++;
        if (throwOnError) rethrow;
      }
      // Abort remaining batches if network is consistently down
      if (consecutiveFailures >= 2) {
        debugPrint('HealthSync: aborting remaining batches after $consecutiveFailures consecutive failures');
        break;
      }
    }

    // Update last sync timestamp
    await prefs.setInt(lastSyncKey, now.millisecondsSinceEpoch);

    debugPrint('HealthSync: done — inserted=$totalInserted, skipped=$totalSkipped, replaced=$totalReplaced');

    // Notify user that sync is complete
    if (consecutiveFailures >= 2 && totalInserted == 0) {
      try { await NotificationService.showSyncFailed(); } catch (_) {}
    } else {
      try { await NotificationService.showSyncComplete(inserted: totalInserted, total: observations.length); } catch (_) {}
    }

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
      HealthDataType.DISTANCE_DELTA: 'distance',
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

  /// Remove overlapping step data points.
  /// Samsung Health Connect returns daily summaries (spanning 24h) alongside
  /// individual step events. The summary includes all individual events, so
  /// we must remove the individual events to prevent double-counting.
  static List<HealthDataPoint> _deduplicateOverlappingSteps(
      List<HealthDataPoint> points) {
    // Find daily summary step points (spanning > 12 hours)
    final stepSummaries = points.where((p) =>
        p.type == HealthDataType.STEPS &&
        p.dateTo.difference(p.dateFrom).inHours > 12).toList();

    if (stepSummaries.isEmpty) return points;

    // Remove individual step events that fall within any summary's range
    return points.where((p) {
      if (p.type != HealthDataType.STEPS) return true;
      // Keep summaries themselves
      if (p.dateTo.difference(p.dateFrom).inHours > 12) return true;
      // Remove if this point falls within any summary's time range
      for (final summary in stepSummaries) {
        if (!p.dateFrom.isBefore(summary.dateFrom) &&
            !p.dateTo.isAfter(summary.dateTo)) {
          return false; // Drop — already included in summary
        }
      }
      return true;
    }).toList();
  }

  /// Upload a batch of observations with retry on 503 / timeout.
  /// Returns (inserted, skipped, replaced).
  static Future<(int, int, int)> _uploadBatchWithRetry(
    List<Map<String, dynamic>> batch,
    String person, {
    int maxRetries = 2,
  }) async {
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        final resp = await apiClient.dio.post(
          ApiConstants.syncIngest,
          data: {'observations': batch, 'person': person},
          options: Options(
            receiveTimeout: const Duration(seconds: 90),
            sendTimeout: const Duration(seconds: 60),
          ),
        );
        if (resp.statusCode == 200) {
          return (
            (resp.data['inserted'] as int?) ?? 0,
            (resp.data['skipped'] as int?) ?? 0,
            (resp.data['replaced'] as int?) ?? 0,
          );
        }
      } catch (e) {
        debugPrint('HealthSync: upload attempt ${attempt + 1} error: $e');
        final isRetryable = e is DioException &&
            (e.response?.statusCode == 503 ||
             e.type == DioExceptionType.receiveTimeout ||
             e.type == DioExceptionType.connectionTimeout ||
             e.type == DioExceptionType.connectionError ||
             e.type == DioExceptionType.unknown);
        if (!isRetryable || attempt == maxRetries) {
          debugPrint('HealthSync: upload failed after ${attempt + 1} attempts');
          return (0, 0, 0);
        }
        // Wait before retry: 5s, 15s, 30s
        final delays = [5, 15, 30];
        await Future.delayed(Duration(seconds: delays[attempt.clamp(0, 2)]));
      }
    }
    return (0, 0, 0);
  }

  /// Fallback: read data via aggregate/interval APIs when raw data points
  /// are not available (common on Samsung devices with Health Connect).
  /// Returns canonical observation maps ready for upload.
  static Future<List<Map<String, dynamic>>> _readAggregateData(
      DateTime start, DateTime end) async {
    final observations = <Map<String, dynamic>>[];
    final sourceId = Platform.isIOS ? 'apple_health' : 'health_connect';
    final tz = DateTime.now().timeZoneName;

    // Read daily step totals
    try {
      // Get steps day by day
      var day = DateTime(start.year, start.month, start.day);
      final endDay = DateTime(end.year, end.month, end.day);
      while (!day.isAfter(endDay)) {
        final dayEnd = day.add(const Duration(days: 1));
        final steps = await _health.getTotalStepsInInterval(day, dayEnd);
        if (steps != null && steps > 0) {
          // Use local time (NOT UTC) to preserve the correct calendar date.
          // Converting to UTC shifts midnight backward for positive UTC offsets
          // (e.g., IST midnight → previous day 18:30 UTC), causing the backend
          // to file the cache under the wrong date.
          observations.add({
            'data_type': 'steps',
            'effective_start': day.toIso8601String(),
            'effective_end': dayEnd.toIso8601String(),
            'value_numeric': steps.toDouble(),
            'value_text': null,
            'value_json': null,
            'unit': 'steps',
            'source_id': sourceId,
            'source_record_id': 'agg_steps_${day.toIso8601String().substring(0, 10)}',
            'time_zone': tz,
            'is_manual': false,
          });
        }
        day = dayEnd;
      }
      debugPrint('HealthSync: aggregate steps → ${observations.length} daily entries');
    } catch (e) {
      debugPrint('HealthSync: aggregate steps error: $e');
    }

    // Try getHealthIntervalDataFromTypes for other data types.
    // DISTANCE_WALKING_RUNNING is iOS-only; use DISTANCE_DELTA on Android.
    final aggregateTypes = [
      HealthDataType.HEART_RATE,
      HealthDataType.ACTIVE_ENERGY_BURNED,
      if (Platform.isIOS) HealthDataType.DISTANCE_WALKING_RUNNING,
      if (Platform.isAndroid) HealthDataType.DISTANCE_DELTA,
      HealthDataType.SLEEP_ASLEEP,
      HealthDataType.WEIGHT,
    ];

    final typeToCanonical = {
      HealthDataType.HEART_RATE: ('heart_rate', 'bpm'),
      HealthDataType.ACTIVE_ENERGY_BURNED: ('active_calories', 'kcal'),
      HealthDataType.DISTANCE_WALKING_RUNNING: ('distance', 'm'),
      HealthDataType.DISTANCE_DELTA: ('distance', 'm'),
      HealthDataType.SLEEP_ASLEEP: ('sleep_session', 'min'),
      HealthDataType.WEIGHT: ('weight', 'kg'),
    };

    for (final type in aggregateTypes) {
      try {
        final points = await _health.getHealthIntervalDataFromTypes(
          types: [type],
          startDate: start,
          endDate: end,
          interval: 1,
        );
        for (final p in points) {
          final mapping = typeToCanonical[type];
          if (mapping == null) continue;
          double? value;
          if (p.value is NumericHealthValue) {
            value = (p.value as NumericHealthValue).numericValue.toDouble();
          }
          if (value == null || value == 0) continue;
          observations.add({
            'data_type': mapping.$1,
            'effective_start': p.dateFrom.toIso8601String(),
            'effective_end': p.dateTo.toIso8601String(),
            'value_numeric': value,
            'value_text': null,
            'value_json': null,
            'unit': mapping.$2,
            'source_id': sourceId,
            'source_record_id': p.uuid,
            'time_zone': tz,
            'is_manual': false,
          });
        }
        if (points.isNotEmpty) {
          debugPrint('HealthSync: aggregate ${type.name} → ${points.length} points');
        }
      } catch (e) {
        debugPrint('HealthSync: aggregate ${type.name} error: $e');
        // Continue with next type
      }
    }

    return observations;
  }
}
