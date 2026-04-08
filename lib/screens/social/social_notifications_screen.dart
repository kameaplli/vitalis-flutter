import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/themed_spinner.dart';

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
  String _filterType = 'all'; // 'all', 'unread', 'social', 'polls', 'groups'

  static const _filterOptions = [
    ('all', 'All'),
    ('unread', 'Unread'),
    ('social', 'Social'),
    ('polls', 'Polls'),
    ('groups', 'Groups'),
  ];

  List<SocialNotification> _applyFilter(List<SocialNotification> all) {
    switch (_filterType) {
      case 'unread':
        return all.where((n) => !n.isRead).toList();
      case 'social':
        return all
            .where((n) => [
                  'connection_request',
                  'connection_accepted',
                  'reaction',
                  'comment',
                  'badge_earned',
                  'level_up',
                ].contains(n.notificationType))
            .toList();
      case 'polls':
        return all
            .where((n) =>
                n.notificationType == 'poll_vote' ||
                n.notificationType == 'poll_comment')
            .toList();
      case 'groups':
        return all
            .where((n) =>
                n.notificationType == 'group_invite' ||
                n.notificationType == 'group_mention')
            .toList();
      default:
        return all;
    }
  }

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

  List<_DaySection> _groupByDay(List<SocialNotification> notifications) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<SocialNotification>> groups = {};
    final Map<String, String> labels = {};

    for (final n in notifications) {
      final day = DateTime(n.createdAt.year, n.createdAt.month, n.createdAt.day);
      final key = '${day.year}-${day.month}-${day.day}';
      groups.putIfAbsent(key, () => []).add(n);
      if (!labels.containsKey(key)) {
        if (day == today) {
          labels[key] = 'Today';
        } else if (day == yesterday) {
          labels[key] = 'Yesterday';
        } else if (now.difference(day).inDays < 7) {
          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
          labels[key] = days[day.weekday - 1];
        } else {
          labels[key] = '${day.month}/${day.day}/${day.year}';
        }
      }
    }

    return groups.entries
        .map((e) => _DaySection(label: labels[e.key]!, notifications: e.value))
        .toList();
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
      case 'poll_vote':
      case 'poll_comment':
        final pollId = data['poll_id'] as String? ?? '';
        if (pollId.isNotEmpty) {
          context.push('/social'); // TODO: deep link to poll detail
        }
        break;
      case 'group_invite':
      case 'group_mention':
        final groupId = data['group_id'] as String? ?? '';
        if (groupId.isNotEmpty) {
          context.push('/social/groups/$groupId');
        }
        break;
      case 'badge_earned':
      case 'level_up':
        context.push('/social/profile/${data['user_id'] ?? ''}');
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
      body: Column(
        children: [
          // Filter chips
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _filterOptions.map((opt) {
                final isSelected = _filterType == opt.$1;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(opt.$2),
                    selected: isSelected,
                    onSelected: (_) =>
                        setState(() => _filterType = opt.$1),
                    showCheckmark: false,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? cs.onPrimary : cs.onSurface,
                    ),
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.3),
                    selectedColor: cs.primary,
                  ),
                );
              }).toList(),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: cs.primary,
              onRefresh: () async {
                ref.invalidate(socialNotificationsProvider);
                ref.invalidate(notificationBadgeProvider);
                await ref.read(socialNotificationsProvider.future);
              },
              child: notificationsAsync.when(
          loading: () =>
              const ThemedSpinner(),
          error: (err, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 48, color: cs.error),
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
          data: (allNotifications) {
            final notifications = _applyFilter(allNotifications);
            if (notifications.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                  Center(
                    child: Column(
                      children: [
                        HugeIcon(icon: HugeIcons.strokeRoundedNotification01,
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

            // Group by day
            final grouped = _groupByDay(notifications);
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: grouped.length,
              itemBuilder: (_, i) {
                final section = grouped[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Day header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
                      child: Text(
                        section.label,
                        style: tt.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    ...section.notifications.map((notif) {
                      return Column(
                        children: [
                          _NotificationTile(
                            notification: notif,
                            onTap: () => _handleNotificationTap(notif),
                            onDismiss: () => _markOneRead(notif.id),
                          ),
                          Divider(
                            height: 1,
                            indent: 72,
                            color: cs.outlineVariant.withValues(alpha: 0.3),
                          ),
                        ],
                      );
                    }),
                  ],
                );
              },
            );
          },
        ),
      ),
          ),
        ],
      ),
    );
  }
}

// ── Day Section ──────────────────────────────────────────────────────────────

class _DaySection {
  final String label;
  final List<SocialNotification> notifications;
  const _DaySection({required this.label, required this.notifications});
}

// ── Notification Tile ──────────────────────────────────────────────────────────

class _NotificationTile extends StatelessWidget {
  final SocialNotification notification;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.onTap,
    this.onDismiss,
  });

  List<List<dynamic>> _iconForType(String type) => switch (type) {
        'connection_request' => HugeIcons.strokeRoundedUserAdd01,
        'connection_accepted' => HugeIcons.strokeRoundedUserCheck01,
        'reaction' => HugeIcons.strokeRoundedFavourite,
        'comment' => HugeIcons.strokeRoundedComment01,
        'challenge_created' => HugeIcons.strokeRoundedAward01,
        'challenge_completed' => HugeIcons.strokeRoundedAward01,
        'streak_nudge' => HugeIcons.strokeRoundedNotification01,
        'poll_vote' => HugeIcons.strokeRoundedChartColumn,
        'poll_comment' => HugeIcons.strokeRoundedComment01,
        'group_invite' => HugeIcons.strokeRoundedUserAdd01,
        'group_mention' => HugeIcons.strokeRoundedMail01,
        'badge_earned' => HugeIcons.strokeRoundedAward01,
        'level_up' => HugeIcons.strokeRoundedArrowUp01,
        _ => HugeIcons.strokeRoundedNotification01,
      };

  Color _colorForType(String type, ColorScheme cs) => switch (type) {
        'connection_request' || 'connection_accepted' => const Color(0xFF0D7377),
        'reaction' => Colors.redAccent,
        'comment' || 'poll_comment' => cs.primary,
        'challenge_created' || 'challenge_completed' => Colors.amber.shade700,
        'streak_nudge' => Colors.orange,
        'poll_vote' => const Color(0xFF8B5CF6),
        'group_invite' || 'group_mention' => const Color(0xFF3B82F6),
        'badge_earned' || 'level_up' => const Color(0xFFEAB308),
        _ => cs.primary,
      };

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

    Widget tile = InkWell(
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
              child: HugeIcon(icon: _iconForType(type), color: color, size: 22),
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

    // Swipe to mark as read
    if (!notification.isRead && onDismiss != null) {
      tile = Dismissible(
        key: ValueKey(notification.id),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onDismiss!(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: cs.primary.withValues(alpha: 0.1),
          child: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: cs.primary),
        ),
        child: tile,
      );
    }

    return tile;
  }
}
