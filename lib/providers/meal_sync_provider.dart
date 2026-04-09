import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import '../models/food_item.dart';
import '../models/nutrition_log.dart';
import 'dashboard_provider.dart';
import 'nutrition_analytics_provider.dart';
import 'nutrition_provider.dart';

/// Optimistic local-first meal logging with background sync.
///
/// Flow: user taps "Log Meal" → local entry appears instantly → API POST fires
/// in background → on failure retries at 1 min, 3 min, 5 min → on final
/// failure removes local entry and surfaces error for user to relog.

// ─── Pending meal model ─────────────────────────────────────────────────────

enum MealSyncStatus { pending, syncing, failed }

class PendingMeal {
  final String tempId;
  final String mealType;
  final String date;
  final String time;
  final String? forChild;
  final String personId;
  final List<Map<String, dynamic>> foodsPayload; // API-ready foods list
  final List<SelectedFood> selectedFoods; // for local display
  final int attempt;
  final MealSyncStatus status;
  final String? error;
  final DateTime createdAt;

  const PendingMeal({
    required this.tempId,
    required this.mealType,
    required this.date,
    required this.time,
    this.forChild,
    required this.personId,
    required this.foodsPayload,
    required this.selectedFoods,
    this.attempt = 0,
    this.status = MealSyncStatus.pending,
    this.error,
    required this.createdAt,
  });

  PendingMeal copyWith({
    int? attempt,
    MealSyncStatus? status,
    String? error,
  }) =>
      PendingMeal(
        tempId: tempId,
        mealType: mealType,
        date: date,
        time: time,
        forChild: forChild,
        personId: personId,
        foodsPayload: foodsPayload,
        selectedFoods: selectedFoods,
        attempt: attempt ?? this.attempt,
        status: status ?? this.status,
        error: error,
        createdAt: createdAt,
      );

  /// Convert to a local NutritionEntry for display in the entries list.
  NutritionEntry toLocalEntry() {
    final desc = selectedFoods.map((sf) => sf.food.name).join(', ');
    final totalCal = selectedFoods.fold(0.0, (s, sf) => s + sf.calories);
    return NutritionEntry(
      id: tempId,
      date: date,
      time: time,
      meal: mealType,
      person: forChild != null ? '' : 'Me',
      personId: personId,
      description: desc,
      calories: totalCal,
    );
  }

  Map<String, dynamic> toJson() => {
        'tempId': tempId,
        'mealType': mealType,
        'date': date,
        'time': time,
        'forChild': forChild,
        'personId': personId,
        'foodsPayload': foodsPayload,
        'selectedFoods': selectedFoods
            .map((sf) => {'food': sf.food.toJson(), 'grams': sf.grams})
            .toList(),
        'attempt': attempt,
        'status': status.index,
        'createdAt': createdAt.toIso8601String(),
      };

