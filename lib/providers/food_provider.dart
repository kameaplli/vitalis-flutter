import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/food_item.dart';

final foodDatabaseProvider = FutureProvider<List<FoodCategory>>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.foodDatabase);
  final categories = res.data['categories'] as List<dynamic>;
  return categories.map((c) => FoodCategory.fromJson(c)).toList();
});

/// Recent meal combinations for quick re-logging.
final recentMealsProvider = FutureProvider<List<RecentMeal>>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.frequentFoods);
  return (res.data['meals'] as List<dynamic>? ?? [])
      .map((m) => RecentMeal.fromJson(m))
      .toList();
});
