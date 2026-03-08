import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/dashboard_data.dart';

// ── Family snapshot model ───────────────────────────────────────────────────

class PersonSnapshot {
  final String id;
  final String name;
  final String? avatarUrl;
  final double healthScore;
  final double todayCalories;
  final double todayWater;

  const PersonSnapshot({
    required this.id,
    required this.name,
    this.avatarUrl,
    required this.healthScore,
    required this.todayCalories,
    required this.todayWater,
  });

  factory PersonSnapshot.fromJson(Map<String, dynamic> json) => PersonSnapshot(
        id: json['id'] ?? 'self',
        name: json['name'] ?? '',
        avatarUrl: json['avatar_url'],
        healthScore: (json['health_score'] as num?)?.toDouble() ?? 0,
        todayCalories: (json['today_calories'] as num?)?.toDouble() ?? 0,
        todayWater: (json['today_water'] as num?)?.toDouble() ?? 0,
      );
}

/// Fetches lightweight snapshot for all family members in one call.
final familySnapshotProvider =
    FutureProvider<List<PersonSnapshot>>((ref) async {
  ref.keepAlive();
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final res = await apiClient.dio.get(
    ApiConstants.dashboardFamily,
    queryParameters: {'date': today},
  );
  final persons = (res.data['persons'] as List<dynamic>? ?? [])
      .map((p) => PersonSnapshot.fromJson(p as Map<String, dynamic>))
      .toList();
  return persons;
});

/// Family provider — keyed by person ('self' or family_member_id).
///
/// Cache strategy:
///  1. Fresh cache (< 5 min) → return immediately (sub-50ms)
///  2. Stale/absent → fetch from network → save to cache
///  3. Network error + stale cache exists → return stale data (no error UI)
///  4. Network error + no cache → propagate error
final dashboardProvider =
    FutureProvider.family<DashboardData, String>((ref, person) async {
  ref.keepAlive();

  final today = DateTime.now().toIso8601String().substring(0, 10);

  // 1. Fresh cache hit → instant return
  final cached = await AppCache.loadDashboard(person);
  if (cached != null) {
    return DashboardData.fromJson(cached);
  }

  // 2. Fetch from network
  try {
    final res = await apiClient.dio.get(
      ApiConstants.dashboard,
      queryParameters: {
        if (person != 'self') 'person': person,
        'date': today,
      },
    );
    await AppCache.saveDashboard(person, Map<String, dynamic>.from(res.data as Map));
    return DashboardData.fromJson(res.data);
  } catch (_) {
    // 3. Network failed — fall back to stale cache if available
    final stale = await AppCache.loadDashboard(person, stale: true);
    if (stale != null) return DashboardData.fromJson(stale);
    rethrow; // 4. No cache at all — propagate error to UI
  }
});
