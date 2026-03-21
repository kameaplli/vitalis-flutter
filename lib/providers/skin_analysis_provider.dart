import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/skin_analysis_data.dart';

/// Analyze a skin photo by ID. Returns the analysis result.
final skinAnalyzeProvider =
    FutureProvider.family<SkinAnalysis, ({String photoId, String? compareToId})>(
  (ref, args) async {
    final resp = await apiClient.dio.post(ApiConstants.skinAnalyze, data: {
      'photo_id': args.photoId,
      if (args.compareToId != null) 'compare_to_id': args.compareToId,
    });
    return SkinAnalysis.fromJson(resp.data as Map<String, dynamic>);
  },
);

/// Get analysis history for a specific photo.
final skinPhotoAnalysisProvider =
    FutureProvider.family<SkinAnalysis?, String>((ref, photoId) async {
  final resp = await apiClient.dio.get(
    ApiConstants.skinAnalyses,
    queryParameters: {'photo_id': photoId},
  );
  final list = resp.data as List;
  if (list.isEmpty) return null;
  return SkinAnalysis.fromJson(list.first as Map<String, dynamic>);
});

/// Get severity trend.
final skinTrendProvider =
    FutureProvider.family<SkinTrend, String>((ref, person) async {
  final famId = person == 'self' ? null : person;
  final resp = await apiClient.dio.get(
    ApiConstants.skinTrend,
    queryParameters: {
      'days': 90,
      if (famId != null) 'family_member_id': famId,
    },
  );
  return SkinTrend.fromJson(resp.data as Map<String, dynamic>);
});
