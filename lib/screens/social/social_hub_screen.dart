import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../widgets/social/feed_card.dart';

// ── Social Hub Screen ──────────────────────────────────────────────────────────

class SocialHubScreen extends ConsumerStatefulWidget {
  const SocialHubScreen({super.key});

  @override
  ConsumerState<SocialHubScreen> createState() => _SocialHubScreenState();
}

class _SocialHubScreenState extends ConsumerState<SocialHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _showComposeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ComposeSheet(
        onPosted: () {
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
            // Title row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text(
                    'Community Hub',
                    style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.search, color: cs.onSurfaceVariant),
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

            // Tab bar
            TabBar(
              controller: _tabCtrl,
              labelColor: cs.primary,
              unselectedLabelColor: cs.onSurfaceVariant,
              indicatorColor: cs.primary,
              tabs: const [
                Tab(text: 'Feed'),
                Tab(text: 'Recipes'),
                Tab(text: 'Challenges'),
              ],
            ),

            // Tab content
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: const [
                  _FeedTab(),
                  _RecipesTab(),
                  _ChallengesTab(),
                ],
              ),
            ),
          ],
        ),

        // ── FAB: Compose / Create Post ──────────────────────────────────────
        // Methods are defined below in the state class
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton(
            heroTag: 'social_compose',
            backgroundColor: cs.primary,
            foregroundColor: cs.onPrimary,
            onPressed: () {
              HapticFeedback.lightImpact();
              _showComposeSheet(context);
            },
            child: const Icon(Icons.edit_outlined),
          ),
        ),
      ],
    );
  }
}

// ── Feed Tab ────────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerWidget {
  const _FeedTab();

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
            Icon(Icons.error_outline, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('Failed to load feed',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => ref.invalidate(socialFeedProvider(null)),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (events) {
        if (events.isEmpty) {
          return _EmptyFeedState();
        }

        return RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(socialFeedProvider(null));
          },
          child: ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 80),
            itemCount: events.length,
            itemBuilder: (_, i) {
              final event = events[i];
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
                onProfileTap: () {
                  context.push('/social/profile/${event.actorId}');
                },
              );
            },
          ),
        );
      },
    );
  }
}

