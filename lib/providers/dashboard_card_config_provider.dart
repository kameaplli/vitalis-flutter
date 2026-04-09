import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All available dashboard card types.
///
/// Small tiles (isSmallTile=true) render in a 2-column grid.
/// Large cards render full-width.
enum DashboardCardType {
  // ── Small stat tiles (2-column grid) ───────────────────────────────────
  calories('Calories', 'Daily calorie intake', 'calories', true, true),
  weight('Weight', 'Current weight & change', 'weight', true, true),
  meals('Meals', 'Meals logged today', 'meals', true, true),
  water('Water', 'Hydration intake', 'water', true, true),
  steps('Steps', 'Daily step count', 'steps', true, true),
  sleep('Sleep', 'Sleep duration', 'sleep', false, true),
  heartRate('Heart Rate', 'Average heart rate', 'heart_rate', false, true),
  spo2('SpO2', 'Blood oxygen level', 'spo2', false, true),
  exercise('Exercise', 'Active calories burned', 'exercise', false, true),
  distance('Distance', 'Distance walked/run', 'distance', false, true),

  // ── Full-width cards ───────────────────────────────────────────────────
  quickActions('Quick Actions', 'Log meal, water, weight, mood', 'quick_actions', true, false),
  hydrationQuickLog('Hydration Log', 'Quick water buttons + timeline', 'hydration_quick_log', true, false),
  wearableSummary('Wearable Health', 'Health Connect data overview', 'wearable_summary', false, false),
  macros('Macros', 'Protein, carbs, fat breakdown', 'macros', false, false),
  mealDistribution('Meal Distribution', '7-day meal type split', 'meal_distribution', false, false),
  healthScore('Health Score', 'Overall wellness score', 'health_score', true, false),
  flareRisk('Eczema Flare Risk', 'AI-predicted flare probability', 'flare_risk', false, false),
  topFoods('Top Foods', 'Top calorie sources this week', 'top_foods', false, false),
  insights('Insights', 'Personalized wellness tips', 'insights', false, false),
  grocerySnapshot('Grocery Snapshot', 'Monthly spending overview', 'grocery_snapshot', false, false),
  dailyProgress('Daily Progress', 'Rings showing nutrition, hydration & meals', 'daily_progress', true, false),
  personalBests('Personal Bests', 'Your recent records & achievements', 'personal_bests', true, false);

  final String displayName;
  final String description;
  final String key;
  final bool defaultVisible;
  final bool isSmallTile;

  const DashboardCardType(this.displayName, this.description, this.key,
      this.defaultVisible, this.isSmallTile);

  String get emoji => switch (this) {
    DashboardCardType.calories => '\uD83D\uDD25',
    DashboardCardType.weight => '\u2696\uFE0F',
    DashboardCardType.meals => '\uD83C\uDF7D\uFE0F',
    DashboardCardType.water => '\uD83D\uDCA7',
    DashboardCardType.steps => '\uD83D\uDEB6',
    DashboardCardType.sleep => '\uD83D\uDE34',
    DashboardCardType.heartRate => '\u2764\uFE0F',
    DashboardCardType.spo2 => '\uD83E\uDE78',
    DashboardCardType.exercise => '\uD83C\uDFCB\uFE0F',
    DashboardCardType.distance => '\uD83D\uDCCF',
    DashboardCardType.quickActions => '\u26A1',
    DashboardCardType.hydrationQuickLog => '\uD83E\uDEB3',
    DashboardCardType.wearableSummary => '\u231A',
    DashboardCardType.macros => '\uD83E\uDD69',
    DashboardCardType.mealDistribution => '\uD83D\uDCCA',
    DashboardCardType.healthScore => '\uD83C\uDFC6',
    DashboardCardType.flareRisk => '\uD83D\uDEA8',
    DashboardCardType.topFoods => '\uD83C\uDF54',
    DashboardCardType.insights => '\uD83D\uDCA1',
    DashboardCardType.grocerySnapshot => '\uD83D\uDED2',
    DashboardCardType.dailyProgress => '\uD83C\uDF00',
    DashboardCardType.personalBests => '\uD83C\uDFC5',
  };
}

/// Holds the user's dashboard card configuration: visibility and order.
class DashboardCardConfig {
  /// Ordered list of card types with their visibility.
  final List<({DashboardCardType type, bool visible})> cards;

