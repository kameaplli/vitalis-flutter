// Blood Test Intelligence — Riverpod providers for lab data.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/lab_result.dart';

// ── Dashboard Provider ──────────────────────────────────────────────────────

final labDashboardProvider =
    FutureProvider.family<LabDashboard, String>((ref, personId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.labDashboard,
    queryParameters: {
      if (personId != 'self') 'person': personId,
    },
  );
  return LabDashboard.fromJson(res.data as Map<String, dynamic>);
});

// ── Reports List Provider ───────────────────────────────────────────────────

final labReportsProvider =
    FutureProvider.family<List<LabReport>, String>((ref, personId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.labReports,
    queryParameters: {
      if (personId != 'self') 'person': personId,
    },
  );
  final reports = (res.data['reports'] as List<dynamic>? ?? [])
      .map((r) => LabReport.fromJson(r as Map<String, dynamic>))
      .toList();
  return reports;
});

// ── Single Report Provider ──────────────────────────────────────────────────

final labReportDetailProvider =
    FutureProvider.family<LabReport, String>((ref, reportId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.labReport(reportId));
  return LabReport.fromJson(res.data as Map<String, dynamic>);
});

// ── Biomarker History Provider ──────────────────────────────────────────────

typedef BiomarkerHistoryKey = ({String code, String person});

final biomarkerHistoryProvider =
    FutureProvider.family<BiomarkerHistory, BiomarkerHistoryKey>(
        (ref, key) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.biomarkerHistory(key.code),
    queryParameters: {
      if (key.person != 'self') 'person': key.person,
    },
  );
  return BiomarkerHistory.fromJson(res.data as Map<String, dynamic>);
});

// ── Biomarker Catalog Provider ──────────────────────────────────────────────

final biomarkerCatalogProvider =
    FutureProvider<List<BiomarkerDefinition>>((ref) async {
  ref.keepAlive(); // static catalog — keep in memory
  final res = await apiClient.dio.get(ApiConstants.labBiomarkers);
  return (res.data['biomarkers'] as List<dynamic>? ?? [])
      .map((b) => BiomarkerDefinition.fromJson(b as Map<String, dynamic>))
      .toList();
});

// ── Insights Provider ───────────────────────────────────────────────────────

final labInsightsProvider =
    FutureProvider.family<List<BiomarkerInsightModel>, String>(
        (ref, personId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.labInsights,
    queryParameters: {
      if (personId != 'self') 'person': personId,
    },
  );
  return (res.data['insights'] as List<dynamic>? ?? [])
      .map((i) => BiomarkerInsightModel.fromJson(i as Map<String, dynamic>))
      .toList();
});

// ── Health Score Provider ───────────────────────────────────────────────────

typedef HealthScoreData = ({HealthScoreSummary? latest, List<HealthScoreSummary> history});

final labScoreProvider =
    FutureProvider.family<HealthScoreData, String>((ref, personId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.labScore,
    queryParameters: {
      if (personId != 'self') 'person': personId,
    },
  );
  final data = res.data as Map<String, dynamic>;
  return (
    latest: data['latest'] != null
        ? HealthScoreSummary.fromJson(data['latest'] as Map<String, dynamic>)
        : null,
    history: (data['history'] as List<dynamic>? ?? [])
        .map((s) => HealthScoreSummary.fromJson(s as Map<String, dynamic>))
        .toList(),
  );
});

// ── Recommendations Provider ────────────────────────────────────────────────

final labRecommendationsProvider =
    FutureProvider.family<List<BiomarkerRecommendation>, String>(
        (ref, personId) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.labRecommendations,
    queryParameters: {
      if (personId != 'self') 'person': personId,
    },
  );
  return (res.data['recommendations'] as List<dynamic>? ?? [])
      .map((r) => BiomarkerRecommendation.fromJson(r as Map<String, dynamic>))
      .toList();
});

// ── Actions ─────────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> reprocessLabResults() async {
  final res = await apiClient.dio.post(ApiConstants.labReprocess);
  return res.data as Map<String, dynamic>;
}

Future<void> dismissInsight(String insightId) async {
  await apiClient.dio.post(ApiConstants.labInsightDismiss(insightId));
}
