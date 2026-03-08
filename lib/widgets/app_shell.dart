import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../models/dashboard_data.dart';
import '../providers/auth_provider.dart';
import '../providers/dashboard_provider.dart';
import '../providers/selected_person_provider.dart';
import '../services/background_service.dart';

// ── Ring design constants ──────────────────────────────────────────────────────
const _kAvatarRadius = 22.0;
const _kStroke       = 2.5;
const _kRingGap      = 2.0;
const _kRing1Box = _kAvatarRadius * 2 + 2 * (_kRingGap + _kStroke);
const _kRing2Box = _kRing1Box     + 2 * (_kRingGap + _kStroke);
const _kRing3Box = _kRing2Box     + 2 * (_kRingGap + _kStroke);

const _kSmallAvatarRadius = 16.0;
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

class _AppShellState extends ConsumerState<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _handleBiometricOffer();
      _runBackgroundChecks();
    });
  }

  Future<void> _runBackgroundChecks() async {
    // Process any pending notification quick-actions (e.g., 250ml hydration tap)
    await BackgroundService.processPendingActions();
    // Check weather-based flare risk (once per day)
    BackgroundService.checkFlareRisk();
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

  static const _navRoutes = ['/dashboard', '/nutrition', '/health', '/grocery'];

  int _indexForLocation(String location) {
    for (int i = 0; i < _navRoutes.length; i++) {
      if (location.startsWith(_navRoutes[i])) return i;
    }
    return 0;
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final location     = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);

    final auth     = ref.watch(authProvider);
    final user     = auth.user;
    final children = user?.profile.children ?? [];

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Top persistent bar: AvatarBar (family) or profile strip (solo) ─
            if (children.isNotEmpty)
              _AvatarBar(user: user, children: children)
            else
              _SoloTopBar(user: user),
            // ── Screen content ───────────────────────────────────────────────
            // Profile switching is handled ONLY by the avatar bar above,
            // not by swiping on screen content (prevents accidental switches
            // when interacting with analytics charts, body maps, etc.).
            Expanded(child: widget.child),
          ],
        ),
      ),
      // ── M3 NavigationBar (4 destinations) ──────────────────────────────────
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (i) => context.go(_navRoutes[i]),
        destinations: const [
          NavigationDestination(
            icon:         Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label:        'Home',
          ),
          NavigationDestination(
            icon:         Icon(Icons.restaurant_outlined),
            selectedIcon: Icon(Icons.restaurant),
            label:        'Nutrition',
          ),
          NavigationDestination(
            icon:         Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label:        'Health',
          ),
          NavigationDestination(
            icon:         Icon(Icons.shopping_cart_outlined),
            selectedIcon: Icon(Icons.shopping_cart),
            label:        'Grocery',
          ),
        ],
      ),
    );
  }
}

// ── Solo top bar (no family members) — persistent profile button ───────────────

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
            'Vitalis',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
                        fontWeight: FontWeight.bold,
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
    allDash[currentPid] = ref.watch(dashboardProvider(currentPid));
    for (final p in otherPersons) {
      allDash[p['id']!] = const AsyncValue.loading();
    }
    if (allDash[currentPid] is AsyncData) {
      for (final p in otherPersons) {
        ref.read(dashboardProvider(p['id']!));
      }
    }

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
                            onTap: () => ref
                                .read(selectedPersonProvider.notifier)
                                .state = p['id']!,
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
                                      fontSize: 9,
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
                                icon: Icon(
                                  Icons.person_add_alt_1_outlined,
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
                                    fontSize: 9,
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
                      fontWeight: FontWeight.bold, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                if (data != null) ...[
                  _RingStat(Icons.local_fire_department,
                      '${data.todayCalories.round()}', 'kcal',
                      calPct, _kCalColor),
                  _RingStat(Icons.water_drop,
                      '${(data.todayWater / 1000).toStringAsFixed(1)}', 'L',
                      waterPct, _kWaterColor),
                  _RingStat(Icons.mood,
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
                      fontWeight: FontWeight.bold,
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
                        fontSize: 12, color: colorScheme.onSurfaceVariant))
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
          Icon(Icons.fingerprint, size: 64, color: cs.primary),
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
  final IconData icon;
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
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          Text(
            '$value $unit',
            style: TextStyle(fontSize: 10, color: Colors.grey.shade700),
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
