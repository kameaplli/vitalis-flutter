import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/social_models.dart';

/// Helper: backend may return a raw List or a wrapped object with a key.
/// This handles both shapes gracefully.
List<dynamic> _extractList(dynamic data, String key) {
  if (data is List) return data;
  if (data is Map) return (data[key] as List<dynamic>?) ?? [];
  return [];
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Social Feed Cache ────────────────────────────────────────────────────────
// In-memory cache with TTL. Serves cached data instantly, refreshes in
// background. Supports optimistic reaction/comment mutations.
// ══════════════════════════════════════════════════════════════════════════════

class _FeedCache {
  List<FeedEvent>? _events;
  DateTime? _fetchedAt;
  static const _ttl = Duration(minutes: 3);

  bool get hasFresh =>
      _events != null &&
      _fetchedAt != null &&
      DateTime.now().difference(_fetchedAt!) < _ttl;

  bool get hasStale => _events != null;

  List<FeedEvent> get events => _events ?? [];

  void update(List<FeedEvent> events) {
    _events = events;
    _fetchedAt = DateTime.now();
  }

  void clear() {
    _events = null;
    _fetchedAt = null;
  }

  /// Optimistically update a single event in cache.
  void updateEvent(String eventId, FeedEvent Function(FeedEvent) mutator) {
    if (_events == null) return;
    _events = _events!.map((e) => e.id == eventId ? mutator(e) : e).toList();
  }
}

class _CommentCache {
  final Map<String, List<Comment>> _cache = {};
  final Map<String, DateTime> _fetchedAt = {};
  static const _ttl = Duration(minutes: 2);

  bool hasFresh(String eventId) {
    final t = _fetchedAt[eventId];
    return _cache.containsKey(eventId) &&
        t != null &&
        DateTime.now().difference(t) < _ttl;
  }

  bool hasStale(String eventId) => _cache.containsKey(eventId);

  List<Comment> get(String eventId) => _cache[eventId] ?? [];

  void update(String eventId, List<Comment> comments) {
    _cache[eventId] = comments;
    _fetchedAt[eventId] = DateTime.now();
  }

  void addComment(String eventId, Comment comment) {
    _cache.putIfAbsent(eventId, () => []);
    _cache[eventId]!.add(comment);
  }

  void clear() {
    _cache.clear();
    _fetchedAt.clear();
  }
}

/// Global singleton caches — survive provider invalidation so we can
/// serve stale data while revalidating.
final _feedCache = _FeedCache();
final _recipeFeedCache = _FeedCache();
final _commentCache = _CommentCache();

// ── Social Profile ──────────────────────────────────────────────────────────

final socialProfileProvider = FutureProvider<SocialProfile>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialProfile);
    return SocialProfile.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return SocialProfile(userId: '');
  }
});

final publicProfileProvider =
    FutureProvider.family<SocialProfile, String>((ref, userId) async {
  try {
    final res =
        await apiClient.dio.get(ApiConstants.socialProfileUser(userId));
    return SocialProfile.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return SocialProfile(userId: userId);
  }
});

// ── Connections ─────────────────────────────────────────────────────────────

