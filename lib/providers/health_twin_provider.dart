import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/health_twin_data.dart';

/// Daily Digital Twin snapshot for a person.
final dailyTwinProvider =
    FutureProvider.family<DailyTwin?, String>((ref, personId) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final params = <String, dynamic>{'date': today};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.twinDaily,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return DailyTwin.fromJson(resp.data as Map<String, dynamic>);
  }
  return null;
});

/// 30-day trend data for sparkline charts.
final twinTrendProvider =
    FutureProvider.family<List<TwinTrendEntry>, String>((ref, personId) async {
  final params = <String, dynamic>{'days': 30};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.twinTrend,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data is List) {
    return (resp.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(TwinTrendEntry.fromJson)
        .toList();
  }
  return [];
});

/// Active health goals for a person.
final userGoalsProvider =
    FutureProvider.family<List<UserGoal>, String>((ref, personId) async {
  final params = <String, dynamic>{'active_only': true};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthGoals,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data is List) {
    return (resp.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(UserGoal.fromJson)
        .toList();
  }
  return [];
});

/// Goal-specific insights for a person.
final goalInsightsProvider =
    FutureProvider.family<List<GoalInsightsResponse>, String>(
        (ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthGoalInsights,
    queryParameters: params,
  );
  if (resp.statusCode == 200 &&
      resp.data != null &&
      resp.data['goals'] is List) {
    return (resp.data['goals'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(GoalInsightsResponse.fromJson)
        .toList();
  }
  return [];
});

/// Latest weekly summary for a person.
final weeklySummaryProvider =
    FutureProvider.family<WeeklySummaryData?, String>((ref, personId) async {
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.weeklySummary,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return WeeklySummaryData.fromJson(resp.data as Map<String, dynamic>);
  }
  return null;
});

/// Weekly summary history (last 8 weeks).
final weeklySummaryHistoryProvider =
    FutureProvider.family<List<WeeklySummaryData>, String>(
        (ref, personId) async {
  final params = <String, dynamic>{'weeks': 8};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.weeklySummaryHistory,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data is List) {
    return (resp.data as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(WeeklySummaryData.fromJson)
        .toList();
  }
  return [];
});
