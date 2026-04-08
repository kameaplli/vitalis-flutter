import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/health_intelligence.dart';

/// Daily health score for a person.
/// Pass `'self'` for the primary user or a family member UUID.
final dailyHealthScoreProvider =
    FutureProvider.family<HealthScore, String>((ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthScoreDaily,
    queryParameters: params,
  );
  return HealthScore.fromJson(res.data as Map<String, dynamic>);
});

/// Weekly health score for a person.
final weeklyHealthScoreProvider =
    FutureProvider.family<HealthScore, String>((ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthScoreWeekly,
    queryParameters: params,
  );
  return HealthScore.fromJson(res.data as Map<String, dynamic>);
});

/// Score history (last 30 days) for a person.
final scoreHistoryProvider =
    FutureProvider.family<List<ScoreHistoryEntry>, String>(
        (ref, personId) async {
  final params = <String, dynamic>{'days': 30};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthScoreHistory,
    queryParameters: params,
  );
  final list = res.data as List<dynamic>;
  return list
      .whereType<Map<String, dynamic>>()
      .map(ScoreHistoryEntry.fromJson)
      .toList();
});

/// Active health alerts for a person.
final healthAlertsProvider =
    FutureProvider.family<List<HealthAlert>, String>((ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthAlerts,
    queryParameters: params,
  );
  final list = res.data as List<dynamic>;
  return list
      .whereType<Map<String, dynamic>>()
      .map(HealthAlert.fromJson)
      .toList();
});

/// Risk profile for a person.
final riskProfileProvider =
    FutureProvider.family<RiskProfile, String>((ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthRiskProfile,
    queryParameters: params,
  );
  return RiskProfile.fromJson(res.data as Map<String, dynamic>);
});

/// Clinical report for a person (default 30-day period).
final clinicalReportProvider =
    FutureProvider.family<ClinicalReport, String>((ref, personId) async {
  final params = <String, dynamic>{'period_days': 30};
  if (personId != 'self') params['family_member_id'] = personId;
  final res = await apiClient.dio.get(
    ApiConstants.healthClinicalReport,
    queryParameters: params,
  );
  return ClinicalReport.fromJson(res.data as Map<String, dynamic>);
});
