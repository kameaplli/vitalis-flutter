import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available app color skins. Dark mode is a separate toggle.
enum AppSkin {
  light('Daylight', Icons.wb_sunny_outlined),
  dark('Teal Dark', Icons.dark_mode_outlined),
  sunset('Sunset Glow', Icons.gradient_outlined),
  ocean('Ocean Blue', Icons.water_outlined),
  lavender('Lavender', Icons.local_florist_outlined);

  final String label;
  final IconData icon;
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
  (ref) => ThemeNotifier(),
);

final darkModeProvider = StateNotifierProvider<DarkModeNotifier, bool>(
  (ref) => DarkModeNotifier(),
);
