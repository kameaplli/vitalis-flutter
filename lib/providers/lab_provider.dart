/// Blood Test Intelligence — Riverpod providers for lab data.
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/lab_result.dart';
import 'selected_person_provider.dart';

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

// ── Upload State ────────────────────────────────────────────────────────────

enum LabUploadStatus { idle, uploading, parsed, confirming, done, error }

class LabUploadState {
  final LabUploadStatus status;
  final List<ParsedLabResult> parsedResults;
  final String? labProvider;
  final String? parseMethod;
  final double? confidence;
  final List<String> errors;
  final String? filename;
  final String? errorMessage;

  const LabUploadState({
    this.status = LabUploadStatus.idle,
    this.parsedResults = const [],
    this.labProvider,
    this.parseMethod,
    this.confidence,
    this.errors = const [],
    this.filename,
    this.errorMessage,
  });

  LabUploadState copyWith({
    LabUploadStatus? status,
    List<ParsedLabResult>? parsedResults,
    String? labProvider,
    String? parseMethod,
    double? confidence,
    List<String>? errors,
    String? filename,
    String? errorMessage,
  }) =>
      LabUploadState(
        status: status ?? this.status,
        parsedResults: parsedResults ?? this.parsedResults,
        labProvider: labProvider ?? this.labProvider,
        parseMethod: parseMethod ?? this.parseMethod,
        confidence: confidence ?? this.confidence,
        errors: errors ?? this.errors,
        filename: filename ?? this.filename,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class LabUploadNotifier extends StateNotifier<LabUploadState> {
  final Ref _ref;

  LabUploadNotifier(this._ref) : super(const LabUploadState());

  Future<void> uploadFile(File file) async {
    state = state.copyWith(status: LabUploadStatus.uploading);
    try {
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path,
            filename: file.path.split('/').last),
      });

      final res = await apiClient.dio.post(
        ApiConstants.labUpload,
        data: formData,
      );

      final data = res.data as Map<String, dynamic>;
      final parsed = (data['parsed_results'] as List<dynamic>? ?? [])
          .map((r) => ParsedLabResult.fromJson(r as Map<String, dynamic>))
          .toList();

      state = state.copyWith(
        status: LabUploadStatus.parsed,
        parsedResults: parsed,
        labProvider: data['lab_provider'],
        parseMethod: data['parse_method'],
        confidence: (data['confidence'] as num?)?.toDouble(),
        errors:
            (data['errors'] as List<dynamic>?)?.cast<String>() ?? [],
        filename: data['filename'],
      );
    } catch (e) {
      state = state.copyWith(
        status: LabUploadStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  Future<bool> confirmResults({
    String? testDate,
    String? familyMemberId,
    String? notes,
  }) async {
    state = state.copyWith(status: LabUploadStatus.confirming);
    try {
      await apiClient.dio.post(
        ApiConstants.labConfirm,
        data: {
          'test_date': testDate ?? DateTime.now().toIso8601String().substring(0, 10),
          'family_member_id': familyMemberId,
          'lab_provider': state.labProvider,
          'report_source': 'upload_pdf',
          'parse_method': state.parseMethod,
          'confidence': state.confidence,
          'filename': state.filename,
          'notes': notes,
          'results': state.parsedResults.map((r) => r.toJson()).toList(),
        },
      );

      state = state.copyWith(status: LabUploadStatus.done);

      // Invalidate dashboard & reports
      final person = _ref.read(selectedPersonProvider);
      _ref.invalidate(labDashboardProvider(person));
      _ref.invalidate(labReportsProvider(person));

      return true;
    } catch (e) {
      state = state.copyWith(
        status: LabUploadStatus.error,
        errorMessage: e.toString(),
      );
      return false;
    }
  }

  void updateResult(int index, ParsedLabResult updated) {
    final results = [...state.parsedResults];
    results[index] = updated;
    state = state.copyWith(parsedResults: results);
  }

  void removeResult(int index) {
    final results = [...state.parsedResults];
    results.removeAt(index);
    state = state.copyWith(parsedResults: results);
  }

  void reset() {
    state = const LabUploadState();
  }
}

final labUploadProvider =
    StateNotifierProvider<LabUploadNotifier, LabUploadState>(
        (ref) => LabUploadNotifier(ref));
