import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

class AchievementBadge {
  final String id;
  final String name;
  final String description;
  final String icon;
  final bool earned;

  const AchievementBadge({
    required this.id,
    required this.name,
    required this.description,
    required this.icon,
    required this.earned,
  });

  factory AchievementBadge.fromJson(Map<String, dynamic> json) {
    return AchievementBadge(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      icon: json['icon'] as String? ?? 'star',
      earned: json['earned'] as bool? ?? false,
    );
  }

  List<List<dynamic>> get iconData {
    const map = {
      'star': HugeIcons.strokeRoundedStar,
      'local_fire_department': HugeIcons.strokeRoundedFire,
      'emoji_events': HugeIcons.strokeRoundedAward01,
      'auto_awesome': HugeIcons.strokeRoundedStars,
      'camera_alt': HugeIcons.strokeRoundedCamera01,
      'qr_code_scanner': HugeIcons.strokeRoundedQrCode,
      'wb_sunny': HugeIcons.strokeRoundedSun01,
      'psychology': HugeIcons.strokeRoundedBrain,
    };
    return map[icon] ?? HugeIcons.strokeRoundedStar;
  }
}

class AchievementStats {
  final int totalEntries;
  final int currentStreak;
  final int longestStreak;
  final int clearSkinStreak;
  final int photosTaken;
  final int productsScanned;
  final int environmentDays;

  const AchievementStats({
    required this.totalEntries,
    required this.currentStreak,
    required this.longestStreak,
    required this.clearSkinStreak,
    required this.photosTaken,
    required this.productsScanned,
    required this.environmentDays,
  });

  factory AchievementStats.fromJson(Map<String, dynamic> json) {
    return AchievementStats(
      totalEntries: json['total_entries'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      clearSkinStreak: json['clear_skin_streak'] as int? ?? 0,
      photosTaken: json['photos_taken'] as int? ?? 0,
      productsScanned: json['products_scanned'] as int? ?? 0,
      environmentDays: json['environment_days'] as int? ?? 0,
    );
  }
}

/// Achievement badges grid with stats.
class AchievementBadgesWidget extends StatelessWidget {
  final List<AchievementBadge> badges;
  final AchievementStats stats;

  const AchievementBadgesWidget({
    super.key,
    required this.badges,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Streak stats
        Row(
          children: [
            _StatChip(
              icon: HugeIcons.strokeRoundedFire,
              label: '${stats.currentStreak}d streak',
              color: stats.currentStreak > 0 ? Colors.orange : Colors.grey,
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: HugeIcons.strokeRoundedAward01,
              label: 'Best: ${stats.longestStreak}d',
              color: Colors.amber,
            ),
            const SizedBox(width: 8),
            _StatChip(
              icon: HugeIcons.strokeRoundedStars,
              label: '${stats.totalEntries} logs',
              color: cs.primary,
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Badge grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: badges.map((b) => _BadgeItem(badge: b)).toList(),
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;

  const _StatChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }
}

class _BadgeItem extends StatelessWidget {
  final AchievementBadge badge;
  const _BadgeItem({required this.badge});

  @override
  Widget build(BuildContext context) {
    final earned = badge.earned;
    return Tooltip(
      message: badge.description,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: earned ? Colors.amber.shade100 : Colors.grey.shade200,
              shape: BoxShape.circle,
              border: Border.all(
                color: earned ? Colors.amber : Colors.grey.shade400,
                width: earned ? 2.5 : 1,
              ),
              boxShadow: earned
                  ? [BoxShadow(color: Colors.amber.withValues(alpha: 0.3), blurRadius: 8)]
                  : null,
            ),
            child: HugeIcon(
              icon: badge.iconData,
              size: 24,
              color: earned ? Colors.amber.shade800 : Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: 64,
            child: Text(
              badge.name,
              style: TextStyle(
                fontSize: 11,
                fontWeight: earned ? FontWeight.w600 : FontWeight.normal,
                color: earned ? null : Colors.grey,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
