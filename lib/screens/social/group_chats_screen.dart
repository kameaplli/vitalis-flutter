import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/group_chat_models.dart';
import '../../providers/group_chat_provider.dart';

class GroupChatsScreen extends ConsumerWidget {
  const GroupChatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final groupsState = ref.watch(groupsNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded),
            onPressed: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
      body: Builder(builder: (_) {
        if (groupsState.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (groupsState.error != null && groupsState.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.wifi_off_rounded, size: 48, color: cs.outline),
                const SizedBox(height: 12),
                Text('Could not load groups', style: tt.bodyMedium),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      ref.read(groupsNotifierProvider.notifier).refresh(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }

        final groups = groupsState.groups;

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.forum_outlined, size: 56, color: cs.outline),
                const SizedBox(height: 12),
                Text('No group chats yet',
                    style: tt.titleSmall?.copyWith(color: cs.outline)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _showCreateSheet(context, ref),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Create Group'),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () =>
              ref.read(groupsNotifierProvider.notifier).refresh(),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: groups.length,
            separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: cs.outlineVariant.withValues(alpha: 0.3)),
            itemBuilder: (_, i) => _GroupChatTile(group: groups[i]),
          ),
        );
      }),
    );
  }

  void _showCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateGroupSheet(ref: ref),
    );
  }
}

class _GroupChatTile extends StatelessWidget {
  final GroupChat group;
  const _GroupChatTile({required this.group});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: cs.primaryContainer,
        child: Text(
          group.name.isNotEmpty ? group.name[0].toUpperCase() : '?',
          style: tt.titleMedium?.copyWith(color: cs.onPrimaryContainer),
        ),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(group.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (group.access == GroupChatAccess.inviteOnly) ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_outline, size: 14, color: cs.outline),
          ],
        ],
      ),
      subtitle: group.lastMessage != null
          ? Text(
              '${group.lastMessage!.senderName}: ${group.lastMessage!.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.bodySmall?.copyWith(color: cs.outline),
            )
          : Text('${group.memberCount} members',
              style: tt.bodySmall?.copyWith(color: cs.outline)),
      trailing: group.unreadCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${group.unreadCount}',
                  style: tt.labelSmall?.copyWith(color: cs.onPrimary)),
            )
          : null,
      onTap: () => context.push('/social/groups/${group.id}', extra: group),
    );
  }
}

// ── Chat Room Screen ────────────────────────────────────────────────────────

