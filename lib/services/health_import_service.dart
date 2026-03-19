import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml_events.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';

/// Supported import source formats.
enum ImportFormat {
  appleHealthXml('apple_health_xml', 'Apple Health Export'),
  mfpCsv('mfp_csv', 'MyFitnessPal CSV'),
  cronometerCsv('cronometer_csv', 'Cronometer CSV'),
  fitbitJson('fitbit_json', 'Fitbit JSON');

  final String code;
  final String displayName;
  const ImportFormat(this.code, this.displayName);

  static ImportFormat? fromFilename(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.xml') || lower.endsWith('.zip')) {
      return ImportFormat.appleHealthXml;
    }
    if (lower.contains('myfitnesspal') || lower.contains('mfp')) {
      return ImportFormat.mfpCsv;
    }
    if (lower.contains('cronometer')) {
      return ImportFormat.cronometerCsv;
    }
    if (lower.endsWith('.json')) {
      return ImportFormat.fitbitJson;
    }
    if (lower.endsWith('.csv')) {
      // Default CSV — will be further detected at parse time
      return ImportFormat.mfpCsv;
    }
    return null;
  }
}

/// Apple Health type string -> canonical code mapping.
const _appleHealthTypeMap = {
  'HKQuantityTypeIdentifierStepCount': 'steps',
  'HKQuantityTypeIdentifierHeartRate': 'heart_rate',
  'HKQuantityTypeIdentifierBodyMass': 'weight',
  'HKQuantityTypeIdentifierActiveEnergyBurned': 'active_calories',
  'HKQuantityTypeIdentifierDistanceWalkingRunning': 'distance',
  'HKQuantityTypeIdentifierBloodGlucose': 'blood_glucose',
  'HKQuantityTypeIdentifierOxygenSaturation': 'spo2',
  'HKQuantityTypeIdentifierBloodPressureSystolic': 'blood_pressure',
  'HKQuantityTypeIdentifierBodyTemperature': 'body_temperature',
  'HKQuantityTypeIdentifierRestingHeartRate': 'resting_heart_rate',
  'HKQuantityTypeIdentifierHeartRateVariabilitySDNN': 'heart_rate_variability',
  'HKQuantityTypeIdentifierBodyFatPercentage': 'body_fat_pct',
  'HKQuantityTypeIdentifierRespiratoryRate': 'respiratory_rate',
  'HKQuantityTypeIdentifierDietaryWater': 'water',
  'HKCategoryTypeIdentifierSleepAnalysis': 'sleep_session',
  'HKQuantityTypeIdentifierDietaryEnergyConsumed': 'dietary_calories',
  'HKQuantityTypeIdentifierDietaryProtein': 'dietary_protein',
  'HKQuantityTypeIdentifierDietaryCarbohydrates': 'dietary_carbs',
  'HKQuantityTypeIdentifierDietaryFatTotal': 'dietary_fat',
  'HKQuantityTypeIdentifierFlightsClimbed': 'flights_climbed',
  'HKQuantityTypeIdentifierVO2Max': 'vo2_max',
  'HKQuantityTypeIdentifierHeight': 'height',
};

/// Unit mapping for Apple Health types.
const _appleUnitMap = {
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
  'sleep_session': 'min',
  'dietary_calories': 'kcal',
  'dietary_protein': 'g',
  'dietary_carbs': 'g',
  'dietary_fat': 'g',
  'respiratory_rate': 'breaths/min',
  'flights_climbed': 'flights',
  'vo2_max': 'mL/kg/min',
  'height': 'cm',
};

class HealthImportService {
  static const int _batchSize = 200;