  const DashboardCardConfig({required this.cards});

  /// Default configuration — all cards in enum order, default visibility.
  factory DashboardCardConfig.defaults() {
    return DashboardCardConfig(
      cards: DashboardCardType.values
          .map((t) => (type: t, visible: t.defaultVisible))
          .toList(),
    );
  }

  /// Get only visible cards in order.
  List<DashboardCardType> get visibleCards =>
      cards.where((c) => c.visible).map((c) => c.type).toList();

  /// Check if a specific card is visible.
  bool isVisible(DashboardCardType type) =>
      cards.any((c) => c.type == type && c.visible);

  /// Create a copy with one card's visibility toggled.
  DashboardCardConfig toggleCard(DashboardCardType type) {
    return DashboardCardConfig(
      cards: cards.map((c) {
        if (c.type == type) return (type: c.type, visible: !c.visible);
        return c;
      }).toList(),
    );
  }

  /// Create a copy with a new card order.
  DashboardCardConfig reorder(int oldIndex, int newIndex) {
    final list = List<({DashboardCardType type, bool visible})>.from(cards);
    if (newIndex > oldIndex) newIndex -= 1;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    return DashboardCardConfig(cards: list);
  }

  /// Serialize to JSON for SharedPreferences.
  String toJson() {
    final list = cards.map((c) => {
      'type': c.type.key,
      'visible': c.visible,
    }).toList();
    return jsonEncode(list);
  }

  /// Deserialize from JSON, preserving any new card types added in updates.
  /// Migrates legacy 'summary_grid' → individual stat tiles.
  factory DashboardCardConfig.fromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      final knownKeys = {for (final t in DashboardCardType.values) t.key: t};
      final parsed = <({DashboardCardType type, bool visible})>[];
      final seen = <DashboardCardType>{};

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final key = map['type'] as String?;

        // Migration: expand legacy 'summary_grid' into individual stat tiles
        if (key == 'summary_grid') {
          final wasVisible = map['visible'] as bool? ?? true;
          for (final statType in [
            DashboardCardType.calories,
            DashboardCardType.weight,
            DashboardCardType.meals,
            DashboardCardType.water,
            DashboardCardType.steps,
            DashboardCardType.sleep,
          ]) {
            if (!seen.contains(statType)) {
              parsed.add((type: statType, visible: wasVisible));
              seen.add(statType);
            }
          }
          continue;
        }

        final type = knownKeys[key];
        if (type != null && !seen.contains(type)) {
          parsed.add((type: type, visible: map['visible'] as bool? ?? type.defaultVisible));
          seen.add(type);
        }
      }

      // Add any new card types that didn't exist in saved config
      for (final type in DashboardCardType.values) {
        if (!seen.contains(type)) {
          parsed.add((type: type, visible: type.defaultVisible));
        }
      }

      return DashboardCardConfig(cards: parsed);
    } catch (_) {
      return DashboardCardConfig.defaults();
    }
  }
}

/// SharedPreferences key for dashboard card config.
const _prefsKey = 'dashboard_card_config';

/// Riverpod provider for dashboard card configuration.
class DashboardCardConfigNotifier extends StateNotifier<DashboardCardConfig> {
  DashboardCardConfigNotifier() : super(DashboardCardConfig.defaults()) {
    _load();
  }

  SharedPreferences? _prefs;

  Future<SharedPreferences> get _sharedPrefs async =>
      _prefs ??= await SharedPreferences.getInstance();

  Future<void> _load() async {
    final prefs = await _sharedPrefs;
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = DashboardCardConfig.fromJson(json);
    }
  }

  Future<void> _save() async {
    final prefs = await _sharedPrefs;
    await prefs.setString(_prefsKey, state.toJson());
  }

  void toggleCard(DashboardCardType type) {
    state = state.toggleCard(type);
    _save();
  }

  void reorder(int oldIndex, int newIndex) {
    state = state.reorder(oldIndex, newIndex);
    _save();
  }

  void resetToDefaults() {
    state = DashboardCardConfig.defaults();
    _save();
  }
}

final dashboardCardConfigProvider =
    StateNotifierProvider<DashboardCardConfigNotifier, DashboardCardConfig>(
  (_) => DashboardCardConfigNotifier(),
);
