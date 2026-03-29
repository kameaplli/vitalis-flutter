import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/dm_models.dart';

// ── Conversations List ────────────────────────────────────────────────────────

class DmListState {
  final List<DmConversation> conversations;
  final bool isLoading;
  final String? error;

  const DmListState({
    this.conversations = const [],
    this.isLoading = true,
    this.error,
  });

  DmListState copyWith({
    List<DmConversation>? conversations,
    bool? isLoading,
    String? error,
  }) =>
      DmListState(
        conversations: conversations ?? this.conversations,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class DmListNotifier extends StateNotifier<DmListState> {
  DmListNotifier() : super(const DmListState()) {
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await apiClient.dio.get(ApiConstants.dmConversations);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['conversations'] as List? ?? [];
      final convos = list
          .map((e) => DmConversation.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) {
        state = state.copyWith(conversations: convos, isLoading: false);
      }
    } catch (e) {
      if (mounted) {
        state = state.copyWith(isLoading: false, error: e.toString());
      }
    }
  }

  Future<void> refresh() async {
    try {
      final res = await apiClient.dio.get(ApiConstants.dmConversations);
      final list = res.data is List
          ? res.data as List
          : (res.data as Map)['conversations'] as List? ?? [];
      final convos = list
          .map((e) => DmConversation.fromJson(e as Map<String, dynamic>))
          .toList();
      if (mounted) state = state.copyWith(conversations: convos, error: null);
    } catch (_) {}
  }
}

final dmListProvider =
    StateNotifierProvider<DmListNotifier, DmListState>((ref) {
  return DmListNotifier();
});

// ── DM Messages ───────────────────────────────────────────────────────────────

class DmChatState {
  final List<DmMessage> messages;
  final bool isLoading;
  final bool hasMore;

  const DmChatState({
    this.messages = const [],
    this.isLoading = true,
    this.hasMore = true,
  });

  DmChatState copyWith({
    List<DmMessage>? messages,
    bool? isLoading,
    bool? hasMore,
  }) =>
      DmChatState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        hasMore: hasMore ?? this.hasMore,
      );
}

class DmChatNotifier extends StateNotifier<DmChatState> {
  final String _conversationId;
  Timer? _pollTimer;

  DmChatNotifier(this._conversationId) : super(const DmChatState()) {
    _loadInitial();
  }

  Future<void> _loadInitial() async {
    try {
      final messages = await _fetch();
      if (mounted) {
        state = DmChatState(
          messages: messages,
          isLoading: false,
          hasMore: messages.length >= 50,
        );
      }
      _pollTimer = Timer.periodic(
        const Duration(seconds: 4),
        (_) => _pollNew(),
      );
    } catch (e) {
      if (mounted) {
        state = DmChatState(isLoading: false);
      }
    }
  }

  Future<List<DmMessage>> _fetch({String? before}) async {
    final params = <String, dynamic>{};
    if (before != null) params['before'] = before;
    final res = await apiClient.dio.get(
      ApiConstants.dmMessages(_conversationId),
      queryParameters: params,
    );
    final list = res.data is List
        ? res.data as List
        : (res.data as Map)['messages'] as List? ?? [];
    return list
        .map((e) => DmMessage.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading || state.messages.isEmpty) return;
    try {
      final older = await _fetch(before: state.messages.last.id);
      if (mounted) {
        state = state.copyWith(
          messages: [...state.messages, ...older],
          hasMore: older.length >= 50,
        );
      }
    } catch (_) {}
  }

  Future<void> _pollNew() async {
    if (!mounted) return;
    try {
      final fresh = await _fetch();
      if (!mounted || fresh.isEmpty) return;
      final ids = state.messages.map((m) => m.id).toSet();
      final newOnes = fresh.where((m) => !ids.contains(m.id)).toList();
      if (newOnes.isNotEmpty) {
        state = state.copyWith(messages: [...newOnes, ...state.messages]);
      }
    } catch (_) {}
  }

  Future<void> sendMessage(String text) async {
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final optimistic = DmMessage(
      id: tempId,
      conversationId: _conversationId,
      senderId: '',
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(messages: [optimistic, ...state.messages]);

    try {
      await apiClient.dio.post(
        ApiConstants.dmMessages(_conversationId),
        data: {'text': text},
      );
      if (mounted) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != tempId).toList(),
        );
        await _pollNew();
      }
    } catch (_) {}
  }

  Future<void> markAsRead() async {
    try {
      await apiClient.dio.post(
        '${ApiConstants.dmMessages(_conversationId)}/read',
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final dmChatProvider =
    StateNotifierProvider.family<DmChatNotifier, DmChatState, String>(
        (ref, conversationId) {
  return DmChatNotifier(conversationId);
});

// ── Actions ──────────────────────────────────────────────────────────────────

/// Start or get existing conversation with a user.
Future<DmConversation> startConversation(String otherUserId) async {
  final res = await apiClient.dio.post(
    ApiConstants.dmConversations,
    data: {'other_user_id': otherUserId},
  );
  return DmConversation.fromJson(res.data as Map<String, dynamic>);
}