  /// Pick a file for import. Returns null if user cancels.
  static Future<PlatformFile?> pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xml', 'csv', 'zip', 'json'],
    );
    if (result == null || result.files.isEmpty) return null;
    return result.files.first;
  }

  /// Upload the file to the backend and create an ImportJob.
  /// Returns (jobId, batchId, detectedFormat).
  static Future<({String jobId, String batchId, String source})?> uploadFile(
    PlatformFile file,
  ) async {
    final filePath = file.path;
    if (filePath == null) return null;

    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: file.name),
    });

    final resp = await apiClient.dio.post(
      ApiConstants.importUpload,
      data: formData,
      options: Options(
        contentType: 'multipart/form-data',
        receiveTimeout: const Duration(seconds: 60),
      ),
    );

    if (resp.statusCode == 200) {
      return (
        jobId: resp.data['job_id'] as String,
        batchId: resp.data['batch_id'] as String,
        source: resp.data['source'] as String,
      );
    }
    return null;
  }

  /// Estimate record count by quickly scanning the file.
  /// For XML, counts <Record> occurrences; for CSV, counts lines.
  static Future<int> estimateRecordCount(String filePath, ImportFormat format) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    switch (format) {
      case ImportFormat.appleHealthXml:
        return _estimateXmlRecords(file);
      case ImportFormat.mfpCsv:
      case ImportFormat.cronometerCsv:
        return _estimateCsvRecords(file);
      case ImportFormat.fitbitJson:
        return _estimateJsonRecords(file);
    }
  }

  static Future<int> _estimateXmlRecords(File file) async {
    int count = 0;
    await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      // Count <Record lines — fast estimate without full XML parsing
      if (line.trimLeft().startsWith('<Record ')) {
        count++;
      }
    }
    return count;
  }

  static Future<int> _estimateCsvRecords(File file) async {
    int count = 0;
    await for (final _ in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      count++;
    }
    // Subtract header row
    return count > 0 ? count - 1 : 0;
  }

  static Future<int> _estimateJsonRecords(File file) async {
    try {
      final content = await file.readAsString();
      final data = json.decode(content);
      if (data is List) return data.length;
      if (data is Map && data.containsKey('activities')) {
        return (data['activities'] as List?)?.length ?? 0;
      }
      return 0;
    } catch (_) {
      return 0;
    }
  }

  /// Get the date range from a file by scanning first and last records.
  static Future<({DateTime? earliest, DateTime? latest})> getDateRange(
    String filePath,
    ImportFormat format,
  ) async {
    DateTime? earliest;
    DateTime? latest;
    final file = File(filePath);
    if (!await file.exists()) return (earliest: null, latest: null);

    switch (format) {
      case ImportFormat.appleHealthXml:
        // Scan first 100 and last 100 records for a quick range estimate
        int count = 0;
        await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
          if (count > 200) break;
          if (line.trimLeft().startsWith('<Record ')) {
            final dateMatch = RegExp(r'startDate="([^"]+)"').firstMatch(line);
            if (dateMatch != null) {
              final dt = _parseAppleDate(dateMatch.group(1)!);
              if (dt != null) {
                if (earliest == null || dt.isBefore(earliest)) earliest = dt;
                if (latest == null || dt.isAfter(latest)) latest = dt;
              }
            }
            count++;
          }
        }
        break;
      case ImportFormat.mfpCsv:
      case ImportFormat.cronometerCsv:
        int lineNo = 0;
        await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
          lineNo++;
          if (lineNo == 1) continue; // skip header
          if (lineNo > 200) break;
          final parts = line.split(',');
          if (parts.isNotEmpty) {
            final dt = DateTime.tryParse(parts[0].replaceAll('"', '').trim());
            if (dt != null) {
              if (earliest == null || dt.isBefore(earliest)) earliest = dt;
              if (latest == null || dt.isAfter(latest)) latest = dt;
            }
          }
        }
        break;
      case ImportFormat.fitbitJson:
        // Not easily streamable — skip range estimation for JSON
        break;
    }

    return (earliest: earliest, latest: latest);
  }

  /// Process the import file — parse + send batches to backend.
  static Future<void> processImport({
    required String filePath,
    required String jobId,
    required ImportFormat format,
    required void Function(ImportProgress) onProgress,
    required int totalRecords,
  }) async {
    switch (format) {
      case ImportFormat.appleHealthXml:
        await _importAppleHealthXml(filePath, jobId, onProgress, totalRecords);
        break;
      case ImportFormat.mfpCsv:
        await _importMfpCsv(filePath, jobId, onProgress, totalRecords);
        break;
      case ImportFormat.cronometerCsv:
        await _importCronometerCsv(filePath, jobId, onProgress, totalRecords);
        break;
      case ImportFormat.fitbitJson:
        await _importFitbitJson(filePath, jobId, onProgress, totalRecords);
        break;
    }

    // Mark job as completed
    try {
      await apiClient.dio.post(ApiConstants.importComplete(jobId));
    } catch (_) {
      // Best effort
    }
  }

  /// Cancel a running import.
  static Future<void> cancelImport(String jobId) async {
    await apiClient.dio.post(ApiConstants.importCancel(jobId));
  }

  /// Rollback a completed import.
  static Future<int> rollbackImport(String jobId) async {
    final resp = await apiClient.dio.post(ApiConstants.importRollback(jobId));
    return (resp.data['rolled_back_count'] as int?) ?? 0;
  }

  /// Get the current status of an import job.
  static Future<ImportProgress> getJobStatus(String jobId) async {
    final resp = await apiClient.dio.get(ApiConstants.importJob(jobId));
    return ImportProgress.fromJson(resp.data as Map<String, dynamic>);
  }

  // ── Apple Health XML Import ──────────────────────────────────────────────

  static Future<void> _importAppleHealthXml(
    String filePath,
    String jobId,
    void Function(ImportProgress) onProgress,
    int totalRecords,
  ) async {
    final file = File(filePath);
    final batch = <Map<String, dynamic>>[];
    int processed = 0;
    int inserted = 0;
    int skipped = 0;
    int errors = 0;

    // Use SAX-style streaming parser via xml_events to avoid OOM
    final stream = file.openRead().transform(utf8.decoder);
    final events = stream.toXmlEvents().withParentEvents();

    await for (final eventList in events) {
      for (final event in eventList) {
        if (event is! XmlStartElementEvent || event.name != 'Record') continue;

        final attrs = {for (final a in event.attributes) a.name: a.value};
        final type = attrs['type'];
        final value = attrs['value'];
        final startDate = attrs['startDate'];
        final endDate = attrs['endDate'];
        final unit = attrs['unit'];

        if (type == null || startDate == null) continue;

        final canonicalCode = _appleHealthTypeMap[type];
        if (canonicalCode == null) continue; // Unsupported type

        final parsedStart = _parseAppleDate(startDate);
        if (parsedStart == null) continue;

        final parsedEnd = endDate != null ? _parseAppleDate(endDate) : null;

        double? numericValue;
        if (value != null) {
          numericValue = double.tryParse(value);
        }

        batch.add({
          'data_type': canonicalCode,
          'effective_start': parsedStart.toUtc().toIso8601String(),
          'effective_end': parsedEnd?.toUtc().toIso8601String(),
          'value_numeric': numericValue,
          'unit': unit ?? _appleUnitMap[canonicalCode] ?? '',
          'source_id': 'apple_health_import',
          'source_record_id': '${type}_$startDate',
          'is_manual': false,
        });

        // Send batch when full
        if (batch.length >= _batchSize) {
          final result = await _sendBatch(jobId, batch);
          inserted += result.inserted;
          skipped += result.skipped;
          processed += batch.length;
          batch.clear();

          onProgress(ImportProgress(
            jobId: jobId,
            source: 'apple_health_xml',
            status: 'running',
            totalRecords: totalRecords,
            processedCount: processed,
            insertedCount: inserted,
            skippedCount: skipped,
            errorCount: errors,
          ));
        }
      }
    }

    // Send remaining batch
    if (batch.isNotEmpty) {
      try {
        final result = await _sendBatch(jobId, batch);
        inserted += result.inserted;
        skipped += result.skipped;
        processed += batch.length;
      } catch (e) {
        errors += batch.length;
      }
    }

    onProgress(ImportProgress(
      jobId: jobId,
      source: 'apple_health_xml',
      status: 'completed',
      totalRecords: totalRecords,
      processedCount: processed,
      insertedCount: inserted,
      skippedCount: skipped,
      errorCount: errors,
    ));
  }

  // ── MyFitnessPal CSV Import ──────────────────────────────────────────────

  static Future<void> _importMfpCsv(
    String filePath,
    String jobId,
    void Function(ImportProgress) onProgress,
    int totalRecords,
  ) async {
    final file = File(filePath);
    final lines = <String>[];
    await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      lines.add(line);
    }

    if (lines.isEmpty) return;

    // Parse CSV
    const csvConverter = CsvToListConverter();
    final parsed = csvConverter.convert(lines.join('\n'));
    if (parsed.length < 2) return; // header only

    final header = parsed[0].map((e) => e.toString().toLowerCase().trim()).toList();
    final dateIdx = _findColumn(header, ['date']);
    final caloriesIdx = _findColumn(header, ['calories', 'energy', 'kcal']);
    final proteinIdx = _findColumn(header, ['protein']);
    final carbsIdx = _findColumn(header, ['carbs', 'carbohydrates', 'total carbohydrates']);
    final fatIdx = _findColumn(header, ['fat', 'total fat']);

    final batch = <Map<String, dynamic>>[];
    int processed = 0;
    int inserted = 0;
    int skipped = 0;
    int errors = 0;

    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.length <= (dateIdx ?? 0)) continue;

      final dateStr = dateIdx != null ? row[dateIdx].toString().trim() : null;
      if (dateStr == null || dateStr.isEmpty) continue;

      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;

      final startIso = dt.toUtc().toIso8601String();

      // Add calorie observation
      if (caloriesIdx != null && caloriesIdx < row.length) {
        final cal = double.tryParse(row[caloriesIdx].toString());
        if (cal != null && cal > 0) {
          batch.add({
            'data_type': 'dietary_calories',
            'effective_start': startIso,
            'value_numeric': cal,
            'unit': 'kcal',
            'source_id': 'myfitnesspal_import',
            'source_record_id': 'mfp_cal_${dateStr}_$i',
            'is_manual': false,
          });
        }
      }

      // Add protein observation
      if (proteinIdx != null && proteinIdx < row.length) {
        final val = double.tryParse(row[proteinIdx].toString());
        if (val != null && val > 0) {
          batch.add({
            'data_type': 'dietary_protein',
            'effective_start': startIso,
            'value_numeric': val,
            'unit': 'g',
            'source_id': 'myfitnesspal_import',
            'source_record_id': 'mfp_pro_${dateStr}_$i',
            'is_manual': false,
          });
        }
      }

      // Add carbs observation
      if (carbsIdx != null && carbsIdx < row.length) {
        final val = double.tryParse(row[carbsIdx].toString());
        if (val != null && val > 0) {
          batch.add({
            'data_type': 'dietary_carbs',
            'effective_start': startIso,
            'value_numeric': val,
            'unit': 'g',
            'source_id': 'myfitnesspal_import',
            'source_record_id': 'mfp_carb_${dateStr}_$i',
            'is_manual': false,
          });
        }
      }

      // Add fat observation
      if (fatIdx != null && fatIdx < row.length) {
        final val = double.tryParse(row[fatIdx].toString());
        if (val != null && val > 0) {
          batch.add({
            'data_type': 'dietary_fat',
            'effective_start': startIso,
            'value_numeric': val,
            'unit': 'g',
            'source_id': 'myfitnesspal_import',
            'source_record_id': 'mfp_fat_${dateStr}_$i',
            'is_manual': false,
          });
        }
      }

      // Send batch when full
      if (batch.length >= _batchSize) {
        try {
          final result = await _sendBatch(jobId, batch);
          inserted += result.inserted;
          skipped += result.skipped;
        } catch (e) {
          errors += batch.length;
        }
        processed += batch.length;
        batch.clear();

        onProgress(ImportProgress(
          jobId: jobId,
          source: 'mfp_csv',
          status: 'running',
          totalRecords: totalRecords,
          processedCount: processed,
          insertedCount: inserted,
          skippedCount: skipped,
          errorCount: errors,
        ));
      }
    }

    // Send remaining
    if (batch.isNotEmpty) {
      try {
        final result = await _sendBatch(jobId, batch);
        inserted += result.inserted;
        skipped += result.skipped;
        processed += batch.length;
      } catch (e) {
        errors += batch.length;
      }
    }

    onProgress(ImportProgress(
      jobId: jobId,
      source: 'mfp_csv',
      status: 'completed',
      totalRecords: totalRecords,
      processedCount: processed,
      insertedCount: inserted,
      skippedCount: skipped,
      errorCount: errors,
    ));
  }

  // ── Cronometer CSV Import ────────────────────────────────────────────────

  static Future<void> _importCronometerCsv(
    String filePath,
    String jobId,
    void Function(ImportProgress) onProgress,
    int totalRecords,
  ) async {
    final file = File(filePath);
    final lines = <String>[];
    await for (final line in file.openRead().transform(utf8.decoder).transform(const LineSplitter())) {
      lines.add(line);
    }

    if (lines.isEmpty) return;

    const csvConverter = CsvToListConverter();
    final parsed = csvConverter.convert(lines.join('\n'));
    if (parsed.length < 2) return;

    final header = parsed[0].map((e) => e.toString().toLowerCase().trim()).toList();
    final dateIdx = _findColumn(header, ['date', 'day']);
    final energyIdx = _findColumn(header, ['energy (kcal)', 'energy', 'calories']);
    final proteinIdx = _findColumn(header, ['protein (g)', 'protein']);
    final carbsIdx = _findColumn(header, ['carbs (g)', 'carbohydrates (g)', 'net carbs (g)', 'carbs']);
    final fatIdx = _findColumn(header, ['fat (g)', 'fat']);
    final fiberIdx = _findColumn(header, ['fiber (g)', 'fiber']);
    final sugarIdx = _findColumn(header, ['sugars (g)', 'sugar (g)', 'sugar']);
    final sodiumIdx = _findColumn(header, ['sodium (mg)', 'sodium']);
    final cholesterolIdx = _findColumn(header, ['cholesterol (mg)', 'cholesterol']);
    final waterIdx = _findColumn(header, ['water (g)', 'water']);

    // Cronometer nutrient column map -> canonical type
    final nutrientCols = <int, ({String type, String unit})>{};
    if (energyIdx != null) nutrientCols[energyIdx] = (type: 'dietary_calories', unit: 'kcal');
    if (proteinIdx != null) nutrientCols[proteinIdx] = (type: 'dietary_protein', unit: 'g');
    if (carbsIdx != null) nutrientCols[carbsIdx] = (type: 'dietary_carbs', unit: 'g');
    if (fatIdx != null) nutrientCols[fatIdx] = (type: 'dietary_fat', unit: 'g');
    if (fiberIdx != null) nutrientCols[fiberIdx] = (type: 'dietary_fiber', unit: 'g');
    if (sugarIdx != null) nutrientCols[sugarIdx] = (type: 'dietary_sugar', unit: 'g');
    if (sodiumIdx != null) nutrientCols[sodiumIdx] = (type: 'dietary_sodium', unit: 'mg');
    if (cholesterolIdx != null) nutrientCols[cholesterolIdx] = (type: 'dietary_cholesterol', unit: 'mg');
    if (waterIdx != null) nutrientCols[waterIdx] = (type: 'water', unit: 'mL');

    final batch = <Map<String, dynamic>>[];
    int processed = 0;
    int inserted = 0;
    int skipped = 0;
    int errors = 0;

    for (int i = 1; i < parsed.length; i++) {
      final row = parsed[i];
      if (row.length <= (dateIdx ?? 0)) continue;

      final dateStr = dateIdx != null ? row[dateIdx].toString().trim() : null;
      if (dateStr == null || dateStr.isEmpty) continue;

      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;

      final startIso = dt.toUtc().toIso8601String();

      for (final entry in nutrientCols.entries) {
        final colIdx = entry.key;
        final info = entry.value;
        if (colIdx >= row.length) continue;

        final val = double.tryParse(row[colIdx].toString());
        if (val == null || val <= 0) continue;

        batch.add({
          'data_type': info.type,
          'effective_start': startIso,
          'value_numeric': val,
          'unit': info.unit,
          'source_id': 'cronometer_import',
          'source_record_id': 'cron_${info.type}_${dateStr}_$i',
          'is_manual': false,
        });
      }

      if (batch.length >= _batchSize) {
        try {
          final result = await _sendBatch(jobId, batch);
          inserted += result.inserted;
          skipped += result.skipped;
        } catch (e) {
          errors += batch.length;
        }
        processed += batch.length;
        batch.clear();

        onProgress(ImportProgress(
          jobId: jobId,
          source: 'cronometer_csv',
          status: 'running',
          totalRecords: totalRecords,
          processedCount: processed,
          insertedCount: inserted,
          skippedCount: skipped,
          errorCount: errors,
        ));
      }
    }

    if (batch.isNotEmpty) {
      try {
        final result = await _sendBatch(jobId, batch);
        inserted += result.inserted;
        skipped += result.skipped;
        processed += batch.length;
      } catch (e) {
        errors += batch.length;
      }
    }

    onProgress(ImportProgress(
      jobId: jobId,
      source: 'cronometer_csv',
      status: 'completed',
      totalRecords: totalRecords,
      processedCount: processed,
      insertedCount: inserted,
      skippedCount: skipped,
      errorCount: errors,
    ));
  }

  // ── Fitbit JSON Import ───────────────────────────────────────────────────

  static Future<void> _importFitbitJson(
    String filePath,
    String jobId,
    void Function(ImportProgress) onProgress,
    int totalRecords,
  ) async {
    final file = File(filePath);
    final content = await file.readAsString();
    final data = json.decode(content);

    List<dynamic> activities;
    if (data is List) {
      activities = data;
    } else if (data is Map && data.containsKey('activities')) {
      activities = data['activities'] as List;
    } else {
      return;
    }

    final batch = <Map<String, dynamic>>[];
    int processed = 0;
    int inserted = 0;
    int skipped = 0;
    int errors = 0;

    for (final activity in activities) {
      if (activity is! Map) continue;

      final dateStr = activity['dateOfActivity'] as String? ??
          activity['startDate'] as String? ??
          activity['date'] as String?;
      if (dateStr == null) continue;

      final dt = DateTime.tryParse(dateStr);
      if (dt == null) continue;
      final startIso = dt.toUtc().toIso8601String();

      // Steps
      final steps = activity['steps'] as int?;
      if (steps != null && steps > 0) {
        batch.add({
          'data_type': 'steps',
          'effective_start': startIso,
          'value_numeric': steps.toDouble(),
          'unit': 'steps',
          'source_id': 'fitbit_import',
          'source_record_id': 'fitbit_steps_$dateStr',
          'is_manual': false,
        });
      }

      // Calories
      final calories = activity['calories'] as num?;
      if (calories != null && calories > 0) {
        batch.add({
          'data_type': 'active_calories',
          'effective_start': startIso,
          'value_numeric': calories.toDouble(),
          'unit': 'kcal',
          'source_id': 'fitbit_import',
          'source_record_id': 'fitbit_cal_$dateStr',
          'is_manual': false,
        });
      }

      // Distance
      final distance = activity['distance'] as num?;
      if (distance != null && distance > 0) {
        batch.add({
          'data_type': 'distance',
          'effective_start': startIso,
          'value_numeric': (distance * 1000).toDouble(), // km -> m
          'unit': 'm',
          'source_id': 'fitbit_import',
          'source_record_id': 'fitbit_dist_$dateStr',
          'is_manual': false,
        });
      }

      // Heart rate
      final hr = activity['averageHeartRate'] as num?;
      if (hr != null && hr > 0) {
        batch.add({
          'data_type': 'heart_rate',
          'effective_start': startIso,
          'value_numeric': hr.toDouble(),
          'unit': 'bpm',
          'source_id': 'fitbit_import',
          'source_record_id': 'fitbit_hr_$dateStr',
          'is_manual': false,
        });
      }

      if (batch.length >= _batchSize) {
        try {
          final result = await _sendBatch(jobId, batch);
          inserted += result.inserted;
          skipped += result.skipped;
        } catch (e) {
          errors += batch.length;
        }
        processed += batch.length;
        batch.clear();

        onProgress(ImportProgress(
          jobId: jobId,
          source: 'fitbit_json',
          status: 'running',
          totalRecords: totalRecords,
          processedCount: processed,
          insertedCount: inserted,
          skippedCount: skipped,
          errorCount: errors,
        ));
      }
    }

    if (batch.isNotEmpty) {
      try {
        final result = await _sendBatch(jobId, batch);
        inserted += result.inserted;
        skipped += result.skipped;
        processed += batch.length;
      } catch (e) {
        errors += batch.length;
      }
    }

    onProgress(ImportProgress(
      jobId: jobId,
      source: 'fitbit_json',
      status: 'completed',
      totalRecords: totalRecords,
      processedCount: processed,
      insertedCount: inserted,
      skippedCount: skipped,
      errorCount: errors,
    ));
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  static Future<({int inserted, int skipped})> _sendBatch(
    String jobId,
    List<Map<String, dynamic>> observations,
  ) async {
    final resp = await apiClient.dio.post(
      ApiConstants.importBatch,
      data: {
        'job_id': jobId,
        'observations': observations,
      },
      options: Options(receiveTimeout: const Duration(seconds: 30)),
    );
    return (
      inserted: (resp.data['inserted'] as int?) ?? 0,
      skipped: (resp.data['skipped'] as int?) ?? 0,
    );
  }

  /// Parse Apple Health date format: "2024-01-15 08:30:00 -0500"
  static DateTime? _parseAppleDate(String dateStr) {
    try {
      // Apple Health format: "2024-01-15 08:30:00 -0500"
      // Replace space before timezone offset with 'T' for ISO parsing
      final cleaned = dateStr.trim();
      // Try ISO 8601 first
      final dt = DateTime.tryParse(cleaned);
      if (dt != null) return dt;

      // Apple's format: "YYYY-MM-DD HH:MM:SS -HHMM"
      final match = RegExp(
        r'(\d{4}-\d{2}-\d{2})\s+(\d{2}:\d{2}:\d{2})\s+([+-]\d{4})',
      ).firstMatch(cleaned);
      if (match != null) {
        final date = match.group(1)!;
        final time = match.group(2)!;
        final tz = match.group(3)!;
        // Convert -0500 to -05:00
        final tzFormatted = '${tz.substring(0, 3)}:${tz.substring(3)}';
        return DateTime.parse('${date}T$time$tzFormatted');
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Find a column index from a list of possible column names.
  static int? _findColumn(List<String> header, List<String> names) {
    for (final name in names) {
      final idx = header.indexOf(name);
      if (idx >= 0) return idx;
    }
    // Partial match
    for (final name in names) {
      for (int i = 0; i < header.length; i++) {
        if (header[i].contains(name)) return i;
      }
    }
    return null;
  }
}
