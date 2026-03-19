import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/hydration_log.dart';

/// Key: 'person_days_date' (date is client's local YYYY-MM-DD, optional)
final hydrationHistoryProvider =
    FutureProvider.family<List<HydrationLog>, String>((ref, key) async {
  ref.keepAlive(); // keep cached between navigations
  final (person, days, date) = PK.personDaysDate(key);
  final res = await apiClient.dio.get(
    ApiConstants.hydrationHistory,
    queryParameters: {
      'person': person,
      'days': days,
      'date': date,
    },
  );
  return (res.data['entries'] as List<dynamic>)
      .map((e) => HydrationLog.fromJson(e))
      .toList();
});

/// Today's total for a specific person ('self' or family_member_id).
final todayHydrationProvider =
    FutureProvider.family<double, String>((ref, person) async {
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final logs = await ref.watch(hydrationHistoryProvider('${person}_1_$today').future);
  double total = 0.0;
  for (final l in logs.where((l) => l.date == today)) {
    total += l.quantity;
  }
  return total;
});

/// Personalized daily hydration goal in ml, keyed by personId.
final hydrationGoalProvider =
    FutureProvider.family<double, String>((ref, person) async {
  try {
    final res = await apiClient.dio.get(
      ApiConstants.hydrationGoal,
      queryParameters: {'person': person},
    );
    return (res.data['goal_ml'] as num).toDouble();
  } catch (_) {
    return 2500.0; // fallback default
  }
});

final beveragePresetsProvider = FutureProvider<List<BeveragePreset>>((ref) async {
  ref.keepAlive(); // static presets — keep in memory
  final res = await apiClient.dio.get(ApiConstants.beveragePresets);
  return (res.data['presets'] as List<dynamic>)
      .map((p) => BeveragePreset.fromJson(p))
      .toList();
});
