import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/social/connection_button.dart';

// ── Social Profile Screen ──────────────────────────────────────────────────────

class SocialProfileScreen extends ConsumerStatefulWidget {
  final String userId;

  const SocialProfileScreen({super.key, required this.userId});

  @override
  ConsumerState<SocialProfileScreen> createState() =>
      _SocialProfileScreenState();
}

class _SocialProfileScreenState extends ConsumerState<SocialProfileScreen> {
  ConnectionStatus _connectionStatus = ConnectionStatus.none;
  bool _loadingConnection = false;

  @override
  void initState() {
    super.initState();
    _loadConnectionStatus();
  }

  Future<void> _loadConnectionStatus() async {
    try {
      final connections = await ref.read(connectionsProvider.future);
      final pending = await ref.read(pendingRequestsProvider.future);

      if (!mounted) return;

      // Check if connected
      final isConnected = connections.any(
        (c) =>
            (c.requesterId == widget.userId ||
                c.addresseeId == widget.userId) &&
            c.status == 'accepted',
      );
      if (isConnected) {
        setState(() => _connectionStatus = ConnectionStatus.connected);
        return;
      }

      // Check pending sent
      final sentPending = connections.any(
        (c) => c.addresseeId == widget.userId && c.status == 'pending',
      );
      if (sentPending) {
        setState(() => _connectionStatus = ConnectionStatus.pendingSent);
        return;
      }

      // Check pending received
      final receivedPending = pending.any(
        (c) => c.requesterId == widget.userId && c.status == 'pending',
      );
      if (receivedPending) {
        setState(() => _connectionStatus = ConnectionStatus.pendingReceived);
        return;
      }

      setState(() => _connectionStatus = ConnectionStatus.none);
    } catch (_) {
      // Keep default
    }
  }

  Future<void> _sendRequest() async {
    setState(() => _loadingConnection = true);
    try {
      await apiClient.dio.post(
        ApiConstants.socialConnections,
        data: {'addressee_id': widget.userId, 'connection_type': 'buddy'},
      );
      if (mounted) {
        setState(() => _connectionStatus = ConnectionStatus.pendingSent);
      }
      ref.invalidate(connectionsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingConnection = false);
    }
  }

