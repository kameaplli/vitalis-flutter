import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/weight_log.dart';

// key = "person:days" e.g. "self:30"
final weightHistoryProvider = FutureProvider.family<List<WeightLog>, String>((ref, key) async {
  final parts = key.split(':');
  final person = parts[0].isNotEmpty ? parts[0] : 'self';
  final days = int.tryParse(parts.elementAtOrNull(1) ?? '30') ?? 30;
  final res = await apiClient.dio.get(
    ApiConstants.weightHistory,
    queryParameters: {'person': person, 'days': days},
  );
  return (res.data['entries'] as List<dynamic>)
      .map((e) => WeightLog.fromJson(e))
      .toList();
});