class _EmptyFeedState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 64,
                color: cs.onSurfaceVariant.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(
              'No activity yet',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Connect with friends to see their updates!',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recipes Tab ─────────────────────────────────────────────────────────────────

class _RecipesTab extends ConsumerStatefulWidget {
  const _RecipesTab();

  @override
  ConsumerState<_RecipesTab> createState() => _RecipesTabState();
}

class _RecipesTabState extends ConsumerState<_RecipesTab> {
  String _selectedFilter = 'All';

  static const _filters = [
    'All',
    'Breakfast',
    'Lunch',
    'Dinner',
    'Snack',
    'High Protein',
  ];

  @override
  Widget build(BuildContext context) {
    final recipesAsync = ref.watch(recipeFeedProvider(null));
    final cs = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                backgroundColor: cs.surfaceContainerHighest.withOpacity(0.5),
              );
            },
          ),
        ),

        // Recipe grid
        Expanded(
          child: recipesAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => Center(
              child: Text('Failed to load recipes',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            data: (recipes) {
              if (recipes.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.menu_book,
                          size: 48,
                          color: cs.onSurfaceVariant.withOpacity(0.4)),
                      const SizedBox(height: 12),
                      Text('No recipes shared yet',
                          style: TextStyle(color: cs.onSurfaceVariant)),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
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
          ),
        ),
      ],
    );
  }
}

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
    final triedCount = (snap['tried_count'] as num?)?.toInt() ?? 0;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder with colored gradient
          Container(
            height: 100,
            decoration: BoxDecoration(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF22C55E).withOpacity(0.7),
                  const Color(0xFF10B981).withOpacity(0.5),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Center(
              child: Icon(Icons.restaurant_menu, color: Colors.white, size: 32),
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
                    style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
                      // Author avatar
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
                        Icon(Icons.star, size: 12,
                            color: const Color(0xFFEAB308)),
                        Text(
                          rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 10, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                  if (triedCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        '$triedCount tried',
                        style: TextStyle(
                          fontSize: 10,
                          color: cs.onSurfaceVariant.withOpacity(0.7),
                        ),
                      ),
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

// ── Challenges Tab ──────────────────────────────────────────────────────────────

class _ChallengesTab extends ConsumerWidget {
  const _ChallengesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myAsync = ref.watch(myChallengesProvider);
    final allAsync = ref.watch(challengesProvider);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(myChallengesProvider);
        ref.invalidate(challengesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(top: 8, bottom: 80),
        children: [
          // ── Active Challenges ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Active Challenges',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          myAsync.when(
            skipLoadingOnReload: true,
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Failed to load',
                  style: TextStyle(color: cs.onSurfaceVariant)),
            ),
            data: (challenges) {
              final active =
                  challenges.where((c) => c.isActive).toList();
              final completed =
                  challenges.where((c) => c.isCompleted).toList();

              if (active.isEmpty && completed.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'No challenges joined yet',
                      style: TextStyle(color: cs.onSurfaceVariant),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active progress cards
                  ...active.map(
                    (c) => _ActiveChallengeCard(
                      challenge: c,
                      onTap: () => context.push('/social/challenge/${c.id}'),
                    ),
                  ),

                  // Completed section
                  if (completed.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Text(
                        'Completed',
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    ...completed.map(
                      (c) => _CompletedChallengeCard(challenge: c),
                    ),
                  ],
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // ── Available Challenges ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'Available Challenges',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          allAsync.when(
            skipLoadingOnReload: true,
            loading: () => const SizedBox(
              height: 140,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (challenges) {
              final available =
                  challenges.where((c) => c.isOpen).toList();
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
                  padding: const EdgeInsets.symmetric(horizontal: 16),
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
          ),
        ],
      ),
    );
  }
}

// ── Active Challenge Card ────────────────────────────────────────────────────

class _ActiveChallengeCard extends StatelessWidget {
  final Challenge challenge;
  final VoidCallback? onTap;

  const _ActiveChallengeCard({required this.challenge, this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pct = challenge.myCompletionPct ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: cs.surface,
          border: Border.all(
            color: cs.outlineVariant.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8B5CF6), Color(0xFF6366F1)],
                    ),
                  ),
                  child: const Icon(Icons.flag, color: Colors.white, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        challenge.title,
                        style: tt.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${challenge.participantCount} participants · ${challenge.daysRemaining} days left',
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18, color: cs.onSurfaceVariant),
              ],
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: pct / 100,
                minHeight: 6,
                color: pct >= 100
                    ? const Color(0xFF22C55E)
                    : const Color(0xFF8B5CF6),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${pct.round()}% complete',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
            ),
          ],
        ),
      ),
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
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [
              const Color(0xFF8B5CF6).withOpacity(0.15),
              const Color(0xFF6366F1).withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: const Color(0xFF8B5CF6).withOpacity(0.2),
              ),
              child: const Icon(Icons.flag,
                  color: Color(0xFF8B5CF6), size: 16),
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
              '${challenge.participantCount} joined · ${challenge.durationDays}d',
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

// ── Completed Challenge Card ─────────────────────────────────────────────────

class _CompletedChallengeCard extends StatelessWidget {
  final Challenge challenge;
  const _CompletedChallengeCard({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        border: Border.all(
          color: cs.outlineVariant.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFFFBBF24).withOpacity(0.15),
            ),
            child: const Icon(Icons.emoji_events,
                color: Color(0xFFFBBF24), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  challenge.title,
                  style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Completed',
                  style: tt.bodySmall?.copyWith(
                    color: const Color(0xFF22C55E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.military_tech,
              color: Color(0xFFFBBF24), size: 24),
        ],
      ),
    );
  }
}

// ── Compose Sheet ───────────────────────────────────────────────────────────

