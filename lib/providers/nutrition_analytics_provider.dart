import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/nutrition_analytics.dart';

// key = "person_days"  e.g. "self_30"
final nutritionAnalyticsProvider =
    FutureProvider.family<NutritionAnalyticsData, String>((ref, key) async {
  final (person, daysInt) = PK.personDays(key);
  final days = daysInt.toString();

  // 1. Fresh cache hit (uses analytics cache with 30-min TTL)
  final cached = await AppCache.loadAnalytics('nb_$key');
  if (cached != null) {
    return NutritionAnalyticsData.fromJson(cached);
  }

  // 2. Fetch from network
  try {
    final res = await apiClient.dio.get(
      ApiConstants.nutritionBreakdown,
      queryParameters: {'person': person, 'days': int.parse(days)},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    await AppCache.saveAnalytics('nb_$key', data);
    return NutritionAnalyticsData.fromJson(data);
  } catch (_) {
    // 3. Network failed — try stale cache
    final stale = await AppCache.loadAnalytics('nb_$key', stale: true);
    if (stale != null) return NutritionAnalyticsData.fromJson(stale);
    rethrow;
  }
});
