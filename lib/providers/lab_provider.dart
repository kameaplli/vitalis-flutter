/// Blood Test Intelligence — Riverpod providers for lab data.
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/lab_result.dart';

// ── Dashboard Provider ──────────────────────────────────────────────────────

final labDashboardProvider =
    FutureProvider.family<LabDashboard, String>((ref, personId) async {
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
  final res = await apiClient.dio.get(ApiConstants.labReport(reportId));
  return LabReport.fromJson(res.data as Map<String, dynamic>);
});

// ── Biomarker History Provider ──────────────────────────────────────────────

typedef BiomarkerHistoryKey = ({String code, String person});

final biomarkerHistoryProvider =
    FutureProvider.family<BiomarkerHistory, BiomarkerHistoryKey>(
        (ref, key) async {
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
  final res = await apiClient.dio.get(ApiConstants.labBiomarkers);
  return (res.data['biomarkers'] as List<dynamic>? ?? [])
      .map((b) => BiomarkerDefinition.fromJson(b as Map<String, dynamic>))
      .toList();
});

// ── Reprocess ──────────────────────────────────────────────────────────────

Future<Map<String, dynamic>> reprocessLabResults() async {
  final res = await apiClient.dio.post(ApiConstants.labReprocess);
  return res.data as Map<String, dynamic>;
}
