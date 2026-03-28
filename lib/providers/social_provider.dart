import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/social_models.dart';
import '../services/social_cache_service.dart';

/// Helper: backend may return a raw List or a wrapped object with a key.
List<dynamic> _extractList(dynamic data, String key) {
  if (data is List) return data;
  if (data is Map) return (data[key] as List<dynamic>?) ?? [];
  return [];
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Feed State + Notifier ────────────────────────────────────────────────────
// Uses StateNotifier so we can update state WITHOUT going through loading.
// The key insight: FutureProvider.invalidate() always resets to loading state,
// which causes UI flicker. StateNotifier lets us replace data in-place.
// ══════════════════════════════════════════════════════════════════════════════

class FeedState {
  final List<FeedEvent> events;
  final bool isLoading;    // true only on very first load
  final bool isRefreshing; // true during background refresh (no UI change)
  final bool isLoadingMore; // true during infinite scroll load
  final bool hasMore;       // false when all pages exhausted
  final String? error;

  const FeedState({
    this.events = const [],
    this.isLoading = true,
    this.isRefreshing = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
  });

  FeedState copyWith({
    List<FeedEvent>? events,
    bool? isLoading,
    bool? isRefreshing,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
  }) =>
      FeedState(
        events: events ?? this.events,
        isLoading: isLoading ?? this.isLoading,
        isRefreshing: isRefreshing ?? this.isRefreshing,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class FeedNotifier extends StateNotifier<FeedState> {
  final String _endpoint;
  final bool _isRecipeFeed;
  Timer? _refreshTimer;

  FeedNotifier(this._endpoint, {String? contentTypeFilter})
      : _isRecipeFeed = contentTypeFilter != null,
        super(const FeedState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    // ── Step 1: Render from local cache instantly (no network wait) ──
    final cached = _isRecipeFeed
        ? await SocialCacheService.loadRecipeFeed()
        : await SocialCacheService.loadFeed();
    if (cached != null && cached.isNotEmpty && mounted) {
      state = FeedState(events: cached, isLoading: false);
    }

    // ── Step 2: Fetch fresh data in background, merge in-place ──
    // If cache was loaded, this is a silent background update (no loading state).
    // If no cache, user sees loading spinner until network returns.
    try {
      final events = await _fetch(null);
      if (mounted) {
        state = FeedState(events: events, isLoading: false);
        // Persist to cache for next cold start
        if (_isRecipeFeed) {
          SocialCacheService.saveRecipeFeed(events);
        } else {
          SocialCacheService.saveFeed(events);
        }
      }
      // Auto-refresh every 2 minutes in background
      _refreshTimer = Timer.periodic(
        const Duration(minutes: 2),
        (_) => refreshInBackground(),
      );
    } catch (e) {
      if (mounted) {
        // If we have cache, keep showing it (no error state)
        if (state.events.isNotEmpty) {
          state = state.copyWith(isLoading: false);
          _refreshTimer = Timer.periodic(
            const Duration(minutes: 2),
            (_) => refreshInBackground(),
          );
        } else {
          state = FeedState(isLoading: false, error: e.toString());
        }
      }
    }
  }

  Future<List<FeedEvent>> _fetch(String? cursor) async {
    final queryParams = <String, dynamic>{};
    if (cursor != null && cursor.isNotEmpty) {
      queryParams['cursor'] = cursor;
    }
    final res = await apiClient.dio.get(
      _endpoint,
      queryParameters: queryParams,
    );
    return _extractList(res.data, 'events')
        .map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Refresh feed in background — no loading state shown.
  /// Updates local cache after successful fetch.
  Future<void> refreshInBackground() async {
    if (state.isRefreshing) return;
    state = state.copyWith(isRefreshing: true);
    try {
      final events = await _fetch(null);
      if (mounted) {
        state = state.copyWith(events: events, isRefreshing: false, error: null);
        // Update cache for next cold start
        if (_isRecipeFeed) {
          SocialCacheService.saveRecipeFeed(events);
        } else {
          SocialCacheService.saveFeed(events);
        }
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isRefreshing: false);
    }
  }

  /// Full refresh — shows loading ONLY if no data exists.
  Future<void> forceRefresh() async {
    if (state.events.isEmpty) {
      state = state.copyWith(isLoading: true);
    }
    try {
      final events = await _fetch(null);
      if (mounted) {
        state = FeedState(events: events, isLoading: false);
        if (_isRecipeFeed) {
          SocialCacheService.saveRecipeFeed(events);
        } else {
          SocialCacheService.saveFeed(events);
        }
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(
          isLoading: false,
          error: state.events.isEmpty ? e.toString() : null,
        );
      }
    }
  }

  /// Load next page of events (infinite scroll).
  /// Uses the last event's ID as cursor for the backend.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.events.isEmpty) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final cursor = state.events.last.id;
      final moreEvents = await _fetch(cursor);
      if (mounted) {
        state = state.copyWith(
          events: [...state.events, ...moreEvents],
          isLoadingMore: false,
          hasMore: moreEvents.length >= 20, // page size assumed 20
        );
      }
    } catch (_) {
      if (mounted) state = state.copyWith(isLoadingMore: false);
    }
  }

  /// Optimistic reaction — updates local state instantly, syncs in background.
  /// Handles: toggle off (same type), switch (different type), new reaction.
  void optimisticReact(FeedEvent event, String reactionType) {
    final oldReactions = event.reactions;

    // Find user's current reaction (any type)
    final userCurrent = oldReactions.where((r) => r.userReacted).firstOrNull;
    final tappedSameType = userCurrent?.type == reactionType;

    List<ReactionSummary> newReactions;

    if (userCurrent != null && tappedSameType) {
      // Toggle OFF — user tapped the same reaction they already have
      newReactions = oldReactions.map((r) {
        if (r.type == reactionType) {
          return ReactionSummary(
            type: r.type,
            count: (r.count - 1).clamp(0, 99999),
            userReacted: false,
          );
        }
        return r;
      }).where((r) => r.count > 0).toList();
    } else if (userCurrent != null) {
      // SWITCH — user already reacted with a different type, replace it
      // Decrement old type, increment new type
      var handled = false;
      newReactions = oldReactions.map((r) {
        if (r.type == userCurrent.type) {
          // Remove user from old reaction
          return ReactionSummary(
            type: r.type,
            count: (r.count - 1).clamp(0, 99999),
            userReacted: false,
          );
        }
        if (r.type == reactionType) {
          // Add user to new reaction
          handled = true;
          return ReactionSummary(
            type: r.type,
            count: r.count + 1,
            userReacted: true,
          );
        }
        return r;
      }).where((r) => r.count > 0).toList();
      // If the new reaction type didn't exist yet, add it
      if (!handled) {
        newReactions.add(
          ReactionSummary(type: reactionType, count: 1, userReacted: true),
        );
      }
    } else {
      // NEW — no existing reaction from user
      final existingType =
          oldReactions.where((r) => r.type == reactionType).firstOrNull;
      if (existingType != null) {
        newReactions = oldReactions.map((r) {
          if (r.type == reactionType) {
            return ReactionSummary(
                type: r.type, count: r.count + 1, userReacted: true);
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

    // Update state instantly
    _updateEvent(event.id, (e) => e.copyWith(reactions: newReactions));

    // Fire API in background
    apiClient.dio.post(ApiConstants.socialReactions, data: {
      'feed_event_id': event.id,
      'reaction_type': reactionType,
    }).then((_) {
      // Silent background refresh after API success
      refreshInBackground();
    }).catchError((_) {
      // Rollback on failure
      _updateEvent(event.id, (e) => e.copyWith(reactions: oldReactions));
    });
  }

  /// Optimistic comment count increment.
  void incrementCommentCount(String eventId) {
    _updateEvent(eventId, (e) => e.copyWith(commentCount: e.commentCount + 1));
  }

  void _updateEvent(String eventId, FeedEvent Function(FeedEvent) mutator) {
    if (!mounted) return;
    state = state.copyWith(
      events: state.events
          .map((e) => e.id == eventId ? mutator(e) : e)
          .toList(),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// ── Feed Providers ──────────────────────────────────────────────────────────

final socialFeedNotifierProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  ref.keepAlive();
  return FeedNotifier(ApiConstants.socialFeed);
});

final recipeFeedNotifierProvider =
    StateNotifierProvider<FeedNotifier, FeedState>((ref) {
  ref.keepAlive();
  return FeedNotifier(ApiConstants.socialFeedRecipes,
      contentTypeFilter: 'recipe');
});

/// Legacy compatibility — keep for providers that just need the list.
final socialFeedProvider =
    Provider.family<AsyncValue<List<FeedEvent>>, String?>((ref, cursor) {
  ref.keepAlive();
  final feedState = ref.watch(socialFeedNotifierProvider);
  if (feedState.isLoading) return const AsyncLoading();
  if (feedState.error != null && feedState.events.isEmpty) {
    return AsyncError(feedState.error!, StackTrace.current);
  }
  return AsyncData(feedState.events);
});

final recipeFeedProvider =
    Provider.family<AsyncValue<List<FeedEvent>>, String?>((ref, cursor) {
  ref.keepAlive();
  final feedState = ref.watch(recipeFeedNotifierProvider);
  if (feedState.isLoading) return const AsyncLoading();
  if (feedState.error != null && feedState.events.isEmpty) {
    return AsyncError(feedState.error!, StackTrace.current);
  }
  return AsyncData(feedState.events);
});

// ── Helper Functions (called from UI) ───────────────────────────────────────

/// Force refresh feed — use for pull-to-refresh.
void forceRefreshFeed(WidgetRef ref) {
  ref.read(socialFeedNotifierProvider.notifier).forceRefresh();
}

/// Force refresh recipe feed.
void forceRefreshRecipeFeed(WidgetRef ref) {
  ref.read(recipeFeedNotifierProvider.notifier).forceRefresh();
}

/// Optimistic reaction — instant UI, background API sync.
void optimisticReaction({
  required WidgetRef ref,
  required FeedEvent event,
  required String reactionType,
}) {
  ref
      .read(socialFeedNotifierProvider.notifier)
      .optimisticReact(event, reactionType);
  // Also update recipe feed if it contains this event
  ref
      .read(recipeFeedNotifierProvider.notifier)
      .optimisticReact(event, reactionType);
}

// ── Social Profile ──────────────────────────────────────────────────────────

final socialProfileProvider = FutureProvider<SocialProfile>((ref) async {
  ref.keepAlive();
  try {
    final res = await apiClient.dio.get(ApiConstants.socialProfile);
    return SocialProfile.fromJson(res.data as Map<String, dynamic>);
  } catch (_) {
    return SocialProfile(userId: '');
  }
});

final publicProfileProvider =
    FutureProvider.family<SocialProfile, String>((ref, userId) async {
  ref.keepAlive();
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
  ref.keepAlive();
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
  ref.keepAlive();
  try {
    final res =
        await apiClient.dio.get(ApiConstants.socialConnectionsPending);
    return _extractList(res.data, 'connections')
        .map((c) => Connection.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // Rethrow so UI can show errors; silently returning [] hides real issues
    rethrow;
  }
});

// ── Unread Count ────────────────────────────────────────────────────────────

final unreadCountProvider = FutureProvider<int>((ref) async {
  ref.keepAlive();
  try {
    final res = await apiClient.dio.get(ApiConstants.socialFeedUnreadCount);
    return (res.data['unread_count'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

// ── Challenges ──────────────────────────────────────────────────────────────

final challengesProvider = FutureProvider<List<Challenge>>((ref) async {
  ref.keepAlive();
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
  ref.keepAlive();
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
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.challengeDetail(id));
  return Challenge.fromJson(res.data as Map<String, dynamic>);
});

final challengeLeaderboardProvider =
    FutureProvider.family<List<ChallengeMember>, String>((ref, id) async {
  ref.keepAlive();
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
  ref.keepAlive();
  try {
    final res = await apiClient.dio.get(ApiConstants.socialNotifications);
    return _extractList(res.data, 'notifications')
        .map((n) => SocialNotification.fromJson(n as Map<String, dynamic>))
        .toList();
  } catch (e) {
    // Rethrow so the UI can show errors instead of silently returning empty
    rethrow;
  }
});

final notificationBadgeProvider = FutureProvider<int>((ref) async {
  ref.keepAlive();
  try {
    final res =
        await apiClient.dio.get(ApiConstants.socialNotificationsUnread);
    final count = (res.data['unread_count'] as num?)?.toInt() ?? 0;

    // Auto-refresh badge every 60 seconds
    final timer = Timer(const Duration(seconds: 60), () {
      ref.invalidateSelf();
    });
    ref.onDispose(timer.cancel);

    return count;
  } catch (_) {
    return 0;
  }
});

// ── Dashboard Widget ────────────────────────────────────────────────────────

final communityPulseProvider = FutureProvider<CommunityPulse>((ref) async {
  ref.keepAlive();
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
  ref.keepAlive();
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

// ── Comments ────────────────────────────────────────────────────────────────

final commentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, feedEventId) async {
  ref.keepAlive();
  try {
    final res = await apiClient.dio.get(
      ApiConstants.socialCommentsForEvent(feedEventId),
    );
    return _extractList(res.data, 'comments')
        .map((c) => Comment.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Report & Block ──────────────────────────────────────────────────────────

/// Submit a report against content or a user.
Future<void> submitReport({
  required ReportTargetType targetType,
  required String targetId,
  required ReportReason reason,
  String? details,
}) async {
  await apiClient.dio.post(ApiConstants.socialReport, data: {
    'target_type': targetType.value,
    'target_id': targetId,
    'reason': reason.value,
    if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
  });
}

/// Block a user.
Future<void> blockUser(String userId) async {
  await apiClient.dio.post(ApiConstants.socialBlock, data: {
    'user_id': userId,
  });
}

/// Unblock a user.
Future<void> unblockUser(String userId) async {
  await apiClient.dio.delete(ApiConstants.socialUnblock(userId));
}

/// Provider for blocked users list.
final blockedUsersProvider = FutureProvider<List<BlockedUser>>((ref) async {
  ref.keepAlive();
  try {
    final res = await apiClient.dio.get(ApiConstants.socialBlockedUsers);
    return _extractList(res.data, 'blocked_users')
        .map((u) => BlockedUser.fromJson(u as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Share Card Data ──────────────────────────────────────────────────────────

final shareCardDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, cardType) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(
    ApiConstants.socialShareCard,
    queryParameters: {'card_type': cardType},
  );
  return res.data as Map<String, dynamic>;
});
