import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';

/// Modern feed card — LinkedIn/Instagram style with inline reactions.
class FeedCard extends StatefulWidget {
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
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _doubleTapCtrl;
  late final Animation<double> _doubleTapScale;
  late final Animation<double> _doubleTapOpacity;
  bool _showDoubleTapHeart = false;

  FeedEvent get event => widget.event;
  ValueChanged<String>? get onReact => widget.onReact;
  VoidCallback? get onComment => widget.onComment;
  VoidCallback? get onShare => widget.onShare;
  VoidCallback? get onProfileTap => widget.onProfileTap;

  // Forward getters from the widget's static/instance members
  List<Color> get _gradient {
    if (event.isStreak) return FeedCard._typeGradients['streak']!;
    if (event.isRecipe) return FeedCard._typeGradients['recipe']!;
    if (event.isAchievement) return FeedCard._typeGradients['achievement']!;
    if (event.eventType == 'challenge') return FeedCard._typeGradients['challenge']!;
    if (event.contentType == 'daily_nutrition') {
      return FeedCard._typeGradients['daily_nutrition']!;
    }
    return [const Color(0xFF64748B), const Color(0xFF94A3B8)];
  }

  String get _emoji {
    return FeedCard._typeEmojis[event.contentType] ??
        FeedCard._typeEmojis[event.eventType] ??
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

  bool get _userLiked {
    for (final r in event.reactions) {
      if (r.userReacted) return true;
    }
    return false;
  }

  List<String> get _topReactionEmojis {
    const emojiMap = <String, String>{
      'love': '\u2764\uFE0F',
      'fire': '\uD83D\uDD25',
      'clap': '\uD83D\uDC4F',
      'inspiring': '\uD83D\uDCAA',
      'agree': '\uD83D\uDE4C',
    };
    final sorted = [...event.reactions]..sort((a, b) => b.count.compareTo(a.count));
    return sorted
        .where((r) => r.count > 0)
        .take(3)
        .map((r) => emojiMap[r.type] ?? '\u2764\uFE0F')
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _doubleTapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _doubleTapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.2), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.2, end: 0.95), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.95, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(CurvedAnimation(parent: _doubleTapCtrl, curve: Curves.easeOut));
    _doubleTapOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
    ]).animate(_doubleTapCtrl);

    _doubleTapCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showDoubleTapHeart = false);
      }
    });
  }

  @override
  void dispose() {
    _doubleTapCtrl.dispose();
    super.dispose();
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _showDoubleTapHeart = true);
    _doubleTapCtrl.forward(from: 0);
    onReact?.call('love');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onDoubleTap: _handleDoubleTap,
      child: Container(
        color: cs.surface,
        child: Stack(
          children: [
            Column(
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

          // ── Engagement stats line (like LinkedIn: emoji icons + count · comments) ──
          if (_totalReactions > 0 || event.commentCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  if (_totalReactions > 0) ...[
                    // Show top reaction emojis stacked
                    SizedBox(
                      width: _topReactionEmojis.length * 16.0 + 4,
                      height: 20,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (var i = 0; i < _topReactionEmojis.length; i++)
                            Positioned(
                              left: i * 14.0,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: cs.surface,
                                  border: Border.all(color: cs.surface, width: 1.5),
                                ),
                                child: Center(
                                  child: Text(
                                    _topReactionEmojis[i],
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$_totalReactions',
                      style: TextStyle(
                        fontSize: 13,
                        color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (event.commentCount > 0)
                    GestureDetector(
                      onTap: onComment,
                      child: Text(
                        '${event.commentCount} ${event.commentCount == 1 ? 'comment' : 'comments'}',
                        style: TextStyle(
                          fontSize: 13,
                          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── Divider before actions ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Divider(
              height: 1,
              thickness: 0.5,
              color: cs.outlineVariant.withValues(alpha: 0.25),
            ),
          ),

          // ── Bottom actions row (LinkedIn style: Like · Comment · Share) ──
          _ActionBar(
            userLiked: _userLiked,
            onLike: () {
              HapticFeedback.lightImpact();
              onReact?.call('love');
            },
            onLongPressLike: () {
              HapticFeedback.mediumImpact();
              _showReactionPicker(context);
            },
            onComment: () {
              HapticFeedback.lightImpact();
              onComment?.call();
            },
            onShare: () {
              HapticFeedback.lightImpact();
              onShare?.call();
            },
          ),

          // ── Bottom divider (thick separator between posts) ──
          Divider(
            height: 1,
            thickness: 6,
            color: cs.outlineVariant.withValues(alpha: 0.12),
          ),
              ],
            ),
            // ── Double-tap heart overlay (Instagram-style) ──
            if (_showDoubleTapHeart)
              Positioned.fill(
                child: IgnorePointer(
                  child: Center(
                    child: FadeTransition(
                      opacity: _doubleTapOpacity,
                      child: ScaleTransition(
                        scale: _doubleTapScale,
                        child: const Icon(
                          Icons.favorite_rounded,
                          size: 80,
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              blurRadius: 24,
                              color: Color(0x88E53935),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showReactionPicker(BuildContext context) {
    const reactions = <String, String>{
      'love': '\u2764\uFE0F',
      'fire': '\uD83D\uDD25',
      'clap': '\uD83D\uDC4F',
      'inspiring': '\uD83D\uDCAA',
      'agree': '\uD83D\uDE4C',
    };

    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (ctx) => Stack(
        children: [
          // Dismiss on tap outside
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Center(
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(32),
              shadowColor: Colors.black26,
              color: cs.surface,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.2),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: reactions.entries.map((entry) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(ctx);
                        HapticFeedback.lightImpact();
                        onReact?.call(entry.key);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 28),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
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
          colors: FeedCard._avatarGradientColors,
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

/// LinkedIn-style action bar with Instagram-style heart animation.
class _ActionBar extends StatefulWidget {
  final bool userLiked;
  final VoidCallback onLike;
  final VoidCallback onLongPressLike;
  final VoidCallback onComment;
  final VoidCallback onShare;

  const _ActionBar({
    required this.userLiked,
    required this.onLike,
    required this.onLongPressLike,
    required this.onComment,
    required this.onShare,
  });

  @override
  State<_ActionBar> createState() => _ActionBarState();
}

class _ActionBarState extends State<_ActionBar> with TickerProviderStateMixin {
  late final AnimationController _heartCtrl;
  late final Animation<double> _heartScale;
  late final AnimationController _burstCtrl;
  bool _wasLiked = false;

  @override
  void initState() {
    super.initState();
    _wasLiked = widget.userLiked;

    _heartCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _heartScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 0.85), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.85, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _heartCtrl, curve: Curves.easeOut));

    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
  }

  @override
  void didUpdateWidget(_ActionBar old) {
    super.didUpdateWidget(old);
    // Trigger animation when transitioning from not-liked to liked
    if (widget.userLiked && !_wasLiked) {
      _heartCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
    }
    _wasLiked = widget.userLiked;
  }

  @override
  void dispose() {
    _heartCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  void _handleLikeTap() {
    if (!widget.userLiked) {
      // Trigger animation immediately (optimistic)
      _heartCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
    }
    widget.onLike();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final inactiveColor = cs.onSurfaceVariant.withValues(alpha: 0.65);
    const likedColor = Color(0xFFE53935);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
      child: Row(
        children: [
          // Like button with animation
          Expanded(
            child: GestureDetector(
              onLongPress: widget.onLongPressLike,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: _handleLikeTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            // Particle burst (behind heart)
                            AnimatedBuilder(
                              animation: _burstCtrl,
                              builder: (_, __) {
                                if (!_burstCtrl.isAnimating &&
                                    _burstCtrl.status != AnimationStatus.completed) {
                                  return const SizedBox.shrink();
                                }
                                return CustomPaint(
                                  size: const Size(28, 28),
                                  painter: _BurstPainter(
                                    progress: _burstCtrl.value,
                                    color: likedColor,
                                  ),
                                );
                              },
                            ),
                            // Heart icon
                            ScaleTransition(
                              scale: _heartScale,
                              child: Icon(
                                widget.userLiked
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                size: 19,
                                color: widget.userLiked
                                    ? likedColor
                                    : inactiveColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Like',
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.userLiked ? likedColor : inactiveColor,
                          fontWeight: widget.userLiked
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Comment button
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onComment,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 18, color: inactiveColor),
                    const SizedBox(width: 6),
                    Text(
                      'Comment',
                      style: TextStyle(
                        fontSize: 13,
                        color: inactiveColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Share button
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: widget.onShare,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.share_outlined,
                        size: 18, color: inactiveColor),
                    const SizedBox(width: 6),
                    Text(
                      'Share',
                      style: TextStyle(
                        fontSize: 13,
                        color: inactiveColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a ring of particles bursting outward (Instagram heart animation).
class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;

  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.9;
    final particleCount = 8;

    // Ring that expands and fades
    final ringRadius = maxRadius * progress;
    final ringOpacity = (1 - progress).clamp(0.0, 0.6);
    final ringPaint = Paint()
      ..color = color.withValues(alpha: ringOpacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 * (1 - progress);
    canvas.drawCircle(center, ringRadius, ringPaint);

    // Small dots bursting outward
    for (int i = 0; i < particleCount; i++) {
      final angle = (i / particleCount) * 2 * math.pi;
      final dotRadius = maxRadius * 0.6 + maxRadius * 0.4 * progress;
      final dotX = center.dx + math.cos(angle) * dotRadius;
      final dotY = center.dy + math.sin(angle) * dotRadius;
      final dotOpacity = (1 - progress * 1.2).clamp(0.0, 0.8);
      final dotSize = 2.0 * (1 - progress * 0.7);

      final dotPaint = Paint()
        ..color = (i.isEven ? color : const Color(0xFFFF9800))
            .withValues(alpha: dotOpacity);
      canvas.drawCircle(Offset(dotX, dotY), dotSize, dotPaint);
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}
