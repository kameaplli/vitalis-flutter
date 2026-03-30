import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants.dart';
import '../../models/dm_models.dart';
import '../../providers/dm_provider.dart';
import '../../widgets/social/online_indicator.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/themed_spinner.dart';

// ── DM Inbox ──────────────────────────────────────────────────────────────────

class DmInboxScreen extends ConsumerWidget {
  const DmInboxScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final state = ref.watch(dmListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: Builder(builder: (_) {
        if (state.isLoading) {
          return const ThemedSpinner();
        }
        if (state.error != null && state.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text('Failed to load messages',
                    style: tt.bodyMedium?.copyWith(color: cs.error)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.read(dmListProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        if (state.conversations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedComment01,
                    size: 64,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                const SizedBox(height: 16),
                Text('No messages yet',
                    style: tt.titleMedium?.copyWith(
                        color: cs.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text('Start a conversation from someone\'s profile',
                    style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.6))),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: () => ref.read(dmListProvider.notifier).refresh(),
          child: ListView.separated(
            itemCount: state.conversations.length,
            separatorBuilder: (_, __) => Divider(
              height: 1,
              indent: 72,
              color: cs.outlineVariant.withValues(alpha: 0.3),
            ),
            itemBuilder: (_, i) {
              final convo = state.conversations[i];
              return _ConversationTile(conversation: convo);
            },
          ),
        );
      }),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final DmConversation conversation;
  const _ConversationTile({required this.conversation});

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final hasAvatar = conversation.otherAvatarUrl != null &&
        conversation.otherAvatarUrl!.isNotEmpty;
    final initial = conversation.otherUserName.isNotEmpty
        ? conversation.otherUserName[0].toUpperCase()
        : '?';

    return ListTile(
      leading: AvatarWithPresence(
        avatarUrl: hasAvatar
            ? ApiConstants.resolveUrl(conversation.otherAvatarUrl)
            : null,
        fallbackInitial: initial,
        isOnline: conversation.isOtherOnline,
        radius: 24,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(conversation.otherUserName,
                style: tt.bodyMedium?.copyWith(
                  fontWeight: conversation.unreadCount > 0
                      ? FontWeight.w700
                      : FontWeight.w500,
                )),
          ),
          Text(
            _timeAgo(conversation.updatedAt),
            style: tt.labelSmall?.copyWith(
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              conversation.lastMessage?.text ?? 'No messages',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(
                color: conversation.unreadCount > 0
                    ? cs.onSurface
                    : cs.onSurfaceVariant,
                fontWeight: conversation.unreadCount > 0
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          if (conversation.unreadCount > 0)
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${conversation.unreadCount}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => DmChatScreen(conversation: conversation),
        ));
      },
    );
  }
}

// ── DM Chat Room ──────────────────────────────────────────────────────────────

class DmChatScreen extends ConsumerStatefulWidget {
  final DmConversation conversation;
  const DmChatScreen({super.key, required this.conversation});

  @override
  ConsumerState<DmChatScreen> createState() => _DmChatScreenState();
}

class _DmChatScreenState extends ConsumerState<DmChatScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(dmChatProvider(widget.conversation.id).notifier)
          .markAsRead();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(dmChatProvider(widget.conversation.id).notifier).loadMore();
    }
  }

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    HapticFeedback.lightImpact();
    ref
        .read(dmChatProvider(widget.conversation.id).notifier)
        .sendMessage(text);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chatState = ref.watch(dmChatProvider(widget.conversation.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.primaryContainer,
              child: Text(
                widget.conversation.otherUserName.isNotEmpty
                    ? widget.conversation.otherUserName[0].toUpperCase()
                    : '?',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer),
              ),
            ),
            const SizedBox(width: 10),
            Text(widget.conversation.otherUserName,
                style: tt.titleSmall),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const ThemedSpinner()
                : chatState.messages.isEmpty
                    ? Center(
                        child: Text(
                          'Say hello!',
                          style: TextStyle(
                            fontSize: 15,
                            color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true,
                        padding: const EdgeInsets.all(12),
                        itemCount: chatState.messages.length,
                        itemBuilder: (_, i) {
                          final msg = chatState.messages[i];
                          final isMe = msg.senderId.isEmpty ||
                              msg.id.startsWith('temp_');
                          return _DmBubble(message: msg, isMe: isMe);
                        },
                      ),
          ),

          // Input bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: cs.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedSent, size: 20),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DmBubble extends StatelessWidget {
  final DmMessage message;
  final bool isMe;

  const _DmBubble({required this.message, required this.isMe});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isTemp = message.id.startsWith('temp_');

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        constraints:
            BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe
              ? cs.primaryContainer
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isMe
                ? const Radius.circular(16)
                : const Radius.circular(4),
            bottomRight: isMe
                ? const Radius.circular(4)
                : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 14.5,
                color: isTemp
                    ? cs.onSurface.withValues(alpha: 0.5)
                    : isMe
                        ? cs.onPrimaryContainer
                        : cs.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${message.createdAt.hour.toString().padLeft(2, '0')}:${message.createdAt.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    fontSize: 10,
                    color: (isMe ? cs.onPrimaryContainer : cs.onSurfaceVariant)
                        .withValues(alpha: 0.5),
                  ),
                ),
                if (isMe && message.isRead) ...[
                  const SizedBox(width: 4),
                  HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01,
                      size: 12,
                      color: cs.primary.withValues(alpha: 0.7)),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
