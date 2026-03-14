import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/social_models.dart';

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
    return (res.data['connections'] as List<dynamic>? ?? [])
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
    return (res.data['connections'] as List<dynamic>? ?? [])
        .map((c) => Connection.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

// ── Feed ────────────────────────────────────────────────────────────────────

final socialFeedProvider =
    FutureProvider.family<List<FeedEvent>, int>((ref, page) async {
  try {
    final res = await apiClient.dio.get(
      ApiConstants.socialFeed,
      queryParameters: {'page': page},
    );
    return (res.data['events'] as List<dynamic>? ?? [])
        .map((e) => FeedEvent.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final recipeFeedProvider =
    FutureProvider.family<List<FeedEvent>, int>((ref, page) async {
  try {
    final res = await apiClient.dio.get(
      ApiConstants.socialFeedRecipes,
      queryParameters: {'page': page},
    );
    return (res.data['events'] as List<dynamic>? ?? [])
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
    return (res.data['challenges'] as List<dynamic>? ?? [])
        .map((c) => Challenge.fromJson(c as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});

final myChallengesProvider = FutureProvider<List<Challenge>>((ref) async {
  try {
    final res = await apiClient.dio.get(ApiConstants.challengesMine);
    return (res.data['challenges'] as List<dynamic>? ?? [])
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
    return (res.data['leaderboard'] as List<dynamic>? ?? [])
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
    return (res.data['notifications'] as List<dynamic>? ?? [])
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
    return (res.data['results'] as List<dynamic>? ?? [])
        .map((u) => UserSearchResult.fromJson(u as Map<String, dynamic>))
        .toList();
  } catch (_) {
    return [];
  }
});
