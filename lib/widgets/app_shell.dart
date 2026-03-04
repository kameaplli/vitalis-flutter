import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../models/dashboard_data.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hydration_provider.dart';
import '../providers/nutrition_provider.dart';
import '../providers/selected_person_provider.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  static const _navRoutes = ['/dashboard', '/nutrition', '/hydration', '/health'];

  static const _navItems = [
    BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Dashboard'),
    BottomNavigationBarItem(icon: Icon(Icons.restaurant_outlined), activeIcon: Icon(Icons.restaurant), label: 'Nutrition'),
    BottomNavigationBarItem(icon: Icon(Icons.water_drop_outlined), activeIcon: Icon(Icons.water_drop), label: 'Hydration'),
    BottomNavigationBarItem(icon: Icon(Icons.favorite_outline), activeIcon: Icon(Icons.favorite), label: 'Health'),
    BottomNavigationBarItem(icon: Icon(Icons.menu), activeIcon: Icon(Icons.menu_open), label: 'More'),
  ];

  int _indexForLocation(String location) {
    for (int i = 0; i < _navRoutes.length; i++) {
      if (location.startsWith(_navRoutes[i])) return i;
    }
    return 4;
  }

  void _onNavTap(int index) {
    if (index < 4) {
      context.go(_navRoutes[index]);
    } else {
      _scaffoldKey.currentState?.openDrawer();
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);

    final auth = ref.watch(authProvider);
    final user = auth.user;
    final children = user?.profile.children ?? [];

    final persons = <String>[
      'self',
      ...children.map<String>((c) => c.id as String),
    ];
    final currentIndex = persons.indexOf(ref.watch(selectedPersonProvider));

    void swipeTo(int index) {
      if (persons.isEmpty) return;
      final wrapped = ((index % persons.length) + persons.length) % persons.length;
      ref.read(selectedPersonProvider.notifier).state = persons[wrapped];
    }

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (children.isNotEmpty)
              _AvatarBar(user: user, children: children),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: children.isNotEmpty
                    ? (details) {
                        final v = details.primaryVelocity ?? 0;
                        if (v < -400) swipeTo(currentIndex + 1);
                        if (v > 400) swipeTo(currentIndex - 1);
                      }
                    : null,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: _onNavTap,
        items: _navItems,
        type: BottomNavigationBarType.fixed,
      ),
      drawer: _buildDrawer(context),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final user = ref.read(authProvider).user;
    final avatarUrl = user?.avatarUrl != null
        ? ApiConstants.resolveUrl(user!.avatarUrl)
        : null;
    final cs = Theme.of(context).colorScheme;
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(color: cs.surfaceContainerLow),
              margin: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 32,
                    backgroundColor: cs.primaryContainer,
                    backgroundImage: avatarUrl != null
                        ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                        : null,
                    child: avatarUrl == null
                        ? Text(
                            (user?.name ?? 'V').substring(0, 1).toUpperCase(),
                            style: TextStyle(
                                color: cs.onPrimaryContainer, fontSize: 26),
                          )
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Text(user?.name ?? '',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(user?.email ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            const Divider(height: 1),
            _drawerItem(context, Icons.person_outline, 'Profile', '/profile'),
            _drawerItem(context, Icons.monitor_weight_outlined, 'Weight', '/weight'),
            _drawerItem(context, Icons.list_alt_outlined, 'Entries', '/entries'),
            _drawerItem(context, Icons.healing_outlined, 'Eczema', '/eczema'),
            _drawerItem(context, Icons.bar_chart_outlined, 'Analytics', '/analytics'),
            _drawerItem(context, Icons.qr_code_scanner_outlined, 'Scanner', '/scanner'),
            _drawerItem(context, Icons.shopping_cart_outlined, 'Grocery Intelligence', '/grocery'),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _drawerItem(BuildContext context, IconData icon, String label, String route) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.pop(context);
        context.go(route);
      },
    );
  }
}

// ── Avatar bar ─────────────────────────────────────────────────────────────────

class _AvatarBar extends ConsumerWidget {
  final dynamic user;
  final List<dynamic> children;

