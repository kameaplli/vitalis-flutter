import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../providers/auth_provider.dart';
import '../providers/social_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final user = ref.watch(authProvider).user;
    final badgeCount = ref.watch(notificationBadgeProvider).valueOrNull ?? 0;
    final avatarUrl = user?.avatarUrl != null
        ? ApiConstants.resolveUrl(user!.avatarUrl)
        : null;

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Profile header card ──────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: cs.primaryContainer,
                          backgroundImage: avatarUrl != null
                              ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                              : null,
                          child: avatarUrl == null
                              ? Text(
                                  (user?.name ?? 'Q').substring(0, 1).toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800,
                                    color: cs.onPrimaryContainer,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? 'User',
                                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'View profile',
                                style: tt.bodySmall?.copyWith(color: cs.primary),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Feature grid ────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 0.85,
                ),
                delegate: SliverChildListDelegate(
                  _buildItems(context, badgeCount),
                ),
              ),
            ),

            // ── Version footer ──────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Center(
                  child: Text(
                    'QoreHealth v5.0',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.4),
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

  List<Widget> _buildItems(BuildContext context, int badgeCount) {
    return [
      _MoreItem(
        icon: Icons.water_drop_rounded,
        label: 'Hydration',
        color: const Color(0xFF3B82F6),
        onTap: () => context.push('/hydration'),
      ),
      _MoreItem(
        icon: Icons.monitor_weight_rounded,
        label: 'Weight',
        color: const Color(0xFFF97316),
        onTap: () => context.push('/health/weight'),
      ),
      _MoreItem(
        icon: Icons.healing_rounded,
        label: 'Eczema',
        color: const Color(0xFFEF4444),
        onTap: () => context.push('/eczema'),
      ),
      _MoreItem(
        icon: Icons.science_rounded,
        label: 'Lab Results',
        color: const Color(0xFFD32F2F),
        onTap: () => context.push('/labs'),
      ),
      _MoreItem(
        icon: Icons.insights_rounded,
        label: 'Insights',
        color: const Color(0xFF8B5CF6),
        onTap: () => context.push('/insights'),
      ),
      _MoreItem(
        icon: Icons.people_rounded,
        label: 'Community',
        color: const Color(0xFF06B6D4),
        badge: badgeCount,
        onTap: () => context.push('/social'),
      ),
      _MoreItem(
        icon: Icons.shopping_cart_rounded,
        label: 'Grocery',
        color: const Color(0xFF22C55E),
        onTap: () => context.push('/grocery'),
      ),
      _MoreItem(
        icon: Icons.qr_code_scanner_rounded,
        label: 'Scanner',
        color: const Color(0xFF64748B),
        onTap: () => context.push('/scanner'),
      ),
      _MoreItem(
        icon: Icons.camera_alt_rounded,
        label: 'Skin Photos',
        color: const Color(0xFFEC4899),
        onTap: () => context.push('/skin-photos'),
      ),
      _MoreItem(
        icon: Icons.history_rounded,
        label: 'History',
        color: const Color(0xFF14B8A6),
        onTap: () => context.push('/entries'),
      ),
      _MoreItem(
        icon: Icons.notifications_rounded,
        label: 'Alerts',
        color: const Color(0xFFF59E0B),
        onTap: () => context.push('/notifications'),
      ),
      _MoreItem(
        icon: Icons.account_balance_rounded,
        label: 'Finance',
        color: const Color(0xFF6366F1),
        onTap: () => context.push('/finance'),
      ),
    ];
  }
}

class _MoreItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final int badge;
  final VoidCallback onTap;

  const _MoreItem({
    required this.icon,
    required this.label,
    required this.color,
    this.badge = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Badge(
            isLabelVisible: badge > 0,
            label: Text('$badge'),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: cs.onSurface,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
