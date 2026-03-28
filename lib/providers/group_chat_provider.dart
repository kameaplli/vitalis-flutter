import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/group_chat_models.dart';
import '../services/social_cache_service.dart';

// ── Groups State ────────────────────────────────────────────────────────────

class GroupsState {
  final List<GroupChat> groups;
  final bool isLoading;
  final String? error;

  const GroupsState({
    this.groups = const [],
    this.isLoading = true,
    this.error,
  });

  GroupsState copyWith({
    List<GroupChat>? groups,
    bool? isLoading,
    String? error,
  }) =>
      GroupsState(
        groups: groups ?? this.groups,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class GroupsNotifier extends StateNotifier<GroupsState> {
  GroupsNotifier() : super(const GroupsState()) {
    _load();
  }

  Future<void> _load() async {
    final cached = await SocialCacheService.loadGroups();
    if (cached != null && cached.isNotEmpty && mounted) {
      state = state.copyWith(groups: cached, isLoading: false);
    }
    try {
      final res = await apiClient.dio.get(ApiConstants.groupChats);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['groups'] as List? ?? [];
      final groups = list
          .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = state.copyWith(groups: groups, isLoading: false);
      SocialCacheService.saveGroups(groups);
    } catch (e) {
      if (mounted && state.groups.isEmpty) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> refresh() async {
    try {
      final res = await apiClient.dio.get(ApiConstants.groupChats);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['groups'] as List? ?? [];
      final groups = list
          .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = state.copyWith(groups: groups, error: null);
      SocialCacheService.saveGroups(groups);
    } catch (_) {}
  }
}

final groupsNotifierProvider =
    StateNotifierProvider<GroupsNotifier, GroupsState>((ref) {
  return GroupsNotifier();
});

// ── Legacy (still used in some places) ──────────────────────────────────────

/// All visible group chats (public + user's private groups).
final groupChatsProvider = FutureProvider<List<GroupChat>>((ref) async {
  ref.keepAlive();
  final res = await apiClient.dio.get(ApiConstants.groupChats);
  final list = res.data is List
      ? res.data as List
      : (res.data as Map)['groups'] as List? ?? [];
  return list
      .map((e) => GroupChat.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Single group chat detail.
final groupChatDetailProvider =
    FutureProvider.family<GroupChat, String>((ref, groupId) async {
  final res = await apiClient.dio.get(ApiConstants.groupChatDetail(groupId));
  return GroupChat.fromJson(res.data as Map<String, dynamic>);
});

/// Members of a group chat.
final groupChatMembersProvider =
    FutureProvider.family<List<GroupMember>, String>((ref, groupId) async {
  final res = await apiClient.dio.get(ApiConstants.groupChatMembers(groupId));
  final list = res.data is List
      ? res.data as List
      : (res.data as Map)['members'] as List? ?? [];
  return list
      .map((e) => GroupMember.fromJson(e as Map<String, dynamic>))
      .toList();
});

// ── Chat Messages (StateNotifier for real-time feel) ────────────────────────

class ChatState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool hasMore;
  final String? error;

  const ChatState({
    this.messages = const [],
    this.isLoading = true,
    this.hasMore = true,
    this.error,
  });

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? hasMore,
    String? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

class ChatNotifier extends StateNotifier<ChatState> {
  final String _groupId;
  Timer? _pollTimer;

  ChatNotifier(this._groupId) : super(const ChatState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final messages = await _fetchMessages();
      if (mounted) {
        state = ChatState(
          messages: messages,
          isLoading: false,
          hasMore: messages.length >= 50,
        );
      }
      // Poll for new messages every 5 seconds
      _pollTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => _pollNewMessages(),
      );
    } catch (e) {
      if (mounted) {
        state = ChatState(isLoading: false, error: e.toString());
      }
    }
  }

  Future<List<ChatMessage>> _fetchMessages({String? before}) async {
    final params = <String, dynamic>{};
    if (before != null) params['before'] = before;
    final res = await apiClient.dio.get(
      ApiConstants.groupChatMessages(_groupId),
      queryParameters: params,
    );
    final list = res.data is List
        ? res.data as List
        : (res.data as Map)['messages'] as List? ?? [];
    return list
        .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Load older messages (infinite scroll up).
  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    if (state.messages.isEmpty) return;
    try {
      final oldest = state.messages.last;
      final older = await _fetchMessages(before: oldest.id);
      if (mounted) {
        state = state.copyWith(
          messages: [...state.messages, ...older],
          hasMore: older.length >= 50,
        );
      }
    } catch (_) {}
  }

  /// Poll for new messages (prepend to top).
  Future<void> _pollNewMessages() async {
    if (!mounted) return;
    try {
      final fresh = await _fetchMessages();
      if (!mounted || fresh.isEmpty) return;
      // Only update if there are genuinely new messages
      final currentIds = state.messages.map((m) => m.id).toSet();
      final newOnes = fresh.where((m) => !currentIds.contains(m.id)).toList();
      if (newOnes.isNotEmpty) {
        state = state.copyWith(messages: [...newOnes, ...state.messages]);
      }
    } catch (_) {}
  }

  /// Optimistic send — show message locally, then sync to server.
  Future<void> sendMessage(String text, {String? senderName, String? senderId}) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = ChatMessage(
      id: tempId,
      groupId: _groupId,
      senderId: senderId ?? '',
      senderName: senderName ?? 'You',
      text: text,
      createdAt: DateTime.now(),
    );

    // Show immediately
    state = state.copyWith(messages: [optimistic, ...state.messages]);

    try {
      await apiClient.dio.post(
        ApiConstants.groupChatMessages(_groupId),
        data: {'text': text},
      );
      // Remove optimistic, let next poll pick up the server version
      if (mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
        );
        await _pollNewMessages();
      }
    } catch (_) {
      // Keep optimistic message visible on failure
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final chatNotifierProvider =
    StateNotifierProvider.family<ChatNotifier, ChatState, String>(
        (ref, groupId) {
  return ChatNotifier(groupId);
});

// ── Group Chat Actions ──────────────────────────────────────────────────────

Future<GroupChat> createGroupChat({
  required String name,
  String? description,
  GroupChatAccess access = GroupChatAccess.public_,
  List<String>? invitedUserIds,
}) async {
  final res = await apiClient.dio.post(ApiConstants.groupChats, data: {
    'name': name,
    if (description != null) 'description': description,
    'access': access.value,
    if (invitedUserIds != null) 'invited_user_ids': invitedUserIds,
  });
  return GroupChat.fromJson(res.data as Map<String, dynamic>);
}

Future<void> joinGroupChat(String groupId) async {
  await apiClient.dio.post(ApiConstants.groupChatJoin(groupId));
}

Future<void> leaveGroupChat(String groupId) async {
  await apiClient.dio.post(ApiConstants.groupChatLeave(groupId));
}

Future<void> inviteToGroupChat(String groupId, List<String> userIds) async {
  await apiClient.dio.post(
    ApiConstants.groupChatInvite(groupId),
    data: {'user_ids': userIds},
  );
}
