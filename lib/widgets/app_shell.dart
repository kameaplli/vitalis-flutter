import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../models/dashboard_data.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/hydration_provider.dart';
import '../providers/selected_person_provider.dart';
import '../services/background_service.dart';
import '../services/biometric_service.dart';
import '../services/notification_service.dart';
import '../services/prefetch_service.dart';
import 'voice_meal_sheet.dart';
import 'package:hugeicons/hugeicons.dart';

// ── Ring design constants ──────────────────────────────────────────────────────
const _kAvatarRadius = 22.0;
const _kStroke       = 2.5;
const _kRingGap      = 2.0;
const _kRing1Box = _kAvatarRadius * 2 + 2 * (_kRingGap + _kStroke);
const _kRing2Box = _kRing1Box     + 2 * (_kRingGap + _kStroke);
const _kRing3Box = _kRing2Box     + 2 * (_kRingGap + _kStroke);

const _kSmallAvatarRadius = 20.0;
const _kSmallRingStroke   = 2.5;
const _kSmallRingGap      = 2.0;
const _kSmallRingBox = _kSmallAvatarRadius * 2 + 2 * (_kSmallRingGap + _kSmallRingStroke);

const _kCalColor   = Color(0xFFF97316);
const _kWaterColor = Color(0xFF3B82F6);
const _kMoodColor  = Color(0xFF22C55E);

