import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/food_item.dart';

final foodDatabaseProvider = FutureProvider<List<FoodCategory>>((ref) async {
  // 1. Fresh cache (24h TTL)
  final cached = await AppCache.loadFoodDb();
  if (cached != null) {
    return cached.map((c) => FoodCategory.fromJson(c)).toList();
  }

  // 2. Fetch from network
  try {
    final res = await apiClient.dio.get(ApiConstants.foodDatabase);
    final categories = res.data['categories'] as List<dynamic>;
    await AppCache.saveFoodDb(categories);
    return categories.map((c) => FoodCategory.fromJson(c)).toList();
  } catch (_) {
    // 3. Stale cache fallback
    final stale = await AppCache.loadFoodDb(stale: true);
    if (stale != null) return stale.map((c) => FoodCategory.fromJson(c)).toList();
    rethrow;
  }
});

/// Recent meal combinations for quick re-logging.
final recentMealsProvider = FutureProvider<List<RecentMeal>>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.frequentFoods);
  return (res.data['meals'] as List<dynamic>? ?? [])
      .map((m) => RecentMeal.fromJson(m))
      .toList();
});
