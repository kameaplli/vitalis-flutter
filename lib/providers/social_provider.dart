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

// ── Feed ────────────────────────────────────────────────────────────────────

/// Feed provider uses cursor-based pagination.
/// Pass `null` or empty string for the first page, or the last event ID as cursor.
final socialFeedProvider =
    FutureProvider.family<List<FeedEvent>, String?>((ref, cursor) async {
  try {
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
  } catch (_) {
    return [];
  }
});

final recipeFeedProvider =
    FutureProvider.family<List<FeedEvent>, String?>((ref, cursor) async {
  try {
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
  } catch (_) {
    return [];
  }
});

final unreadCountProvider = FutureProvider<int>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.socialFeedUnreadCount);
    return (res.data['unread_count'] as num?)?.toInt() ?? 0;
  } catch (_) {
    return 0;
  }
});

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

// ── Comments ─────────────────────────────────────────────────────────────────

final commentsProvider =
    FutureProvider.family<List<Comment>, String>((ref, feedEventId) async {
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

// ── Share Card Data ──────────────────────────────────────────────────────────

final shareCardDataProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, cardType) async {
  final res = await apiClient.dio.get(
    ApiConstants.socialShareCard,
    queryParameters: {'card_type': cardType},
  );
  return res.data as Map<String, dynamic>;
});