// ── Main shell ─────────────────────────────────────────────────────────────────

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _locked = false;
  bool _checkingBio = false;
  bool _wentToBackground = false;
  DateTime? _backgroundAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Wire up foreground hydration quick-log callback so taps process immediately
    NotificationService.onHydrationLogged = _processPendingActionsOnResume;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricLock();
      _handleBiometricOffer();
      _runBackgroundChecks();
    });
  }

  @override
  void dispose() {
    NotificationService.onHydrationLogged = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wentToBackground = true;
      _backgroundAt = DateTime.now();
    }
    if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      final away = _backgroundAt != null
          ? DateTime.now().difference(_backgroundAt!)
          : Duration.zero;
      _backgroundAt = null;
      // Only lock if away for more than 10 seconds (skip for file pickers, share sheets, etc.)
      if (away.inSeconds > 10) {
        _checkBiometricLock();
      }
      // Re-schedule notifications (Android may kill them on force-stop)
      NotificationService.scheduleAll().catchError((_) {});
      // Process any pending notification actions (e.g., hydration quick-log tapped while backgrounded)
      _processPendingActionsOnResume();
      // Check for new social notifications on resume
      BackgroundService.checkSocialNotifications();
    }
  }

  Future<void> _checkBiometricLock() async {
    if (_checkingBio) return;
    _checkingBio = true;
    try {
      // Skip if user is not logged in (e.g. just signed out)
      final user = ref.read(authProvider).user;
      if (user == null || !mounted) return;

      final enabled = await SecureStorage.getBiometricsEnabled();
      if (!enabled || !mounted) return;

      setState(() => _locked = true);
      final ok = await BiometricService.authenticate(
        reason: 'Unlock QoreHealth',
      );
      if (mounted) setState(() => _locked = !ok);
    } finally {
      _checkingBio = false;
    }
  }

  Future<void> _runBackgroundChecks() async {
    final hydrationLogged = await BackgroundService.processPendingActions();
    if (hydrationLogged) {
      // Refresh dashboard + hydration data so notification-logged water shows up
      final person = ref.read(selectedPersonProvider);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      ref.invalidate(todayHydrationProvider(person));
      ref.invalidate(dashboardProvider((person, today)));
    }
    BackgroundService.checkFlareRisk();
    BackgroundService.checkSocialNotifications();
    _prefetchAndWarm();
  }

  /// Process pending notification actions on resume (not just cold start).
  /// Fixes: hydration quick-log buttons tapped while app is backgrounded
  /// were only processed on cold start, never appearing on the dashboard.
  Future<void> _processPendingActionsOnResume() async {
    final hydrationLogged = await BackgroundService.processPendingActions();
    if (hydrationLogged && mounted) {
      final person = ref.read(selectedPersonProvider);
      final today = DateTime.now().toIso8601String().substring(0, 10);
      ref.invalidate(todayHydrationProvider(person));
      ref.invalidate(dashboardProvider((person, today)));
    }
  }

  void _prefetchAndWarm() {
    // Prefetch data for screens the user is likely to visit
    final person = ref.read(selectedPersonProvider);
    PrefetchService.warmAll(ref, person);
  }

  Future<void> _handleBiometricOffer() async {
    final auth = ref.read(authProvider);
    if (!auth.showBioOffer) return;
    final email    = auth.bioOfferEmail;
    final password = auth.bioOfferPassword;
    ref.read(authProvider.notifier).clearBioOffer();
    if (email == null || password == null || !mounted) return;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _BioOfferDialog(),
    );

    await SecureStorage.setBiometricsPrompted(true);
    if (accepted != true || !mounted) return;

    final name = ref.read(authProvider).user?.name ?? '';
    await Future.wait([
      SecureStorage.saveBioCredentials(
          email: email, password: password, name: name),
      SecureStorage.setBiometricsEnabled(true),
    ]);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Biometric sign-in enabled!')),
      );
    }
  }

  // ── Navigation ─────────────────────────────────────────────────────────────

  static const _navRoutes = ['/dashboard', '/nutrition', '/health', '/more'];

  int _indexForLocation(String location) {
    for (int i = 0; i < _navRoutes.length; i++) {
      if (location.startsWith(_navRoutes[i])) return i;
    }
    return 0;
  }

  void _openMorePage(BuildContext context) {
    context.go('/more');
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Biometric lock screen
    if (_locked) {
      return _BiometricLockScreen(onRetry: _checkBiometricLock);
    }

    final location     = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);

    final auth     = ref.watch(authProvider);
    final user     = auth.user;
    final children = user?.profile.children ?? [];

    // Hide person switching on certain screens (always main profile)
    final hidePersonSwitcher = location.startsWith('/grocery') ||
        location.startsWith('/profile');

    final isOnline = ref.watch(connectivityProvider);
    final welcomeActive = ref.watch(welcomeOverlayProvider);

    // When welcome overlay is active, render child fullscreen (no bars)
    if (welcomeActive && location == '/dashboard') {
      return Scaffold(
        body: widget.child,
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (hidePersonSwitcher)
              _SoloTopBar(user: user)
            else if (children.isNotEmpty)
              _AvatarBar(user: user, children: children)
            else
              _SoloTopBar(user: user),
            if (!isOnline)
              _OfflineBanner(onRetry: () => ref.read(connectivityProvider.notifier).refresh()),
            Expanded(child: widget.child),
          ],
        ),
      ),
      bottomNavigationBar: _BottomNavWithGenie(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_navRoutes[i]),
        onGenieTap: () {
          final personId = ref.read(selectedPersonProvider);
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => VoiceMealSheet(
              personId: personId,
              onLogged: () {
                ref.invalidate(dashboardProvider((personId, DateTime.now().toIso8601String().substring(0, 10))));
              },
            ),
          );
        },
        onMoreTap: () => _openMorePage(context),
      ),
    );
  }
}

// ── Bottom nav with center genie button ──────────────────────────────────────

