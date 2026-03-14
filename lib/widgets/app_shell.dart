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
import '../providers/selected_person_provider.dart';
import '../services/background_service.dart';
import '../services/biometric_service.dart';
import '../services/prefetch_service.dart';
import '../providers/social_provider.dart';
import 'voice_meal_sheet.dart';

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
  bool _locked = false;
  bool _checkingBio = false;
  bool _wentToBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkBiometricLock();
      _handleBiometricOffer();
      _runBackgroundChecks();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      _wentToBackground = true;
    }
    if (state == AppLifecycleState.resumed && _wentToBackground) {
      _wentToBackground = false;
      _checkBiometricLock();
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
        reason: 'Unlock Vitalis',
      );
      if (mounted) setState(() => _locked = !ok);
    } finally {
      _checkingBio = false;
    }
  }

  Future<void> _runBackgroundChecks() async {
    await BackgroundService.processPendingActions();
    BackgroundService.checkFlareRisk();
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
    // Biometric lock screen
    if (_locked) {
      return _BiometricLockScreen(onRetry: _checkBiometricLock);
    }

    final location     = GoRouterState.of(context).matchedLocation;
    final selectedIndex = _indexForLocation(location);

    final auth     = ref.watch(authProvider);
    final user     = auth.user;
    final children = user?.profile.children ?? [];

    // Hide person switching on Finance & Grocery (always main profile)
    // Disabled for v1 — finance module reserved for separate app
    final hidePersonSwitcher = /* location.startsWith('/finance') || */
        location.startsWith('/grocery');

    final isOnline = ref.watch(connectivityProvider);
    final welcomeActive = ref.watch(welcomeOverlayProvider);

    // When welcome overlay is active, render child fullscreen (no bars)
    if (welcomeActive && location == '/dashboard') {
      return Scaffold(
        body: widget.child,
      );
    }

    final unreadBadge = ref.watch(notificationBadgeProvider);
    final badgeCount = unreadBadge.valueOrNull ?? 0;

    return Scaffold(
      drawer: _AppDrawer(user: user, badgeCount: badgeCount),
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
      ),
    );
  }
}

// ── Bottom nav with center genie button ──────────────────────────────────────

