import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/weight_log.dart';

// key = "person_days" e.g. "self_30" or "child_123_30"
final weightHistoryProvider = FutureProvider.family<WeightHistory, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
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