class _BottomNavWithGenie extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onGenieTap;
  final VoidCallback onMoreTap;

  const _BottomNavWithGenie({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onGenieTap,
    required this.onMoreTap,
  });

  static const _iconSize = 26.0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Map selectedIndex to NavigationBar index (0=Home, 1=Nutrition, skip Genie, 2=Health, 3=More)
    final navBarIndex = selectedIndex > 1 ? selectedIndex + 1 : selectedIndex;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        NavigationBar(
          height: 68,
          selectedIndex: navBarIndex.clamp(0, 4),
          onDestinationSelected: (i) {
            if (i == 2) return; // Genie placeholder — handled by overlay
            if (i == 4) { onMoreTap(); return; }
            final mapped = i > 2 ? i - 1 : i;
            onDestinationSelected(mapped);
          },
          destinations: [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: cs.onSurfaceVariant, size: _iconSize),
              selectedIcon: Icon(Icons.home, color: cs.primary, size: _iconSize),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.restaurant_outlined, color: cs.onSurfaceVariant, size: _iconSize),
              selectedIcon: Icon(Icons.restaurant, color: cs.primary, size: _iconSize),
              label: 'Nutrition',
            ),
            // Placeholder for center Genie button
            const NavigationDestination(
              icon: SizedBox(width: 24, height: 24),
              label: '',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border, color: cs.onSurfaceVariant, size: _iconSize),
              selectedIcon: Icon(Icons.favorite, color: cs.primary, size: _iconSize),
              label: 'Health',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined, color: cs.onSurfaceVariant, size: _iconSize),
              selectedIcon: Icon(Icons.grid_view, color: cs.primary, size: _iconSize),
              label: 'More',
            ),
          ],
        ),
        // Center voice button overlay (glowing + at same height as other nav icons)
        Positioned(
          top: 2,
          child: GestureDetector(
            onTap: onGenieTap,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [cs.primary, cs.tertiary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: HugeIcon(icon: 
                HugeIcons.strokeRoundedAdd01,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// _GenieBowlPainter removed — replaced with HugeIcons.strokeRoundedStars

// _AppDrawer removed — replaced by MoreScreen (full-page route)

// ── Biometric lock screen ─────────────────────────────────────────────────────

class _BiometricLockScreen extends StatelessWidget {
  final VoidCallback onRetry;
  const _BiometricLockScreen({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedLockPassword, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text('QoreHealth is locked',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Verify your identity to continue',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurfaceVariant)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: HugeIcon(icon: HugeIcons.strokeRoundedFingerAccess),
              label: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Offline banner ────────────────────────────────────────────────────────────

class _OfflineBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _OfflineBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.errorContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            HugeIcon(icon: HugeIcons.strokeRoundedWifiOff01, size: 16, color: cs.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You\'re offline \u2014 some features may be limited',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cs.onErrorContainer),
              ),
            ),
            GestureDetector(
              onTap: onRetry,
              child: HugeIcon(icon: HugeIcons.strokeRoundedRefresh, size: 18, color: cs.onErrorContainer),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Solo top bar (no family members) ──────────────────────────────────────────

class _SoloTopBar extends ConsumerWidget {
  final dynamic user;
  const _SoloTopBar({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final avatarUrl = user?.avatarUrl != null
        ? ApiConstants.resolveUrl(user!.avatarUrl)
        : null;

    return Container(
      color: cs.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Text(
            'QoreHealth',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              color: cs.primary,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: cs.primaryContainer,
              backgroundImage: avatarUrl != null
                  ? CachedNetworkImageProvider(avatarUrl) as ImageProvider
                  : null,
              child: avatarUrl == null
                  ? Text(
                      (user?.name ?? 'V').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        color: cs.onPrimaryContainer,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Avatar bar (family mode) ───────────────────────────────────────────────────

class _AvatarBar extends ConsumerWidget {
  final dynamic user;
  final List<dynamic> children;

  const _AvatarBar({required this.user, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected    = ref.watch(selectedPersonProvider);
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

    final currentIndex  = persons.indexWhere((p) => p['id'] == selected);
    final currentPerson = currentIndex >= 0 ? persons[currentIndex] : persons.first;
    final otherPersons  = persons.where((p) => p['id'] != selected).toList();

    final Map<String, AsyncValue<DashboardData>> allDash = {};
    final currentPid = currentPerson['id']!;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    allDash[currentPid] = ref.watch(dashboardProvider((currentPid, today)));
    for (final p in otherPersons) {
      allDash[p['id']!] = const AsyncValue.loading();
    }
    if (allDash[currentPid] is AsyncData) {
      for (final p in otherPersons) {
        ref.read(dashboardProvider((p['id']!, today)));
      }
    }

    void goTo(int index) {
      if (persons.isEmpty) return;
      final i = ((index % persons.length) + persons.length) % persons.length;
      ref.read(selectedPersonProvider.notifier).state = persons[i]['id']!;
      HapticFeedback.lightImpact();
    }

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (v < -300) goTo(currentIndex + 1);
        if (v > 300) goTo(currentIndex - 1);
      },
      child: Container(
        color: colorScheme.surface,
        padding: const EdgeInsets.fromLTRB(8, 7, 6, 7),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Selected person card ──────────────────────────────────────
              Expanded(
                flex: 55,
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: _PersonCard(
                    person: currentPerson,
                    dashAsync: allDash[currentPerson['id']!] ??
                        const AsyncValue.loading(),
                    colorScheme: colorScheme,
                  ),
                ),
              ),
              // ── Vertical divider ──────────────────────────────────────────
              Container(
                width: 1,
                margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                color: colorScheme.outlineVariant.withValues(alpha: 0.4),
              ),
              // ── Other persons + add button ────────────────────────────────
              Expanded(
                flex: 45,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      for (final p in otherPersons)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          child: GestureDetector(
                            onTap: () {
                              ref.read(selectedPersonProvider.notifier).state = p['id']!;
                              HapticFeedback.lightImpact();
                            },
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _SmallRingAvatar(
                                  avatarUrl: p['avatarUrl'],
                                  name: p['name'] ?? '',
                                  dashAsync: allDash[p['id']!] ??
                                      const AsyncValue.loading(),
                                  colorScheme: colorScheme,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  _short(p['name'] ?? ''),
                                  style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: colorScheme.onSurfaceVariant),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Add person button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: _kSmallRingBox,
                              height: _kSmallRingBox,
                              child: IconButton(
                                icon: HugeIcon(icon: 
                                  HugeIcons.strokeRoundedUserAdd01,
                                  size: 18,
                                  color: colorScheme.primary,
                                ),
                                padding: EdgeInsets.zero,
                                tooltip: 'Add family member',
                                onPressed: () => context.push('/profile'),
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text('Add',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.primary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _short(String name) =>
      name.length > 6 ? name.substring(0, 6) : name;
}

// ── Selected person card with 3-ring activity avatar ──────────────────────────

class _PersonCard extends StatelessWidget {
  final Map<String, String?> person;
  final AsyncValue<DashboardData> dashAsync;
  final ColorScheme colorScheme;

  const _PersonCard({
    required this.person,
    required this.dashAsync,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final avatarUrl = person['avatarUrl'];
    final name      = person['name'] ?? '';
    final firstName = name.split(' ').first;

    return dashAsync.when(
      skipLoadingOnReload: true,
      loading: () => _buildLayout(
        context, avatarUrl, firstName, name,
        calPct: 0, waterPct: 0, moodPct: 0, data: null,
      ),
      error: (_, __) => _buildLayout(
        context, avatarUrl, firstName, name,
        calPct: 0, waterPct: 0, moodPct: 0, data: null,
      ),
      data: (data) {
        final calPct   = (data.todayCalories / 2000).clamp(0.0, 1.0);
        final waterPct = (data.todayWater / 2500).clamp(0.0, 1.0);
        final moodPct  = (data.healthScore.mood / 20).clamp(0.0, 1.0);
        return _buildLayout(
          context, avatarUrl, firstName, name,
          calPct: calPct, waterPct: waterPct, moodPct: moodPct, data: data,
        );
      },
    );
  }

  Widget _buildLayout(
    BuildContext context,
    String? avatarUrl,
    String firstName,
    String name, {
    required double calPct,
    required double waterPct,
    required double moodPct,
    required DashboardData? data,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Row(
        children: [
          _RingAvatar(
            avatarUrl:    avatarUrl,
            name:         name,
            caloriesPct:  calPct,
            waterPct:     waterPct,
            moodPct:      moodPct,
            colorScheme:  colorScheme,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  firstName,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: -0.2),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                if (data != null) ...[
                  _RingStat(HugeIcons.strokeRoundedFire,
                      '${data.todayCalories.round()}', 'kcal',
                      calPct, _kCalColor),
                  _RingStat(HugeIcons.strokeRoundedDroplet,
                      (data.todayWater / 1000).toStringAsFixed(1), 'L',
                      waterPct, _kWaterColor),
                  _RingStat(HugeIcons.strokeRoundedSmileDizzy,
                      '${(data.healthScore.mood / 2).round()}', '/10',
                      moodPct, _kMoodColor),
                ] else
                  const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── 3-concentric-ring avatar ──────────────────────────────────────────────────

class _RingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final double caloriesPct;
  final double waterPct;
  final double moodPct;
  final ColorScheme colorScheme;

  const _RingAvatar({
    required this.avatarUrl,
    required this.name,
    required this.caloriesPct,
    required this.waterPct,
    required this.moodPct,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return SizedBox(
      width: _kRing3Box,
      height: _kRing3Box,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _AnimatedRing(value: caloriesPct, boxSize: _kRing3Box,
              color: _kCalColor, duration: const Duration(milliseconds: 1200)),
          _AnimatedRing(value: waterPct, boxSize: _kRing2Box,
              color: _kWaterColor, duration: const Duration(milliseconds: 1000)),
          _AnimatedRing(value: moodPct, boxSize: _kRing1Box,
              color: _kMoodColor, duration: const Duration(milliseconds: 800)),
          CircleAvatar(
            radius: _kAvatarRadius,
            backgroundColor: colorScheme.primaryContainer,
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl!) as ImageProvider
                : null,
            child: avatarUrl == null
                ? Text(
                    initial,
                    style: TextStyle(
                      fontSize: _kAvatarRadius * 0.72,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Single-ring avatar (unselected family member) ─────────────────────────────

class _SmallRingAvatar extends StatelessWidget {
  final String? avatarUrl;
  final String name;
  final AsyncValue<DashboardData> dashAsync;
  final ColorScheme colorScheme;

  const _SmallRingAvatar({
    required this.avatarUrl,
    required this.name,
    required this.dashAsync,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final vitalityPct = dashAsync.whenOrNull(data: (data) {
      final cal   = (data.todayCalories / 2000).clamp(0.0, 1.0);
      final water = (data.todayWater / 2500).clamp(0.0, 1.0);
      final mood  = (data.healthScore.mood / 20).clamp(0.0, 1.0);
      return (cal + water + mood) / 3;
    }) ?? 0.0;

    final ringColor = vitalityPct >= 0.75
        ? _kMoodColor
        : vitalityPct >= 0.4
            ? _kCalColor
            : Colors.red.shade400;

    return SizedBox(
      width: _kSmallRingBox,
      height: _kSmallRingBox,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _AnimatedRing(
            value: vitalityPct,
            boxSize: _kSmallRingBox,
            color: ringColor,
            strokeWidth: _kSmallRingStroke,
            duration: const Duration(milliseconds: 900),
          ),
          CircleAvatar(
            radius: _kSmallAvatarRadius,
            backgroundColor: colorScheme.surfaceContainerHighest,
            backgroundImage: avatarUrl != null
                ? CachedNetworkImageProvider(avatarUrl!) as ImageProvider
                : null,
            child: avatarUrl == null
                ? Text(initial,
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700, color: colorScheme.onSurfaceVariant))
                : null,
          ),
        ],
      ),
    );
  }
}

// ── Animated circular progress ring ───────────────────────────────────────────

class _AnimatedRing extends StatelessWidget {
  final double value;
  final double boxSize;
  final Color color;
  final double strokeWidth;
  final Duration duration;

  const _AnimatedRing({
    required this.value,
    required this.boxSize,
    required this.color,
    this.strokeWidth = _kStroke,
    required this.duration,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: boxSize,
        height: boxSize,
        child: CircularProgressIndicator(
          value: v,
          strokeWidth: strokeWidth,
          color: color,
          backgroundColor: color.withValues(alpha: 0.15),
          strokeCap: StrokeCap.round,
        ),
      ),
    );
  }
}

// ── Biometric offer dialog ─────────────────────────────────────────────────────

class _BioOfferDialog extends StatelessWidget {
  const _BioOfferDialog();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AlertDialog(
      title: const Text('Faster sign-ins'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedFingerAccess, size: 64, color: cs.primary),
          const SizedBox(height: 12),
          const Text(
            'Use your fingerprint or face to sign in next time. '
            'Your password stays safe on this device.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Enable'),
        ),
      ],
    );
  }
}

// ── Compact stat row with mini progress bar ────────────────────────────────────

class _RingStat extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String value;
  final String unit;
  final double pct;
  final Color color;

  const _RingStat(this.icon, this.value, this.unit, this.pct, this.color);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$value $unit',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: 30,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct,
                    color: pct >= 1.0 ? Colors.red.shade400 : color,
                    backgroundColor: color.withValues(alpha: 0.15),
                    minHeight: 3,
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
