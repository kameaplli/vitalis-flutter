import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';
import 'reaction_bar.dart';

/// Modern feed card inspired by clean social platform design.
class FeedCard extends StatelessWidget {
  final FeedEvent event;
  final ValueChanged<String>? onReact;
  final VoidCallback? onComment;
  final VoidCallback? onShare;
  final VoidCallback? onProfileTap;

  const FeedCard({
    super.key,
    required this.event,
    this.onReact,
    this.onComment,
    this.onShare,
    this.onProfileTap,
  });

  // Gradient pairs for each content type
  static const _typeGradients = <String, List<Color>>{
    'streak': [Color(0xFFF97316), Color(0xFFFBBF24)],
    'recipe': [Color(0xFF22C55E), Color(0xFF10B981)],
    'achievement': [Color(0xFFFBBF24), Color(0xFFEAB308)],
    'challenge': [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    'daily_nutrition': [Color(0xFF3B82F6), Color(0xFF06B6D4)],
  };

  static const _typeEmojis = <String, String>{
    'streak': '\uD83D\uDD25',
    'recipe': '\uD83C\uDF73',
    'achievement': '\uD83C\uDFC6',
    'challenge': '\uD83D\uDEA9',
    'daily_nutrition': '\uD83C\uDF4E',
    'meal_photo': '\uD83D\uDCF8',
  };

  List<Color> get _gradient {
    if (event.isStreak) return _typeGradients['streak']!;
    if (event.isRecipe) return _typeGradients['recipe']!;
    if (event.isAchievement) return _typeGradients['achievement']!;
    if (event.eventType == 'challenge') return _typeGradients['challenge']!;
    if (event.contentType == 'daily_nutrition') {
      return _typeGradients['daily_nutrition']!;
    }
    return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
  }

  String get _emoji {
    return _typeEmojis[event.contentType] ??
        _typeEmojis[event.eventType] ??
        '\u2728';
  }

  bool get _isNoteType => event.isNote || event.contentType == 'note';

  String get _eventDescription {
    final snap = event.contentSnapshot;
    final ct = event.contentType;
    final et = event.eventType;

    if (ct == 'streak' || et == 'streak') {
      final days = snap['streak_days'] ?? snap['days'] ?? '?';
      return 'is on a $days-day streak! \uD83D\uDD25';
    }
    if (ct == 'daily_nutrition') {
      final cals = snap['total_calories'] ?? snap['calories'];
      if (cals != null) return 'logged $cals kcal today';
      return 'shared their nutrition summary';
    }
    if (ct == 'note') return '';
    if (ct == 'recipe') {
      final name = snap['recipe_name'] ?? snap['name'] ?? 'a recipe';
      return 'shared a recipe: $name';
    }
    if (ct == 'meal_photo') return 'shared a meal photo';
    if (ct == 'meal') {
      final mealType = snap['meal_type'] ?? 'meal';
      return 'shared their $mealType';
    }

    if (et == 'achievement') {
      final badge = snap['badge_name'] ?? snap['title'] ?? 'a badge';
      return 'earned $badge \uD83C\uDFC6';
    }
    if (et == 'challenge') {
      final title = snap['challenge_title'] ?? snap['title'] ?? 'a challenge';
      return 'joined "$title"';
    }

    return snap['description']?.toString() ?? 'shared an update';
  }

  String get _noteText {
    final snap = event.contentSnapshot;
    return snap['note']?.toString() ??
        snap['text']?.toString() ??
        snap['description']?.toString() ??
        '';
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(event.createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${event.createdAt.month}/${event.createdAt.day}';
  }

  int get _totalReactions {
    int total = 0;
    for (final r in event.reactions) {
      total += r.count;
    }
    return total;
  }

  // Avatar gradient colors (Instagram-story-ring style)
  static const _avatarGradientColors = [
    Color(0xFFE040FB),
    Color(0xFFFF5722),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE040FB),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: Avatar + Name + Time ──
          _buildHeader(context),

          // ── Content area ──
          if (_isNoteType) ...[
            _buildNoteContent(context),
          ] else ...[
            _buildActivityContent(context),
            const SizedBox(height: 12),
            _buildGradientContentCard(context),
          ],

          // ── Note text for non-note types ──
          if (!_isNoteType && _noteText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Text(
                _noteText,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.5,
                  color: cs.onSurface.withValues(alpha: 0.85),
                  letterSpacing: 0.1,
                ),
              ),
            ),

          // ── Reaction summary ──
          if (_totalReactions > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: ReactionBar(
                reactions: event.reactions,
                onReact: onReact,
              ),
            ),

          // ── Engagement stats line ──
          if (_totalReactions > 0 || event.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  if (_totalReactions > 0)
                    Text(
                      '$_totalReactions ${_totalReactions == 1 ? 'like' : 'likes'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: cs.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  if (_totalReactions > 0 && event.commentCount > 0)
                    Text(
                      '  \u00B7  ',
                      style: TextStyle(
                        color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  if (event.commentCount > 0)
                    GestureDetector(
                      onTap: onComment,
                      child: Text(
                        '${event.commentCount} ${event.commentCount == 1 ? 'comment' : 'comments'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Divider before actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
          ),

          // ── Bottom actions row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
            child: Row(
              children: [
                // React button
                _ActionButton(
                  icon: Icons.favorite_outline_rounded,
                  label: 'Like',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onReact?.call('love');
                  },
                ),
                // Comment button
                _ActionButton(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Comment',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onComment?.call();
                  },
                ),
                // Share button
                _ActionButton(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onShare?.call();
                  },
                ),
              ],
            ),
          ),

          // ── Bottom divider ──
          Divider(
            height: 1,
            thickness: 6,
            color: cs.outlineVariant.withValues(alpha: 0.12),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onProfileTap,
            child: _buildAvatar(cs),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: onProfileTap,
                  child: Text(
                    event.actorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      letterSpacing: -0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _timeAgo,
                  style: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              size: 20,
            ),
            onPressed: () {},
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(ColorScheme cs) {
    final initial =
        (event.actorName.isNotEmpty ? event.actorName[0] : '?').toUpperCase();
    final hasImage =
        event.actorAvatarUrl != null && event.actorAvatarUrl!.isNotEmpty;

    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: _avatarGradientColors,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: cs.surface,
        ),
        padding: const EdgeInsets.all(2),
        child: hasImage
            ? CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(event.actorAvatarUrl!),
                backgroundColor: cs.primaryContainer,
              )
            : CircleAvatar(
                radius: 18,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  initial,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: cs.onPrimaryContainer,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNoteContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = _noteText;
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
        child: Text(
          'Shared a note',
          style: TextStyle(
            fontSize: 15,
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 15.5,
          height: 1.55,
          color: cs.onSurface,
          letterSpacing: 0.1,
        ),
      ),
    );
  }

  Widget _buildActivityContent(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final desc = _eventDescription;
    if (desc.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: RichText(
        text: TextSpan(
          children: [
            TextSpan(
              text: event.actorName,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14.5,
                color: cs.onSurface,
                letterSpacing: -0.1,
              ),
            ),
            TextSpan(
              text: ' $desc',
              style: TextStyle(
                fontSize: 14.5,
                color: cs.onSurface.withValues(alpha: 0.85),
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientContentCard(BuildContext context) {
    final snap = event.contentSnapshot;
    final title = snap['title']?.toString() ??
        event.eventType.replaceAll('_', ' ');

    String? statsText;
    if (event.isStreak || event.contentType == 'streak') {
      final days = snap['streak_days'] ?? snap['days'];
      if (days != null) statsText = '\uD83D\uDD25 $days consecutive days';
    } else if (event.contentType == 'daily_nutrition') {
      final cals = snap['total_calories'] ?? snap['calories'];
      final protein = snap['protein'];
      final carbs = snap['carbs'];
      final fat = snap['fat'];
      if (cals != null) {
        statsText = '$cals kcal';
        if (protein != null) statsText = '$statsText \u00B7 P:${protein}g';
        if (carbs != null) statsText = '$statsText \u00B7 C:${carbs}g';
        if (fat != null) statsText = '$statsText \u00B7 F:${fat}g';
      }
    } else if (event.contentType == 'meal') {
      final cals = snap['total_calories'];
      if (cals != null) statsText = '$cals kcal';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Center(
              child: Text(
                _emoji,
                style: const TextStyle(fontSize: 22),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: -0.2,
                  ),
                ),
                if (snap['subtitle'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      snap['subtitle'].toString(),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (statsText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      statsText,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
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

/// Action button used in the bottom row (Like, Comment, Share).
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: cs.onSurfaceVariant.withValues(alpha: 0.7)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
