import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/food_detail.dart';
import '../models/food_item.dart';

// ── Favorite Foods ──────────────────────────────────────────────────────────

final favoriteFoodsProvider = FutureProvider<List<FoodItem>>((ref) async {
  ref.keepAlive(); // keep favorites in memory
  final res = await apiClient.dio.get(ApiConstants.foodFavorites);
  return (res.data['favorites'] as List<dynamic>? ?? [])
      .map((f) => FoodItem.fromJson(f))
      .toList();
});

final favoriteIdsProvider = Provider<Set<String>>((ref) {
  final favs = ref.watch(favoriteFoodsProvider);
  return favs.maybeWhen(
    data: (list) => list.map((f) => f.id).toSet(),
    orElse: () => <String>{},
  );
});

// ── Recent & Frequent Individual Foods (for search pre-fill) ────────────────

class RecentFrequentFoods {
  final List<FoodItem> recent;
  final List<FoodItem> frequent;
  const RecentFrequentFoods({required this.recent, required this.frequent});
}

final recentFrequentProvider =
    FutureProvider.family<RecentFrequentFoods, String>((ref, person) async {
  ref.keepAlive(); // keep recent/frequent foods cached
  final res = await apiClient.dio.get(
    ApiConstants.recentFrequent,
    queryParameters: {'person': person, 'limit': 10},
  );
  return RecentFrequentFoods(
    recent: (res.data['recent'] as List<dynamic>? ?? [])
        .map((f) => FoodItem.fromJson(f))
        .toList(),
    frequent: (res.data['frequent'] as List<dynamic>? ?? [])
        .map((f) => FoodItem.fromJson(f))
        .toList(),
  );
});

// ── Yesterday's Meals (copy meal feature) ───────────────────────────────────

class YesterdayMeal {
  final String mealType;
  final double totalCalories;
  final List<Map<String, dynamic>> items;
  const YesterdayMeal({required this.mealType, required this.totalCalories, required this.items});
}

final yesterdayMealsProvider =
    FutureProvider.family<List<YesterdayMeal>, String>((ref, person) async {
  final res = await apiClient.dio.get(
    ApiConstants.yesterdayMeals,
    queryParameters: {'person': person},
  );
  return (res.data['meals'] as List<dynamic>? ?? []).map((m) {
    return YesterdayMeal(
      mealType: m['meal_type'] ?? 'snack',
      totalCalories: (m['total_calories'] as num?)?.toDouble() ?? 0,
      items: (m['items'] as List<dynamic>? ?? [])
          .map((i) => Map<String, dynamic>.from(i as Map))
          .toList(),
    );
  }).toList();
});

final foodDatabaseProvider = FutureProvider<List<FoodCategory>>((ref) async {
  ref.keepAlive(); // food DB is large — keep in memory after first load
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
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.frequentFoods);
  return (res.data['meals'] as List<dynamic>? ?? [])
      .map((m) => RecentMeal.fromJson(m))
      .toList();
});

// ── Food Detail (info card) ──────────────────────────────────────────────

final foodDetailProvider =
    FutureProvider.family<FoodDetail, String>((ref, foodId) async {
  // 1. Fresh local cache (7-day TTL) — instant display
  final cached = await AppCache.loadFoodDetail(foodId);
  if (cached != null) {
    return FoodDetail.fromJson(cached);
  }

  // 2. Fetch from network
  try {
    final res = await apiClient.dio.get(ApiConstants.foodDetail(foodId));
    final data = res.data as Map<String, dynamic>;
    await AppCache.saveFoodDetail(foodId, data);
    return FoodDetail.fromJson(data);
  } catch (_) {
    // 3. Stale cache fallback
    final stale = await AppCache.loadFoodDetail(foodId, stale: true);
    if (stale != null) return FoodDetail.fromJson(stale);
    rethrow;
  }
});

/// Per-meal-type suggestions (breakfast, lunch, dinner, snack).
/// Returns {meal_type: [RecentMeal]} for smart suggestions.
final mealSuggestionsProvider =
    FutureProvider<Map<String, List<RecentMeal>>>((ref) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.frequentFoods);
  final suggestions = res.data['suggestions'] as Map<String, dynamic>? ?? {};
  final result = <String, List<RecentMeal>>{};
  for (final entry in suggestions.entries) {
    result[entry.key] = (entry.value as List<dynamic>)
        .map((m) => RecentMeal.fromJson(m))
        .toList();
  }
  return result;
});