  factory PendingMeal.fromJson(Map<String, dynamic> json) {
    final foods = (json['selectedFoods'] as List<dynamic>? ?? [])
        .map((e) {
          final m = e as Map<String, dynamic>;
          return SelectedFood(
            food: FoodItem.fromJson(m['food'] as Map<String, dynamic>),
            grams: (m['grams'] as num).toDouble(),
          );
        })
        .toList();
    return PendingMeal(
      tempId: json['tempId'] as String,
      mealType: json['mealType'] as String,
      date: json['date'] as String,
      time: json['time'] as String,
      forChild: json['forChild'] as String?,
      personId: json['personId'] as String? ?? 'self',
      foodsPayload: (json['foodsPayload'] as List<dynamic>)
          .cast<Map<String, dynamic>>(),
      selectedFoods: foods,
      attempt: json['attempt'] as int? ?? 0,
      status: MealSyncStatus.values[json['status'] as int? ?? 0],
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

// ─── State ──────────────────────────────────────────────────────────────────

class MealSyncState {
  final List<PendingMeal> pendingMeals;
  final Map<String, String> failedMeals; // tempId → error message
  final List<PendingMeal> failedMealData; // actual meal data for display + retry
  final List<String> recentWarnings; // macro validation warnings from last sync

  const MealSyncState({
    this.pendingMeals = const [],
    this.failedMeals = const {},
    this.failedMealData = const [],
    this.recentWarnings = const [],
  });

  MealSyncState copyWith({
    List<PendingMeal>? pendingMeals,
    Map<String, String>? failedMeals,
    List<PendingMeal>? failedMealData,
    List<String>? recentWarnings,
  }) =>
      MealSyncState(
        pendingMeals: pendingMeals ?? this.pendingMeals,
        failedMeals: failedMeals ?? this.failedMeals,
        failedMealData: failedMealData ?? this.failedMealData,
        recentWarnings: recentWarnings ?? this.recentWarnings,
      );

  /// Get local NutritionEntry objects for merging with server entries.
  /// Includes both pending AND failed meals so they remain visible in history.
  List<NutritionEntry> get localEntries => [
        ...pendingMeals.map((m) => m.toLocalEntry()),
        ...failedMealData.map((m) => m.toLocalEntry()),
      ];

  bool get hasPending => pendingMeals.isNotEmpty;
  bool get hasFailures => failedMeals.isNotEmpty;
}

// ─── Notifier ───────────────────────────────────────────────────────────────

class MealSyncNotifier extends StateNotifier<MealSyncState> {
  final Ref _ref;
  static const _storageKey = 'meal_sync_queue';
  static const _failedStorageKey = 'meal_sync_failed';
  // Retry intervals: 1 min, 3 min, 5 min
  static const _retryDelays = [
    Duration(minutes: 1),
    Duration(minutes: 3),
    Duration(minutes: 5),
  ];

  final Map<String, Timer> _retryTimers = {};

  MealSyncNotifier(this._ref) : super(const MealSyncState()) {
    _loadFromDisk();
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _loadFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load pending meals
      final raw = prefs.getString(_storageKey);
      final pendingList = raw != null
          ? (jsonDecode(raw) as List<dynamic>)
              .map((e) => PendingMeal.fromJson(e as Map<String, dynamic>))
              .toList()
          : <PendingMeal>[];

      // Load failed meals
      final failedRaw = prefs.getString(_failedStorageKey);
      final failedList = failedRaw != null
          ? (jsonDecode(failedRaw) as List<dynamic>)
              .map((e) => PendingMeal.fromJson(e as Map<String, dynamic>))
              .toList()
          : <PendingMeal>[];

      // Rebuild failedMeals map from failedMealData
      final failedMap = <String, String>{};
      for (final m in failedList) {
        failedMap[m.tempId] =
            m.error ?? 'Failed to sync meal. Tap retry or log again.';
      }

      if (pendingList.isNotEmpty || failedList.isNotEmpty) {
        state = state.copyWith(
          pendingMeals: pendingList,
          failedMealData: failedList,
          failedMeals: failedMap,
        );
        // Resume syncing for any pending meals
        for (final meal in pendingList) {
          if (meal.status != MealSyncStatus.failed) {
            _syncToBackend(meal.tempId);
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _saveToDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save pending meals
      if (state.pendingMeals.isEmpty) {
        await prefs.remove(_storageKey);
      } else {
        await prefs.setString(
          _storageKey,
          jsonEncode(state.pendingMeals.map((m) => m.toJson()).toList()),
        );
      }

      // Save failed meals
      if (state.failedMealData.isEmpty) {
        await prefs.remove(_failedStorageKey);
      } else {
        await prefs.setString(
          _failedStorageKey,
          jsonEncode(state.failedMealData.map((m) => m.toJson()).toList()),
        );
      }
    } catch (_) {}
  }

  // ── Queue a new meal (called from logNutrition) ───────────────────────────

  /// Queue a meal for instant local display + background sync.
  /// Returns the temp ID assigned to the local entry.
  String queueMeal({
    required List<SelectedFood> selectedFoods,
    required String mealType,
    required String date,
    required String time,
    String? forChild,
    required String personId,
  }) {
    final tempId = 'pending_${DateTime.now().millisecondsSinceEpoch}';
    final foodsPayload = selectedFoods
        .map((sf) => <String, dynamic>{
              'food_id': sf.food.id,
              'quantity': sf.grams / (sf.food.servingSize ?? 100),
            })
        .toList();

    final pending = PendingMeal(
      tempId: tempId,
      mealType: mealType,
      date: date,
      time: time,
      forChild: forChild,
      personId: personId,
      foodsPayload: foodsPayload,
      selectedFoods: selectedFoods,
      createdAt: DateTime.now(),
    );

    state = state.copyWith(
      pendingMeals: [...state.pendingMeals, pending],
    );
    _saveToDisk();

    // Fire background sync
    _syncToBackend(tempId);

    return tempId;
  }

  // ── Background sync with retry ────────────────────────────────────────────

  Future<void> _syncToBackend(String tempId) async {
    final idx = state.pendingMeals.indexWhere((m) => m.tempId == tempId);
    if (idx < 0) return;

    // Mark as syncing
    final meals = [...state.pendingMeals];
    final meal = meals[idx].copyWith(status: MealSyncStatus.syncing);
    meals[idx] = meal;
    state = state.copyWith(pendingMeals: meals);

    try {
      final queryParams = <String, dynamic>{};
      if (meal.forChild != null) {
        queryParams['family_member_id'] = meal.forChild;
      }

      final response = await apiClient.dio.post(
        ApiConstants.nutritionLog,
        data: {
          'meal_type': meal.mealType,
          'for_child': meal.forChild,
          'date': meal.date,
          'time': meal.time,
          'foods': meal.foodsPayload,
        },
      );

      // Surface macro validation warnings (non-blocking)
      final responseData = response.data as Map<String, dynamic>?;
      final warnings = (responseData?['warnings'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [];
      if (warnings.isNotEmpty && mounted) {
        state = state.copyWith(recentWarnings: warnings);
      }

      // Success — remove from pending queue
      if (!mounted) return;
      final syncedMeal = state.pendingMeals.firstWhere(
        (m) => m.tempId == tempId,
        orElse: () => meal,
      );
      state = state.copyWith(
        pendingMeals:
            state.pendingMeals.where((m) => m.tempId != tempId).toList(),
      );
      _saveToDisk();

      // Clear caches first, then invalidate providers to force fresh network fetch
      final today = DateTime.now().toIso8601String().substring(0, 10);
      await AppCache.clearDashboard(syncedMeal.personId, date: today);
      AppCache.clearAnalytics();
      _ref.invalidate(nutritionEntriesProvider);
      _ref.invalidate(dashboardProvider((syncedMeal.personId, today)));
      _ref.invalidate(nutritionAnalyticsProvider);
    } catch (e) {
      if (!mounted) return;

      final currentIdx =
          state.pendingMeals.indexWhere((m) => m.tempId == tempId);
      if (currentIdx < 0) return;

      final current = state.pendingMeals[currentIdx];
      final nextAttempt = current.attempt + 1;

      if (nextAttempt < _retryDelays.length) {
        // Schedule retry
        final updated = current.copyWith(
          attempt: nextAttempt,
          status: MealSyncStatus.pending,
          error: 'Retrying in ${_retryDelays[nextAttempt].inMinutes} min...',
        );
        final updatedMeals = [...state.pendingMeals];
        updatedMeals[currentIdx] = updated;
        state = state.copyWith(pendingMeals: updatedMeals);
        _saveToDisk();

        _retryTimers[tempId]?.cancel();
        _retryTimers[tempId] = Timer(_retryDelays[nextAttempt], () {
          if (mounted) _syncToBackend(tempId);
        });
      } else {
        // All retries exhausted — preserve meal data for display + retry
        final failedMeal = current.copyWith(
          status: MealSyncStatus.failed,
          error: 'Failed to sync after 3 retries.',
        );
        state = state.copyWith(
          pendingMeals:
              state.pendingMeals.where((m) => m.tempId != tempId).toList(),
          failedMeals: {
            ...state.failedMeals,
            tempId:
                'Failed to sync meal after 3 retries. Tap retry or log again.',
          },
          failedMealData: [...state.failedMealData, failedMeal],
        );
        _saveToDisk();
      }
    }
  }

  /// Retry a specific failed sync (user tapped retry).
  void retryMeal(String tempId, [PendingMeal? meal]) {
    // Find the meal from failedMealData if not provided
    final mealToRetry = meal ??
        state.failedMealData.cast<PendingMeal?>().firstWhere(
              (m) => m?.tempId == tempId,
              orElse: () => null,
            );
    if (mealToRetry == null) return;

    final restored = mealToRetry.copyWith(
      attempt: 0,
      status: MealSyncStatus.pending,
      error: null,
    );
    state = state.copyWith(
      pendingMeals: [...state.pendingMeals, restored],
      failedMeals: Map.of(state.failedMeals)..remove(tempId),
      failedMealData:
          state.failedMealData.where((m) => m.tempId != tempId).toList(),
    );
    _saveToDisk();
    _syncToBackend(tempId);
  }

  /// Clear macro validation warnings (after UI has shown them).
  void clearWarnings() {
    state = state.copyWith(recentWarnings: []);
  }

  /// Dismiss a failure notification and remove the failed meal data.
  void dismissFailure(String tempId) {
    state = state.copyWith(
      failedMeals: Map.of(state.failedMeals)..remove(tempId),
      failedMealData:
          state.failedMealData.where((m) => m.tempId != tempId).toList(),
    );
    _saveToDisk();
  }

  @override
  void dispose() {
    for (final timer in _retryTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}

// ─── Provider ───────────────────────────────────────────────────────────────

final mealSyncProvider =
    StateNotifierProvider<MealSyncNotifier, MealSyncState>((ref) {
  return MealSyncNotifier(ref);
});
