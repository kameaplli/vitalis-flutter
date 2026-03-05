import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/dashboard_data.dart';

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
