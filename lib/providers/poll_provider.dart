import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/poll_models.dart';
import '../services/social_cache_service.dart';

// ── Poll State ──────────────────────────────────────────────────────────────

class PollsState {
  final List<Poll> polls;
  final bool isLoading;
  final String? error;

  const PollsState({
    this.polls = const [],
    this.isLoading = true,
    this.error,
  });

  PollsState copyWith({
    List<Poll>? polls,
    bool? isLoading,
    String? error,
  }) =>
      PollsState(
        polls: polls ?? this.polls,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

// ── Polls Notifier (optimistic voting, no double-refresh) ───────────────────

class PollsNotifier extends StateNotifier<PollsState> {
  PollsNotifier() : super(const PollsState()) {
    _load();
  }

  Future<void> _load() async {
    // Local-first: render from cache instantly, then sync from network
    final cached = await SocialCacheService.loadPolls();
    if (cached != null && cached.isNotEmpty && mounted) {
      state = state.copyWith(polls: cached, isLoading: false);
    }

    // Background network fetch
    try {
      final res = await apiClient.dio.get(ApiConstants.polls);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['polls'] as List? ?? [];
      final polls =
          list.map((e) => Poll.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) state = state.copyWith(polls: polls, isLoading: false);
      SocialCacheService.savePolls(polls);
    } catch (e) {
      if (mounted && state.polls.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> refresh() async {
    try {
      final res = await apiClient.dio.get(ApiConstants.polls);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['polls'] as List? ?? [];
      final polls =
          list.map((e) => Poll.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) state = state.copyWith(polls: polls, error: null);
      SocialCacheService.savePolls(polls);
    } catch (_) {}
  }

  /// Optimistic vote — update UI immediately, then sync with server.
  Future<void> vote(String pollId, String optionId) async {
    // Optimistic: mark voted locally
    final idx = state.polls.indexWhere((p) => p.id == pollId);
    if (idx == -1) return;

    final poll = state.polls[idx];
    final updatedOptions = poll.options.map((o) {
      if (o.id == optionId) {
        return o.copyWith(voteCount: o.voteCount + 1);
      }
      return o;
    }).toList();

    final optimistic = poll.copyWith(
      options: updatedOptions,
      userVoteOptionId: optionId,
      totalVotes: poll.totalVotes + 1,
    );

    final updated = List<Poll>.from(state.polls);
    updated[idx] = optimistic;
    state = state.copyWith(polls: updated);

    // Server sync
    try {
      final serverPoll = await votePoll(pollId, optionId);
      final syncIdx = state.polls.indexWhere((p) => p.id == pollId);
      if (syncIdx != -1 && mounted) {
        final synced = List<Poll>.from(state.polls);
        synced[syncIdx] = serverPoll;
        state = state.copyWith(polls: synced);
      }
    } catch (_) {
      // Revert on failure
      if (mounted) {
        final revertIdx = state.polls.indexWhere((p) => p.id == pollId);
        if (revertIdx != -1) {
          final reverted = List<Poll>.from(state.polls);
          reverted[revertIdx] = poll;
          state = state.copyWith(polls: reverted);
        }
      }
    }
  }
}

final pollsNotifierProvider =
    StateNotifierProvider<PollsNotifier, PollsState>((ref) {
  return PollsNotifier();
});

// ── Legacy providers (still used for detail/mine) ───────────────────────────

/// All public + user-visible polls (feed tab).
final pollsProvider = FutureProvider<List<Poll>>((ref) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.polls);
  final list = res.data is List
      ? res.data as List
      : (res.data as Map)['polls'] as List? ?? [];
  return list.map((e) => Poll.fromJson(e as Map<String, dynamic>)).toList();
});

/// Polls created by current user.
final myPollsProvider = FutureProvider<List<Poll>>((ref) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.pollsMine);
  final list = res.data is List
      ? res.data as List
      : (res.data as Map)['polls'] as List? ?? [];
  return list.map((e) => Poll.fromJson(e as Map<String, dynamic>)).toList();
});

/// Single poll detail.
final pollDetailProvider =
    FutureProvider.family<Poll, String>((ref, pollId) async {
  final res = await apiClient.dio.get(ApiConstants.pollDetail(pollId));
  return Poll.fromJson(res.data as Map<String, dynamic>);
});

// ── Poll Actions ────────────────────────────────────────────────────────────

/// Create a new poll.
Future<Poll> createPoll({
  required String question,
  required List<String> options,
  PollAccess access = PollAccess.public_,
  int durationHours = 24,
  List<String>? invitedUserIds,
}) async {
  final res = await apiClient.dio.post(ApiConstants.polls, data: {
    'question': question,
    'options': options,
    'access': access.value,
    'duration_hours': durationHours,
    if (invitedUserIds != null) 'invited_user_ids': invitedUserIds,
  });
  return Poll.fromJson(res.data as Map<String, dynamic>);
}

/// Vote on a poll option. Returns updated poll.
Future<Poll> votePoll(String pollId, String optionId) async {
  final res = await apiClient.dio.post(
    ApiConstants.pollVote(pollId),
    data: {'option_id': optionId},
  );
  return Poll.fromJson(res.data as Map<String, dynamic>);
}

/// Invite users to an invite-only poll.
Future<void> inviteToPoll(String pollId, List<String> userIds) async {
  await apiClient.dio.post(
    ApiConstants.pollInvite(pollId),
    data: {'user_ids': userIds},
  );
}

// ── Poll Comments ──────────────────────────────────────────────────────────

/// Comments on a specific poll.
final pollCommentsProvider =
    FutureProvider.family<List<PollComment>, String>((ref, pollId) async {
  final res = await apiClient.dio.get(ApiConstants.pollComments(pollId));
  final list = res.data is List
      ? res.data as List
      : (res.data as Map)['comments'] as List? ?? [];
  return list
      .map((e) => PollComment.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Post a comment on a poll. Returns the new comment.
Future<PollComment> postPollComment(String pollId, String text) async {
  final res = await apiClient.dio.post(
    ApiConstants.pollComments(pollId),
    data: {'text': text},
  );
  return PollComment.fromJson(res.data as Map<String, dynamic>);
}
