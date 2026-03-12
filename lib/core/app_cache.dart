import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Lightweight JSON cache backed by SharedPreferences.
/// Persists across app restarts. Each key has a configurable TTL.
///
/// Fresh TTLs (returned when stale=false):
///   Dashboard  —  5 minutes
///   Analytics  — 30 minutes
///   Food DB    — 24 hours
///
/// When stale=true: returns data regardless of age (error fallback).
class AppCache {
  static const _dashTtl      = 5;
  static const _analyticsTtl = 30;
  static const _foodTtl      = 60 * 24;

  // ── Dashboard ────────────────────────────────────────────────────────────────

  static Future<void> saveDashboard(String personId, Map<String, dynamic> json) =>
      _save('dash_$personId', json);

  /// [stale=false] → only return if < 5 min old.
  /// [stale=true]  → return even if expired (graceful error fallback).
  static Future<Map<String, dynamic>?> loadDashboard(String personId,
          {bool stale = false}) =>
      _loadMap('dash_$personId', stale ? null : _dashTtl);

  // ── Analytics ────────────────────────────────────────────────────────────────

  static Future<void> saveAnalytics(String key, Map<String, dynamic> json) =>
      _save('analytics_$key', json);

  static Future<Map<String, dynamic>?> loadAnalytics(String key,
          {bool stale = false}) =>
      _loadMap('analytics_$key', stale ? null : _analyticsTtl);

  /// Clear all analytics cache entries so next provider read fetches fresh.
  static Future<void> clearAnalytics() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('analytics_'));
      for (final k in keys) {
        await prefs.remove(k);
        await prefs.remove('${k}_ts');
      }
    } catch (_) {}
  }

  // ── Food database ────────────────────────────────────────────────────────────

  static Future<void> saveFoodDb(List<dynamic> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('food_db', jsonEncode(list));
      await prefs.setInt('food_db_ts', _nowMs());
    } catch (_) {}
  }

  /// Clear food database cache so next provider read fetches fresh from network.
  static Future<void> clearFoodDb() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('food_db');
      await prefs.remove('food_db_ts');
    } catch (_) {}
  }

  static Future<List<dynamic>?> loadFoodDb({bool stale = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!stale && _isStale(prefs, 'food_db_ts', _foodTtl)) return null;
      final raw = prefs.getString('food_db');
      if (raw == null) return null;
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  static Future<void> _save(String key, Map<String, dynamic> json) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(json));
      await prefs.setInt('${key}_ts', _nowMs());
    } catch (_) {}
  }

  /// [ttlMinutes=null] → return regardless of age.
  static Future<Map<String, dynamic>?> _loadMap(
      String key, int? ttlMinutes) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (ttlMinutes != null && _isStale(prefs, '${key}_ts', ttlMinutes)) {
        return null;
      }
      final raw = prefs.getString(key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  static bool _isStale(SharedPreferences prefs, String tsKey, int ttlMinutes) {
    final ts = prefs.getInt(tsKey);
    if (ts == null) return true;
    return (_nowMs() - ts) > ttlMinutes * 60 * 1000;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}
