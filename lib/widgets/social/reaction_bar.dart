import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';

/// Emoji-based reaction bar with Instagram-style pill design.
class ReactionBar extends StatefulWidget {
  final List<ReactionSummary> reactions;
  final ValueChanged<String>? onReact;

  const ReactionBar({
    super.key,
    required this.reactions,
    this.onReact,
  });

  @override
  State<ReactionBar> createState() => _ReactionBarState();
}

class _ReactionBarState extends State<ReactionBar>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _pickerOverlay;
  final LayerLink _layerLink = LayerLink();
  late final AnimationController _pickerAnimCtrl;
  late final Animation<double> _pickerScale;
  late final Animation<double> _pickerFade;

  static const _reactionEmojis = <String, String>{
    'love': '\u2764\uFE0F',
    'fire': '\uD83D\uDD25',
    'clap': '\uD83D\uDC4F',
    'inspiring': '\uD83D\uDCAA',
    'agree': '\uD83D\uDE4C',
  };

  @override
  void initState() {
    super.initState();
    _pickerAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _pickerScale = CurvedAnimation(
      parent: _pickerAnimCtrl,
      curve: Curves.easeOutBack,
    );
    _pickerFade = CurvedAnimation(
      parent: _pickerAnimCtrl,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _dismissPicker();
    _pickerAnimCtrl.dispose();
    super.dispose();
  }

  void _showPicker() {
    if (_pickerOverlay != null) {
      _dismissPicker();
      return;
    }

    final overlay = Overlay.of(context);
    _pickerOverlay = OverlayEntry(
      builder: (ctx) => _ReactionPickerOverlay(
        layerLink: _layerLink,
        scaleAnimation: _pickerScale,
        fadeAnimation: _pickerFade,
        onSelect: (type) {
          _dismissPicker();
          if (widget.onReact != null) {
            HapticFeedback.lightImpact();
            widget.onReact!(type);
          }
        },
        onDismiss: _dismissPicker,
      ),
    );
    overlay.insert(_pickerOverlay!);
    _pickerAnimCtrl.forward();
  }

  void _dismissPicker() {
    _pickerAnimCtrl.reverse().then((_) {
      _pickerOverlay?.remove();
      _pickerOverlay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final reactionMap = {for (final r in widget.reactions) r.type: r};

    // Show only reactions that have counts > 0, plus always allow adding
    final activeReactions = _reactionEmojis.entries.where((entry) {
      final reaction = reactionMap[entry.key];
      return (reaction?.count ?? 0) > 0 ||
          (reaction?.userReacted ?? false);
    }).toList();

    return CompositedTransformTarget(
      link: _layerLink,
      child: Row(
        children: [
          // Show active reactions as pills
          ...activeReactions.map((entry) {
            final type = entry.key;
            final emoji = entry.value;
            final reaction = reactionMap[type];
            final count = reaction?.count ?? 0;
            final userReacted = reaction?.userReacted ?? false;

            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: widget.onReact != null
                    ? () {
                        HapticFeedback.lightImpact();
                        widget.onReact!(type);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    color: userReacted
                        ? cs.primary.withValues(alpha: 0.12)
                        : cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    border: userReacted
                        ? Border.all(
                            color: cs.primary.withValues(alpha: 0.3),
                            width: 1.5)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        emoji,
                        style: TextStyle(
                          fontSize: userReacted ? 18 : 15,
                        ),
                      ),
                      if (count > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          _formatCount(count),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: userReacted
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: userReacted
                                ? cs.primary
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            );
          }),

          // "+" button to open reaction picker
          if (widget.onReact != null)
            GestureDetector(
              onTap: _showPicker,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
                child: Icon(
                  Icons.add,
                  size: 18,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return '$count';
  }
}

/// Floating pill overlay that shows all 5 emoji reactions.
class _ReactionPickerOverlay extends StatelessWidget {
  final LayerLink layerLink;
  final Animation<double> scaleAnimation;
  final Animation<double> fadeAnimation;
  final ValueChanged<String> onSelect;
  final VoidCallback onDismiss;

  static const _reactions = <String, String>{
    'love': '\u2764\uFE0F',
    'fire': '\uD83D\uDD25',
    'clap': '\uD83D\uDC4F',
    'inspiring': '\uD83D\uDCAA',
    'agree': '\uD83D\uDE4C',
  };

  const _ReactionPickerOverlay({
    required this.layerLink,
    required this.scaleAnimation,
    required this.fadeAnimation,
    required this.onSelect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Dismiss area
        Positioned.fill(
          child: GestureDetector(
            onTap: onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox.expand(),
          ),
        ),
        // Picker pill
        CompositedTransformFollower(
          link: layerLink,
          targetAnchor: Alignment.topLeft,
          followerAnchor: Alignment.bottomLeft,
          offset: const Offset(0, -8),
          child: FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              alignment: Alignment.bottomLeft,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(28),
                shadowColor: Colors.black26,
                color: cs.surface,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: _reactions.entries.map((entry) {
                      return _PickerEmoji(
                        emoji: entry.value,
                        onTap: () => onSelect(entry.key),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PickerEmoji extends StatefulWidget {
  final String emoji;
  final VoidCallback onTap;

  const _PickerEmoji({required this.emoji, required this.onTap});

  @override
  State<_PickerEmoji> createState() => _PickerEmojiState();
}

class _PickerEmojiState extends State<_PickerEmoji> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _hovering = true),
      onTapUp: (_) {
        setState(() => _hovering = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(8),
        child: AnimatedScale(
          scale: _hovering ? 1.4 : 1.0,
          duration: const Duration(milliseconds: 150),
          child: Text(
            widget.emoji,
            style: const TextStyle(fontSize: 24),
          ),
        ),
      ),
    );
  }
}