class _BottomNavWithGenie extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final VoidCallback onGenieTap;

  const _BottomNavWithGenie({
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.onGenieTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Left nav items: Home, Nutrition
              _NavItem(Icons.home_outlined, Icons.home, 'Home', 0,
                  selectedIndex, onDestinationSelected),
              _NavItem(Icons.restaurant_outlined, Icons.restaurant, 'Nutrition', 1,
                  selectedIndex, onDestinationSelected),

              // Center genie button
              Expanded(
                child: GestureDetector(
                  onTap: onGenieTap,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Transform.translate(
                        offset: const Offset(0, -20),
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: cs.surface,
                            border: Border.all(
                              color: cs.outlineVariant.withOpacity(0.5),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: CustomPaint(
                            painter: _GenieBowlPainter(
                              iconColor: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                      Transform.translate(
                        offset: const Offset(0, -16),
                        child: Text('Zenie',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Right nav items: Health, Grocery
              _NavItem(Icons.favorite_outline, Icons.favorite, 'Health', 2,
                  selectedIndex, onDestinationSelected),
              _NavItem(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Grocery', 3,
                  selectedIndex, onDestinationSelected),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final int index;
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _NavItem(this.icon, this.activeIcon, this.label, this.index,
      this.selectedIndex, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isSelected = index == selectedIndex;
    final cs = Theme.of(context).colorScheme;
    final color = isSelected ? cs.primary : cs.onSurfaceVariant;

    return Expanded(
      child: InkResponse(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSelected ? activeIcon : icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(fontSize: 11, color: color,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal)),
          ],
        ),
      ),
    );
  }
}

/// Custom painter: draws a genie rising from a food bowl.
class _GenieBowlPainter extends CustomPainter {
  final Color iconColor;
  _GenieBowlPainter({this.iconColor = Colors.grey});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // ── Bowl ────────────────────────────────────────
    final bowlPaint = Paint()
      ..color = iconColor.withOpacity(0.15)
      ..style = PaintingStyle.fill;
    final bowlStroke = Paint()
      ..color = iconColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // Bowl shape (rounded trapezoid)
    final bowlPath = Path()
      ..moveTo(cx - 15, cy + 4)
      ..quadraticBezierTo(cx - 16, cy + 16, cx - 8, cy + 17)
      ..lineTo(cx + 8, cy + 17)
      ..quadraticBezierTo(cx + 16, cy + 16, cx + 15, cy + 4)
      ..close();
    canvas.drawPath(bowlPath, bowlPaint);
    canvas.drawPath(bowlPath, bowlStroke);

    // Bowl rim
    canvas.drawLine(Offset(cx - 17, cy + 4), Offset(cx + 17, cy + 4), bowlStroke);

    // Food items in bowl (colorful)
    canvas.drawCircle(Offset(cx - 7, cy + 9), 3.5, Paint()..color = const Color(0xFFEF5350)); // red
    canvas.drawCircle(Offset(cx + 1, cy + 7), 3.8, Paint()..color = const Color(0xFF66BB6A)); // green
    canvas.drawCircle(Offset(cx + 9, cy + 9), 3.2, Paint()..color = const Color(0xFFFFB74D)); // orange

    // ── Genie figure (rising from bowl) ─────────────
    final geniePaint = Paint()
      ..color = iconColor.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;

    // Genie body — flowing S-curve rising from bowl
    final bodyPath = Path()
      ..moveTo(cx, cy + 2)
      ..cubicTo(cx + 10, cy - 6, cx - 8, cy - 12, cx + 2, cy - 18);
    canvas.drawPath(bodyPath, geniePaint);

    // Genie head
    canvas.drawCircle(Offset(cx + 2, cy - 20), 4, Paint()
      ..color = iconColor.withOpacity(0.5)
      ..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(cx + 2, cy - 20), 4, Paint()
      ..color = iconColor.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5);

    // Genie arms (small curved lines)
    final armPaint = Paint()
      ..color = iconColor.withOpacity(0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Left arm
    canvas.drawLine(Offset(cx - 2, cy - 12), Offset(cx - 8, cy - 15), armPaint);
    // Right arm
    canvas.drawLine(Offset(cx + 5, cy - 12), Offset(cx + 11, cy - 15), armPaint);

    // Sparkle stars
    _drawStar(canvas, Offset(cx - 10, cy - 8), 2.0, iconColor.withOpacity(0.4));
    _drawStar(canvas, Offset(cx + 12, cy - 18), 1.8, iconColor.withOpacity(0.35));
    _drawStar(canvas, Offset(cx - 6, cy - 22), 1.5, iconColor.withOpacity(0.3));
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color color) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    // 4-pointed star as two overlapping diamonds
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.4, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.4, center.dy)
      ..close()
      ..moveTo(center.dx - radius, center.dy)
      ..lineTo(center.dx, center.dy + radius * 0.4)
      ..lineTo(center.dx + radius, center.dy)
      ..lineTo(center.dx, center.dy - radius * 0.4)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _GenieBowlPainter oldDelegate) =>
      oldDelegate.iconColor != iconColor;
}

// ── App Drawer ────────────────────────────────────────────────────────────────

class _AppDrawer extends StatelessWidget {
  final dynamic user;
  final int badgeCount;

  const _AppDrawer({required this.user, required this.badgeCount});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drawer header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: cs.primaryContainer,
                    child: Text(
                      (user?.name ?? 'V').substring(0, 1).toUpperCase(),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: cs.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? 'User',
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Vitalis',
                          style: tt.bodySmall?.copyWith(
                            color: cs.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: cs.outlineVariant.withOpacity(0.3)),

            // Profile
            ListTile(
              leading: Icon(Icons.person_outline, color: cs.onSurfaceVariant),
              title: const Text('Profile'),
              onTap: () {
                Navigator.pop(context);
                context.push('/profile');
              },
            ),

            // Community Hub (with badge)
            ListTile(
              leading: Badge(
                isLabelVisible: badgeCount > 0,
                label: Text(
                  '$badgeCount',
                  style: const TextStyle(fontSize: 10),
                ),
                child: Icon(Icons.people_outline, color: cs.onSurfaceVariant),
              ),
              title: const Text('Community Hub'),
              onTap: () {
                Navigator.pop(context);
                context.push('/social');
              },
            ),

            // Analytics & Insights
            ListTile(
              leading: Icon(Icons.insights, color: cs.onSurfaceVariant),
              title: const Text('Analytics & Insights'),
              onTap: () {
                Navigator.pop(context);
                context.push('/insights');
              },
            ),

            // Notifications
            ListTile(
              leading: Icon(Icons.notifications_outlined, color: cs.onSurfaceVariant),
              title: const Text('Notifications'),
              onTap: () {
                Navigator.pop(context);
                context.push('/notifications');
              },
            ),

            const Spacer(),
            Divider(color: cs.outlineVariant.withOpacity(0.3)),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Text(
                'Vitalis v5.0',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
            Icon(Icons.lock_outline, size: 64, color: cs.primary),
            const SizedBox(height: 16),
            Text('Vitalis is locked',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onSurface)),
            const SizedBox(height: 8),
            Text('Verify your identity to continue',
                style: TextStyle(color: cs.onSurfaceVariant)),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.fingerprint),
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
            Icon(Icons.wifi_off, size: 16, color: cs.onErrorContainer),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'You\'re offline \u2014 some features may be limited',
                style: TextStyle(fontSize: 12, color: cs.onErrorContainer),
              ),
            ),
            GestureDetector(
              onTap: onRetry,
              child: Icon(Icons.refresh, size: 18, color: cs.onErrorContainer),
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
          GestureDetector(
            onTap: () => Scaffold.of(context).openDrawer(),
            child: Icon(Icons.menu, size: 22, color: cs.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
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
                                    fontSize: 11,
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
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant),
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
