import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/social_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/social/feed_card.dart';
import '../../widgets/social/comment_sheet.dart';

// ── Social Hub Screen ──────────────────────────────────────────────────────────

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  /// Optimistic posts that appear instantly before server confirms.
  final List<FeedEvent> _optimisticPosts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _addOptimisticPost(FeedEvent event) {
    setState(() => _optimisticPosts.insert(0, event));
  }

  void _removeOptimisticPost(String tempId) {
    setState(() => _optimisticPosts.removeWhere((e) => e.id == tempId));
  }

  void _showComposeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ComposeSheet(
        onPosted: () {
          ref.invalidate(socialFeedProvider(null));
        },
        onOptimisticPost: (event) => _addOptimisticPost(event),
        onConfirmed: (tempId) {
          _removeOptimisticPost(tempId);
          ref.invalidate(socialFeedProvider(null));
        },
      ),
    );
  }

  void _showUserSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _UserSearchSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Stack(
      children: [
        Column(
          children: [
            // ── Title row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  Text(
                    'Community',
                    style: tt.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search_rounded, color: cs.onSurfaceVariant),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _showUserSearch(context);
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.notifications_outlined,
                        color: cs.onSurfaceVariant),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                    },
                  ),
                ],
              ),
            ),

            // ── Tab bar (sleek underline) ──
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              child: TabBar(
                controller: _tabCtrl,
                labelColor: cs.onSurface,
                unselectedLabelColor: cs.onSurfaceVariant,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
                unselectedLabelStyle: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 15,
                ),
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 3,
                indicatorColor: cs.primary,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: 'Feed'),
                  Tab(text: 'Discover'),
                ],
              ),
            ),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _FeedTab(optimisticPosts: _optimisticPosts),
                  const _DiscoverTab(),
                ],
              ),
            ),
          ],
        ),

        // ── Gradient FAB ──
        Positioned(
          right: 20,
          bottom: 20,
          child: _GradientFab(
            onPressed: () {
              HapticFeedback.lightImpact();
              _showComposeSheet(context);
            },
          ),
        ),
      ],
    );
  }
}

// ── Gradient FAB with glow ──────────────────────────────────────────────────

class _GradientFab extends StatelessWidget {
  final VoidCallback onPressed;
  const _GradientFab({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: cs.primary.withValues(alpha: 0.4),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: FloatingActionButton(
        heroTag: 'social_compose',
        onPressed: onPressed,
        elevation: 0,
        shape: const CircleBorder(),
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [cs.primary, cs.tertiary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
        ),
      ),
    );
  }
}

// ── Stories Row ──────────────────────────────────────────────────────────────

class _StoriesRow extends ConsumerWidget {
  const _StoriesRow();

  static const _storyGradient = [
    Color(0xFFE040FB),
    Color(0xFFFF5722),
    Color(0xFFFFC107),
    Color(0xFF4CAF50),
    Color(0xFF2196F3),
    Color(0xFFE040FB),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionsAsync = ref.watch(connectionsProvider);

    return SizedBox(
      height: 100,
      child: connectionsAsync.when(
        loading: () => _buildWithConnections(context, []),
        error: (_, __) => _buildWithConnections(context, []),
        data: (connections) => _buildWithConnections(context, connections),
      ),
    );
  }

