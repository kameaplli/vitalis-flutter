import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Bottom sheet for viewing and adding comments on a feed event.
class CommentSheet extends ConsumerStatefulWidget {
  final FeedEvent event;
  final VoidCallback? onCommentAdded;

  const CommentSheet({
    super.key,
    required this.event,
    this.onCommentAdded,
  });

  @override
  ConsumerState<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends ConsumerState<CommentSheet> {
  final _textCtrl = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollCtrl = ScrollController();
  bool _posting = false;
  List<Comment> _localComments = [];
  bool _loaded = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    // Don't try to load comments for optimistic (temp) posts
    if (widget.event.id.startsWith('temp_')) {
      if (mounted) setState(() => _loaded = true);
      return;
    }

    try {
      final res = await apiClient.dio.get(
        ApiConstants.socialCommentsForEvent(widget.event.id),
      );
      final list = res.data is List
          ? res.data as List
          : (res.data is Map ? (res.data['comments'] ?? res.data['data'] ?? []) as List : []);
      if (mounted) {
        setState(() {
          _localComments = list
              .map((c) => Comment.fromJson(c as Map<String, dynamic>))
              .toList();
          _loaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _error = 'Could not load comments';
        });
      }
    }
  }

  Future<void> _postComment() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;

    // Can't comment on optimistic posts
    if (widget.event.id.startsWith('temp_')) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post is still uploading, try again shortly')),
        );
      }
      return;
    }

    setState(() => _posting = true);
    try {
      final res = await apiClient.dio.post(
        ApiConstants.socialComments,
        data: {
          'feed_event_id': widget.event.id,
          'text': text,
        },
      );
      if (res.data is Map<String, dynamic>) {
        final newComment = Comment.fromJson(res.data as Map<String, dynamic>);
        setState(() {
          _localComments.add(newComment);
          _textCtrl.clear();
        });
      } else {
        // Even if response shape is unexpected, clear input and reload
        _textCtrl.clear();
        await _loadComments();
      }
      widget.onCommentAdded?.call();
      ref.invalidate(commentsProvider(widget.event.id));

      // Auto-scroll to bottom after posting
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(
            _scrollCtrl.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post comment: ${_friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  String _friendlyError(dynamic e) {
    final s = e.toString();
    if (s.contains('404')) return 'Post not found';
    if (s.contains('401') || s.contains('403')) return 'Not authorized';
    if (s.contains('SocketException') || s.contains('Connection')) return 'No connection';
    return 'Please try again';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                    letterSpacing: -0.3,
                  ),
                ),
                if (_localComments.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_localComments.length}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                IconButton(
                  icon: HugeIcon(icon: HugeIcons.strokeRoundedCancel01, color: cs.onSurfaceVariant, size: 20),
                  onPressed: () => Navigator.pop(context),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),

          // Comments list
          Flexible(
            child: !_loaded
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              HugeIcon(icon: HugeIcons.strokeRoundedAlert01,
                                  size: 40, color: cs.error),
                              const SizedBox(height: 12),
                              Text(_error!,
                                  style: TextStyle(color: cs.onSurfaceVariant)),
                              const SizedBox(height: 12),
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _error = null;
                                    _loaded = false;
                                  });
                                  _loadComments();
                                },
                                child: const Text('Retry'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : _localComments.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(40),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  HugeIcon(icon: 
                                    HugeIcons.strokeRoundedComment01,
                                    size: 48,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No comments yet',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Be the first to comment!',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shrinkWrap: true,
                            itemCount: _localComments.length,
                            itemBuilder: (_, i) {
                              final c = _localComments[i];
                              return _CommentTile(
                                comment: c,
                                timeAgo: _timeAgo(c.createdAt),
                              );
                            },
                          ),
          ),

          // Input area
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.25),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 8, 8 + bottom),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    focusNode: _focusNode,
                    maxLines: 3,
                    minLines: 1,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _postComment(),
                    style: const TextStyle(fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: 'Write a comment...',
                      hintStyle: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                        fontSize: 14.5,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                _posting
                    ? const SizedBox(
                        width: 36,
                        height: 36,
                        child: Padding(
                          padding: EdgeInsets.all(8),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        onPressed: _postComment,
                        icon: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [cs.primary, cs.tertiary],
                            ),
                          ),
                          child: HugeIcon(icon: 
                            HugeIcons.strokeRoundedSent,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final Comment comment;
  final String timeAgo;

  const _CommentTile({required this.comment, required this.timeAgo});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = (comment.userName.isNotEmpty ? comment.userName[0] : '?').toUpperCase();
    final hasAvatar = comment.userAvatarUrl != null && comment.userAvatarUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          hasAvatar
              ? CircleAvatar(
                  radius: 16,
                  backgroundImage: CachedNetworkImageProvider(comment.userAvatarUrl!),
                  backgroundColor: cs.primaryContainer,
                )
              : CircleAvatar(
                  radius: 16,
                  backgroundColor: cs.primaryContainer,
                  child: Text(
                    initial,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimaryContainer,
                    ),
                  ),
                ),
          const SizedBox(width: 10),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + comment in a bubble
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.text,
                        style: TextStyle(
                          fontSize: 14,
                          color: cs.onSurface.withValues(alpha: 0.9),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                // Time
                Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
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
