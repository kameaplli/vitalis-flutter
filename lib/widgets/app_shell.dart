import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../providers/auth_provider.dart';
import '../providers/selected_person_provider.dart';
import '../services/background_service.dart';

// ── Avatar bar constants ─────────────────────────────────────────────────────
const _kAvatarSize   = 38.0;
const _kSelectedSize = 42.0;

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
            _TopBar(user: user, children: children),
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

// ── Unified top bar: brand + avatar selector + settings ─────────────────────

class _TopBar extends ConsumerWidget {
  final dynamic user;
  final List<dynamic> children;
  const _TopBar({required this.user, required this.children});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final selected = ref.watch(selectedPersonProvider);

    final selfUrl = user?.avatarUrl != null
        ? ApiConstants.resolveUrl(user!.avatarUrl) : null;

    final persons = <Map<String, String?>>[
      {'id': 'self', 'name': user?.name ?? 'Me', 'url': selfUrl},
      for (final c in children)
        {
          'id': c.id,
          'name': c.name,
          'url': c.avatarUrl != null ? ApiConstants.resolveUrl(c.avatarUrl) : null,
        },
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(bottom: BorderSide(color: cs.outlineVariant.withAlpha(40))),
      ),
      child: Row(
        children: [
          // Brand
          Text('Vitalis',
            style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: cs.primary, letterSpacing: -0.5,
            ),
          ),
          const SizedBox(width: 16),
          // Person pills
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final p in persons)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _PersonPill(
                        name: p['name'] ?? '',
                        avatarUrl: p['url'],
                        isSelected: p['id'] == selected,
                        onTap: () => ref.read(selectedPersonProvider.notifier).state = p['id']!,
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings_outlined, size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
    );
  }
}

class _PersonPill extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonPill({
    required this.name,
    this.avatarUrl,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    final firstName = name.split(' ').first;
    final radius = isSelected ? _kSelectedSize / 2 : _kAvatarSize / 2;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 10 : 4,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected ? cs.primaryContainer : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: isSelected ? _kSelectedSize : _kAvatarSize,
              height: isSelected ? _kSelectedSize : _kAvatarSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(color: cs.primary, width: 2.5)
                    : null,
              ),
              child: CircleAvatar(
                radius: radius - (isSelected ? 2.5 : 0),
                backgroundColor: cs.surfaceContainerHighest,
                backgroundImage: avatarUrl != null && avatarUrl!.isNotEmpty
                    ? CachedNetworkImageProvider(avatarUrl!) as ImageProvider
                    : null,
                child: avatarUrl == null || avatarUrl!.isEmpty
                    ? Text(initial,
                        style: TextStyle(
                          fontSize: isSelected ? 15 : 13,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ))
                    : null,
              ),
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                firstName,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cs.onPrimaryContainer,
                ),
              ),
            ],
          ],
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

