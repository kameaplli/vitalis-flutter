import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/analytics_provider.dart';
import '../providers/nutrition_analytics_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/hydration_provider.dart';
import '../providers/grocery_provider.dart';
import '../providers/health_provider.dart';
import '../providers/weight_provider.dart';
import '../providers/food_provider.dart';
import '../providers/lab_provider.dart';
import '../providers/social_provider.dart';

/// Predictive data prefetcher.
///
/// Call from dashboard or app_shell to warm data for screens the user
/// is likely to navigate to. All fetches are fire-and-forget — they
/// populate the Riverpod cache / AppCache so when the user navigates,
/// data is already available (sub-100ms).
class PrefetchService {
  static bool _prefetching = false;
  static bool _secondaryPrefetching = false;

  /// Warm critical data immediately after login/app open.
  /// This covers the screens the user is most likely to visit first.
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

      // Phase 1: Critical data (dashboard + most-visited screens)
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
        // Weight history (30-day default — used by Weight screen)
        _safe(() => ref.read(weightHistoryProvider('${personId}_30').future)),
        // Food database (large, cached 24h — instant food search)
        _safe(() => ref.read(foodDatabaseProvider.future)),
        // Beverage presets (static data — instant hydration logging)
        _safe(() => ref.read(beveragePresetsProvider.future)),
      ]);
    } finally {
      _prefetching = false;
    }

    // Phase 2: Secondary data — warm in background after critical path
    _warmSecondary(ref, personId);
  }

  /// Phase 2: Warm less-visited screens in background (non-blocking).
  static Future<void> _warmSecondary(WidgetRef ref, String personId) async {
    if (_secondaryPrefetching) return;
    _secondaryPrefetching = true;

    try {
      // Eagerly init the social feed — triggers cache load + background fetch
      // so Community tab is instant when the user taps it
      _safe(() async => ref.read(socialFeedNotifierProvider));

      await Future.wait([
        // Health providers (7-day windows — used by Health screen tabs)
        _safe(() => ref.read(symptomsProvider('${personId}_7').future)),
        _safe(() => ref.read(moodProvider('${personId}_7').future)),
        _safe(() => ref.read(sleepProvider('${personId}_7').future)),
        _safe(() => ref.read(exerciseProvider('${personId}_7').future)),
        // Recent/frequent foods (used by nutrition food search)
        _safe(() => ref.read(recentFrequentProvider(personId).future)),
        // Favorites (used by food search)
        _safe(() => ref.read(favoriteFoodsProvider.future)),
        // Meal suggestions (used by nutrition screen)
        _safe(() => ref.read(mealSuggestionsProvider.future)),
        // Lab dashboard (used by lab screen)
        _safe(() => ref.read(labDashboardProvider(personId).future)),
      ]);
    } finally {
      _secondaryPrefetching = false;
    }
  }

  /// Swallow errors — prefetch failures should never affect the user.
  static Future<void> _safe(Future<void> Function() fn) async {
    try {
      await fn();
    } catch (_) {}
  }
}
