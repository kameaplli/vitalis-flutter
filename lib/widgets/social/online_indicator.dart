import 'package:flutter/material.dart';

/// Small green dot indicating online status, positioned on top of an avatar.
class OnlineIndicator extends StatelessWidget {
  final bool isOnline;
  final double size;

  const OnlineIndicator({
    super.key,
    required this.isOnline,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    if (!isOnline) return const SizedBox.shrink();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF22C55E),
        shape: BoxShape.circle,
        border: Border.all(
          color: Theme.of(context).colorScheme.surface,
          width: 2,
        ),
      ),
    );
  }
}

/// Avatar with online indicator overlay.
class AvatarWithPresence extends StatelessWidget {
  final String? avatarUrl;
  final String fallbackInitial;
  final bool isOnline;
  final double radius;

  const AvatarWithPresence({
    super.key,
    this.avatarUrl,
    required this.fallbackInitial,
    required this.isOnline,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasAvatar = avatarUrl != null && avatarUrl!.isNotEmpty;

    return SizedBox(
      width: radius * 2 + 4,
      height: radius * 2 + 4,
      child: Stack(
        children: [
          CircleAvatar(
            radius: radius,
            backgroundColor: cs.primaryContainer,
            backgroundImage:
                hasAvatar ? NetworkImage(avatarUrl!) : null,
            child: !hasAvatar
                ? Text(
                    fallbackInitial.isNotEmpty
                        ? fallbackInitial[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: radius * 0.6,
                      color: cs.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
          if (isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: OnlineIndicator(isOnline: true, size: radius * 0.5),
            ),
        ],
      ),
    );
  }
}

/// Presence text badge (e.g., "Online" or "3h ago").
class PresenceBadge extends StatelessWidget {
  final bool isOnline;
  final String presenceText;

  const PresenceBadge({
    super.key,
    required this.isOnline,
    required this.presenceText,
  });

  @override
  Widget build(BuildContext context) {
    if (presenceText.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: isOnline ? const Color(0xFF22C55E) : cs.outline,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          presenceText,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isOnline
                ? const Color(0xFF22C55E)
                : cs.onSurfaceVariant.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}