  Future<void> _acceptRequest() async {
    setState(() => _loadingConnection = true);
    try {
      // Find the connection to accept
      final pending = await ref.read(pendingRequestsProvider.future);
      final conn = pending.firstWhere(
        (c) => c.requesterId == widget.userId,
      );
      await apiClient.dio
          .put(ApiConstants.socialConnectionAccept(conn.id));
      if (mounted) {
        setState(() => _connectionStatus = ConnectionStatus.connected);
      }
      ref.invalidate(connectionsProvider);
      ref.invalidate(pendingRequestsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to accept request')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingConnection = false);
    }
  }

  Future<void> _declineRequest() async {
    setState(() => _loadingConnection = true);
    try {
      final pending = await ref.read(pendingRequestsProvider.future);
      final conn = pending.firstWhere(
        (c) => c.requesterId == widget.userId,
      );
      await apiClient.dio
          .put(ApiConstants.socialConnectionReject(conn.id));
      if (mounted) {
        setState(() => _connectionStatus = ConnectionStatus.none);
      }
      ref.invalidate(pendingRequestsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to decline request')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingConnection = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(publicProfileProvider(widget.userId));
    final cs = Theme.of(context).colorScheme;

    return profileAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('Failed to load profile',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(publicProfileProvider(widget.userId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (profile) => _buildProfile(context, profile),
    );
  }

  Widget _buildProfile(BuildContext context, SocialProfile profile) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final privacy = profile.privacySettings;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        children: [
          const SizedBox(height: 16),

          // Large avatar
          CircleAvatar(
            radius: 48,
            backgroundColor: cs.primaryContainer,
            child: Text(
              (profile.displayName?.isNotEmpty == true
                      ? profile.displayName![0]
                      : '?')
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Display name
          Text(
            profile.displayName ?? 'User',
            style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),

          // Level badge
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.primaryContainer.withOpacity(0.5),
            ),
            child: Text(
              'Level ${profile.level}',
              style: tt.bodySmall?.copyWith(
                color: cs.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // Bio
          if (profile.bio != null && profile.bio!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                profile.bio!,
                textAlign: TextAlign.center,
                style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
              ),
            ),
          ],

          // Connection button
          const SizedBox(height: 16),
          if (_loadingConnection)
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else
            ConnectionButton(
              status: _connectionStatus,
              onAddFriend: _sendRequest,
              onAccept: _acceptRequest,
              onDecline: _declineRequest,
              onRemove: () {
                // Show confirmation dialog
                showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    title: const Text('Remove friend?'),
                    content: Text(
                      'Are you sure you want to remove ${profile.displayName ?? 'this user'} as a friend?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                          // TODO: Implement remove connection
                        },
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
              },
            ),

          const SizedBox(height: 24),

          // Stats showcase
          _StatsSection(profile: profile, privacy: privacy),

          const SizedBox(height: 16),

          // Achievement badges
          if (profile.badgeShowcase.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Badges',
                    style:
                        tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${profile.badgeShowcase.length}',
                    style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _BadgeGrid(badges: profile.badgeShowcase),
          ],

          const SizedBox(height: 16),

          // Invite to challenge button
          if (_connectionStatus == ConnectionStatus.connected)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    // TODO: Navigate to challenge creation with this user
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Challenge invite coming soon!'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.flag, size: 18),
                  label: const Text('Invite to Challenge'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Stats Section ────────────────────────────────────────────────────────────

class _StatsSection extends StatelessWidget {
  final SocialProfile profile;
  final Map<String, dynamic> privacy;

  const _StatsSection({required this.profile, required this.privacy});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final showStreak = privacy['streak'] != 'hidden';
    final showXp = privacy['xp'] != 'hidden';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          if (showXp)
            _StatItem(
              icon: Icons.bolt,
              value: '${profile.xpTotal}',
              label: 'XP',
              color: const Color(0xFFF97316),
            ),
          if (showStreak)
            _StatItem(
              icon: Icons.local_fire_department,
              value: '${profile.level}',
              label: 'Level',
              color: const Color(0xFFEAB308),
            ),
          _StatItem(
            icon: Icons.emoji_events,
            value: '${profile.badgeShowcase.length}',
            label: 'Badges',
            color: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}

// ── Badge Grid ───────────────────────────────────────────────────────────────

class _BadgeGrid extends StatelessWidget {
  final List<String> badges;
  const _BadgeGrid({required this.badges});

  static const _badgeIcons = <String, IconData>{
    'streak_7': Icons.local_fire_department,
    'streak_30': Icons.whatshot,
    'first_meal': Icons.restaurant,
    'hydration_star': Icons.water_drop,
    'social_butterfly': Icons.people,
    'challenge_winner': Icons.emoji_events,
    'recipe_master': Icons.menu_book,
  };

  static const _badgeColors = <String, Color>{
    'streak_7': Color(0xFFF97316),
    'streak_30': Color(0xFFEF4444),
    'first_meal': Color(0xFF22C55E),
    'hydration_star': Color(0xFF3B82F6),
    'social_butterfly': Color(0xFF8B5CF6),
    'challenge_winner': Color(0xFFFBBF24),
    'recipe_master': Color(0xFF10B981),
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: badges.map((badge) {
          final icon = _badgeIcons[badge] ?? Icons.star;
          final color = _badgeColors[badge] ?? cs.primary;
          final label = badge.replaceAll('_', ' ');

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withOpacity(0.15),
                  border: Border.all(color: color.withOpacity(0.4), width: 2),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 60,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 9, color: cs.onSurfaceVariant),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
