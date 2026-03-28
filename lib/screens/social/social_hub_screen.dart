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
import '../../widgets/social/poll_card.dart';
import '../../widgets/social/create_poll_sheet.dart';
import 'community_guidelines_screen.dart';
import '../../models/poll_models.dart';
import '../../providers/poll_provider.dart';
import '../../providers/group_chat_provider.dart';
import '../../models/group_chat_models.dart';

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
    _tabCtrl = TabController(length: 4, vsync: this);
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
          ref.read(socialFeedNotifierProvider.notifier).refreshInBackground();
        },
        onOptimisticPost: (event) => _addOptimisticPost(event),
        onConfirmed: (tempId) {
          _removeOptimisticPost(tempId);
          ref.read(socialFeedNotifierProvider.notifier).refreshInBackground();
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
                icon: Icon(Icons.shield_outlined,
                    color: cs.onSurfaceVariant, size: 22),
                tooltip: 'Community Guidelines',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CommunityGuidelinesScreen(),
                  ),
                ),
              ),
              _NotificationBellButton(),
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
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [
              Tab(text: 'Feed'),
              Tab(text: 'Polls'),
              Tab(text: 'Groups'),
              Tab(text: 'Discover'),
            ],
          ),
        ),

            // ── Tab content ──
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  _FeedTab(
                    optimisticPosts: _optimisticPosts,
                    onCompose: () {
                      HapticFeedback.lightImpact();
                      _showComposeSheet(context);
                    },
                  ),
                  const _PollsTab(),
                  const _GroupsTab(),
                  const _DiscoverTab(),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Compose Prompt Bar (LinkedIn-style "Start a post") ─────────────────────

class _ComposePromptBar extends StatelessWidget {
  final VoidCallback? onTap;
  const _ComposePromptBar({this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              child: Icon(Icons.person_rounded,
                  size: 20, color: cs.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: cs.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  'Share something with your community...',
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Feed Tab ────────────────────────────────────────────────────────────────────

class _FeedTab extends ConsumerStatefulWidget {
  final List<FeedEvent> optimisticPosts;
  final VoidCallback? onCompose;
  const _FeedTab({this.optimisticPosts = const [], this.onCompose});

  @override
  ConsumerState<_FeedTab> createState() => _FeedTabState();
}

class _FeedTabState extends ConsumerState<_FeedTab> {
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 300) {
      ref.read(socialFeedNotifierProvider.notifier).loadMore();
    }
  }

  void _showCommentSheet(BuildContext context, FeedEvent event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentSheet(
        event: event,
        onCommentAdded: () {
          ref.read(socialFeedNotifierProvider.notifier)
              .incrementCommentCount(event.id);
        },
      ),
    );
  }

  void _sharePost(BuildContext context, FeedEvent event) {
    final snap = event.contentSnapshot;
    final ct = event.contentType;
    String shareText = '${event.actorName} on QoreHealth:\n';

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
    shareText += '\n\nTracked with QoreHealth';

    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    final feedState = ref.watch(socialFeedNotifierProvider);
    final cs = Theme.of(context).colorScheme;

    // First load only — show shimmer skeletons
    if (feedState.isLoading) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        children: const [FeedCardShimmer(), FeedCardShimmer(), FeedCardShimmer()],
      );
    }