final connectionsProvider = FutureProvider<List<Connection>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialConnections);
    return _extractList(res.data, 'connections')
        .map((c) => Connection.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final pendingRequestsProvider = FutureProvider<List<Connection>>((ref) async {
  try {
    final res =
        await apiClient.dio.get(ApiConstants.socialConnectionsPending);
    return _extractList(res.data, 'connections')
        .map((c) => Connection.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Feed (Cached + Stale-While-Revalidate) ──────────────────────────────────

/// Feed provider with stale-while-revalidate caching.
/// Returns cached data instantly if available, fetches fresh in background.
final socialFeedProvider =
    FutureProvider.family<List<FeedEvent>, String?>((ref, cursor) async {
  // Only cache the first page (cursor == null)
  final isFirstPage = cursor == null || cursor.isEmpty;

  // If first page and we have fresh cache, return it immediately
  if (isFirstPage && _feedCache.hasFresh) {
    // Schedule background refresh when nearing TTL
    return _feedCache.events;
  }

  // If we have stale cache, return it and kick off background refresh
  if (isFirstPage && _feedCache.hasStale) {
    // Fire off background refresh (don't await)
    _fetchFeed(cursor).then((events) {
      _feedCache.update(events);
      // Silently invalidate to pick up new data on next frame
      ref.invalidateSelf();
    });
    return _feedCache.events;
  }

  // No cache — must wait for network
  try {
    final events = await _fetchFeed(cursor);
    if (isFirstPage) _feedCache.update(events);
    return events;
  } catch (_) {
    // Return stale cache on error if available
    if (isFirstPage && _feedCache.hasStale) return _feedCache.events;
    return [];
  }
});

Future<List<FeedEvent>> _fetchFeed(String? cursor) async {
  final queryParams = <String, dynamic>{};
  if (cursor != null && cursor.isNotEmpty) {
    queryParams['cursor'] = cursor;
  }
  final res = await apiClient.dio.get(
    ApiConstants.socialFeed,
    queryParameters: queryParams,
  );
  return _extractList(res.data, 'events')
      .map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
      .toList();
}

final recipeFeedProvider =
    FutureProvider.family<List<FeedEvent>, String?>((ref, cursor) async {
  final isFirstPage = cursor == null || cursor.isEmpty;

  if (isFirstPage && _recipeFeedCache.hasFresh) {
    return _recipeFeedCache.events;
  }

  if (isFirstPage && _recipeFeedCache.hasStale) {
    _fetchRecipeFeed(cursor).then((events) {
      _recipeFeedCache.update(events);
      ref.invalidateSelf();
    });
    return _recipeFeedCache.events;
  }

  try {
    final events = await _fetchRecipeFeed(cursor);
    if (isFirstPage) _recipeFeedCache.update(events);
    return events;
  } catch (_) {
    if (isFirstPage && _recipeFeedCache.hasStale) {
      return _recipeFeedCache.events;
    }
    return [];
  }
});

Future<List<FeedEvent>> _fetchRecipeFeed(String? cursor) async {
  final queryParams = <String, dynamic>{};
  if (cursor != null && cursor.isNotEmpty) {
    queryParams['cursor'] = cursor;
  }
  final res = await apiClient.dio.get(
    ApiConstants.socialFeedRecipes,
    queryParameters: queryParams,
  );
  return _extractList(res.data, 'events')
      .map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
      .toList();
}

final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialFeedUnreadCount);
    return (res.data['unread_count'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

// ── Optimistic Reaction Helper ──────────────────────────────────────────────
// Call this from UI to get instant feedback. It updates the cache, then
// fires the API call. On failure, it rolls back and invalidates.

/// Toggle a reaction optimistically. Returns immediately after updating cache.
/// The API call runs in the background.
Future<void> optimisticReaction({
  required WidgetRef ref,
  required FeedEvent event,
  required String reactionType,
}) async {
  // 1. Compute optimistic new reactions
  final oldReactions = event.reactions;
  final existing = oldReactions.where((r) => r.type == reactionType).firstOrNull;
  final bool wasReacted = existing?.userReacted ?? false;

  List<ReactionSummary> newReactions;
  if (wasReacted) {
    // Un-react: decrement count, set userReacted false
    newReactions = oldReactions.map((r) {
      if (r.type == reactionType) {
        final newCount = r.count - 1;
        return ReactionSummary(
          type: r.type,
          count: newCount < 0 ? 0 : newCount,
          userReacted: false,
        );
      }
      return r;
    }).where((r) => r.count > 0 || r.type == reactionType).toList();
  } else {
    // React: increment or add
    if (existing != null) {
      newReactions = oldReactions.map((r) {
        if (r.type == reactionType) {
          return ReactionSummary(
            type: r.type,
            count: r.count + 1,
            userReacted: true,
          );
        }
        return r;
      }).toList();
    } else {
      newReactions = [
        ...oldReactions,
        ReactionSummary(type: reactionType, count: 1, userReacted: true),
      ];
    }
  }

  // 2. Update cache instantly
  _feedCache.updateEvent(event.id, (e) => e.copyWith(reactions: newReactions));
  _recipeFeedCache.updateEvent(
      event.id, (e) => e.copyWith(reactions: newReactions));

  // 3. Invalidate provider to reflect cache change in UI
  ref.invalidate(socialFeedProvider(null));

  // 4. Fire API call in background
  try {
    await apiClient.dio.post(
      ApiConstants.socialReactions,
      data: {
        'feed_event_id': event.id,
        'reaction_type': reactionType,
      },
    );
    // After API success, do a silent refresh to sync server state
    _fetchFeed(null).then((events) {
      _feedCache.update(events);
      ref.invalidate(socialFeedProvider(null));
    });
  } catch (_) {
    // Rollback on failure: restore old reactions
    _feedCache.updateEvent(
        event.id, (e) => e.copyWith(reactions: oldReactions));
    _recipeFeedCache.updateEvent(
        event.id, (e) => e.copyWith(reactions: oldReactions));
    ref.invalidate(socialFeedProvider(null));
  }
}

// ── Optimistic Comment Helper ───────────────────────────────────────────────

/// Post a comment optimistically. The comment appears instantly in the sheet,
/// and the comment count updates in the feed card cache.
Future<Comment?> optimisticComment({
  required WidgetRef ref,
  required String eventId,
  required String text,
  required String userName,
  String? userAvatarUrl,
}) async {
  // 1. Create optimistic comment
  final tempComment = Comment(
    id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
    feedEventId: eventId,
    userId: '',
    userName: userName,
    userAvatarUrl: userAvatarUrl,
    text: text,
    createdAt: DateTime.now(),
  );

  // 2. Update caches
  _commentCache.addComment(eventId, tempComment);
  _feedCache.updateEvent(
    eventId,
    (e) => e.copyWith(commentCount: e.commentCount + 1),
  );
  _recipeFeedCache.updateEvent(
    eventId,
    (e) => e.copyWith(commentCount: e.commentCount + 1),
  );

  // 3. Invalidate providers for instant UI update
  ref.invalidate(commentsProvider(eventId));
  ref.invalidate(socialFeedProvider(null));

  // 4. Fire API call
  try {
    final res = await apiClient.dio.post(
      ApiConstants.socialComments,
      data: {
        'feed_event_id': eventId,
        'text': text,
      },
    );
    if (res.data is Map<String, dynamic>) {
      return Comment.fromJson(res.data as Map<String, dynamic>);
    }
    return null;
  } catch (_) {
    // Rollback: decrement comment count
    _feedCache.updateEvent(
      eventId,
      (e) => e.copyWith(commentCount: (e.commentCount - 1).clamp(0, 9999)),
    );
    ref.invalidate(socialFeedProvider(null));
    rethrow;
  }
}

/// Force refresh feed from network (e.g., on pull-to-refresh).
void forceRefreshFeed(WidgetRef ref) {
  _feedCache.clear();
  ref.invalidate(socialFeedProvider(null));
}

/// Force refresh recipe feed.
void forceRefreshRecipeFeed(WidgetRef ref) {
  _recipeFeedCache.clear();
  ref.invalidate(recipeFeedProvider(null));
}

// ── Challenges ──────────────────────────────────────────────────────────────

final challengesProvider = FutureProvider<List<Challenge>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.challenges);
    return _extractList(res.data, 'challenges')
        .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final myChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.challengesMine);
    return _extractList(res.data, 'challenges')
        .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final challengeDetailProvider =
    FutureProvider.family<Challenge, String>((ref, id) async {
  final res = await apiClient.dio.get(ApiConstants.challengeDetail(id));
  return Challenge.fromJson(res.data as Map<String, dynamic>);
});

final challengeLeaderboardProvider =
    FutureProvider.family<List<ChallengeMember>, String>((ref, id) async {
  try {
    final res =
        await apiClient.dio.get(ApiConstants.challengeLeaderboard(id));
    return _extractList(res.data, 'leaderboard')
        .map((m) => ChallengeMember.fromJson(m as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Notifications ───────────────────────────────────────────────────────────

final socialNotificationsProvider =
    FutureProvider<List<SocialNotification>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialNotifications);
    return _extractList(res.data, 'notifications')
        .map((n) => SocialNotification.fromJson(n as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final notificationBadgeProvider = FutureProvider<int>((ref) async {
  try {
    final res =
        await apiClient.dio.get(ApiConstants.socialNotificationsUnread);
    return (res.data['unread_count'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

// ── Dashboard Widget ────────────────────────────────────────────────────────

final communityPulseProvider = FutureProvider<CommunityPulse>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialCommunityPulse);
    return CommunityPulse.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return CommunityPulse();
  }
});

// ── User Search ─────────────────────────────────────────────────────────────

final userSearchProvider =
    FutureProvider.family<List<UserSearchResult>, String>((ref, query) async {
  if (query.trim().isEmpty) return [];
  try {
    final res = await apiClient.dio.get(
      ApiConstants.socialSearch,
      queryParameters: {'q': query},
    );
    return _extractList(res.data, 'results')
        .map((u) => UserSearchResult.fromJson(u as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Comments (Cached) ───────────────────────────────────────────────────────

final commentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, feedEventId) async {
  // Return cached if fresh
  if (_commentCache.hasFresh(feedEventId)) {
    return _commentCache.get(feedEventId);
  }

  // Return stale + background refresh
  if (_commentCache.hasStale(feedEventId)) {
    _fetchComments(feedEventId).then((comments) {
      _commentCache.update(feedEventId, comments);
      ref.invalidateSelf();
    });
    return _commentCache.get(feedEventId);
  }

  try {
    final comments = await _fetchComments(feedEventId);
    _commentCache.update(feedEventId, comments);
    return comments;
  } catch (_) {
    if (_commentCache.hasStale(feedEventId)) {
      return _commentCache.get(feedEventId);
    }
    return [];
  }
});

Future<List<Comment>> _fetchComments(String feedEventId) async {
  final res = await apiClient.dio.get(
    ApiConstants.socialCommentsForEvent(feedEventId),
  );
  return _extractList(res.data, 'comments')
      .map((c) => Comment.fromJson(c as Map<String, dynamic>))
      .toList();
}

// ── Share Card Data ──────────────────────────────────────────────────────────

final shareCardDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, cardType) async {
  final res = await apiClient.dio.get(
    ApiConstants.socialShareCard,
    queryParameters: {'card_type': cardType},
  );
  return res.data as Map<String, dynamic>;
});
