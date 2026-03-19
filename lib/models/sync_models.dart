class ConnectedAccount {
  final String id;
  final String sourceId;
  final String displayName;
  final String sourceType; // on_device, cloud_api
  final String status; // active, expired, error, pending
  final String? iconName;
  final String? lastSync;
  final String? errorMessage;
  final String? personId;
  final List<String> dataTypes;

  ConnectedAccount({
    required this.id,
    required this.sourceId,
    required this.displayName,
    required this.sourceType,
    required this.status,
    this.iconName,
    this.lastSync,
    this.errorMessage,
    this.personId,
    this.dataTypes = const [],
  });

  factory ConnectedAccount.fromJson(Map<String, dynamic> json) =>
      ConnectedAccount(
        id: json['id'] as String? ?? '',
        sourceId: json['source_id'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        sourceType: json['source_type'] as String? ?? 'on_device',
        status: json['status'] as String? ?? 'pending',
        iconName: json['icon_name'] as String?,
        lastSync: json['last_sync'] as String?,
        errorMessage: json['error_message'] as String?,
        personId: json['person_id'] as String?,
        dataTypes: (json['data_types'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class SyncStatus {
  final String? lastSync;
  final int totalObservations;
  final Map<String, int> dataTypeCounts;
  final List<ConnectedAccount> accounts;

  SyncStatus({
    this.lastSync,
    required this.totalObservations,
    required this.dataTypeCounts,
    required this.accounts,
  });

  factory SyncStatus.fromJson(Map<String, dynamic> json) => SyncStatus(
        lastSync: json['last_sync'] as String?,
        totalObservations: (json['total_observations'] as int?) ?? 0,
        dataTypeCounts: (json['data_type_counts'] as Map<String, dynamic>?)
                ?.map((k, v) => MapEntry(k, (v as num).toInt())) ??
            {},
        accounts: (json['accounts'] as List<dynamic>?)
                ?.map((a) =>
                    ConnectedAccount.fromJson(a as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class DailyHealthSummary {
  final String date;
  final Map<String, HealthMetric> metrics;

  DailyHealthSummary({
    required this.date,
    required this.metrics,
  });

  factory DailyHealthSummary.fromJson(Map<String, dynamic> json) =>
      DailyHealthSummary(
        date: json['date'] as String? ?? '',
        metrics: (json['metrics'] as Map<String, dynamic>?)?.map(
              (k, v) =>
                  MapEntry(k, HealthMetric.fromJson(v as Map<String, dynamic>)),
            ) ??
            {},
      );
}

class HealthMetric {
  final String dataType;
  final String displayName;
  final String? unit;
  final double? valueSum;
  final double? valueAvg;
  final double? valueMin;
  final double? valueMax;
  final double? valueLatest;
  final int? valueCount;
  final List<String> sources;

  HealthMetric({
    required this.dataType,
    required this.displayName,
    this.unit,
    this.valueSum,
    this.valueAvg,
    this.valueMin,
    this.valueMax,
    this.valueLatest,
    this.valueCount,
    this.sources = const [],
  });

  factory HealthMetric.fromJson(Map<String, dynamic> json) => HealthMetric(
        dataType: json['data_type'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        unit: json['unit'] as String?,
        valueSum: (json['value_sum'] as num?)?.toDouble(),
        valueAvg: (json['value_avg'] as num?)?.toDouble(),
        valueMin: (json['value_min'] as num?)?.toDouble(),
        valueMax: (json['value_max'] as num?)?.toDouble(),
        valueLatest: (json['value_latest'] as num?)?.toDouble(),
        valueCount: (json['value_count'] as num?)?.toInt(),
        sources: (json['sources'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );
}

class SyncResult {
  final int inserted;
  final int skipped;
  final int replaced;

  SyncResult({
    required this.inserted,
    required this.skipped,
    required this.replaced,
  });

  factory SyncResult.fromJson(Map<String, dynamic> json) => SyncResult(
        inserted: (json['inserted'] as int?) ?? 0,
        skipped: (json['skipped'] as int?) ?? 0,
        replaced: (json['replaced'] as int?) ?? 0,
      );
}

class HealthDataTypeInfo {
  final String code;
  final String displayName;
  final String category;
  final String? unit;
  final String valueType;
  final String aggregation;

  HealthDataTypeInfo({
    required this.code,
    required this.displayName,
    required this.category,
    this.unit,
    required this.valueType,
    required this.aggregation,
  });

  factory HealthDataTypeInfo.fromJson(Map<String, dynamic> json) =>
      HealthDataTypeInfo(
        code: json['code'] as String? ?? '',
        displayName: json['display_name'] as String? ?? '',
        category: json['category'] as String? ?? '',
        unit: json['unit'] as String?,
        valueType: json['value_type'] as String? ?? 'numeric',
        aggregation: json['aggregation'] as String? ?? 'sum',
      );
}

class ImportProgress {
  final String jobId;
  final String source;
  final String status; // pending, running, completed, failed, cancelled, rolled_back
  final int totalRecords;
  final int processedCount;
  final int insertedCount;
  final int skippedCount;
  final int errorCount;
  final String? lastError;
  final String? batchId;
  final String? startedAt;
  final String? completedAt;
  final String? createdAt;
  final List<String>? dataTypes;

  ImportProgress({
    required this.jobId,
    required this.source,
    required this.status,
    this.totalRecords = 0,
    this.processedCount = 0,
    this.insertedCount = 0,
    this.skippedCount = 0,
    this.errorCount = 0,
    this.lastError,
    this.batchId,
    this.startedAt,
    this.completedAt,
    this.createdAt,
    this.dataTypes,
  });

  factory ImportProgress.fromJson(Map<String, dynamic> json) => ImportProgress(
        jobId: json['id'] as String? ?? '',
        source: json['source'] as String? ?? '',
        status: json['status'] as String? ?? 'pending',
        totalRecords: (json['total_records'] as int?) ?? 0,
        processedCount: (json['processed_count'] as int?) ?? 0,
        insertedCount: (json['inserted_count'] as int?) ?? 0,
        skippedCount: (json['skipped_count'] as int?) ?? 0,
        errorCount: (json['error_count'] as int?) ?? 0,
        lastError: json['last_error'] as String?,
        batchId: json['batch_id'] as String?,
        startedAt: json['started_at'] as String?,
        completedAt: json['completed_at'] as String?,
        createdAt: json['created_at'] as String?,
        dataTypes: (json['data_types'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList(),
      );

  double get progressPercent =>
      totalRecords > 0 ? processedCount / totalRecords : 0;

  bool get isActive => status == 'pending' || status == 'running';
  bool get isCompleted => status == 'completed';
  bool get isFailed => status == 'failed';
  bool get isCancelled => status == 'cancelled';
  bool get isRolledBack => status == 'rolled_back';
}

class UserDeviceInfo {
  final String id;
  final String sourceId;
  final String? deviceName;
  final String? deviceModel;
  final String? manufacturer;
  final bool isPrimary;
  final String? lastSeenAt;

  UserDeviceInfo({
    required this.id,
    required this.sourceId,
    this.deviceName,
    this.deviceModel,
    this.manufacturer,
    required this.isPrimary,
    this.lastSeenAt,
  });

  factory UserDeviceInfo.fromJson(Map<String, dynamic> json) => UserDeviceInfo(
        id: json['id'] as String? ?? '',
        sourceId: json['source_id'] as String? ?? '',
        deviceName: json['device_name'] as String?,
        deviceModel: json['device_model'] as String?,
        manufacturer: json['manufacturer'] as String?,
        isPrimary: json['is_primary'] as bool? ?? false,
        lastSeenAt: json['last_seen_at'] as String?,
      );
}
