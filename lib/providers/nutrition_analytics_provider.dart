import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/nutrition_analytics.dart';

// key = "person:days"  e.g. "self:30"
final nutritionAnalyticsProvider =
    FutureProvider.family<NutritionAnalyticsData, String>((ref, key) async {
  final parts = key.split(':');
  final person = parts[0];
  final days = parts.length > 1 ? parts[1] : '30';
  final res = await apiClient.dio.get(
    ApiConstants.nutritionBreakdown,
    queryParameters: {'person': person, 'days': int.parse(days)},
  );
  return NutritionAnalyticsData.fromJson(res.data as Map<String, dynamic>);
});
