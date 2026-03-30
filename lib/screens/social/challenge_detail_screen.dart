import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../widgets/themed_spinner.dart';
// ── Challenge Detail Screen ────────────────────────────────────────────────────

class ChallengeDetailScreen extends ConsumerWidget {
  final String challengeId;

  const ChallengeDetailScreen({super.key, required this.challengeId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailAsync = ref.watch(challengeDetailProvider(challengeId));
    final boardAsync = ref.watch(challengeLeaderboardProvider(challengeId));
    final cs = Theme.of(context).colorScheme;

    return detailAsync.when(
      loading: () => const ThemedSpinner(),
      error: (e, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedAlert01, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('Failed to load challenge',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  ref.invalidate(challengeDetailProvider(challengeId)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (challenge) => challenge == null
          ? Center(
              child: Text('Challenge not found',
                  style: TextStyle(color: cs.onSurfaceVariant)))
          : _ChallengeContent(
              challenge: challenge,
              boardAsync: boardAsync,
            ),
    );
  }
}

class _ChallengeContent extends ConsumerWidget {
  final Challenge challenge;
  final AsyncValue<List<ChallengeMember>> boardAsync;

  const _ChallengeContent({
    required this.challenge,
    required this.boardAsync,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isJoined = challenge.myCompletionPct != null;
    final pct = challenge.myCompletionPct ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.vertical(
                bottom: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: HugeIcon(
                          icon: _typeIcon(challenge.challengeType),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              challenge.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                            Text(
                              '${challenge.participantCount} participants',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (challenge.description != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      challenge.description!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Date range
                  Row(
                    children: [
                      HugeIcon(icon: HugeIcons.strokeRoundedCalendar01,
                          size: 14, color: Colors.white.withValues(alpha: 0.7)),
                      const SizedBox(width: 6),
                      Text(
                        '${_formatDate(challenge.startDate)} - ${_formatDate(challenge.endDate)}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          challenge.daysRemaining > 0
                              ? '${challenge.daysRemaining}d left'
                              : 'Ended',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Progress ring (if joined)
          if (isJoined) ...[
            const SizedBox(height: 24),
            Center(
              child: _ProgressRing(
                completionPct: pct,
                completed: challenge.myCompleted ?? false,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                challenge.myCompleted == true
                    ? 'Challenge completed!'
                    : '${pct.round()}% complete',
                style: tt.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: challenge.myCompleted == true
                      ? const Color(0xFF22C55E)
                      : cs.onSurface,
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Completion Board
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Completion Board',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 8),

          boardAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: const ThemedSpinner(),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load board',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            data: (members) {
              if (members.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No participants yet',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                );
              }

              // Sort: completed first, then by completion % descending
              final sorted = List<ChallengeMember>.from(members)
                ..sort((a, b) {
                  if (a.completed && !b.completed) return -1;
                  if (!a.completed && b.completed) return 1;
                  return b.completionPct.compareTo(a.completionPct);
                });

              return Column(
                children: sorted
                    .map((m) => _CompletionBoardItem(member: m))
                    .toList(),
              );
            },
          ),

          const SizedBox(height: 24),

          // Join / Leave button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              width: double.infinity,
              child: isJoined
                  ? OutlinedButton(
                      onPressed: () async {
                        HapticFeedback.lightImpact();
                        try {
                          await apiClient.dio.post(
                            ApiConstants.challengeLeave(challenge.id),
                          );
                          ref.invalidate(
                              challengeDetailProvider(challenge.id));
                          ref.invalidate(myChallengesProvider);
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text('Failed to leave challenge')),
                            );
                          }
                        }
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        'Leave Challenge',
                        style: TextStyle(color: cs.error),
                      ),
                    )
                  : FilledButton(
                      onPressed: challenge.isOpen
                          ? () async {
                              HapticFeedback.lightImpact();
                              try {
                                await apiClient.dio.post(
                                  ApiConstants.challengeJoin(challenge.id),
                                );
                                ref.invalidate(
                                    challengeDetailProvider(challenge.id));
                                ref.invalidate(myChallengesProvider);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content:
                                            Text('Joined challenge!')),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Failed to join challenge')),
                                  );
                                }
                              }
                            }
                          : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Join Challenge',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  List<List<dynamic>> _typeIcon(String type) {
    switch (type) {
      case 'hydration':
        return HugeIcons.strokeRoundedDroplet;
      case 'nutrition':
        return HugeIcons.strokeRoundedRestaurant01;
      case 'exercise':
        return HugeIcons.strokeRoundedDumbbell01;
      case 'streak':
        return HugeIcons.strokeRoundedFire;
      case 'weight':
        return HugeIcons.strokeRoundedBodyWeight;
      default:
        return HugeIcons.strokeRoundedFlag01;
    }
  }

  String _formatDate(DateTime date) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}

// ── Progress Ring ────────────────────────────────────────────────────────────

class _ProgressRing extends StatelessWidget {
  final double completionPct;
  final bool completed;

  const _ProgressRing({
    required this.completionPct,
    required this.completed,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final pct = (completionPct / 100).clamp(0.0, 1.0);
    final color =
        completed ? const Color(0xFF22C55E) : const Color(0xFF8B5CF6);

    return SizedBox(
      width: 120,
      height: 120,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: pct),
        duration: const Duration(milliseconds: 1200),
        curve: Curves.easeOutCubic,
        builder: (_, v, child) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 120,
              height: 120,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
                strokeCap: StrokeCap.round,
              ),
            ),
            child!,
          ],
        ),
        child: completed
            ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: color, size: 48)
            : Text(
                '${completionPct.round()}%',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: cs.onSurface,
                ),
              ),
      ),
    );
  }
}

// ── Completion Board Item ────────────────────────────────────────────────────

class _CompletionBoardItem extends StatelessWidget {
  final ChallengeMember member;

  const _CompletionBoardItem({required this.member});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = (member.completionPct / 100).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: cs.primaryContainer,
            child: Text(
              (member.userName.isNotEmpty ? member.userName[0] : '?')
                  .toUpperCase(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: cs.onPrimaryContainer,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Name + progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.userName,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (member.completed)
                  Text(
                    '${member.completionPct.round()}% achieved',
                    style: tt.bodySmall?.copyWith(
                      color: const Color(0xFF22C55E),
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 5,
                      color: const Color(0xFF8B5CF6),
                      backgroundColor: cs.surfaceContainerHighest,
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Status icon
          if (member.completed)
            HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: Color(0xFF22C55E), size: 22)
          else
            Text(
              '${member.completionPct.round()}%',
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontWeight: FontWeight.w500,
              ),
            ),
        ],
      ),
    );
  }
}
