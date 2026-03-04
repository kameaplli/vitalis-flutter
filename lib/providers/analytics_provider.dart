import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/analytics_data.dart';

// key = "person:days" e.g. "self:7"
final analyticsProvider = FutureProvider.family<NutritionAnalytics, String>((ref, key) async {
  final parts = key.split(':');
  final person = parts[0];
  final days = int.tryParse(parts.elementAtOrNull(1) ?? '7') ?? 7;
  final res = await apiClient.dio.get(ApiConstants.analyticsNutrition,
      queryParameters: {'person': person, 'days': days});
  return NutritionAnalytics.fromJson(res.data);
});
