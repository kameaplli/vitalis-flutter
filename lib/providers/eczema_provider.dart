import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/eczema_log.dart';

/// Key format: "person_days"  e.g. "self_30"
final eczemaProvider =
    FutureProvider.family<List<EczemaLogSummary>, String>((ref, key) async {
  ref.keepAlive(); // keep cached between tab switches
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.eczemaHistory,
      queryParameters: {'person': person, 'days': days});
  return (res.data['entries'] as List)
      .map((e) => EczemaLogSummary.fromJson(e))
      .toList();
});

/// Key format: "person_days"  e.g. "self_30"
final eczemaHeatmapProvider =
    FutureProvider.family<EczemaHeatmapData, String>((ref, key) async {
  ref.keepAlive();
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.eczemaHeatmap,
      queryParameters: {'person': person, 'days': days});
  return EczemaHeatmapData.fromJson(res.data as Map<String, dynamic>);
});

/// Key format: "person_days"
final eczemaFoodCorrelationProvider =
    FutureProvider.family<FoodCorrelationData, String>((ref, key) async {
  ref.keepAlive();
  final (person, days) = PK.personDays(key, 90);
  final res = await apiClient.dio.get(ApiConstants.eczemaFoodCorrelation,
      queryParameters: {'person': person, 'days': days});
  return FoodCorrelationData.fromJson(res.data as Map<String, dynamic>);
});

class FoodCorrelationData {
  final List<FoodCorrelation> badFoods;
  final List<FoodCorrelation> goodFoods;

  const FoodCorrelationData({required this.badFoods, required this.goodFoods});

  factory FoodCorrelationData.fromJson(Map<String, dynamic> json) {
    return FoodCorrelationData(
      badFoods: (json['bad_foods'] as List? ?? [])
          .map((e) => FoodCorrelation.fromJson(e as Map<String, dynamic>))
          .toList(),
      goodFoods: (json['good_foods'] as List? ?? [])
          .map((e) => FoodCorrelation.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class FoodCorrelation {
  final String foodName;
  final double avgItchWith;
  final double avgItchWithout;
  final double correlationScore;
  final int timesEaten;

  const FoodCorrelation({
    required this.foodName,
    required this.avgItchWith,
    required this.avgItchWithout,
    required this.correlationScore,
    required this.timesEaten,
  });

  factory FoodCorrelation.fromJson(Map<String, dynamic> json) {
    return FoodCorrelation(
      foodName: json['food_name'] as String? ?? '',
      avgItchWith: (json['avg_itch_with'] as num?)?.toDouble() ?? 0,
      avgItchWithout: (json['avg_itch_without'] as num?)?.toDouble() ?? 0,
      correlationScore: (json['correlation_score'] as num?)?.toDouble() ?? 0,
      timesEaten: (json['times_eaten'] as num?)?.toInt() ?? 0,
    );
  }
}

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
