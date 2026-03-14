import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Encrypted JSON cache for health data, backed by flutter_secure_storage.
/// Non-sensitive data (food DB) stays in SharedPreferences for performance.
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

  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Dashboard (encrypted — contains personal health data) ─────────────────

  static Future<void> saveDashboard(String personId, Map<String, dynamic> json, {String? date}) {
    final dateStr = date ?? DateTime.now().toIso8601String().substring(0, 10);
    return _secureSave('dash_${personId}_$dateStr', json);
  }

  /// [stale=false] → only return if < 5 min old.
  /// [stale=true]  → return even if expired (graceful error fallback).
  static Future<Map<String, dynamic>?> loadDashboard(String personId,
          {bool stale = false, String? date}) {
    final dateStr = date ?? DateTime.now().toIso8601String().substring(0, 10);
    return _secureLoadMap('dash_${personId}_$dateStr', stale ? null : _dashTtl);
  }

  // ── Analytics (encrypted — contains personal health analytics) ─────────────

  static Future<void> saveAnalytics(String key, Map<String, dynamic> json) =>
      _secureSave('analytics_$key', json);

  static Future<Map<String, dynamic>?> loadAnalytics(String key,
          {bool stale = false}) =>
      _secureLoadMap('analytics_$key', stale ? null : _analyticsTtl);

  /// Clear all analytics cache entries so next provider read fetches fresh.
  static Future<void> clearAnalytics() async {
    try {
      final all = await _secureStorage.readAll();
      final keys = all.keys.where((k) => k.startsWith('analytics_'));
      for (final k in keys) {
        await _secureStorage.delete(key: k);
        await _secureStorage.delete(key: '${k}_ts');
      }
    } catch (_) {}
  }

  // ── Food database (SharedPreferences — not personal health data) ──────────

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

  // ── Secure Internal helpers ────────────────────────────────────────────────

  static Future<void> _secureSave(String key, Map<String, dynamic> json) async {
    try {
      await _secureStorage.write(key: key, value: jsonEncode(json));
      await _secureStorage.write(key: '${key}_ts', value: _nowMs().toString());
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> _secureLoadMap(
      String key, int? ttlMinutes) async {
    try {
      if (ttlMinutes != null) {
        final tsStr = await _secureStorage.read(key: '${key}_ts');
        if (tsStr == null) return null;
        final ts = int.tryParse(tsStr);
        if (ts == null || (_nowMs() - ts) > ttlMinutes * 60 * 1000) return null;
      }
      final raw = await _secureStorage.read(key: key);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  // ── SharedPreferences helpers (food DB only) ───────────────────────────────

  static bool _isStale(SharedPreferences prefs, String tsKey, int ttlMinutes) {
    final ts = prefs.getInt(tsKey);
    if (ts == null) return true;
    return (_nowMs() - ts) > ttlMinutes * 60 * 1000;
  }

  static int _nowMs() => DateTime.now().millisecondsSinceEpoch;
}
