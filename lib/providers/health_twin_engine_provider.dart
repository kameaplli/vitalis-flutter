import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/health_twin_engine_data.dart';

// ── Cross-Domain Correlations ───────────────────────────────────────────────

final crossDomainCorrelationsProvider =
    FutureProvider.family<CrossDomainCorrelations?, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{'days': 30};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.crossDomainCorrelations,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return CrossDomainCorrelations.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Health Level ────────────────────────────────────────────────────────────

final healthLevelProvider =
    FutureProvider.family<HealthLevel?, String>((ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthLevel,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return HealthLevel.fromJson(resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Streaks ─────────────────────────────────────────────────────────────────

final healthStreaksProvider =
    FutureProvider.family<HealthStreaks?, String>((ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthStreaks,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return HealthStreaks.fromJson(resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Achievements ────────────────────────────────────────────────────────────

final healthAchievementsProvider =
    FutureProvider.family<AchievementsData?, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthAchievements,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return AchievementsData.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Engagement Summary ──────────────────────────────────────────────────────

final engagementSummaryProvider =
    FutureProvider.family<EngagementSummary?, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.engagementSummary,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return EngagementSummary.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Predictions ─────────────────────────────────────────────────────────────

final healthPredictionsProvider =
    FutureProvider.family<PredictionsData?, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.healthPredictions,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return PredictionsData.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── What-If Scenarios ───────────────────────────────────────────────────────

final whatIfScenariosProvider =
    FutureProvider.family<List<WhatIfScenario>, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.whatIfScenarios,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    final scenarios = resp.data['scenarios'] as List<dynamic>? ?? [];
    return scenarios
        .whereType<Map<String, dynamic>>()
        .map(WhatIfScenario.fromJson)
        .toList();
  }
  return [];
});

// ── Lab Feedback ────────────────────────────────────────────────────────────

final labFeedbackProvider =
    FutureProvider.family<LabFeedbackData?, String>(
        (ref, personId) async {
  ref.keepAlive();
  final params = <String, dynamic>{};
  if (personId != 'self') params['family_member_id'] = personId;
  final resp = await apiClient.dio.get(
    ApiConstants.labFeedback,
    queryParameters: params,
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return LabFeedbackData.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});

// ── Family Overview ─────────────────────────────────────────────────────────

final familyOverviewProvider =
    FutureProvider<FamilyOverviewData?>((ref) async {
  ref.keepAlive();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final resp = await apiClient.dio.get(
    ApiConstants.familyOverview,
    queryParameters: {'date': today},
  );
  if (resp.statusCode == 200 && resp.data != null) {
    return FamilyOverviewData.fromJson(
        resp.data as Map<String, dynamic>);
  }
  return null;
});
