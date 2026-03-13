import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/weight_log.dart';

// key = "person_days" e.g. "self_30"
final weightHistoryProvider = FutureProvider.family<WeightHistory, String>((ref, key) async {
  final parts = key.split('_');
  final person = parts[0].isNotEmpty ? parts[0] : 'self';
  final days = int.tryParse(parts.elementAtOrNull(1) ?? '30') ?? 30;
  final res = await apiClient.dio.get(
    ApiConstants.weightHistory,
    queryParameters: {'person': person, 'days': days},
  );
  final data = res.data as Map<String, dynamic>;
  return WeightHistory(
    entries: (data['entries'] as List<dynamic>)
        .map((e) => WeightLog.fromJson(e))
        .toList(),
    idealWeight: (data['ideal_weight'] as num?)?.toDouble(),
    idealMin:    (data['ideal_min'] as num?)?.toDouble(),
    idealMax:    (data['ideal_max'] as num?)?.toDouble(),
  );
});
