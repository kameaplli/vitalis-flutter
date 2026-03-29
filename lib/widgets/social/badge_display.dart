import 'package:flutter/material.dart' hide Badge;
import '../../models/social_models.dart';
import 'package:hugeicons/hugeicons.dart';

/// Displays a row of badge icons from a badge showcase list (IDs).
class BadgeShowcaseRow extends StatelessWidget {
  final List<String> badgeIds;
  final double size;

  const BadgeShowcaseRow({
    super.key,
    required this.badgeIds,
    this.size = 28,
  });

  @override
  Widget build(BuildContext context) {
    if (badgeIds.isEmpty) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: badgeIds.take(6).map((id) {
        return Tooltip(
          message: BadgeCatalog.name(id),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primaryContainer.withValues(alpha: 0.4),
            ),
            alignment: Alignment.center,
            child: Text(
              BadgeCatalog.icon(id),
              style: TextStyle(fontSize: size * 0.55),
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Full badge card for use in a grid or list.
class BadgeCard extends StatelessWidget {
  final Badge badge;
  final VoidCallback? onTap;

  const BadgeCard({super.key, required this.badge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tierColor = _tierColor(badge.tier, cs);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: tierColor.withValues(alpha: 0.4), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    tierColor.withValues(alpha: 0.3),
                    tierColor.withValues(alpha: 0.1),
                  ],
                ),
              ),
              alignment: Alignment.center,
              child: Text(badge.icon, style: const TextStyle(fontSize: 24)),
            ),
            const SizedBox(height: 8),
            // Name
            Text(
              badge.name,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: cs.onSurface,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            // Tier
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: tierColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                badge.tier.label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: tierColor,
                ),
              ),
            ),
            const SizedBox(height: 4),
            // Description
            Text(
              badge.description,
              style: TextStyle(
                fontSize: 11,
                color: cs.onSurfaceVariant.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            // Earned date
            if (badge.earnedAt != null) ...[
              const SizedBox(height: 4),
              Text(
                'Earned ${_formatDate(badge.earnedAt!)}',
                style: TextStyle(
                  fontSize: 10,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _tierColor(BadgeTier tier, ColorScheme cs) => switch (tier) {
        BadgeTier.bronze => const Color(0xFFCD7F32),
        BadgeTier.silver => const Color(0xFFC0C0C0),
        BadgeTier.gold => const Color(0xFFFFD700),
        BadgeTier.platinum => cs.primary,
      };

  String _formatDate(DateTime dt) {
    return '${dt.month}/${dt.day}/${dt.year}';
  }
}

/// Grid of badge cards.
class BadgeGrid extends StatelessWidget {
  final List<Badge> badges;

  const BadgeGrid({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) {
      final cs = Theme.of(context).colorScheme;
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              HugeIcon(icon: HugeIcons.strokeRoundedAward01,
                  size: 48, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              Text(
                'No badges yet',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Keep engaging with the community to earn badges!',
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant.withValues(alpha: 0.4),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: badges.length,
      itemBuilder: (_, i) => BadgeCard(badge: badges[i]),
    );
  }
}
