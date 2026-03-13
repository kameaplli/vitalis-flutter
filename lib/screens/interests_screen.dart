import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/interests_provider.dart';

/// Interest selection screen shown after first registration.
/// Users pick which health modules they want to use.
class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen>
    with SingleTickerProviderStateMixin {
  final Set<String> _selected = {'nutrition'}; // Always on
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: Curves.easeOut);
    _entryCtrl.forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await saveUserInterests(_selected);
    ref.read(userInterestsProvider.notifier).state = Set.from(_selected);
    ref.read(interestsCompleteProvider.notifier).state = true;
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            cs.brightness == Brightness.dark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        body: SafeArea(
          child: FadeTransition(
            opacity: _fadeIn,
            child: Column(
              children: [
                const SizedBox(height: 32),
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Icon(
                          Icons.tune_rounded,
                          color: cs.onPrimaryContainer,
                          size: 30,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'What interests you?',
                        style: tt.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: cs.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Choose the features you want to use.\nYou can change this later in settings.',
                        style: tt.bodyMedium?.copyWith(
                          color: cs.onSurfaceVariant,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                // Interest cards
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: kAllInterests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final interest = kAllInterests[i];
                      final active = _selected.contains(interest.id);
                      return _InterestCard(
                        interest: interest,
                        active: active,
                        onToggle: () {
                          if (interest.alwaysOn) return;
                          HapticFeedback.lightImpact();
                          setState(() {
                            if (active) {
                              _selected.remove(interest.id);
                            } else {
                              _selected.add(interest.id);
                            }
                          });
                        },
                      );
                    },
                  ),
                ),
                // Get Started button
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(
                      onPressed: _finish,
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Get Started',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: MediaQuery.of(context).padding.bottom),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Interest card ─────────────────────────────────────────────────────────────

class _InterestCard extends StatelessWidget {
  final UserInterest interest;
  final bool active;
  final VoidCallback onToggle;

  const _InterestCard({
    required this.interest,
    required this.active,
    required this.onToggle,
  });

  static const _icons = <String, IconData>{
    'nutrition': Icons.restaurant_rounded,
    'eczema': Icons.dry_rounded,
    'family': Icons.family_restroom_rounded,
    'weight': Icons.fitness_center_rounded,
    'hydration': Icons.water_drop_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final icon = _icons[interest.id] ?? Icons.circle;

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: active
              ? cs.primaryContainer.withOpacity(0.5)
              : cs.surfaceContainerHighest.withOpacity(0.4),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: active
                ? cs.primary.withOpacity(0.5)
                : cs.outlineVariant.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: active
                    ? cs.primary.withOpacity(0.12)
                    : cs.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: active ? cs.primary : cs.onSurfaceVariant,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        interest.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: active ? cs.onSurface : cs.onSurfaceVariant,
                        ),
                      ),
                      if (interest.alwaysOn) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Core',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: cs.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    interest.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: interest.alwaysOn
                  ? Icon(
                      Icons.check_circle,
                      key: const ValueKey('locked'),
                      color: cs.primary,
                      size: 24,
                    )
                  : active
                      ? Icon(
                          Icons.check_circle,
                          key: const ValueKey('on'),
                          color: cs.primary,
                          size: 24,
                        )
                      : Icon(
                          Icons.circle_outlined,
                          key: const ValueKey('off'),
                          color: cs.outlineVariant,
                          size: 24,
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
