import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/analytics_data.dart';

// key = "person_days" e.g. "self_7"
final analyticsProvider =
    FutureProvider.family<NutritionAnalytics, String>((ref, key) async {
  final (person, days) = PK.personDays(key, 7);

  // 1. Fresh cache hit
  final cached = await AppCache.loadAnalytics(key);
  if (cached != null) {
    return NutritionAnalytics.fromJson(cached);
  }

  // 2. Fetch from network
  try {
    final res = await apiClient.dio.get(
      ApiConstants.analyticsNutrition,
      queryParameters: {'person': person, 'days': days},
    );
    await AppCache.saveAnalytics(key, Map<String, dynamic>.from(res.data as Map));
    return NutritionAnalytics.fromJson(res.data);
  } catch (_) {
    // 3. Network failed — try stale cache
    final stale = await AppCache.loadAnalytics(key, stale: true);
    if (stale != null) return NutritionAnalytics.fromJson(stale);
    rethrow;
  }
});