  const _AvatarBar({required this.user, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedPersonProvider);
    final colorScheme = Theme.of(context).colorScheme;

    final selfAvatarUrl = user?.avatarUrl != null
        ? ApiConstants.resolveUrl(user!.avatarUrl)
        : null;

    final persons = <Map<String, String?>>[
      {'id': 'self', 'name': user?.name ?? 'Me', 'avatarUrl': selfAvatarUrl},
      for (final c in children)
        {
          'id': c.id,
          'name': c.name,
          'avatarUrl': c.avatarUrl != null
              ? ApiConstants.resolveUrl(c.avatarUrl)
              : null,
        },
    ];

    final currentIndex = persons.indexWhere((p) => p['id'] == selected);
    final currentPerson = currentIndex >= 0 ? persons[currentIndex] : persons.first;
    final otherPersons = persons.where((p) => p['id'] != selected).toList();

    // ── Background prefetch for ALL family members (#5, #6, #7) ──────────────
    // Pre-warm dashboards + hydration for every person so switching is instant.
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final sevenDaysAgo = DateTime.now()
        .subtract(const Duration(days: 7))
        .toIso8601String()
        .substring(0, 10);
    for (final p in persons) {
      final pid = p['id']!;
      ref.watch(dashboardProvider(pid));          // warms dashboard cache
      ref.watch(todayHydrationProvider(pid));     // warms hydration total
    }
    // Pre-fetch last 7 days of nutrition entries for the selected person
    // so Entries page opens instantly. keepAlive keeps it cached.
    ref.watch(nutritionEntriesProvider('$selected|$sevenDaysAgo|$today'));

    // Dashboard data for today's stats on the card
    final dashAsync = ref.watch(dashboardProvider(selected));

    void goTo(int index) {
      if (persons.isEmpty) return;
      final i = ((index % persons.length) + persons.length) % persons.length;
      ref.read(selectedPersonProvider.notifier).state = persons[i]['id']!;
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) goTo(currentIndex + 1);
        if (v > 300) goTo(currentIndex - 1);
      },
      child: Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(8, 9, 4, 9),
        child: Row(
          children: [
            // ── Current person: business card ──────────────────────────────
            Expanded(
              flex: 5,
              child: _PersonCard(
                person: currentPerson,
                dashAsync: dashAsync,
                colorScheme: colorScheme,
              ),
            ),
            const SizedBox(width: 6),
            // ── Other (unselected) avatars ─────────────────────────────────
            Expanded(
              flex: 3,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (final p in otherPersons)
                    GestureDetector(
                      onTap: () => ref
                          .read(selectedPersonProvider.notifier)
                          .state = p['id']!,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _SmallAvatar(
                                avatarUrl: p['avatarUrl'],
                                name: p['name'] ?? '',
                                colorScheme: colorScheme),
                            const SizedBox(height: 2),
                            Text(
                              _short(p['name'] ?? ''),
                              style: TextStyle(
                                  fontSize: 9,
                                  color: colorScheme.onSurfaceVariant),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.person_add_alt_1_outlined,
                          size: 16),
                      padding: EdgeInsets.zero,
                      tooltip: 'Add family member',
                      onPressed: () => context.go('/profile'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _short(String name) =>
      name.length > 5 ? name.substring(0, 5) : name;
}

// ── Business card for the selected person ─────────────────────────────────────

class _PersonCard extends StatelessWidget {
  final Map<String, String?> person;
  final AsyncValue<DashboardData> dashAsync;
  final ColorScheme colorScheme;

  const _PersonCard(
      {required this.person,
      required this.dashAsync,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final avatarUrl = person['avatarUrl'];
    final name = person['name'] ?? '';
    final firstName = name.split(' ').first;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          // Avatar with glow ring
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: colorScheme.primary, width: 2),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.45),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
                BoxShadow(
                  color: colorScheme.primary.withOpacity(0.2),
                  blurRadius: 16,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                  : null,
              child: avatarUrl == null
                  ? Text(initial,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onPrimaryContainer))
                  : null,
            ),
          ),
          const SizedBox(width: 8),
          // Name + stats
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  firstName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                dashAsync.when(
                  skipLoadingOnReload: true,
                  loading: () => const SizedBox(
                    height: 12,
                    width: 12,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                  data: (data) => Row(
                    children: [
                      _Stat(Icons.local_fire_department,
                          '${data.todayCalories.round()}', Colors.orange),
                      const SizedBox(width: 6),
                      _Stat(Icons.water_drop,
                          '${(data.todayWater / 1000).toStringAsFixed(1)}L',
                          Colors.blue),
                      const SizedBox(width: 6),
                      _Stat(Icons.mood,
                          '${(data.healthScore.mood / 2).round()}',
                          Colors.amber),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Small (unselected) avatar circle ──────────────────────────────────────────

class _SmallAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final ColorScheme colorScheme;

  const _SmallAvatar(
      {required this.avatarUrl,
      required this.name,
      required this.colorScheme});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 16,
      backgroundColor: colorScheme.surfaceContainerHighest,
      backgroundImage: avatarUrl != null
          ? CachedNetworkImageProvider(avatarUrl!) as ImageProvider
          : null,
      child: avatarUrl == null
          ? Text(initial,
              style: TextStyle(
                  fontSize: 12, color: colorScheme.onSurfaceVariant))
          : null,
    );
  }
}

// ── Compact stat (icon + value) ───────────────────────────────────────────────

class _Stat extends StatelessWidget {
  final IconData icon;
  final String value;
  final Color color;

  const _Stat(this.icon, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 2),
        Text(value,
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700)),
      ],
    );
  }
}