    // Error with no data
    if (feedState.error != null && feedState.events.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 48, color: cs.error),
            const SizedBox(height: 12),
            Text('Failed to load feed',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => forceRefreshFeed(ref),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Merge optimistic posts with server data
    final events = feedState.events;
    final serverIds = events.map((e) => e.id).toSet();
    final allEvents = [
      ...widget.optimisticPosts.where((op) => !serverIds.contains(op.id)),
      ...events,
    ];

    if (allEvents.isEmpty) {
      return const _EmptyFeedState();
    }

    return RefreshIndicator(
      color: cs.primary,
      onRefresh: () async {
        await ref.read(socialFeedNotifierProvider.notifier).forceRefresh();
        ref.invalidate(connectionsProvider);
      },
      child: CustomScrollView(
        controller: _scrollCtrl,
        slivers: [
          // Compose prompt bar
          SliverToBoxAdapter(
            child: _ComposePromptBar(onTap: widget.onCompose),
          ),
          SliverToBoxAdapter(
            child: Container(height: 8, color: cs.surfaceContainerLow),
          ),
          // Feed items
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (_, i) {
                final event = allEvents[i];
                return FeedCard(
                  key: ValueKey(event.id),
                  event: event,
                  onReact: (type) {
                    HapticFeedback.lightImpact();
                    optimisticReaction(
                      ref: ref,
                      event: event,
                      reactionType: type,
                    );
                  },
                  onComment: () => _showCommentSheet(context, event),
                  onShare: () => _sharePost(context, event),
                  onProfileTap: () {
                    context.push('/social/profile/${event.actorId}');
                  },
                );
              },
              childCount: allEvents.length,
            ),
          ),
          // Loading indicator for infinite scroll
          if (feedState.isLoadingMore)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
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
            child: const Center(
              child: Text(
                '\uD83C\uDF1F',
                style: TextStyle(fontSize: 48),
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

// ── Notification Bell with Badge ─────────────────────────────────────────────

class _NotificationBellButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final badgeAsync = ref.watch(notificationBadgeProvider);
    final badgeCount = badgeAsync.valueOrNull ?? 0;

    return IconButton(
      icon: Badge(
        isLabelVisible: badgeCount > 0,
        label: Text('$badgeCount', style: const TextStyle(fontSize: 10)),
        child: Icon(Icons.notifications_outlined, color: cs.onSurfaceVariant),
      ),
      onPressed: () {
        HapticFeedback.lightImpact();
        context.push('/social/notifications');
      },
    );
  }
}

// ── Polls Tab ─────────────────────────────────────────────────────────────────

class _PollsTab extends ConsumerStatefulWidget {
  const _PollsTab();

  @override
  ConsumerState<_PollsTab> createState() => _PollsTabState();
}

enum _PollFilter { all, active, expired, mine }

class _PollsTabState extends ConsumerState<_PollsTab> {
  _PollFilter _filter = _PollFilter.all;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<Poll> _applyFilters(List<Poll> polls) {
    var filtered = polls;

    // Text search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((p) =>
          p.question.toLowerCase().contains(q) ||
          p.creatorName.toLowerCase().contains(q)).toList();
    }

    // Filter chips
    switch (_filter) {
      case _PollFilter.all:
        break;
      case _PollFilter.active:
        filtered = filtered.where((p) => p.isActive).toList();
      case _PollFilter.expired:
        filtered = filtered.where((p) => !p.isActive).toList();
      case _PollFilter.mine:
        // Show polls the user voted on or created
        filtered = filtered.where((p) => p.hasVoted).toList();
    }

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final pollsState = ref.watch(pollsNotifierProvider);

    if (pollsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (pollsState.error != null && pollsState.polls.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.poll_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('Could not load polls', style: tt.bodyMedium),
            TextButton(
              onPressed: () =>
                  ref.read(pollsNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _applyFilters(pollsState.polls);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(pollsNotifierProvider.notifier).refresh(),
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search polls...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 8,
                children: _PollFilter.values.map((f) {
                  final selected = _filter == f;
                  final label = switch (f) {
                    _PollFilter.all => 'All',
                    _PollFilter.active => 'Active',
                    _PollFilter.expired => 'Ended',
                    _PollFilter.mine => 'Voted',
                  };
                  return FilterChip(
                    label: Text(label, style: TextStyle(fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
          ),

          // Create poll button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: OutlinedButton.icon(
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  final created = await showModalBottomSheet<bool>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: cs.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => const CreatePollSheet(),
                  );
                  if (created == true) {
                    ref.read(pollsNotifierProvider.notifier).refresh();
                  }
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Poll'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.poll_outlined, size: 56, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No polls match "$_searchQuery"'
                          : 'No polls yet',
                      style: tt.titleSmall?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try a different search'
                          : 'Be the first to create one!',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => PollCard(
                  poll: filtered[i],
                  onVote: (optionId) {
                    ref
                        .read(pollsNotifierProvider.notifier)
                        .vote(filtered[i].id, optionId);
                  },
                ),
                childCount: filtered.length,
              ),
            ),

          const SliverPadding(padding: EdgeInsets.only(bottom: 80)),
        ],
      ),
    );
  }
}

// ── Groups Tab ────────────────────────────────────────────────────────────────

class _GroupsTab extends ConsumerStatefulWidget {
  const _GroupsTab();

  @override
  ConsumerState<_GroupsTab> createState() => _GroupsTabState();
}

enum _GroupFilter { all, joined, public_ }

class _GroupsTabState extends ConsumerState<_GroupsTab> {
  _GroupFilter _filter = _GroupFilter.all;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<GroupChat> _applyFilters(List<GroupChat> groups) {
    var filtered = groups;
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      filtered = filtered.where((g) =>
          g.name.toLowerCase().contains(q) ||
          (g.description?.toLowerCase().contains(q) ?? false)).toList();
    }
    switch (_filter) {
      case _GroupFilter.all:
        break;
      case _GroupFilter.joined:
        filtered = filtered.where((g) => g.isMember).toList();
      case _GroupFilter.public_:
        filtered = filtered.where((g) => g.access == GroupChatAccess.public_).toList();
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final groupsState = ref.watch(groupsNotifierProvider);

    if (groupsState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (groupsState.error != null && groupsState.groups.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.forum_outlined, size: 48, color: cs.outline),
            const SizedBox(height: 12),
            Text('Could not load groups', style: tt.bodyMedium),
            TextButton(
              onPressed: () =>
                  ref.read(groupsNotifierProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filtered = _applyFilters(groupsState.groups);

    return RefreshIndicator(
      onRefresh: () =>
          ref.read(groupsNotifierProvider.notifier).refresh(),
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Search groups...',
                  hintStyle: TextStyle(
                    color: cs.onSurfaceVariant.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                  prefixIcon: Icon(Icons.search_rounded, size: 20,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.4),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  isDense: true,
                ),
              ),
            ),
          ),

          // Filter chips
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Wrap(
                spacing: 8,
                children: _GroupFilter.values.map((f) {
                  final selected = _filter == f;
                  final label = switch (f) {
                    _GroupFilter.all => 'All',
                    _GroupFilter.joined => 'Joined',
                    _GroupFilter.public_ => 'Public',
                  };
                  return FilterChip(
                    label: Text(label, style: TextStyle(fontSize: 12,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400)),
                    selected: selected,
                    onSelected: (_) => setState(() => _filter = f),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  );
                }).toList(),
              ),
            ),
          ),

          // Create group button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: OutlinedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: cs.surface,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (_) => _CreateGroupInline(ref: ref),
                  );
                },
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('Create Group'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),

          if (filtered.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.forum_outlined, size: 56, color: cs.outline),
                    const SizedBox(height: 12),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'No groups match "$_searchQuery"'
                          : 'No groups yet',
                      style: tt.titleSmall?.copyWith(color: cs.outline),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchQuery.isNotEmpty
                          ? 'Try a different search'
                          : 'Start a conversation!',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final g = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: cs.primaryContainer,
                      child: Text(
                        g.name.isNotEmpty ? g.name[0].toUpperCase() : '?',
                        style: tt.titleSmall
                            ?.copyWith(color: cs.onPrimaryContainer),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(g.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (g.access == GroupChatAccess.inviteOnly) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.lock_outline,
                              size: 14, color: cs.outline),
                        ],
                        if (g.isMuted) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.notifications_off_outlined,
                              size: 14, color: cs.outline),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (g.description != null &&
                            g.description!.isNotEmpty)
                          Text(g.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodySmall
                                  ?.copyWith(color: cs.outline)),
                        Text(
                          g.lastMessage != null
                              ? '${g.lastMessage!.senderName}: ${g.lastMessage!.text}'
                              : '${g.memberCount} members',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                              color: cs.outline,
                              fontSize: 11),
                        ),
                      ],
                    ),
                    trailing: !g.isMember &&
                            g.access == GroupChatAccess.public_
                        ? FilledButton.tonal(
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              try {
                                await joinGroupChat(g.id);
                                ref.read(groupsNotifierProvider.notifier).refresh();
                              } catch (_) {}
                            },
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12),
                              minimumSize: const Size(0, 32),
                            ),
                            child: const Text('Join'),
                          )
                        : g.unreadCount > 0
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: cs.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text('${g.unreadCount}',
                                    style: tt.labelSmall
                                        ?.copyWith(color: cs.onPrimary)),
                              )
                            : null,
                    onTap: g.isMember
                        ? () => context.push(
                              '/social/groups/${g.id}',
                              extra: g,
                            )
                        : null,
                  );
                },
                childCount: filtered.length,
              ),
            ),
        ],
      ),
    );
  }
}

