import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';

/// Row of reaction icons with counts. Tap to toggle a reaction.
class ReactionBar extends StatelessWidget {
  final List<ReactionSummary> reactions;
  final ValueChanged<String>? onReact;

  const ReactionBar({
    super.key,
    required this.reactions,
    this.onReact,
  });

  static const _reactionIcons = <String, IconData>{
    'heart': Icons.favorite,
    'clap': Icons.back_hand,
    'fire': Icons.local_fire_department,
    'star': Icons.star,
    'flex': Icons.fitness_center,
    'yum': Icons.restaurant,
  };

  static const _reactionColors = <String, Color>{
    'heart': Color(0xFFEF4444),
    'clap': Color(0xFFF59E0B),
    'fire': Color(0xFFF97316),
    'star': Color(0xFFEAB308),
    'flex': Color(0xFF8B5CF6),
    'yum': Color(0xFF22C55E),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Build a map of existing reactions by type for quick lookup
    final reactionMap = {for (final r in reactions) r.type: r};

    return Row(
      children: _reactionIcons.entries.map((entry) {
        final type = entry.key;
        final icon = entry.value;
        final reaction = reactionMap[type];
        final count = reaction?.count ?? 0;
        final userReacted = reaction?.userReacted ?? false;
        final color = _reactionColors[type] ?? cs.onSurfaceVariant;

        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onReact != null
                ? () {
                    HapticFeedback.lightImpact();
                    onReact!(type);
                  }
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: userReacted
                    ? color.withOpacity(0.15)
                    : cs.surfaceContainerHighest.withOpacity(0.5),
                border: userReacted
                    ? Border.all(color: color.withOpacity(0.4), width: 1)
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: 14,
                    color: userReacted ? color : cs.onSurfaceVariant,
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            userReacted ? FontWeight.w600 : FontWeight.normal,
                        color: userReacted ? color : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
