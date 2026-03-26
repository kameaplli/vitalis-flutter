import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';
import '../models/food_item.dart';
import '../models/nutrition_log.dart';

// ─── Selected food (quantity stored in grams) ─────────────────────────────────

class SelectedFood {
  final FoodItem food;
  final double grams;

  const SelectedFood({required this.food, required this.grams});

  double get calories => (food.cal ?? 0) / 100 * grams;
  double get protein  => (food.protein ?? 0) / 100 * grams;
  double get carbs    => (food.carbs ?? 0) / 100 * grams;
  double get fat      => (food.fat ?? 0) / 100 * grams;

  SelectedFood withGrams(double g) => SelectedFood(food: food, grams: g);
}

// ─── State ────────────────────────────────────────────────────────────────────

/// Infer meal type from the current time of day.
String inferMealType() {
  final hour = DateTime.now().hour;
  if (hour < 11) return 'breakfast';
  if (hour < 14) return 'lunch';
  if (hour < 17) return 'snack';
  return 'dinner';
}

class NutritionState {
  final List<SelectedFood> selectedFoods;
  final String mealType;
  final String? forChild;
  final bool isLoading;
  final String? error;
  final TimeOfDay mealTime;
  final String? editEntryId; // null = new entry, non-null = editing existing

  NutritionState({
    this.selectedFoods = const [],
    String? mealType,
    this.forChild,
    this.isLoading = false,
    this.error,
    TimeOfDay? mealTime,
    this.editEntryId,
  }) : mealType = mealType ?? inferMealType(),
       mealTime = mealTime ?? TimeOfDay.now();

  double get totalCalories => selectedFoods.fold(0.0, (s, f) => s + f.calories);
  double get totalProtein  => selectedFoods.fold(0.0, (s, f) => s + f.protein);
  double get totalCarbs    => selectedFoods.fold(0.0, (s, f) => s + f.carbs);
  double get totalFat      => selectedFoods.fold(0.0, (s, f) => s + f.fat);

