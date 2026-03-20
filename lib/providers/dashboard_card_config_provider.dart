import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All available dashboard card types.
enum DashboardCardType {
  quickActions('Quick Actions', 'Log meal, water, weight, mood', 'quick_actions', true),
  summaryGrid('Daily Summary', 'Calories, weight, meals, water', 'summary_grid', true),
  hydrationQuickLog('Hydration Log', 'Quick water buttons + timeline', 'hydration_quick_log', true),
  wearableSummary('Wearable Health', 'Steps, heart rate, sleep from wearables', 'wearable_summary', true),
  macros('Macros', 'Protein, carbs, fat breakdown', 'macros', false),
  mealDistribution('Meal Distribution', '7-day breakfast/lunch/dinner/snack split', 'meal_distribution', false),
  healthScore('Health Score', 'Overall wellness score', 'health_score', false),
  flareRisk('Eczema Flare Risk', 'AI-predicted flare probability', 'flare_risk', false),
  topFoods('Top Foods', 'Top calorie sources today', 'top_foods', false),
  insights('Insights', 'Personalized wellness tips', 'insights', false),
  grocerySnapshot('Grocery Snapshot', 'Monthly spending overview', 'grocery_snapshot', false);

  final String displayName;
  final String description;
  final String key;
  final bool defaultVisible;

  const DashboardCardType(this.displayName, this.description, this.key, this.defaultVisible);

  String get emoji => switch (this) {
    DashboardCardType.quickActions => '\u26A1',
    DashboardCardType.summaryGrid => '\uD83D\uDCCA',
    DashboardCardType.hydrationQuickLog => '\uD83D\uDCA7',
    DashboardCardType.wearableSummary => '\u231A',
    DashboardCardType.macros => '\uD83E\uDD69',
    DashboardCardType.mealDistribution => '\uD83C\uDF7D\uFE0F',
    DashboardCardType.healthScore => '\u2764\uFE0F',
    DashboardCardType.flareRisk => '\uD83D\uDEA8',
    DashboardCardType.topFoods => '\uD83C\uDF54',
    DashboardCardType.insights => '\uD83D\uDCA1',
    DashboardCardType.grocerySnapshot => '\uD83D\uDED2',
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
  factory DashboardCardConfig.fromJson(String json) {
    try {
      final list = jsonDecode(json) as List;
      final knownKeys = {for (final t in DashboardCardType.values) t.key: t};
      final parsed = <({DashboardCardType type, bool visible})>[];
      final seen = <DashboardCardType>{};

      for (final item in list) {
        final map = item as Map<String, dynamic>;
        final type = knownKeys[map['type']];
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

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(_prefsKey);
    if (json != null) {
      state = DashboardCardConfig.fromJson(json);
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
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
