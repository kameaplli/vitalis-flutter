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

  /// Mark all messages in this group as read.
  Future<void> markAsRead() async {
    try {
      await apiClient.dio.post(
        '${ApiConstants.groupChatMessages(_groupId)}/read',
      );
    } catch (_) {}
  }

  /// React to a message with an emoji. Optimistic update.
  void reactToMessage(String messageId, String emoji) {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = state.messages[idx];

    // Toggle: if user already reacted with this emoji, remove it
    final existing = msg.reactions.where((r) => r.emoji == emoji).firstOrNull;
    List<MessageReaction> newReactions;

    if (existing != null && existing.userReacted) {
      // Un-react
      newReactions = msg.reactions.map((r) {
        if (r.emoji == emoji) {
          return MessageReaction(
            emoji: r.emoji,
            count: (r.count - 1).clamp(0, 99999),
            userReacted: false,
          );
        }
        return r;
      }).where((r) => r.count > 0).toList();
    } else if (existing != null) {
      // Add user to existing reaction
      newReactions = msg.reactions.map((r) {
        if (r.emoji == emoji) {
          return MessageReaction(
            emoji: r.emoji,
            count: r.count + 1,
            userReacted: true,
          );
        }
        return r;
      }).toList();
    } else {
      // New reaction type
      newReactions = [
        ...msg.reactions,
        MessageReaction(emoji: emoji, count: 1, userReacted: true),
      ];
    }

    final updated = List<ChatMessage>.from(state.messages);
    updated[idx] = msg.copyWith(reactions: newReactions);
    state = state.copyWith(messages: updated);

    // Background API call
    apiClient.dio.post(
      '${ApiConstants.groupChatMessages(_groupId)}/$messageId/react',
      data: {'emoji': emoji},
    ).catchError((_) {
      // Revert on failure
      if (mounted) {
        final revertIdx = state.messages.indexWhere((m) => m.id == messageId);
        if (revertIdx != -1) {
          final reverted = List<ChatMessage>.from(state.messages);
          reverted[revertIdx] = msg;
          state = state.copyWith(messages: reverted);
        }
      }
    });
  }

  /// Pin or unpin a message (admin-only).
  Future<void> togglePin(String messageId) async {
    final idx = state.messages.indexWhere((m) => m.id == messageId);
    if (idx == -1) return;
    final msg = state.messages[idx];
    final newPinned = !msg.isPinned;

    // Optimistic update
    final updated = List<ChatMessage>.from(state.messages);
    updated[idx] = msg.copyWith(isPinned: newPinned);
    state = state.copyWith(messages: updated);

    try {
      await apiClient.dio.post(
        '${ApiConstants.groupChatMessages(_groupId)}/${messageId}/pin',
        data: {'pinned': newPinned},
      );
    } catch (_) {
      // Revert
      if (mounted) {
        final revertIdx = state.messages.indexWhere((m) => m.id == messageId);
        if (revertIdx != -1) {
          final reverted = List<ChatMessage>.from(state.messages);
          reverted[revertIdx] = msg;
          state = state.copyWith(messages: reverted);
        }
      }
    }
  }

  /// Get pinned messages from current state.
  List<ChatMessage> get pinnedMessages =>
      state.messages.where((m) => m.isPinned).toList();

  /// Notify server that the user is typing (or stopped).
  Future<void> setTyping(bool typing) async {
    try {
      await apiClient.dio.post(
        '${ApiConstants.groupChatMessages(_groupId)}/typing',
        data: {'typing': typing},
      );
    } catch (_) {
      // Non-critical — typing indicators are best-effort
    }
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

// ── Typing Indicator ─────────────────────────────────────────────────────────

class TypingUser {
  final String userId;
  final String name;

  TypingUser({required this.userId, required this.name});

  factory TypingUser.fromJson(Map<String, dynamic> json) => TypingUser(
        userId: json['user_id'] ?? '',
        name: json['name'] ?? '',
      );
}

final typingUsersProvider =
    StreamProvider.family<List<TypingUser>, String>((ref, groupId) async* {
  // Poll typing status every 3 seconds
  while (true) {
    try {
      final res = await apiClient.dio.get(
        '${ApiConstants.groupChatMessages(groupId)}/typing',
      );
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['typing_users'] as List? ?? [];
      yield list
          .map((e) => TypingUser.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      yield [];
    }
    await Future.delayed(const Duration(seconds: 3));
  }
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

Future<GroupChat> updateGroupChat(
  String groupId, {
  String? name,
  String? description,
}) async {
  final res = await apiClient.dio.patch(
    ApiConstants.groupChatDetail(groupId),
    data: {
      if (name != null) 'name': name,
      if (description != null) 'description': description,
    },
  );
  return GroupChat.fromJson(res.data as Map<String, dynamic>);
}

Future<void> muteGroupChat(String groupId, bool muted) async {
  await apiClient.dio.post(
    '${ApiConstants.groupChatDetail(groupId)}/mute',
    data: {'muted': muted},
  );
}

Future<void> inviteToGroupChat(String groupId, List<String> userIds) async {
  await apiClient.dio.post(
    ApiConstants.groupChatInvite(groupId),
    data: {'user_ids': userIds},
  );
}

Future<void> setGroupNotifPref(String groupId, GroupNotifPref pref) async {
  await apiClient.dio.post(
    '${ApiConstants.groupChatDetail(groupId)}/notifications',
    data: {'pref': pref.value},
  );
}
