import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';
import 'reaction_bar.dart';

/// Single feed event card used in the social feed list.
class FeedCard extends StatelessWidget {
  final FeedEvent event;
  final ValueChanged<String>? onReact;
  final VoidCallback? onTap;
  final VoidCallback? onProfileTap;

  const FeedCard({
    super.key,
    required this.event,
    this.onReact,
    this.onTap,
    this.onProfileTap,
  });

  // Gradient pairs for each content type
  static const _typeGradients = <String, List<Color>>{
    'streak': [Color(0xFFF97316), Color(0xFFFBBF24)],
    'recipe': [Color(0xFF22C55E), Color(0xFF10B981)],
    'achievement': [Color(0xFFFBBF24), Color(0xFFEAB308)],
    'challenge': [Color(0xFF8B5CF6), Color(0xFF6366F1)],
  };

  static const _typeIcons = <String, IconData>{
    'streak': Icons.local_fire_department,
    'recipe': Icons.restaurant_menu,
    'achievement': Icons.emoji_events,
    'challenge': Icons.flag,
    'meal_photo': Icons.camera_alt,
    'note': Icons.sticky_note_2,
  };

  List<Color> get _gradient {
    if (event.isStreak) return _typeGradients['streak']!;
    if (event.isRecipe) return _typeGradients['recipe']!;
    if (event.isAchievement) return _typeGradients['achievement']!;
    if (event.eventType == 'challenge') return _typeGradients['challenge']!;
    return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
  }

  IconData get _icon {
    return _typeIcons[event.contentType] ??
        _typeIcons[event.eventType] ??
        Icons.share;
  }

  String get _eventDescription {
    final snap = event.contentSnapshot;
    switch (event.eventType) {
      case 'streak':
        final days = snap['streak_days'] ?? snap['days'] ?? '?';
        return 'is on a $days-day streak!';
      case 'achievement':
        final badge = snap['badge_name'] ?? snap['title'] ?? 'a badge';
        return 'earned $badge';
      case 'challenge':
        final title = snap['challenge_title'] ?? snap['title'] ?? 'a challenge';
        return 'joined "$title"';
      case 'share':
        if (event.isRecipe) {
          final name = snap['recipe_name'] ?? snap['name'] ?? 'a recipe';
          return 'shared a recipe: $name';
        }
        if (event.isMealPhoto) return 'shared a meal photo';
        return 'shared something';
      default:
        return snap['description'] ?? 'did something awesome';
    }
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(event.createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${event.createdAt.month}/${event.createdAt.day}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final commentCount =
        (event.contentSnapshot['comment_count'] as num?)?.toInt() ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface,
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Actor row: avatar + name + timestamp
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: onProfileTap,
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        (event.actorName.isNotEmpty
                                ? event.actorName[0]
                                : '?')
                            .toUpperCase(),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: cs.onPrimaryContainer,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.actorName,
                          style: tt.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _timeAgo,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.more_horiz,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),

            // Event description
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Text(
                '${event.actorName} $_eventDescription',
                style: tt.bodyMedium,
              ),
            ),

            // Content card with gradient
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  colors: _gradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  Icon(_icon, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.contentSnapshot['title']?.toString() ??
                              event.eventType.replaceAll('_', ' '),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        if (event.contentSnapshot['subtitle'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              event.contentSnapshot['subtitle'].toString(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.85),
                                fontSize: 13,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Reaction bar
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
              child: ReactionBar(
                reactions: event.reactions,
                onReact: onReact,
              ),
            ),

            // Comment count
            if (commentCount > 0)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
                child: Text(
                  '$commentCount comment${commentCount == 1 ? '' : 's'}',
                  style: tt.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),

            const SizedBox(height: 6),
          ],
        ),
      ),
    );
  }
}
