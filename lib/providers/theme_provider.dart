import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available app skins. Add new entries here to extend the theme catalog.
enum AppSkin {
  light('Daylight', Icons.wb_sunny_outlined),
  dark('Dark Mode', Icons.dark_mode_outlined),
  sunset('Sunset Glow', Icons.gradient_outlined);

  final String label;
  final IconData icon;
  const AppSkin(this.label, this.icon);
}

const _prefKey = 'app_skin';

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

final themeProvider = StateNotifierProvider<ThemeNotifier, AppSkin>(
  (ref) => ThemeNotifier(),
);
