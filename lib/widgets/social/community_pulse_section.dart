import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';

/// Dashboard inline widget showing friend streaks + recent activity.
/// Displays a horizontal avatar list and 2 recent activity lines.
class CommunityPulseSection extends ConsumerWidget {
  const CommunityPulseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pulseAsync = ref.watch(communityPulseProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return pulseAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (pulse) {
        if (pulse.friendStreaks.isEmpty && pulse.recentActivity.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: cs.surface,
            border: Border.all(
              color: cs.outlineVariant.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => context.push('/social'),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Icon(Icons.people_outline, size: 16, color: cs.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Community',
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      if (pulse.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            '${pulse.unreadCount}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: cs.onPrimary,
                            ),
                          ),
                        ),
                      const SizedBox(width: 4),
                      Icon(Icons.chevron_right,
                          size: 18, color: cs.onSurfaceVariant),
                    ],
                  ),

                  // Friend streaks — horizontal avatar row
                  if (pulse.friendStreaks.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 50,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: pulse.friendStreaks.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final friend = pulse.friendStreaks[i];
                          return _StreakAvatar(friend: friend);
                        },
                      ),
                    ),
                  ],

                  // Recent activity lines (max 2)
                  if (pulse.recentActivity.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    ...pulse.recentActivity.take(2).map(
                          (event) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 10,
                                  backgroundColor: cs.primaryContainer,
                                  child: Text(
                                    (event.actorName.isNotEmpty
                                            ? event.actorName[0]
                                            : '?')
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      color: cs.onPrimaryContainer,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _activityLine(event),
                                    style: tt.bodySmall?.copyWith(
                                      color: cs.onSurfaceVariant,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _activityLine(FeedEvent event) {
    final name = event.actorName.split(' ').first;
    switch (event.eventType) {
      case 'streak':
        return '$name is on a streak!';
      case 'achievement':
        return '$name earned a badge';
      case 'share':
        if (event.isRecipe) return '$name shared a recipe';
        return '$name shared an update';
      default:
        return '$name was active';
    }
  }
}

class _StreakAvatar extends StatelessWidget {
  final FriendStreak friend;
  const _StreakAvatar({required this.friend});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasStreak = friend.streakDays > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor:
                  hasStreak ? const Color(0xFFF97316) : cs.surfaceContainerHighest,
              child: CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  (friend.name.isNotEmpty ? friend.name[0] : '?')
                      .toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
            ),
            if (hasStreak)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: cs.surface,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.local_fire_department,
                    size: 10,
                    color: Color(0xFFF97316),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          friend.name.split(' ').first,
          style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
