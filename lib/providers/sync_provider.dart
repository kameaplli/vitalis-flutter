import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/sync_models.dart';
import '../services/health_sync_service.dart';

/// Connected accounts for the current user.
final connectedAccountsProvider =
    FutureProvider<List<ConnectedAccount>>((ref) async {
  final resp = await apiClient.dio.get(ApiConstants.syncAccounts);
  return (resp.data['accounts'] as List)
      .map((a) => ConnectedAccount.fromJson(a as Map<String, dynamic>))
      .toList();
});

/// Sync status for a specific person.
final syncStatusProvider =
    FutureProvider.family<SyncStatus, String>((ref, personId) async {
  final resp = await apiClient.dio.get(
    ApiConstants.syncStatus,
    queryParameters: {'person': personId},
  );
  return SyncStatus.fromJson(resp.data as Map<String, dynamic>);
});

/// Daily health summary from cache.
final dailyHealthSummaryProvider = FutureProvider.family<DailyHealthSummary,
    ({String person, String date})>((ref, args) async {
  final resp = await apiClient.dio.get(
    ApiConstants.syncDailySummary,
    queryParameters: {'person': args.person, 'date': args.date},
  );
  return DailyHealthSummary.fromJson(resp.data as Map<String, dynamic>);
});

/// Available health data types.
final healthDataTypesProvider =
    FutureProvider<List<HealthDataTypeInfo>>((ref) async {
  final resp = await apiClient.dio.get(ApiConstants.syncDataTypes);
  return (resp.data['types'] as List)
      .map((t) => HealthDataTypeInfo.fromJson(t as Map<String, dynamic>))
      .toList();
});

/// User's registered devices.
final userDevicesProvider =
    FutureProvider<List<UserDeviceInfo>>((ref) async {
  final resp = await apiClient.dio.get(ApiConstants.syncDevices);
  return (resp.data['devices'] as List)
      .map((d) => UserDeviceInfo.fromJson(d as Map<String, dynamic>))
      .toList();
});

/// Whether platform health permissions are granted.
final healthPermissionsProvider = FutureProvider<bool>((ref) async {
  return await HealthSyncService.hasPermissions();
});

/// Trigger a sync (returns result).
final syncTriggerProvider =
    FutureProvider.family<SyncResult, String>((ref, person) async {
  return await HealthSyncService.syncFromPlatform(person: person);
});

/// List of import jobs for the current user.
final importJobsProvider =
    FutureProvider<List<ImportProgress>>((ref) async {
  final resp = await apiClient.dio.get(ApiConstants.importJobs);
  return (resp.data['imports'] as List)
      .map((j) => ImportProgress.fromJson(j as Map<String, dynamic>))
      .toList();
});

/// Single import job status/progress.
final importJobProvider =
    FutureProvider.family<ImportProgress, String>((ref, jobId) async {
  final resp = await apiClient.dio.get(ApiConstants.importJob(jobId));
  return ImportProgress.fromJson(resp.data as Map<String, dynamic>);
});
