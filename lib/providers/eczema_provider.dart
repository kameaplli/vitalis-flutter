import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/eczema_log.dart';

/// Key format: "person:days"  e.g. "self:30"
final eczemaProvider =
    FutureProvider.family<List<EczemaLogSummary>, String>((ref, key) async {
  final parts = key.split(':');
  final person = parts[0].isNotEmpty ? parts[0] : 'self';
  final days = int.tryParse(parts.elementAtOrNull(1) ?? '30') ?? 30;
  final res = await apiClient.dio.get(ApiConstants.eczemaHistory,
      queryParameters: {'person': person, 'days': days});
  return (res.data['entries'] as List)
      .map((e) => EczemaLogSummary.fromJson(e))
      .toList();
});

/// Key format: "person:days"  e.g. "self:30"
final eczemaHeatmapProvider =
    FutureProvider.family<EczemaHeatmapData, String>((ref, key) async {
  final parts = key.split(':');
  final person = parts[0].isNotEmpty ? parts[0] : 'self';
  final days = int.tryParse(parts.elementAtOrNull(1) ?? '30') ?? 30;
  final res = await apiClient.dio.get(ApiConstants.eczemaHeatmap,
      queryParameters: {'person': person, 'days': days});
  return EczemaHeatmapData.fromJson(res.data as Map<String, dynamic>);
});

class EczemaHeatmapData {
  final Map<String, double> regionIntensity; // zoneId → 0.0-1.0
  final List<({DateTime date, double easi})> easiTrend;
  final List<({String regionId, String label, double frequency, double avgEasi})> topRegions;

  const EczemaHeatmapData({
    required this.regionIntensity,
    required this.easiTrend,
    required this.topRegions,
  });

  factory EczemaHeatmapData.fromJson(Map<String, dynamic> json) {
    final ri = <String, double>{};
    final rawRi = json['region_intensity'] as Map<String, dynamic>? ?? {};
    rawRi.forEach((k, v) => ri[k] = (v as num).toDouble());

    final trend = <({DateTime date, double easi})>[];
    for (final entry in (json['easi_trend'] as List? ?? [])) {
      final m = entry as Map<String, dynamic>;
      final d = DateTime.tryParse(m['date'] as String? ?? '');
      if (d != null) {
        trend.add((date: d, easi: (m['easi_score'] as num).toDouble()));
      }
    }

    final top = <({String regionId, String label, double frequency, double avgEasi})>[];
    for (final entry in (json['top_regions'] as List? ?? [])) {
      final m = entry as Map<String, dynamic>;
      top.add((
        regionId: m['region_id'] as String? ?? '',
        label: m['label'] as String? ?? m['region_id'] as String? ?? '',
        frequency: (m['frequency'] as num).toDouble(),
        avgEasi: (m['avg_easi'] as num).toDouble(),
      ));
    }

    return EczemaHeatmapData(
      regionIntensity: ri,
      easiTrend: trend,
      topRegions: top,
    );
  }
}
