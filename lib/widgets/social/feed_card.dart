import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';
import 'report_block_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

/// Premium feed card — Instagram/LinkedIn hybrid with rich animations.
/// Performance: RepaintBoundary isolation, cached computations, optimistic UI.
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

  static const _avatarGradientColors = [
    Color(0xFFE040FB), Color(0xFFFF5722), Color(0xFFFFC107),
    Color(0xFF4CAF50), Color(0xFF2196F3), Color(0xFFE040FB),
  ];

  static const _reactionEmojis = <String, String>{
    'love': '\u2764\uFE0F',
    'fire': '\uD83D\uDD25',
    'clap': '\uD83D\uDC4F',
    'inspiring': '\uD83D\uDCAA',
    'agree': '\uD83D\uDE4C',
  };

  @override
  State<FeedCard> createState() => _FeedCardState();
}

class _FeedCardState extends State<FeedCard> with TickerProviderStateMixin {
  // ── Double-tap heart overlay ──
  late final AnimationController _doubleTapCtrl;
  late final Animation<double> _doubleTapScale;
  late final Animation<double> _doubleTapOpacity;
  bool _showDoubleTapHeart = false;

  // ── Like button animations ──
  late final AnimationController _likeCtrl;
  late final Animation<double> _likeScale;
  late final AnimationController _burstCtrl;
  bool _wasLiked = false;

  // ── Cached computations ──
  late List<Color> _gradient;
  late String _emoji;
  late bool _isNoteType;
  late List<String> _topEmojis;

  FeedEvent get event => widget.event;