class ChatRoomScreen extends ConsumerStatefulWidget {
  final GroupChat group;
  const ChatRoomScreen({super.key, required this.group});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _textCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when scrolled near top (messages are newest-first)
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      ref.read(chatNotifierProvider(widget.group.id).notifier).loadMore();
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  void _send() {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    HapticFeedback.lightImpact();
    ref
        .read(chatNotifierProvider(widget.group.id).notifier)
        .sendMessage(text);
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Leave Group'),
        content: Text('Leave "${widget.group.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await leaveGroupChat(widget.group.id);
        ref.read(groupsNotifierProvider.notifier).refresh();
        if (mounted) Navigator.pop(context);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to leave: $e')),
          );
        }
      }
    }
  }

  void _showMembersSheet(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final membersAsync = ref.read(groupChatMembersProvider(widget.group.id));

    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Consumer(
        builder: (ctx, ref, _) {
          final members = ref.watch(groupChatMembersProvider(widget.group.id));
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Members',
                    style:
                        tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                members.when(
                  loading: () => const Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => Text('Failed to load members'),
                  data: (list) => ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: cs.secondaryContainer,
                            child: Text(
                              m.userName.isNotEmpty
                                  ? m.userName[0].toUpperCase()
                                  : '?',
                              style: tt.labelSmall?.copyWith(
                                  color: cs.onSecondaryContainer),
                            ),
                          ),
                          title: Text(m.userName, style: tt.bodyMedium),
                          trailing: m.role != GroupChatRole.member
                              ? Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: cs.primaryContainer,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    m.role == GroupChatRole.owner
                                        ? 'Owner'
                                        : 'Admin',
                                    style: tt.labelSmall?.copyWith(
                                        color: cs.onPrimaryContainer),
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final chatState = ref.watch(chatNotifierProvider(widget.group.id));

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.group.name, style: tt.titleSmall),
            Text('${widget.group.memberCount} members',
                style: tt.bodySmall?.copyWith(color: cs.outline)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_outlined),
            onPressed: () => _showMembersSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'leave') _confirmLeave(context);
            },
            itemBuilder: (_) => [
              if (widget.group.access == GroupChatAccess.inviteOnly &&
                  widget.group.isAdmin)
                const PopupMenuItem(
                  value: 'invite',
                  child: ListTile(
                    leading: Icon(Icons.person_add_outlined),
                    title: Text('Invite Members'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: Icon(Icons.exit_to_app, color: Colors.red),
                  title: Text('Leave Group',
                      style: TextStyle(color: Colors.red)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages
          Expanded(
            child: chatState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatState.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 48, color: cs.outline),
                            const SizedBox(height: 12),
                            Text('No messages yet',
                                style: tt.bodyMedium
                                    ?.copyWith(color: cs.outline)),
                            const SizedBox(height: 4),
                            Text('Be the first to say hello!',
                                style: tt.bodySmall
                                    ?.copyWith(color: cs.outline)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        itemCount: chatState.messages.length,
                        itemBuilder: (_, i) {
                          final msg = chatState.messages[i];
                          // Date separator: show when next message (older) is a different day
                          final showDate = i == chatState.messages.length - 1 ||
                              !_sameDay(msg.createdAt,
                                  chatState.messages[i + 1].createdAt);
                          // Collapse avatar if previous message (newer) is same sender
                          final showAvatar = i == 0 ||
                              chatState.messages[i - 1].senderId !=
                                  msg.senderId;
                          return Column(
                            children: [
                              if (showDate) _DateHeader(date: msg.createdAt),
                              _MessageBubble(
                                  message: msg, showAvatar: showAvatar),
                            ],
                          );
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
                      color: cs.outlineVariant.withValues(alpha: 0.3))),
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
                    icon: const Icon(Icons.send_rounded, size: 20),
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

class _DateHeader extends StatelessWidget {
  final DateTime date;
  const _DateHeader({required this.date});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final now = DateTime.now();
    final isToday =
        date.year == now.year && date.month == now.month && date.day == now.day;
    final isYesterday = date.year == now.year &&
        date.month == now.month &&
        date.day == now.day - 1;

    String label;
    if (isToday) {
      label = 'Today';
    } else if (isYesterday) {
      label = 'Yesterday';
    } else {
      label =
          '${date.day}/${date.month}/${date.year}';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(label,
              style: tt.labelSmall?.copyWith(color: cs.outline)),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;
  final bool showAvatar;
  const _MessageBubble({required this.message, this.showAvatar = true});

  String _formatTime(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isTemp = message.id.startsWith('temp_');

    return Padding(
      padding: EdgeInsets.only(bottom: showAvatar ? 6 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showAvatar)
            CircleAvatar(
              radius: 16,
              backgroundColor: cs.secondaryContainer,
              child: Text(
                message.senderName.isNotEmpty
                    ? message.senderName[0].toUpperCase()
                    : '?',
                style: tt.labelSmall
                    ?.copyWith(color: cs.onSecondaryContainer),
              ),
            )
          else
            const SizedBox(width: 32),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showAvatar)
                  Row(
                    children: [
                      Text(message.senderName,
                          style: tt.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(message.createdAt),
                        style: tt.labelSmall?.copyWith(
                            color: cs.outline, fontSize: 10),
                      ),
                    ],
                  ),
                if (showAvatar)
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: tt.bodyMedium?.copyWith(
                      color: isTemp
                          ? cs.onSurface.withValues(alpha: 0.5)
                          : null,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Create Group Sheet ──────────────────────────────────────────────────────

class _CreateGroupSheet extends StatefulWidget {
  final WidgetRef ref;
  const _CreateGroupSheet({required this.ref});

  @override
  State<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends State<_CreateGroupSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  var _access = GroupChatAccess.public_;
  var _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await createGroupChat(
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
        access: _access,
      );
      widget.ref.read(groupsNotifierProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Create Group Chat',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Group name',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _descCtrl,
            maxLength: 200,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<GroupChatAccess>(
            segments: [
              ButtonSegment(
                value: GroupChatAccess.public_,
                label: const Text('Public'),
                icon: const Icon(Icons.public, size: 16),
              ),
              ButtonSegment(
                value: GroupChatAccess.inviteOnly,
                label: const Text('Invite Only'),
                icon: const Icon(Icons.lock_outline, size: 16),
              ),
            ],
            selected: {_access},
            onSelectionChanged: (s) => setState(() => _access = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed:
                _nameCtrl.text.trim().isNotEmpty && !_creating ? _create : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _creating
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Create Group'),
          ),
        ],
      ),
    );
  }
}
