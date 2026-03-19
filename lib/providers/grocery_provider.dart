import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/grocery_models.dart';

// Receipt list — keyed by person ID ('self' or family member UUID)
final groceryReceiptsProvider =
    FutureProvider.family<List<GroceryReceipt>, String>((ref, person) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.groceryReceipts);
  final data = res.data as Map<String, dynamic>;
  return (data['receipts'] as List)
      .map((e) => GroceryReceipt.fromJson(e as Map<String, dynamic>))
      .toList();
});

// Single receipt detail — used for polling after upload
final groceryReceiptDetailProvider =
    FutureProvider.family<GroceryReceipt, String>((ref, id) async {
  final res = await apiClient.dio.get('${ApiConstants.groceryReceipts}/$id');
  return GroceryReceipt.fromJson(res.data as Map<String, dynamic>);
});

// Spending analytics — keyed by "person_period"
final grocerySpendingProvider =
    FutureProvider.family<GrocerySpending, String>((ref, key) async {
  ref.keepAlive();
  final (_, period) = PK.firstSecond(key);
  final res = await apiClient.dio.get(
    ApiConstants.grocerySpending,
    queryParameters: {'period': period},
  );
  return GrocerySpending.fromJson(res.data as Map<String, dynamic>);
});

// Nutrition spectrum — keyed by "person_period"
final groceryNutritionProvider =
    FutureProvider.family<GroceryNutritionSpectrum, String>((ref, key) async {
  ref.keepAlive();
  final (_, period) = PK.firstSecond(key);
  final res = await apiClient.dio.get(
    ApiConstants.groceryNutrition,
    queryParameters: {'period': period},
  );
  return GroceryNutritionSpectrum.fromJson(res.data as Map<String, dynamic>);
});

// Category drill-down — keyed by "category_period"
final groceryCategoryItemsProvider =
    FutureProvider.family<GroceryCategoryItems, String>((ref, key) async {
  final (category, period) = PK.firstSecond(key);
  final res = await apiClient.dio.get(
    ApiConstants.groceryCategoryItems,
    queryParameters: {'category': category, 'period': period},
  );
  return GroceryCategoryItems.fromJson(res.data as Map<String, dynamic>);
});
