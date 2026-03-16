import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';

/// Screen displaying the user's social notifications (reactions, comments,
/// connection requests, challenge invites, nudges, etc.).
class SocialNotificationsScreen extends ConsumerStatefulWidget {
  const SocialNotificationsScreen({super.key});

  @override
  ConsumerState<SocialNotificationsScreen> createState() =>
      _SocialNotificationsScreenState();
}

class _SocialNotificationsScreenState
    extends ConsumerState<SocialNotificationsScreen> {
  bool _markingAllRead = false;

  Future<void> _markAllRead() async {
    setState(() => _markingAllRead = true);
    try {
      await apiClient.dio.put(ApiConstants.socialNotificationsReadAll);
      ref.invalidate(socialNotificationsProvider);
      ref.invalidate(notificationBadgeProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to mark all as read')),
        );
      }
    } finally {
      if (mounted) setState(() => _markingAllRead = false);
    }
  }

  Future<void> _markOneRead(String notificationId) async {
    try {
      await apiClient.dio
          .put(ApiConstants.socialNotificationRead(notificationId));
      ref.invalidate(socialNotificationsProvider);
      ref.invalidate(notificationBadgeProvider);
    } catch (_) {
      // silent
    }
  }

  void _handleNotificationTap(SocialNotification notif) {
    // Mark as read on tap
    if (!notif.isRead) _markOneRead(notif.id);

    // Navigate based on notification type
    final data = notif.data;
    switch (notif.notificationType) {
      case 'connection_request':
      case 'connection_accepted':
        final fromUserId =
            data['from_user_id'] as String? ?? data['user_id'] as String? ?? '';
        if (fromUserId.isNotEmpty) {
          context.push('/social/profile/$fromUserId');
        }
        break;
      case 'reaction':
      case 'comment':
        // Could navigate to the feed event if we had a detail screen
        // For now, go to the social feed
        context.push('/social');
        break;
      case 'challenge_created':
        final challengeId = data['challenge_id'] as String? ?? '';
        if (challengeId.isNotEmpty) {
          context.push('/social/challenge/$challengeId');
        }
        break;
      case 'streak_nudge':
        context.push('/social');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final notificationsAsync = ref.watch(socialNotificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (!_markingAllRead)
            TextButton(
              onPressed: _markAllRead,
              child: Text('Mark all read',
                  style: TextStyle(color: cs.primary, fontSize: 13)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: cs.primary,
        onRefresh: () async {
          ref.invalidate(socialNotificationsProvider);
          ref.invalidate(notificationBadgeProvider);
          // Wait for refetch
          await ref.read(socialNotificationsProvider.future);
        },
        child: notificationsAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: cs.error),
                const SizedBox(height: 12),
                Text('Failed to load notifications',
                    style: tt.bodyMedium?.copyWith(color: cs.error)),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      ref.invalidate(socialNotificationsProvider),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
          data: (notifications) {
            if (notifications.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        Icon(Icons.notifications_none_rounded,
                            size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
                        const SizedBox(height: 16),
                        Text('No notifications yet',
                            style: tt.titleMedium?.copyWith(
                                color: cs.onSurfaceVariant)),
                        const SizedBox(height: 4),
                        Text(
                          'Reactions, comments, and buddy requests\nwill appear here',
                          textAlign: TextAlign.center,
                          style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: notifications.length,
              separatorBuilder: (_, __) => Divider(
                height: 1,
                indent: 72,
                color: cs.outlineVariant.withValues(alpha: 0.3),
              ),
              itemBuilder: (_, i) {
                final notif = notifications[i];
                return _NotificationTile(
                  notification: notif,
                  onTap: () => _handleNotificationTap(notif),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ── Notification Tile ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final SocialNotification notification;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
  });

  IconData _iconForType(String type) {
    switch (type) {
      case 'connection_request':
        return Icons.person_add_rounded;
      case 'connection_accepted':
        return Icons.how_to_reg_rounded;
      case 'reaction':
        return Icons.favorite_rounded;
      case 'comment':
        return Icons.chat_bubble_rounded;
      case 'challenge_created':
        return Icons.emoji_events_rounded;
      case 'streak_nudge':
        return Icons.notifications_active_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(String type, ColorScheme cs) {
    switch (type) {
      case 'connection_request':
      case 'connection_accepted':
        return const Color(0xFF0D7377);
      case 'reaction':
        return Colors.redAccent;
      case 'comment':
        return cs.primary;
      case 'challenge_created':
        return Colors.amber.shade700;
      case 'streak_nudge':
        return Colors.orange;
      default:
        return cs.primary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.month}/${dt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final type = notification.notificationType;
    final color = _colorForType(type, cs);

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        color: notification.isRead
            ? Colors.transparent
            : cs.primaryContainer.withValues(alpha: 0.08),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_iconForType(type), color: color, size: 22),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight:
                          notification.isRead ? FontWeight.w400 : FontWeight.w600,
                      color: cs.onSurface,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (notification.body != null &&
                      notification.body!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      notification.body!,
                      style: tt.bodySmall
                          ?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    _timeAgo(notification.createdAt),
                    style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            // Unread indicator
            if (!notification.isRead)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(
                  color: cs.primary,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
