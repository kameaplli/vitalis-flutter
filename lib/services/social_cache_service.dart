import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/social_models.dart';
import '../models/poll_models.dart';
import '../models/group_chat_models.dart';

/// Local-first cache for social feed data.
/// Stores feed events as JSON in SharedPreferences for instant rendering
/// on tab open. Background sync updates the cache transparently.
class SocialCacheService {
  static const _feedKey = 'social_feed_cache';
  static const _recipeFeedKey = 'social_recipe_feed_cache';
  static const _feedTimestampKey = 'social_feed_cache_ts';
  static const _recipeFeedTimestampKey = 'social_recipe_feed_cache_ts';
  static const _maxCacheAge = Duration(hours: 24);
  static const _maxCachedEvents = 15;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  // ── Save ──────────────────────────────────────────────────────────────────

  /// Persist feed events to local cache (called after successful API fetch).
  static Future<void> saveFeed(List<FeedEvent> events) async {
    await _saveEvents(_feedKey, _feedTimestampKey, events);
  }

  /// Persist recipe feed events to local cache.
  static Future<void> saveRecipeFeed(List<FeedEvent> events) async {
    await _saveEvents(_recipeFeedKey, _recipeFeedTimestampKey, events);
  }

  static Future<void> _saveEvents(
    String key, String tsKey, List<FeedEvent> events,
  ) async {
    try {
      final prefs = await _prefs();
      // Only cache the most recent N events to keep storage bounded
      final capped = events.take(_maxCachedEvents).toList();
      final json = jsonEncode(capped.map((e) => e.toJson()).toList());
      await prefs.setString(key, json);
      await prefs.setInt(tsKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {
      // Cache write failure is non-critical — feed still works via network
    }
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  /// Load cached feed events. Returns null if no cache or cache expired.
  static Future<List<FeedEvent>?> loadFeed() async {
    return _loadEvents(_feedKey, _feedTimestampKey);
  }

  /// Load cached recipe feed events.
  static Future<List<FeedEvent>?> loadRecipeFeed() async {
    return _loadEvents(_recipeFeedKey, _recipeFeedTimestampKey);
  }

  static Future<List<FeedEvent>?> _loadEvents(
    String key, String tsKey,
  ) async {
    try {
      final prefs = await _prefs();
      final ts = prefs.getInt(tsKey);
      if (ts == null) return null;

      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
      if (age > _maxCacheAge) {
        // Cache too old — clear it and return null so we fetch fresh
        await prefs.remove(key);
        await prefs.remove(tsKey);
        return null;
      }

      final json = prefs.getString(key);
      if (json == null) return null;

      final list = jsonDecode(json) as List;
      return list
          .map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Polls Cache ─────────────────────────────────────────────────────────

  static const _pollsKey = 'social_polls_cache';
  static const _pollsTimestampKey = 'social_polls_cache_ts';

  static Future<void> savePolls(List<Poll> polls) async {
    try {
      final prefs = await _prefs();
      final json = jsonEncode(polls.map((p) => p.toJson()).toList());
      await prefs.setString(_pollsKey, json);
      await prefs.setInt(_pollsTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<List<Poll>?> loadPolls() async {
    try {
      final prefs = await _prefs();
      final ts = prefs.getInt(_pollsTimestampKey);
      if (ts == null) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > _maxCacheAge) {
        await prefs.remove(_pollsKey);
        await prefs.remove(_pollsTimestampKey);
        return null;
      }
      final json = prefs.getString(_pollsKey);
      if (json == null) return null;
      final list = jsonDecode(json) as List;
      return list
          .map((e) => Poll.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Groups Cache ────────────────────────────────────────────────────────

  static const _groupsKey = 'social_groups_cache';
  static const _groupsTimestampKey = 'social_groups_cache_ts';

  static Future<void> saveGroups(List<GroupChat> groups) async {
    try {
      final prefs = await _prefs();
      final json = jsonEncode(groups.map((g) => g.toJson()).toList());
      await prefs.setString(_groupsKey, json);
      await prefs.setInt(
          _groupsTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (_) {}
  }

  static Future<List<GroupChat>?> loadGroups() async {
    try {
      final prefs = await _prefs();
      final ts = prefs.getInt(_groupsTimestampKey);
      if (ts == null) return null;
      final age = DateTime.now()
          .difference(DateTime.fromMillisecondsSinceEpoch(ts));
      if (age > _maxCacheAge) {
        await prefs.remove(_groupsKey);
        await prefs.remove(_groupsTimestampKey);
        return null;
      }
      final json = prefs.getString(_groupsKey);
      if (json == null) return null;
      final list = jsonDecode(json) as List;
      return list
          .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return null;
    }
  }

  // ── Invalidate ────────────────────────────────────────────────────────────

  /// Clear all cached feed data (e.g., on logout).
  static Future<void> clearAll() async {
    try {
      final prefs = await _prefs();
      await prefs.remove(_feedKey);
      await prefs.remove(_recipeFeedKey);
      await prefs.remove(_feedTimestampKey);
      await prefs.remove(_recipeFeedTimestampKey);
      await prefs.remove(_pollsKey);
      await prefs.remove(_pollsTimestampKey);
      await prefs.remove(_groupsKey);
      await prefs.remove(_groupsTimestampKey);
    } catch (_) {}
  }

  /// Check if cache exists and is fresh.
  static Future<bool> hasFreshCache() async {
    try {
      final prefs = await _prefs();
      final ts = prefs.getInt(_feedTimestampKey);
      if (ts == null) return false;
      final age = DateTime.now().difference(
        DateTime.fromMillisecondsSinceEpoch(ts),
      );
      return age <= _maxCacheAge;
    } catch (_) {
      return false;
    }
  }
}