  NutritionState copyWith({
    List<SelectedFood>? selectedFoods,
    String? mealType,
    String? forChild,
    bool clearForChild = false,
    bool? isLoading,
    String? error,
    TimeOfDay? mealTime,
    String? editEntryId,
    bool clearEditEntryId = false,
  }) {
    return NutritionState(
      selectedFoods: selectedFoods ?? this.selectedFoods,
      mealType: mealType ?? this.mealType,
      forChild: clearForChild ? null : (forChild ?? this.forChild),
      isLoading: isLoading ?? this.isLoading,
      error: error,
      mealTime: mealTime ?? this.mealTime,
      editEntryId: clearEditEntryId ? null : (editEntryId ?? this.editEntryId),
    );
  }
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class NutritionNotifier extends StateNotifier<NutritionState> {
  NutritionNotifier() : super(NutritionState());

  /// Add a food item. Default grams = food's serving size or 100g.
  void addFood(FoodItem food, {double? grams}) {
    final defaultGrams = grams ?? food.servingSize ?? 100;
    final idx = state.selectedFoods.indexWhere((sf) => sf.food.id == food.id);
    if (idx >= 0) {
      // already in list — increase by one serving
      final updated = [...state.selectedFoods];
      updated[idx] = updated[idx].withGrams(updated[idx].grams + defaultGrams);
      state = state.copyWith(selectedFoods: updated);
    } else {
      state = state.copyWith(
        selectedFoods: [...state.selectedFoods, SelectedFood(food: food, grams: defaultGrams)],
      );
    }
    _saveDraft();
  }

  void removeFood(String foodId) {
    state = state.copyWith(
      selectedFoods: state.selectedFoods.where((sf) => sf.food.id != foodId).toList(),
    );
    _saveDraft();
  }

  void updateGrams(String foodId, double grams) {
    if (grams <= 0) { removeFood(foodId); return; }
    state = state.copyWith(
      selectedFoods: state.selectedFoods
          .map((sf) => sf.food.id == foodId ? sf.withGrams(grams) : sf)
          .toList(),
    );
    _saveDraft();
  }

  /// Load an entire recent meal, replacing the current food list.
  void loadRecentMeal(List<SelectedFood> foods, String mealType) {
    state = state.copyWith(selectedFoods: foods, mealType: mealType);
    _saveDraft();
  }

  void setMealType(String t) => state = state.copyWith(mealType: t);
  void setMealTime(TimeOfDay t) => state = state.copyWith(mealTime: t);
  void setForChild(String? id) => state = state.copyWith(
    forChild: (id == null || id == 'self') ? null : id,
    clearForChild: id == null || id == 'self',
  );
  void clearFoods() {
    state = state.copyWith(selectedFoods: []);
    clearDraft();
  }

  // ─── Draft persistence ───────────────────────────────────────────────────

  static const _draftKey = 'meal_draft';

  /// Auto-save current food selections + meal type to SharedPreferences.
  Future<void> _saveDraft() async {
    if (state.selectedFoods.isEmpty || state.editEntryId != null) {
      // Nothing to draft, or editing an existing entry (not a new meal).
      await _clearDraftStorage();
      return;
    }
    final draft = {
      'meal_type': state.mealType,
      'foods': state.selectedFoods.map((sf) => {
        'food': sf.food.toJson(),
        'grams': sf.grams,
      }).toList(),
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_draftKey, jsonEncode(draft));
  }

  /// Load a previously saved draft (if any) and restore the state.
  Future<bool> loadDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_draftKey);
    if (raw == null) return false;
    try {
      final draft = jsonDecode(raw) as Map<String, dynamic>;
      final mealType = draft['meal_type'] as String?;
      final foodsList = draft['foods'] as List<dynamic>? ?? [];
      if (foodsList.isEmpty) return false;
      final foods = foodsList.map((entry) {
        final map = entry as Map<String, dynamic>;
        return SelectedFood(
          food: FoodItem.fromJson(map['food'] as Map<String, dynamic>),
          grams: (map['grams'] as num).toDouble(),
        );
      }).toList();
      state = state.copyWith(
        selectedFoods: foods,
        mealType: mealType,
      );
      return true;
    } catch (_) {
      // Corrupt draft — discard it.
      await _clearDraftStorage();
      return false;
    }
  }

  /// Clear saved draft (call after successful meal logging).
  Future<void> clearDraft() async {
    await _clearDraftStorage();
  }

  Future<void> _clearDraftStorage() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_draftKey);
  }

  /// Prepare the provider to edit an existing entry.
  void initForEdit(String entryId, String mealType, TimeOfDay time) {
    state = NutritionState(
      mealType: mealType,
      editEntryId: entryId,
      mealTime: time,
      selectedFoods: const [],
    );
  }

  /// Set the food list when editing an existing entry.
  void setEditFoods(List<SelectedFood> foods) {
    state = state.copyWith(selectedFoods: foods);
  }

  /// Log a new meal or update an existing one.
  ///
  /// For **new meals**: returns the snapshot needed for [MealSyncNotifier] to
  /// queue a background sync. The caller (screen) is responsible for calling
  /// `mealSyncProvider.notifier.queueMeal(...)`. This method resets state
  /// instantly so the UI feels immediate.
  ///
  /// For **edits** (editEntryId != null): still awaits the API call since the
  /// user is replacing existing server data.
  Future<bool> logNutrition({String? date, String? personId}) async {
    if (state.selectedFoods.isEmpty) return false;

    final t = state.mealTime;
    final timeStr =
        '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    final forChild = (personId != null && personId != 'self') ? personId : state.forChild;
    final dateStr = date ?? DateTime.now().toIso8601String().substring(0, 10);

    if (state.editEntryId != null) {
      // ── Editing existing entry — await API (no optimistic shortcut) ──
      state = state.copyWith(isLoading: true, error: null);
      try {
        final foods = state.selectedFoods.map((sf) => {
          'food_id': sf.food.id,
          'quantity': sf.grams / (sf.food.servingSize ?? 100),
        }).toList();
        await apiClient.dio.put(
          '${ApiConstants.nutritionLog}/${state.editEntryId}',
          data: {
            'meal_type': state.mealType,
            'for_child': forChild,
            'date': dateStr,
            'time': timeStr,
            'foods': foods,
          },
        );
        state = NutritionState(mealType: state.mealType, forChild: state.forChild);
        await clearDraft();
        return true;
      } catch (e) {
        state = state.copyWith(isLoading: false, error: e.toString());
        return false;
      }
    }

    // ── New meal — reset state instantly, caller queues background sync ──
    state = NutritionState(mealType: state.mealType, forChild: state.forChild);
    await clearDraft();
    return true;
  }
}

final nutritionProvider =
    StateNotifierProvider<NutritionNotifier, NutritionState>((ref) {
  ref.keepAlive();
  return NutritionNotifier();
});

// ─── Entries provider (key = "person_startDate_endDate") ─────────────────────

final nutritionEntriesProvider =
    FutureProvider.family<List<NutritionEntry>, String>((ref, key) async {
  ref.keepAlive(); // keep cached so 7-day prefetch stays warm
  final (person, startDate, endDate) = PK.personDateRange(key);
  final res = await apiClient.dio.get(
    ApiConstants.nutritionAll,
    queryParameters: {
      if (person.isNotEmpty) 'person': person,
      if (startDate != null) 'start_date': startDate,
      if (endDate   != null) 'end_date': endDate,
    },
  );
  return (res.data['entries'] as List<dynamic>)
      .map((e) => NutritionEntry.fromJson(e))
      .toList();
});