  Widget _buildWithConnections(
      BuildContext context, List<Connection> connections) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Filter to accepted connections only
    final accepted =
        connections.where((c) => c.status == 'accepted').toList();

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 1 + accepted.length, // +1 for "Your Story"
      itemBuilder: (_, i) {
        if (i == 0) {
          // "Your Story" / compose item
          return Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
                    border: Border.all(
                      color: cs.outlineVariant.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(Icons.add, color: cs.primary, size: 26),
                ),
                const SizedBox(height: 6),
                Text(
                  'You',
                  style: tt.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          );
        }

        final conn = accepted[i - 1];
        final name = conn.requesterName ?? 'Friend';
        final firstName = name.split(' ').first;
        final initial =
            (name.isNotEmpty ? name[0] : '?').toUpperCase();
        final hasAvatar = conn.requesterAvatarUrl != null &&
            conn.requesterAvatarUrl!.isNotEmpty;

        return Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Gradient ring
              Container(
                width: 62,
                height: 62,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: _storyGradient),
                ),
                padding: const EdgeInsets.all(2.5),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: cs.surface,
                  ),
                  padding: const EdgeInsets.all(2),
                  child: hasAvatar
                      ? CircleAvatar(
                          radius: 25,
                          backgroundImage:
                              NetworkImage(conn.requesterAvatarUrl!),
                          backgroundColor: cs.primaryContainer,
                        )
                      : CircleAvatar(
                          radius: 25,
                          backgroundColor: cs.primaryContainer,
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: cs.onPrimaryContainer,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 62,
                child: Text(
                  firstName,
                  style: tt.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── Feed Tab ────────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerWidget {
  final List<FeedEvent> optimisticPosts;
  const _FeedTab({this.optimisticPosts = const []});

  void _showCommentSheet(BuildContext context, WidgetRef ref, FeedEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(
        event: event,
        onCommentAdded: () {
          ref.invalidate(socialFeedProvider(null));
        },
      ),
    );
  }

  void _sharePost(BuildContext context, FeedEvent event) {
    final snap = event.contentSnapshot;
    final ct = event.contentType;
    String shareText = '${event.actorName} on Vitalis:\n';

    if (ct == 'note') {
      shareText += snap['note']?.toString() ?? snap['text']?.toString() ?? '';
    } else if (ct == 'streak') {
      final days = snap['streak_days'] ?? snap['days'] ?? '?';
      shareText += 'On a $days-day wellness streak!';
    } else if (ct == 'daily_nutrition') {
      final cals = snap['total_calories'] ?? snap['calories'];
      shareText += 'Logged ${cals ?? '?'} kcal today';
    } else {
      shareText += snap['description']?.toString() ?? 'Check out this update!';
    }
    shareText += '\n\nTracked with Vitalis';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(socialFeedProvider(null));
    final cs = Theme.of(context).colorScheme;

    return feedAsync.when(
      skipLoadingOnReload: true,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, __) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('Failed to load feed',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => ref.invalidate(socialFeedProvider(null)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (events) {
        // Merge optimistic posts with server data (dedup by checking temp IDs)
        final serverIds = events.map((e) => e.id).toSet();
        final allEvents = [
          ...optimisticPosts.where((op) => !serverIds.contains(op.id)),
          ...events,
        ];

        if (allEvents.isEmpty) {
          return const _EmptyFeedState();
        }

        return RefreshIndicator(
          color: cs.primary,
          onRefresh: () async {
            ref.invalidate(socialFeedProvider(null));
            ref.invalidate(connectionsProvider);
          },
          child: CustomScrollView(
            slivers: [
              // Stories row
              const SliverToBoxAdapter(child: _StoriesRow()),
              SliverToBoxAdapter(
                child: Divider(
                  height: 1,
                  thickness: 6,
                  color: cs.outlineVariant.withValues(alpha: 0.12),
                ),
              ),
              // Feed items
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) {
                    final event = allEvents[i];
                    return FeedCard(
                      event: event,
                      onReact: (type) async {
                        HapticFeedback.lightImpact();
                        try {
                          await apiClient.dio.post(
                            ApiConstants.socialReactions,
                            data: {
                              'feed_event_id': event.id,
                              'reaction_type': type,
                            },
                          );
                          ref.invalidate(socialFeedProvider(null));
                        } catch (_) {}
                      },
                      onComment: () => _showCommentSheet(context, ref, event),
                      onShare: () => _sharePost(context, event),
                      onProfileTap: () {
                        context.push('/social/profile/${event.actorId}');
                      },
                    );
                  },
                  childCount: allEvents.length,
                ),
              ),
              const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
            ],
          ),
        );
      },
    );
  }
}

// ── Empty Feed State ────────────────────────────────────────────────────────