  @override
  void initState() {
    super.initState();
    _wasLiked = _userLiked;
    _cacheComputations();

    // Double-tap: 650ms total, Instagram-style elastic overshoot
    _doubleTapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _doubleTapScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.3, end: 0.9), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.9, end: 1.0), weight: 10),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 25),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(CurvedAnimation(parent: _doubleTapCtrl, curve: Curves.easeOut));
    _doubleTapOpacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.0), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 55),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 30),
    ]).animate(_doubleTapCtrl);
    _doubleTapCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        setState(() => _showDoubleTapHeart = false);
      }
    });

    // Like button: 300ms, reduced overshoot (1.25x)
    _likeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _likeScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 0.92), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.92, end: 1.0), weight: 40),
    ]).animate(CurvedAnimation(parent: _likeCtrl, curve: Curves.easeOutBack));

    // Burst: 450ms, snappy particles
    _burstCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
  }

  void _cacheComputations() {
    final ct = event.contentType;
    final et = event.eventType;
    _gradient = FeedCard._typeGradients[ct] ??
        FeedCard._typeGradients[et] ??
        [const Color(0xFF64748B), const Color(0xFF94A3B8)];
    _emoji = FeedCard._typeEmojis[ct] ?? FeedCard._typeEmojis[et] ?? '\u2728';
    _isNoteType = event.isNote || ct == 'note';
    _topEmojis = _computeTopEmojis();
  }

  @override
  void didUpdateWidget(FeedCard old) {
    super.didUpdateWidget(old);
    if (old.event.id != event.id ||
        old.event.reactions.length != event.reactions.length) {
      _cacheComputations();
    }
    // Animate when transitioning to liked
    final nowLiked = _userLiked;
    if (nowLiked && !_wasLiked) {
      _likeCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
    }
    _wasLiked = nowLiked;
  }

  @override
  void dispose() {
    _doubleTapCtrl.stop();
    _doubleTapCtrl.dispose();
    _likeCtrl.dispose();
    _burstCtrl.dispose();
    super.dispose();
  }

  bool get _userLiked {
    for (final r in event.reactions) {
      if (r.userReacted) return true;
    }
    return false;
  }

  /// Returns the user's current reaction type (e.g., 'love', 'fire'), or null.
  String? get _userReactionType {
    for (final r in event.reactions) {
      if (r.userReacted) return r.type;
    }
    return null;
  }

  int get _totalReactions {
    int t = 0;
    for (final r in event.reactions) {
      t += r.count;
    }
    return t;
  }

  List<String> _computeTopEmojis() {
    final sorted = [...event.reactions]
      ..sort((a, b) => b.count.compareTo(a.count));
    return sorted
        .where((r) => r.count > 0)
        .take(3)
        .map((r) => FeedCard._reactionEmojis[r.type] ?? '\u2764\uFE0F')
        .toList();
  }

  String get _timeAgo {
    final diff = DateTime.now().difference(event.createdAt);
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${event.createdAt.month}/${event.createdAt.day}';
  }

  String get _noteText {
    final s = event.contentSnapshot;
    return s['note']?.toString() ?? s['text']?.toString() ?? s['description']?.toString() ?? '';
  }

  String get _eventDescription {
    final s = event.contentSnapshot;
    final ct = event.contentType;
    final et = event.eventType;
    if (ct == 'streak' || et == 'streak') return 'is on a ${s['streak_days'] ?? s['days'] ?? '?'}-day streak! \uD83D\uDD25';
    if (ct == 'daily_nutrition') {
      final c = s['total_calories'] ?? s['calories'];
      return c != null ? 'logged $c kcal today' : 'shared their nutrition summary';
    }
    if (ct == 'note') return '';
    if (ct == 'recipe') return 'shared a recipe: ${s['recipe_name'] ?? s['name'] ?? 'a recipe'}';
    if (ct == 'meal_photo') return 'shared a meal photo';
    if (ct == 'meal') return 'shared their ${s['meal_type'] ?? 'meal'}';
    if (et == 'achievement') return 'earned ${s['badge_name'] ?? s['title'] ?? 'a badge'} \uD83C\uDFC6';
    if (et == 'challenge') return 'joined "${s['challenge_title'] ?? s['title'] ?? 'a challenge'}"';
    return s['description']?.toString() ?? 'shared an update';
  }

  void _handleDoubleTap() {
    HapticFeedback.mediumImpact();
    setState(() => _showDoubleTapHeart = true);
    _doubleTapCtrl.forward(from: 0);
    _likeCtrl.forward(from: 0);
    _burstCtrl.forward(from: 0);
    widget.onReact?.call('love');
  }

  void _handleLikeTap() {
    HapticFeedback.lightImpact();
    // Toggle: if user already reacted, un-react with same type; otherwise default to 'love'
    final currentType = _userReactionType ?? 'love';
    if (!_userLiked) {
      _likeCtrl.forward(from: 0);
      _burstCtrl.forward(from: 0);
    }
    widget.onReact?.call(currentType);
  }

  void _showReactionPicker() {
    HapticFeedback.mediumImpact();
    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierColor: Colors.black12,
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              behavior: HitTestBehavior.opaque,
            ),
          ),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutBack,
              builder: (_, v, child) => Transform.scale(
                scale: v,
                child: Opacity(opacity: v.clamp(0.0, 1.0), child: child),
              ),
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(32),
                shadowColor: Colors.black26,
                color: cs.surface,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: FeedCard._reactionEmojis.entries.toList().asMap().entries.map((indexed) {
                      final entry = indexed.value;
                      final delay = indexed.key * 40;
                      return TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 200 + delay),
                        curve: Curves.elasticOut,
                        builder: (_, v, child) => Transform.scale(
                          scale: v,
                          child: child,
                        ),
                        child: _ReactionPickerEmoji(
                          emoji: entry.value,
                          onTap: () {
                            Navigator.pop(ctx);
                            HapticFeedback.lightImpact();
                            widget.onReact?.call(entry.key);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final total = _totalReactions;
    final liked = _userLiked;

    return RepaintBoundary(
      child: GestureDetector(
        onDoubleTap: _handleDoubleTap,
        child: Container(
          color: cs.surface,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  _buildHeader(cs),

                  // ── Content ──
                  if (_isNoteType)
                    _buildNoteContent(cs)
                  else ...[
                    _buildActivityContent(cs),
                    const SizedBox(height: 10),
                    _buildGradientCard(cs),
                  ],

                  // ── Note text for non-note types ──
                  if (!_isNoteType && _noteText.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _noteText,
                        style: TextStyle(
                          fontSize: 15, height: 1.5,
                          color: cs.onSurface.withValues(alpha: 0.85),
                        ),
                      ),
                    ),

                  // ── Divider ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Divider(
                      height: 1, thickness: 0.5,
                      color: cs.outlineVariant.withValues(alpha: 0.15),
                    ),
                  ),

                  // ── Action bar: Reactions + Comment + Share on ONE line ──
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 0),
                    child: Row(
                      children: [
                        // Like button (tap = love, long press = picker)
                        // Shows only an icon — NO emoji here (emojis are in the count section)
                        GestureDetector(
                          onLongPress: _showReactionPicker,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: _handleLikeTap,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                              child: SizedBox(
                                width: 28, height: 28,
                                child: Stack(
                                  alignment: Alignment.center,
                                  clipBehavior: Clip.none,
                                  children: [
                                    AnimatedBuilder(
                                      animation: _burstCtrl,
                                      builder: (_, __) {
                                        if (_burstCtrl.value <= 0) return const SizedBox.shrink();
                                        return CustomPaint(
                                          size: const Size(28, 28),
                                          painter: _BurstPainter(
                                            progress: _burstCtrl.value,
                                            color: const Color(0xFFE53935),
                                          ),
                                        );
                                      },
                                    ),
                                    ScaleTransition(
                                      scale: _likeScale,
                                      child: HugeIcon(icon: 
                                        liked ? HugeIcons.strokeRoundedFavourite : HugeIcons.strokeRoundedFavourite,
                                        size: 20,
                                        color: liked
                                            ? const Color(0xFFE53935)
                                            : cs.onSurfaceVariant.withValues(alpha: 0.6),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Reaction summary: each unique emoji once + total count
                        // e.g. 10 love, 2 fire, 6 support → ❤️🔥💪 18
                        if (total > 0)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (final emoji in _topEmojis)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 1),
                                    child: Text(emoji, style: const TextStyle(fontSize: 14)),
                                  ),
                                const SizedBox(width: 4),
                                Text(
                                  '$total',
                                  style: TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w600,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const Spacer(),

                        // Comment with count
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onComment?.call();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                HugeIcon(icon: HugeIcons.strokeRoundedComment01, size: 18,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                                const SizedBox(width: 5),
                                Text(
                                  event.commentCount > 0 ? '${event.commentCount}' : 'Comment',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Share
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onShare?.call();
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                            child: HugeIcon(icon: HugeIcons.strokeRoundedShare01, size: 18,
                                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Post separator ──
                  Container(
                    height: 8,
                    color: cs.surfaceContainerLow,
                  ),
                ],
              ),

              // ── Double-tap heart overlay ──
              if (_showDoubleTapHeart)
                Positioned.fill(
                  child: IgnorePointer(
                    child: Center(
                      child: FadeTransition(
                        opacity: _doubleTapOpacity,
                        child: ScaleTransition(
                          scale: _doubleTapScale,
                          child: Icon(
                            Icons.favorite,
                            size: 100,
                            color: Colors.white,
                            shadows: [
                              Shadow(blurRadius: 40, color: Color(0xAAFFFFFF)),
                              Shadow(blurRadius: 24, color: Color(0x88E53935)),
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
      ),
    );
  }

  Widget _buildHeader(ColorScheme cs) {
    final initial = (event.actorName.isNotEmpty ? event.actorName[0] : '?').toUpperCase();
    final hasImage = event.actorAvatarUrl != null && event.actorAvatarUrl!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onProfileTap,
            child: Container(
              width: 42, height: 42,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: SweepGradient(colors: FeedCard._avatarGradientColors),
              ),
              padding: const EdgeInsets.all(2),
              child: Container(
                decoration: BoxDecoration(shape: BoxShape.circle, color: cs.surface),
                padding: const EdgeInsets.all(1.5),
                child: hasImage
                    ? CircleAvatar(
                        radius: 17,
                        backgroundImage: CachedNetworkImageProvider(event.actorAvatarUrl!),
                        backgroundColor: cs.primaryContainer,
                      )
                    : CircleAvatar(
                        radius: 17,
                        backgroundColor: cs.primaryContainer,
                        child: Text(initial, style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700,
                          color: cs.onPrimaryContainer,
                        )),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: widget.onProfileTap,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      event.actorName,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 14.5,
                        letterSpacing: -0.3,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '  \u00B7  $_timeAgo',
                    style: TextStyle(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                      fontSize: 12.5, fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            icon: HugeIcon(icon: HugeIcons.strokeRoundedMoreHorizontal,
                color: cs.onSurfaceVariant.withValues(alpha: 0.4), size: 20),
            onPressed: () => ReportBlockSheet.show(
              context,
              targetId: event.id,
              targetType: ReportTargetType.feedEvent,
              targetUserId: event.actorId,
              targetUserName: event.actorName,
            ),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildNoteContent(ColorScheme cs) {
    final text = _noteText;
    if (text.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Text('Shared a note',
            style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant, fontStyle: FontStyle.italic)),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Text(text, style: TextStyle(fontSize: 15, height: 1.5, color: cs.onSurface)),
    );
  }

  Widget _buildActivityContent(ColorScheme cs) {
    final desc = _eventDescription;
    if (desc.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: RichText(
        text: TextSpan(children: [
          TextSpan(text: event.actorName, style: TextStyle(
            fontWeight: FontWeight.w700, fontSize: 14.5,
            color: cs.onSurface, letterSpacing: -0.1,
          )),
          TextSpan(text: ' $desc', style: TextStyle(
            fontSize: 14.5, color: cs.onSurface.withValues(alpha: 0.85),
          )),
        ]),
      ),
    );
  }

  Widget _buildGradientCard(ColorScheme cs) {
    final snap = event.contentSnapshot;
    final title = snap['title']?.toString() ?? event.eventType.replaceAll('_', ' ');

    String? statsText;
    if (event.isStreak || event.contentType == 'streak') {
      final d = snap['streak_days'] ?? snap['days'];
      if (d != null) statsText = '\uD83D\uDD25 $d consecutive days';
    } else if (event.contentType == 'daily_nutrition') {
      final c = snap['total_calories'] ?? snap['calories'];
      if (c != null) {
        statsText = '$c kcal';
        final p = snap['protein'], cb = snap['carbs'], f = snap['fat'];
        if (p != null) statsText = '$statsText \u00B7 P:${p}g';
        if (cb != null) statsText = '$statsText \u00B7 C:${cb}g';
        if (f != null) statsText = '$statsText \u00B7 F:${f}g';
      }
    } else if (event.contentType == 'meal') {
      final c = snap['total_calories'];
      if (c != null) statsText = '$c kcal';
    }

    // Edge-to-edge gradient card (no horizontal margin)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            child: Center(child: Text(_emoji, style: const TextStyle(fontSize: 22))),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700,
                  fontSize: 15, letterSpacing: -0.2,
                )),
                if (snap['subtitle'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(snap['subtitle'].toString(),
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                  ),
                if (statsText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(statsText,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 13, fontWeight: FontWeight.w600,
                        )),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Reaction picker emoji with hover scale effect.
class _ReactionPickerEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;
  const _ReactionPickerEmoji({required this.emoji, required this.onTap});

  @override
  State<_ReactionPickerEmoji> createState() => _ReactionPickerEmojiState();
}

class _ReactionPickerEmojiState extends State<_ReactionPickerEmoji> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 1.5 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutBack,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Text(widget.emoji, style: const TextStyle(fontSize: 30)),
        ),
      ),
    );
  }
}

/// Burst particle painter — 12 particles, randomized angles, dual-color warm palette.
class _BurstPainter extends CustomPainter {
  final double progress;
  final Color color;
  static final _rng = math.Random(42); // Fixed seed for deterministic positions

  _BurstPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;

    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width * 0.95;
    const particleCount = 12;

    // Expanding ring
    final ringRadius = maxRadius * progress;
    final ringOpacity = (1 - progress).clamp(0.0, 0.5);
    canvas.drawCircle(
      center,
      ringRadius,
      Paint()
        ..color = color.withValues(alpha: ringOpacity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0 * (1 - progress),
    );

    // Warm-palette particles with randomized angles
    const colors = [
      Color(0xFFE53935), Color(0xFFFF6B6B), Color(0xFFFFB347),
      Color(0xFFFF5722), Color(0xFFF44336), Color(0xFFFF9800),
    ];

    for (int i = 0; i < particleCount; i++) {
      // Deterministic but varied angle offsets
      final angleOffset = _rng.nextDouble() * 0.4 - 0.2;
      final angle = (i / particleCount) * 2 * math.pi + angleOffset;
      final dotDist = maxRadius * 0.5 + maxRadius * 0.5 * progress;
      final dotX = center.dx + math.cos(angle) * dotDist;
      final dotY = center.dy + math.sin(angle) * dotDist;
      final dotOpacity = (1 - progress * 1.3).clamp(0.0, 0.85);
      final dotSize = (i.isEven ? 2.5 : 1.8) * (1 - progress * 0.6);

      canvas.drawCircle(
        Offset(dotX, dotY),
        dotSize,
        Paint()..color = colors[i % colors.length].withValues(alpha: dotOpacity),
      );
    }
  }

  @override
  bool shouldRepaint(_BurstPainter old) => old.progress != progress;
}

/// Shimmer skeleton for feed loading state.
class FeedCardShimmer extends StatelessWidget {
  const FeedCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shimmerColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header skeleton
          Row(
            children: [
              _ShimmerCircle(size: 42, color: shimmerColor),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ShimmerRect(width: 120, height: 12, color: shimmerColor),
                  const SizedBox(height: 6),
                  _ShimmerRect(width: 60, height: 10, color: shimmerColor),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Content skeleton
          _ShimmerRect(width: double.infinity, height: 14, color: shimmerColor),
          const SizedBox(height: 8),
          _ShimmerRect(width: 200, height: 14, color: shimmerColor),
          const SizedBox(height: 12),
          // Card skeleton
          _ShimmerRect(width: double.infinity, height: 72, color: shimmerColor, radius: 12),
          const SizedBox(height: 12),
          // Action bar skeleton
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _ShimmerRect(width: 60, height: 12, color: shimmerColor),
              _ShimmerRect(width: 70, height: 12, color: shimmerColor),
              _ShimmerRect(width: 50, height: 12, color: shimmerColor),
            ],
          ),
        ],
      ),
    );
  }
}

class _ShimmerCircle extends StatefulWidget {
  final double size;
  final Color color;
  const _ShimmerCircle({required this.size, required this.color});

  @override
  State<_ShimmerCircle> createState() => _ShimmerCircleState();
}

class _ShimmerCircleState extends State<_ShimmerCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: 0.3 + _ctrl.value * 0.4),
        ),
      ),
    );
  }
}

class _ShimmerRect extends StatefulWidget {
  final double width;
  final double height;
  final Color color;
  final double radius;
  const _ShimmerRect({
    required this.width, required this.height,
    required this.color, this.radius = 6,
  });

  @override
  State<_ShimmerRect> createState() => _ShimmerRectState();
}

class _ShimmerRectState extends State<_ShimmerRect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          color: widget.color.withValues(alpha: 0.3 + _ctrl.value * 0.4),
        ),
      ),
    );
  }
}