/// Inline create group sheet used from the Groups tab.
class _CreateGroupInline extends StatefulWidget {
  final WidgetRef ref;
  const _CreateGroupInline({required this.ref});

  @override
  State<_CreateGroupInline> createState() => _CreateGroupInlineState();
}

class _CreateGroupInlineState extends State<_CreateGroupInline> {
  final _nameCtrl = TextEditingController();
  var _access = GroupChatAccess.public_;
  var _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_nameCtrl.text.trim().isEmpty || _creating) return;
    setState(() => _creating = true);
    try {
      await createGroupChat(
        name: _nameCtrl.text.trim(),
        access: _access,
      );
      widget.ref.read(groupsNotifierProvider.notifier).refresh();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed: $e')),
        );
        setState(() => _creating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20, right: 20, top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Create Group',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _nameCtrl,
            maxLength: 50,
            decoration: InputDecoration(
              labelText: 'Group name',
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),
          SegmentedButton<GroupChatAccess>(
            segments: const [
              ButtonSegment(
                value: GroupChatAccess.public_,
                label: Text('Public'),
                icon: Icon(Icons.public, size: 16),
              ),
              ButtonSegment(
                value: GroupChatAccess.inviteOnly,
                label: Text('Invite Only'),
                icon: Icon(Icons.lock_outline, size: 16),
              ),
            ],
            selected: {_access},
            onSelectionChanged: (s) => setState(() => _access = s.first),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _nameCtrl.text.trim().isNotEmpty && !_creating
                ? _create
                : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _creating
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Create Group'),
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

          // Trending section
          if (_selectedFilter == 'All') ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Text(
                  'Trending Now',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ),
            SliverToBoxAdapter(child: _buildTrendingSection()),
          ],

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

  Widget _buildTrendingSection() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Pull stats from existing providers
    final pollsState = ref.watch(pollsNotifierProvider);
    final groupsState = ref.watch(groupsNotifierProvider);
    final feedState = ref.watch(socialFeedNotifierProvider);

    final activePolls = pollsState.polls.where((p) => p.isActive).length;
    final totalVotes = pollsState.polls.fold<int>(0, (s, p) => s + p.totalVotes);
    final activeGroups = groupsState.groups.where((g) => g.isMember).length;
    final recentPosts = feedState.events.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _TrendCard(
              icon: Icons.poll_rounded,
              iconColor: const Color(0xFF6366F1),
              label: 'Active Polls',
              value: '$activePolls',
              subtitle: '$totalVotes votes',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TrendCard(
              icon: Icons.forum_rounded,
              iconColor: const Color(0xFF22C55E),
              label: 'My Groups',
              value: '$activeGroups',
              subtitle: '${groupsState.groups.length} total',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _TrendCard(
              icon: Icons.dynamic_feed_rounded,
              iconColor: const Color(0xFFF97316),
              label: 'Feed',
              value: '$recentPosts',
              subtitle: 'recent posts',
            ),
          ),
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

// ── Trend Card ──────────────────────────────────────────────────────────────

class _TrendCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final String subtitle;

  const _TrendCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: cs.onSurfaceVariant.withValues(alpha: 0.5),
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
  final bool _posting = false;

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