class _ComposeSheet extends ConsumerStatefulWidget {
  final VoidCallback onPosted;
  const _ComposeSheet({required this.onPosted});

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _textCtrl = TextEditingController();
  String _postType = 'note'; // note, share_nutrition, share_streak
  String _audience = 'buddies';
  bool _posting = false;

  final apiClient = ApiClient.instance;

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty && _postType == 'note') return;

    setState(() => _posting = true);
    try {
      if (_postType == 'note') {
        // Post a text note to feed
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'note',
            'audience': _audience,
            'note': text,
          },
        );
      } else if (_postType == 'share_nutrition') {
        // Share today's nutrition summary
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'daily_nutrition',
            'audience': _audience,
            'note': text.isNotEmpty ? text : null,
          },
        );
      } else if (_postType == 'share_streak') {
        await apiClient.dio.post(
          ApiConstants.socialShare,
          data: {
            'content_type': 'streak',
            'audience': _audience,
            'note': text.isNotEmpty ? text : null,
          },
        );
      }

      widget.onPosted();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Posted!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to post. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Text('Create Post', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),

          // Post type chips
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Note'),
                selected: _postType == 'note',
                onSelected: (_) => setState(() => _postType = 'note'),
                avatar: const Icon(Icons.edit_note, size: 18),
              ),
              ChoiceChip(
                label: const Text("Today's Nutrition"),
                selected: _postType == 'share_nutrition',
                onSelected: (_) => setState(() => _postType = 'share_nutrition'),
                avatar: const Icon(Icons.restaurant, size: 18),
              ),
              ChoiceChip(
                label: const Text('My Streak'),
                selected: _postType == 'share_streak',
                onSelected: (_) => setState(() => _postType = 'share_streak'),
                avatar: const Icon(Icons.local_fire_department, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Text input
          TextField(
            controller: _textCtrl,
            maxLines: 4,
            maxLength: 280,
            decoration: InputDecoration(
              hintText: _postType == 'note'
                  ? "What's on your mind?"
                  : 'Add a note (optional)...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: 12),

          // Audience picker
          Row(
            children: [
              Text('Who can see:', style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Friends'),
                selected: _audience == 'buddies',
                onSelected: (_) => setState(() => _audience = 'buddies'),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                label: const Text('Everyone'),
                selected: _audience == 'public',
                onSelected: (_) => setState(() => _audience = 'public'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Post button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _posting ? null : _post,
              icon: _posting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send),
              label: Text(_posting ? 'Posting...' : 'Post'),
            ),
          ),
        ],
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
  final apiClient = ApiClient.instance;

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
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            Text('Find People', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
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
                fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.3),
              ),
            ),
            const SizedBox(height: 12),

            // Results
            Expanded(
              child: _query.length < 2
                  ? Center(
                      child: Text(
                        'Type at least 2 characters to search',
                        style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      ),
                    )
                  : Consumer(
                      builder: (context, ref, _) {
                        final resultsAsync = ref.watch(userSearchProvider(_query));
                        return resultsAsync.when(
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (_, __) => const Center(child: Text('Search failed')),
                          data: (users) {
                            if (users.isEmpty) {
                              return Center(
                                child: Text('No users found', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
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
                                      (user.name.isNotEmpty ? user.name[0] : '?').toUpperCase(),
                                      style: TextStyle(color: cs.onPrimaryContainer),
                                    ),
                                  ),
                                  title: Text(user.name),
                                  trailing: user.connectionStatus == 'accepted'
                                      ? Chip(
                                          label: const Text('Friends'),
                                          backgroundColor: cs.primaryContainer,
                                        )
                                      : user.connectionStatus == 'pending'
                                          ? const Chip(label: Text('Pending'))
                                          : FilledButton.tonal(
                                              onPressed: () => _sendRequest(user.id),
                                              child: const Text('Add'),
                                            ),
                                  onTap: () {
                                    Navigator.pop(context);
                                    context.push('/social/profile/${user.id}');
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