class _EmptyFeedState extends StatelessWidget {
  const _EmptyFeedState();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return SingleChildScrollView(
      child: Column(
        children: [
          const _StoriesRow(),
          Divider(
            height: 1,
            thickness: 0.5,
            color: cs.outlineVariant.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 60),
          // Warm illustration-style empty state
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.1),
                  cs.tertiary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                '\uD83C\uDF1F',
                style: const TextStyle(fontSize: 48),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Your feed is waiting',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Connect with friends and share your wellness journey together. Your community starts here!',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('Find Friends'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Discover Tab ────────────────────────────────────────────────────────────────

class _DiscoverTab extends ConsumerStatefulWidget {
  const _DiscoverTab();

  @override
  ConsumerState<_DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<_DiscoverTab> {
  String _selectedFilter = 'All';

  static const _filters = [
    'All',
    'Recipes',
    'Challenges',
    'Streaks',
    'Achievements',
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: () async {
        ref.invalidate(recipeFeedProvider(null));
        ref.invalidate(challengesProvider);
      },
      child: CustomScrollView(
        slivers: [
          // Filter chips
          SliverToBoxAdapter(
            child: SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                itemCount: _filters.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final filter = _filters[i];
                  final selected = filter == _selectedFilter;
                  return FilterChip(
                    label: Text(filter),
                    selected: selected,
                    onSelected: (_) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedFilter = filter);
                    },
                    selectedColor: cs.primaryContainer,
                    checkmarkColor: cs.onPrimaryContainer,
                    backgroundColor:
                        cs.surfaceContainerHighest.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  );
                },
              ),
            ),
          ),

          // Challenges section
          if (_selectedFilter == 'All' || _selectedFilter == 'Challenges') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Challenges',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildChallengesSection()),
          ],

          // Recipes section
          if (_selectedFilter == 'All' || _selectedFilter == 'Recipes') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text(
                  'Recipes',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildRecipesSection()),
          ],

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }

  Widget _buildChallengesSection() {
    final cs = Theme.of(context).colorScheme;
    final allAsync = ref.watch(challengesProvider);

    return allAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox(
        height: 140,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (challenges) {
        final available = challenges.where((c) => c.isOpen).toList();
        if (available.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'No challenges available right now',
              style: TextStyle(color: cs.onSurfaceVariant),
            ),
          );
        }

        return SizedBox(
          height: 160,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: available.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => _AvailableChallengeCard(
              challenge: available[i],
              onTap: () =>
                  context.push('/social/challenge/${available[i].id}'),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecipesSection() {
    final cs = Theme.of(context).colorScheme;
    final recipesAsync = ref.watch(recipeFeedProvider(null));

    return recipesAsync.when(
      skipLoadingOnReload: true,
      loading: () => const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const SizedBox.shrink(),
      data: (recipes) {
        if (recipes.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: Text('No recipes shared yet',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
          );
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: recipes.length,
          itemBuilder: (_, i) => _RecipeCard(event: recipes[i]),
        );
      },
    );
  }
}

// ── Available Challenge Card (horizontal scroll) ─────────────────────────────

class _AvailableChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onTap;

  const _AvailableChallengeCard({required this.challenge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8B5CF6).withValues(alpha: 0.15),
              const Color(0xFF6366F1).withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
              ),
              child: const Center(
                child: Text('\uD83D\uDEA9', style: TextStyle(fontSize: 18)),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              challenge.title,
              style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Text(
              '${challenge.participantCount} joined \u00B7 ${challenge.durationDays}d',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonal(
                onPressed: onTap,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('View', style: TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recipe Card ──────────────────────────────────────────────────────────────

class _RecipeCard extends StatelessWidget {
  final FeedEvent event;
  const _RecipeCard({required this.event});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final snap = event.contentSnapshot;
    final name = snap['name']?.toString() ??
        snap['recipe_name']?.toString() ??
        'Recipe';
    final calories = (snap['calories'] as num?)?.toInt();
    final rating = (snap['rating'] as num?)?.toDouble();

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder with gradient
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withValues(alpha: 0.7),
                  const Color(0xFF10B981).withValues(alpha: 0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Text('\uD83C\uDF73', style: TextStyle(fontSize: 32)),
            ),
          ),
          // Content
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style:
                        tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Spacer(),
                  if (calories != null)
                    Text(
                      '$calories kcal',
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontSize: 11,
                      ),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          (event.actorName.isNotEmpty
                                  ? event.actorName[0]
                                  : '?')
                              .toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          event.actorName.split(' ').first,
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (rating != null) ...[
                        const Text('\u2B50', style: TextStyle(fontSize: 10)),
                        const SizedBox(width: 2),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Compose Sheet ───────────────────────────────────────────────────────────

class _ComposeSheet extends ConsumerStatefulWidget {
  final VoidCallback onPosted;
  final ValueChanged<FeedEvent>? onOptimisticPost;
  final ValueChanged<String>? onConfirmed;
  const _ComposeSheet({required this.onPosted, this.onOptimisticPost, this.onConfirmed});

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _textCtrl = TextEditingController();
  String _postType = 'note'; // note, share_nutrition, share_streak
  String _audience = 'buddies';
  bool _posting = false;

  final apiClient = ApiClient();

  static const _postTypes = [
    {'key': 'note', 'emoji': '\uD83D\uDCDD', 'label': 'Note'},
    {
      'key': 'share_nutrition',
      'emoji': '\uD83C\uDF7D\uFE0F',
      'label': 'Nutrition'
    },
    {'key': 'share_streak', 'emoji': '\uD83D\uDD25', 'label': 'Streak'},
  ];

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _postType == 'note') return;

    // Create optimistic post immediately
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final authState = ref.read(authProvider);
    final userName = authState.user?.name ?? 'You';

    String contentType;
    Map<String, dynamic> snapshot;
    if (_postType == 'note') {
      contentType = 'note';
      snapshot = {'note': text, 'text': text};
    } else if (_postType == 'share_nutrition') {
      contentType = 'daily_nutrition';
      snapshot = {'description': 'Nutrition summary', 'title': 'Daily Nutrition'};
      if (text.isNotEmpty) snapshot['note'] = text;
    } else {
      contentType = 'streak';
      snapshot = {'title': 'Streak', 'description': 'Wellness streak'};
      if (text.isNotEmpty) snapshot['note'] = text;
    }

    final optimisticEvent = FeedEvent(
      id: tempId,
      actorId: authState.user?.id ?? '',
      actorName: userName,
      actorAvatarUrl: authState.user?.avatarUrl,
      eventType: 'share',
      contentType: contentType,
      contentSnapshot: snapshot,
      isRead: true,
      createdAt: DateTime.now(),
    );

    // Show post immediately and close sheet
    widget.onOptimisticPost?.call(optimisticEvent);
    if (mounted) Navigator.pop(context);

    // Sync to server in background
    try {
      if (_postType == 'note') {
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'note',
            'content_id': 'note_${DateTime.now().millisecondsSinceEpoch}',
            'audience': _audience,
            'note': text,
          },
        );
      } else if (_postType == 'share_nutrition') {
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'daily_nutrition',
            'content_id':
                'nutrition_${DateTime.now().toIso8601String().substring(0, 10)}',
            'audience': _audience,
            'note': text.isNotEmpty ? text : null,
          },
        );
      } else if (_postType == 'share_streak') {
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'streak',
            'content_id': 'streak_${DateTime.now().millisecondsSinceEpoch}',
            'audience': _audience,
            'note': text.isNotEmpty ? text : null,
          },
        );
      }
      // Server confirmed — remove optimistic and refresh with real data
      widget.onConfirmed?.call(tempId);
    } catch (e) {
      debugPrint('[Social] Post failed: $e');
      // Keep optimistic post visible, but refresh feed anyway
      widget.onPosted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            'Create Post',
            style: tt.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 20),

          // Post type chips (horizontal scroll with emojis)
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _postTypes.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final type = _postTypes[i];
                final selected = _postType == type['key'];
                return GestureDetector(
                  onTap: () =>
                      setState(() => _postType = type['key'] as String),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected
                          ? cs.primary.withValues(alpha: 0.12)
                          : cs.surfaceContainerHighest.withValues(alpha: 0.5),
                      border: selected
                          ? Border.all(
                              color: cs.primary.withValues(alpha: 0.3),
                              width: 1.5)
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(type['emoji'] as String,
                            style: const TextStyle(fontSize: 16)),
                        const SizedBox(width: 6),
                        Text(
                          type['label'] as String,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? cs.primary : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 20),

          // Text input (larger area)
          TextField(
            controller: _textCtrl,
            maxLines: 5,
            maxLength: 280,
            style: const TextStyle(fontSize: 16, height: 1.5),
            decoration: InputDecoration(
              hintText: _postType == 'note'
                  ? "What's on your mind?"
                  : 'Add a note (optional)...',
              hintStyle: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                fontSize: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
          const SizedBox(height: 16),

          // Audience picker (segmented button style)
          Row(
            children: [
              Text(
                'Audience',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Row(
                    children: [
                      _AudienceSegment(
                        label: 'Friends',
                        icon: Icons.people_outline,
                        selected: _audience == 'buddies',
                        onTap: () => setState(() => _audience = 'buddies'),
                      ),
                      _AudienceSegment(
                        label: 'Everyone',
                        icon: Icons.public,
                        selected: _audience == 'public',
                        onTap: () => setState(() => _audience = 'public'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Post button (gradient)
          SizedBox(
            width: double.infinity,
            height: 50,
            child: _posting
                ? const Center(child: CircularProgressIndicator())
                : Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      gradient: LinearGradient(
                        colors: [cs.primary, cs.tertiary],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: _post,
                        child: const Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.send_rounded,
                                  color: Colors.white, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'Post',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
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
    );
  }
}

/// Audience segmented button item
class _AudienceSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _AudienceSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? cs.surface : Colors.transparent,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: cs.shadow.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 14,
                color: selected ? cs.primary : cs.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── User Search Sheet ───────────────────────────────────────────────────────

class _UserSearchSheet extends ConsumerStatefulWidget {
  const _UserSearchSheet();

  @override
  ConsumerState<_UserSearchSheet> createState() => _UserSearchSheetState();
}

class _UserSearchSheetState extends ConsumerState<_UserSearchSheet> {
  String _query = '';
  final apiClient = ApiClient();

  Future<void> _sendRequest(String userId) async {
    try {
      await apiClient.dio.post(
        ApiConstants.socialConnections,
        data: {'addressee_id': userId, 'connection_type': 'buddy'},
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend request sent!')),
        );
        ref.invalidate(userSearchProvider(_query));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send request.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Find People',
                style: tt.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),

            // Search field
            TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search by name...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor:
                    cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 12),

            // Results
            Expanded(
              child: _query.length < 2
                  ? Center(
                      child: Text(
                        'Type at least 2 characters to search',
                        style: tt.bodyMedium
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Consumer(
                      builder: (context, ref, _) {
                        final resultsAsync =
                            ref.watch(userSearchProvider(_query));
                        return resultsAsync.when(
                          loading: () => const Center(
                              child: CircularProgressIndicator()),
                          error: (_, __) =>
                              const Center(child: Text('Search failed')),
                          data: (users) {
                            if (users.isEmpty) {
                              return Center(
                                child: Text('No users found',
                                    style: tt.bodyMedium?.copyWith(
                                        color: cs.onSurfaceVariant)),
                              );
                            }
                            return ListView.builder(
                              itemCount: users.length,
                              itemBuilder: (_, i) {
                                final user = users[i];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: cs.primaryContainer,
                                    child: Text(
                                      (user.name.isNotEmpty
                                              ? user.name[0]
                                              : '?')
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: cs.onPrimaryContainer),
                                    ),
                                  ),
                                  title: Text(user.name),
                                  trailing:
                                      user.connectionStatus == 'accepted'
                                          ? Chip(
                                              label: const Text('Friends'),
                                              backgroundColor:
                                                  cs.primaryContainer,
                                            )
                                          : user.connectionStatus ==
                                                  'pending'
                                              ? const Chip(
                                                  label: Text('Pending'))
                                              : FilledButton.tonal(
                                                  onPressed: () =>
                                                      _sendRequest(
                                                          user.id),
                                                  child: const Text('Add'),
                                                ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push(
                                        '/social/profile/${user.id}');
                                  },
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
