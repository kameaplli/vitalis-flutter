import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hugeicons/hugeicons.dart';

/// Available app color skins. Dark mode is a separate toggle.
enum AppSkin {
  light('Daylight', HugeIcons.strokeRoundedSun01),
  dark('Teal Dark', HugeIcons.strokeRoundedMoon01),
  sunset('Sunset Glow', HugeIcons.strokeRoundedCircle),
  ocean('Ocean Blue', HugeIcons.strokeRoundedDroplet),
  lavender('Lavender', HugeIcons.strokeRoundedLeaf01);

  final String label;
  final List<List<dynamic>> icon;
  const AppSkin(this.label, this.icon);
}

const _prefKey = 'app_skin';
const _darkPrefKey = 'dark_mode';

class ThemeNotifier extends StateNotifier<AppSkin> {
  ThemeNotifier() : super(AppSkin.light) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_prefKey);
    if (name != null) {
      state = AppSkin.values.firstWhere(
        (s) => s.name == name,
        orElse: () => AppSkin.light,
      );
    }
  }

  Future<void> setSkin(AppSkin skin) async {
    state = skin;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, skin.name);
  }
}

class DarkModeNotifier extends StateNotifier<bool> {
  DarkModeNotifier() : super(false) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_darkPrefKey) ?? false;
  }

  Future<void> toggle() async {
    state = !state;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkPrefKey, state);
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkPrefKey, value);
  }
}

final themeProvider = StateNotifierProvider<ThemeNotifier, AppSkin>(
  (ref) { ref.keepAlive(); return ThemeNotifier(); },
);

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>(
  (ref) { ref.keepAlive(); return DarkModeNotifier(); },
);
