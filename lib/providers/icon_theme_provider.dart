import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/icon_theme.dart';

const _kIconThemeKey = 'icon_theme';

/// Provider for the currently selected icon theme.
/// Persisted in SharedPreferences so it survives app restarts.
final iconThemeProvider = StateNotifierProvider<IconThemeNotifier, VitalisIcons>((ref) {
  return IconThemeNotifier();
});

/// Provider for the current theme choice enum (for settings UI).
final iconThemeChoiceProvider = StateNotifierProvider<IconThemeChoiceNotifier, IconThemeChoice>((ref) {
  return IconThemeChoiceNotifier(ref);
});

class IconThemeChoiceNotifier extends StateNotifier<IconThemeChoice> {
  final Ref _ref;

  IconThemeChoiceNotifier(this._ref) : super(IconThemeChoice.material) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_kIconThemeKey);
    if (name != null) {
      try {
        final choice = IconThemeChoice.values.byName(name);
        state = choice;
        _ref.read(iconThemeProvider.notifier).set(choice.icons);
      } catch (_) {}
    }
  }

  Future<void> select(IconThemeChoice choice) async {
    state = choice;
    _ref.read(iconThemeProvider.notifier).set(choice.icons);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kIconThemeKey, choice.name);
  }
}

class IconThemeNotifier extends StateNotifier<VitalisIcons> {
  IconThemeNotifier() : super(materialIcons);

  void set(VitalisIcons icons) => state = icons;
}
