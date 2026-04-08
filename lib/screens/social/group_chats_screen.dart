import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:dio/dio.dart' as dio_pkg;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/group_chat_models.dart';
import '../../providers/group_chat_provider.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/themed_spinner.dart';

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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01),
            onPressed: () => _showCreateSheet(context, ref),
          ),
        ],
      ),
      body: Builder(builder: (_) {
        if (groupsState.isLoading) {
          return const ThemedSpinner();
        }
        if (groupsState.error != null && groupsState.groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedWifiOff01, size: 48, color: cs.outline),
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
                HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 56, color: cs.outline),
                const SizedBox(height: 12),
                Text('No group chats yet',
                    style: tt.titleSmall?.copyWith(color: cs.outline)),
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () => _showCreateSheet(context, ref),
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedAdd01, size: 18),
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
            HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, size: 14, color: cs.outline),
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
  bool _isTyping = false;
  List<GroupMember> _mentionSuggestions = [];
  bool _showMentions = false;

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    _textCtrl.addListener(_onTextChanged);
    // Mark messages as read when entering chat
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(chatNotifierProvider(widget.group.id).notifier)
          .markAsRead();
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final typing = _textCtrl.text.isNotEmpty;
    if (typing != _isTyping) {
      _isTyping = typing;
      ref
          .read(chatNotifierProvider(widget.group.id).notifier)
          .setTyping(typing);
    }
    _checkForMention();
  }

  void _checkForMention() {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    if (cursor <= 0 || cursor > text.length) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    // Find the @ before cursor
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx == -1 || (atIdx > 0 && before[atIdx - 1] != ' ' && before[atIdx - 1] != '\n')) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    final query = before.substring(atIdx + 1).toLowerCase();
    if (query.contains(' ') || query.length > 20) {
      if (_showMentions) setState(() => _showMentions = false);
      return;
    }

    // Filter members
    final membersAsync = ref.read(groupChatMembersProvider(widget.group.id));
    membersAsync.whenData((members) {
      final filtered = query.isEmpty
          ? members.take(5).toList()
          : members
              .where((m) => m.userName.toLowerCase().contains(query))
              .take(5)
              .toList();
      setState(() {
        _mentionSuggestions = filtered;
        _showMentions = filtered.isNotEmpty;
      });
    });
  }

  void _insertMention(GroupMember member) {
    final text = _textCtrl.text;
    final cursor = _textCtrl.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx == -1) return;

    final after = text.substring(cursor);
    final mention = '@${member.userName} ';
    final newText = text.substring(0, atIdx) + mention + after;
    _textCtrl.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + mention.length),
    );
    setState(() => _showMentions = false);
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

  File? _pendingImage;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 80,
    );
    if (picked == null) return;
    setState(() => _pendingImage = File(picked.path));
  }

  Future<void> _sendImage() async {
    if (_pendingImage == null) return;
    final file = _pendingImage!;
    setState(() => _pendingImage = null);
    HapticFeedback.lightImpact();

    try {
      final formData = dio_pkg.FormData.fromMap({
        'image': await dio_pkg.MultipartFile.fromFile(file.path),
        if (_textCtrl.text.trim().isNotEmpty) 'text': _textCtrl.text.trim(),
      });
      _textCtrl.clear();
      await apiClient.dio.post(
        ApiConstants.groupChatMessages(widget.group.id),
        data: formData,
        options: dio_pkg.Options(contentType: 'multipart/form-data'),
      );
      // Let poll pick up the new message
      ref.read(chatNotifierProvider(widget.group.id).notifier);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send image: $e')),
        );
      }
    }
  }

  static const _quickReactions = ['\u2764\uFE0F', '\uD83D\uDC4D', '\uD83D\uDE02', '\uD83D\uDD25', '\uD83D\uDE22', '\uD83D\uDE4F'];

  void _showMessageOptions(ChatMessage msg) {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            // Quick reaction row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _quickReactions.map((emoji) {
                  return GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      HapticFeedback.lightImpact();
                      ref
                          .read(chatNotifierProvider(widget.group.id).notifier)
                          .reactToMessage(msg.id, emoji);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                        shape: BoxShape.circle,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            if (widget.group.isAdmin)
              ListTile(
                leading: HugeIcon(
                  icon: HugeIcons.strokeRoundedMapPin,
                  color: cs.primary,
                  size: 24,
                ),
                title: Text(msg.isPinned ? 'Unpin Message' : 'Pin Message'),
                onTap: () {
                  Navigator.pop(ctx);
                  HapticFeedback.lightImpact();
                  ref
                      .read(chatNotifierProvider(widget.group.id).notifier)
                      .togglePin(msg.id);
                },
              ),
            ListTile(
              leading: HugeIcon(icon: HugeIcons.strokeRoundedCopy01, color: cs.onSurfaceVariant),
              title: const Text('Copy Text'),
              onTap: () {
                Navigator.pop(ctx);
                Clipboard.setData(ClipboardData(text: msg.text));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Copied to clipboard'),
                    behavior: SnackBarBehavior.floating,
                    duration: Duration(seconds: 1),
                  ),
                );
              },
            ),
            if (msg.readByCount > 0)
              ListTile(
                leading: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: cs.primary),
                title: Text('Read by ${msg.readByCount}'),
                subtitle: msg.readReceipts.isNotEmpty
                    ? Text(
                        msg.readReceipts
                            .take(5)
                            .map((r) => r.userName)
                            .join(', '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                      )
                    : null,
                onTap: () => Navigator.pop(ctx),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }


  void _showNotifPrefPicker() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Text(
              'Notification Preference',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Choose what notifications you receive from this group',
              style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            ...GroupNotifPref.values.map((pref) {
              final isSelected = widget.group.notifPref == pref;
              return ListTile(
                leading: HugeIcon(icon: pref.icon,
                    color: isSelected ? cs.primary : cs.onSurfaceVariant),
                title: Text(pref.label),
                trailing: isSelected
                    ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: cs.primary)
                    : null,
                selected: isSelected,
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    await setGroupNotifPref(widget.group.id, pref);
                    ref.read(groupsNotifierProvider.notifier).refresh();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Notifications set to: ${pref.label}'),
                          behavior: SnackBarBehavior.floating,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showEditGroupSheet() {
    final cs = Theme.of(context).colorScheme;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _EditGroupSheet(
        group: widget.group,
        onSaved: () {
          ref.read(groupsNotifierProvider.notifier).refresh();
        },
      ),
    );
  }

  Future<void> _toggleMute() async {
    final newMuted = !widget.group.isMuted;
    try {
      await muteGroupChat(widget.group.id, newMuted);
      ref.read(groupsNotifierProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newMuted
                ? 'Notifications muted for ${widget.group.name}'
                : 'Notifications enabled for ${widget.group.name}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
            icon: HugeIcon(icon: HugeIcons.strokeRoundedUserGroup),
            onPressed: () => _showMembersSheet(context),
          ),
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'leave') _confirmLeave(context);
              if (val == 'mute') _toggleMute();
              if (val == 'notif_pref') _showNotifPrefPicker();
              if (val == 'edit') _showEditGroupSheet();
            },
            itemBuilder: (_) => [
              if (widget.group.isAdmin)
                const PopupMenuItem(
                  value: 'edit',
                  child: ListTile(
                    leading: HugeIcon(icon: HugeIcons.strokeRoundedEdit01),
                    title: Text('Edit Group'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              PopupMenuItem(
                value: 'mute',
                child: ListTile(
                  leading: HugeIcon(icon: widget.group.isMuted
                      ? HugeIcons.strokeRoundedNotification01
                      : HugeIcons.strokeRoundedNotification01, size: 20),
                  title: Text(widget.group.isMuted
                      ? 'Unmute Notifications'
                      : 'Mute Notifications'),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'notif_pref',
                child: ListTile(
                  leading: HugeIcon(icon: widget.group.notifPref.icon, size: 20),
                  title: const Text('Notification Preference'),
                  subtitle: Text(widget.group.notifPref.label,
                      style: TextStyle(fontSize: 11, color: cs.outline)),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              if (widget.group.access == GroupChatAccess.inviteOnly &&
                  widget.group.isAdmin)
                const PopupMenuItem(
                  value: 'invite',
                  child: ListTile(
                    leading: HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01),
                    title: Text('Invite Members'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'leave',
                child: ListTile(
                  leading: HugeIcon(icon: HugeIcons.strokeRoundedLogout01, color: Colors.red),
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
          // Pinned message banner
          _PinnedBanner(
            groupId: widget.group.id,
            isAdmin: widget.group.isAdmin,
          ),

          // Messages
          Expanded(
            child: chatState.isLoading
                ? const ThemedSpinner()
                : chatState.messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            HugeIcon(icon: HugeIcons.strokeRoundedComment01,
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
                                message: msg,
                                showAvatar: showAvatar,
                                onLongPress: () => _showMessageOptions(msg),
                              ),
                            ],
                          );
                        },
                      ),
          ),

          // Typing indicator
          _TypingIndicator(groupId: widget.group.id),

          // Mention suggestions overlay
          if (_showMentions && _mentionSuggestions.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: cs.surface,
                border: Border(
                  top: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.shadow.withValues(alpha: 0.08),
                    blurRadius: 8,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: _mentionSuggestions.length,
                itemBuilder: (_, i) {
                  final member = _mentionSuggestions[i];
                  return ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(vertical: -2),
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        member.userName.isNotEmpty
                            ? member.userName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                    title: Text(member.userName,
                        style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500)),
                    trailing: member.role != GroupChatRole.member
                        ? Text(
                            member.role.label,
                            style: TextStyle(
                              fontSize: 10,
                              color: cs.primary,
                            ),
                          )
                        : null,
                    onTap: () => _insertMention(member),
                  );
                },
              ),
            ),

          // Image preview strip
          if (_pendingImage != null)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              color: cs.surface,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _pendingImage!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('Image attached',
                      style: TextStyle(
                          fontSize: 13, color: cs.onSurfaceVariant)),
                  const Spacer(),
                  IconButton(
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01,
                        size: 18, color: cs.error),
                    onPressed: () =>
                        setState(() => _pendingImage = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
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
                  IconButton(
                    onPressed: _pickImage,
                    icon: HugeIcon(icon: HugeIcons.strokeRoundedImage01,
                        size: 22, color: cs.onSurfaceVariant),
                    visualDensity: VisualDensity.compact,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: TextField(
                      controller: _textCtrl,
                      maxLines: 3,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) =>
                          _pendingImage != null ? _sendImage() : _send(),
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
                    onPressed:
                        _pendingImage != null ? _sendImage : _send,
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

/// Renders message text with @mentions highlighted in primary color.
class _MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Color mentionColor;

  const _MentionText({
    required this.text,
    this.style,
    required this.mentionColor,
  });

  @override
  Widget build(BuildContext context) {
    final regex = RegExp(r'@\w+');
    final matches = regex.allMatches(text).toList();

    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <TextSpan>[];
    int lastEnd = 0;

    for (final match in matches) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: text.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: mentionColor,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }

    if (lastEnd < text.length) {
      spans.add(TextSpan(text: text.substring(lastEnd)));
    }

    return RichText(text: TextSpan(style: style, children: spans));
  }
}

class _PinnedBanner extends ConsumerWidget {
  final String groupId;
  final bool isAdmin;
  const _PinnedBanner({required this.groupId, required this.isAdmin});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final chatState = ref.watch(chatNotifierProvider(groupId));
    final pinned = chatState.messages.where((m) => m.isPinned).toList();

    if (pinned.isEmpty) return const SizedBox.shrink();

    final latest = pinned.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.primaryContainer.withValues(alpha: 0.2),
        border: Border(
          bottom: BorderSide(
            color: cs.primary.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedMapPin, size: 16, color: cs.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  latest.senderName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: cs.primary,
                  ),
                ),
                Text(
                  latest.text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: cs.onSurface.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          if (pinned.length > 1)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(
                '+${pinned.length - 1}',
                style: TextStyle(
                  fontSize: 11,
                  color: cs.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (isAdmin)
            IconButton(
              icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, size: 16, color: cs.outline),
              onPressed: () {
                ref
                    .read(chatNotifierProvider(groupId).notifier)
                    .togglePin(latest.id);
              },
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
            ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends ConsumerWidget {
  final String groupId;
  const _TypingIndicator({required this.groupId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final typingAsync = ref.watch(typingUsersProvider(groupId));

    return typingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (users) {
        if (users.isEmpty) return const SizedBox.shrink();

        final text = users.length == 1
            ? '${users.first.name} is typing...'
            : users.length == 2
                ? '${users[0].name} and ${users[1].name} are typing...'
                : '${users.length} people are typing...';

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              _BouncingDots(color: cs.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Three bouncing dots animation for typing indicator.
class _BouncingDots extends StatefulWidget {
  final Color color;
  const _BouncingDots({required this.color});

  @override
  State<_BouncingDots> createState() => _BouncingDotsState();
}

class _BouncingDotsState extends State<_BouncingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24,
      height: 12,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, __) => Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(3, (i) {
            final delay = i * 0.2;
            final t = ((_ctrl.value - delay) % 1.0).clamp(0.0, 1.0);
            final bounce = t < 0.5
                ? (t * 2) * -4
                : ((1 - t) * 2) * -4;
            return Transform.translate(
              offset: Offset(0, bounce),
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            );
          }),
        ),
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
  final VoidCallback? onLongPress;
  const _MessageBubble({
    required this.message,
    this.showAvatar = true,
    this.onLongPress,
  });

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: InteractiveViewer(
            child: CachedNetworkImage(
              imageUrl: ApiConstants.resolveUrl(url),
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

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

    return GestureDetector(
      onLongPress: onLongPress,
      child: Padding(
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
                        if (message.isPinned) ...[
                          const SizedBox(width: 6),
                          HugeIcon(icon: HugeIcons.strokeRoundedMapPin, size: 12,
                              color: cs.primary.withValues(alpha: 0.7)),
                        ],
                        if (message.readByCount > 0) ...[
                          const SizedBox(width: 6),
                          HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 14,
                              color: cs.primary.withValues(alpha: 0.6)),
                        ],
                      ],
                    ),
                  if (showAvatar)
                  const SizedBox(height: 2),
                  Container(
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: message.isPinned
                          ? cs.primaryContainer.withValues(alpha: 0.3)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                        bottomRight: Radius.circular(14),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image attachment
                        if (message.imageUrl != null &&
                            message.imageUrl!.isNotEmpty)
                          GestureDetector(
                            onTap: () => _showFullImage(
                                context, message.imageUrl!),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                  maxWidth: 240, maxHeight: 200),
                              child: CachedNetworkImage(
                                imageUrl: ApiConstants.resolveUrl(
                                    message.imageUrl),
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  width: 200,
                                  height: 120,
                                  color: cs.surfaceContainerHighest,
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
                                  width: 200,
                                  height: 80,
                                  color: cs.errorContainer,
                                  child: HugeIcon(icon: HugeIcons.strokeRoundedImage01,
                                      color: cs.onErrorContainer),
                                ),
                              ),
                            ),
                          ),
                        // Text content
                        if (message.text.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: _MentionText(
                              text: message.text,
                              mentionColor: cs.primary,
                              style: tt.bodyMedium?.copyWith(
                                color: isTemp
                                    ? cs.onSurface.withValues(alpha: 0.5)
                                    : cs.onSurface,
                              ),
                            ),
                          ),
                        if (message.text.isEmpty &&
                            (message.imageUrl == null ||
                                message.imageUrl!.isEmpty))
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            child: _MentionText(
                              text: message.text,
                              mentionColor: cs.primary,
                              style: tt.bodyMedium?.copyWith(
                                color: cs.onSurface,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  // Reaction pills
                  if (message.reactions.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Wrap(
                        spacing: 4,
                        runSpacing: 2,
                        children: message.reactions.map((r) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: r.userReacted
                                  ? cs.primaryContainer.withValues(alpha: 0.4)
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                              border: r.userReacted
                                  ? Border.all(
                                      color: cs.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(r.emoji,
                                    style: const TextStyle(fontSize: 12)),
                                if (r.count > 1) ...[
                                  const SizedBox(width: 2),
                                  Text('${r.count}',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: cs.onSurfaceVariant,
                                        fontWeight: FontWeight.w500,
                                      )),
                                ],
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
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
                icon: HugeIcon(icon: HugeIcons.strokeRoundedGlobe02, size: 16),
              ),
              ButtonSegment(
                value: GroupChatAccess.inviteOnly,
                label: const Text('Invite Only'),
                icon: HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, size: 16),
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

// ── Edit Group Sheet ─────────────────────────────────────────────────────────

class _EditGroupSheet extends StatefulWidget {
  final GroupChat group;
  final VoidCallback onSaved;
  const _EditGroupSheet({required this.group, required this.onSaved});

  @override
  State<_EditGroupSheet> createState() => _EditGroupSheetState();
}

class _EditGroupSheetState extends State<_EditGroupSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.group.name);
    _descCtrl = TextEditingController(text: widget.group.description ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await updateGroupChat(
        widget.group.id,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isNotEmpty
            ? _descCtrl.text.trim()
            : null,
      );
      widget.onSaved();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Group updated'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Edit Group',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: 'Group Name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            maxLength: 50,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            decoration: InputDecoration(
              labelText: 'Description (optional)',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            maxLines: 3,
            maxLength: 200,
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _nameCtrl.text.trim().isNotEmpty && !_saving
                ? _save
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _saving
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save Changes'),
          ),
        ],
      ),
    );
  }
}
