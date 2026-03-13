import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_provider.dart';
import '../providers/nutrition_analytics_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/hydration_provider.dart';
import '../providers/grocery_provider.dart';

/// Predictive data prefetcher.
///
/// Call from dashboard or app_shell to warm data for screens the user
/// is likely to navigate to. All fetches are fire-and-forget — they
/// populate the Riverpod cache / AppCache so when the user navigates,
/// data is already available.
class PrefetchService {
  static bool _prefetching = false;

  /// Warm nutrition, analytics, hydration, and grocery data in background.
  /// Safe to call multiple times — guards against concurrent runs.
  static Future<void> warmAll(WidgetRef ref, String personId) async {
    if (_prefetching) return;
    _prefetching = true;

    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final sevenDaysAgo = DateTime.now()
          .subtract(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10);

      // Fire all prefetches concurrently — don't await sequentially
      await Future.wait([
        // Nutrition entries (last 7 days — used by Nutrition History tab)
        _safe(() => ref.read(nutritionEntriesProvider('${personId}_${sevenDaysAgo}_$today').future)),
        // Nutrition analytics (30-day breakdown — used by Nutrition Analytics tab)
        _safe(() => ref.read(nutritionAnalyticsProvider('${personId}_30').future)),
        // General analytics (7-day — used by Dashboard analytics section)
        _safe(() => ref.read(analyticsProvider('${personId}_7').future)),
        // Hydration history (used by Dashboard hydration card)
        _safe(() => ref.read(hydrationHistoryProvider('${personId}_7_$today').future)),
        // Grocery spending (used by Grocery tab)
        _safe(() => ref.read(grocerySpendingProvider('${personId}_month').future)),
      ]);
    } finally {
      _prefetching = false;
    }
  }

  /// Warm only the data for the Nutrition screen (entries + analytics).
  static Future<void> warmNutrition(WidgetRef ref, String personId) async {
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);

    await Future.wait([
      _safe(() => ref.read(nutritionEntriesProvider('${personId}_${sevenDaysAgo}_$today').future)),
      _safe(() => ref.read(nutritionAnalyticsProvider('${personId}_30').future)),
    ]);
  }

  /// Swallow errors — prefetch failures should never affect the user.
  static Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}
