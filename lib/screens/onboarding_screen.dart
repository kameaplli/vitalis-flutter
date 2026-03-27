import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/onboarding_provider.dart';
import '../providers/interests_provider.dart';
import '../providers/voice_locale_provider.dart';
import '../services/health_sync_service.dart';
import '../services/notification_service.dart';

const _kOnboardingCompleteKey = 'onboarding_complete';

Future<bool> isOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompleteKey) ?? false;
}

Future<void> setOnboardingComplete() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingCompleteKey, true);
}

// ── Brand palette (app icon: pink → orange → purple gradient) ────────────────
const _pink       = Color(0xFFE91E63);
const _pinkDark   = Color(0xFF880E4F);
// Page-specific accent gradients
const _pageGradients = <List<Color>>[
  [Color(0xFF880E4F), Color(0xFFE91E63), Color(0xFFFF6090)], // Welcome
  [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFAB47BC)], // Problem areas
  [Color(0xFFBF360C), Color(0xFFFF6D00), Color(0xFFFF9E40)], // Triggers
  [Color(0xFF880E4F), Color(0xFFD81B60), Color(0xFFFF6090)], // Location
  [Color(0xFF4A148C), Color(0xFF7B1FA2), Color(0xFFCE93D8)], // Reminders
  [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF4DB6AC)], // Connect devices
  [Color(0xFFBF360C), Color(0xFFFF6D00), Color(0xFFFFAB40)], // Voice locale
  [Color(0xFF880E4F), Color(0xFFE91E63), Color(0xFFFF6090)], // Ready
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final _pageCtrl = PageController();
  int _page = 0;

  // Whether eczema interest is selected — determines which pages to show
  late final bool _showEczema;
  int get _totalPages => _showEczema ? 8 : 6; // +1 for voice locale, +1 for devices page

  // Swipe-up dismiss state
  double _dismissDy = 0;
  bool _dismissing = false;

  // Staggered entry animation
  late final AnimationController _entryCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;

  // Floating orbs animation
  late final AnimationController _orbCtrl;

  // User selections
  final Set<String> _problemAreas = {};
  final Set<String> _knownTriggers = {};
  bool _locationEnabled = false;
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 18, minute: 30);
  bool _hydrationReminders = true;
  bool _mealReminders = true;

  static const _areas = [
    'Face', 'Neck', 'Arms', 'Hands', 'Legs', 'Feet', 'Torso', 'Back', 'Scalp',
  ];
  static const _triggers = [
    'Dairy', 'Eggs', 'Nuts', 'Wheat', 'Soy', 'Citrus', 'Shellfish', 'None / Unsure',
  ];

  @override
  void initState() {
    super.initState();
    _showEczema = ref.read(userInterestsProvider).contains('eczema');

    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fadeIn = CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _slideUp = Tween(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _entryCtrl, curve: const Interval(0.1, 0.7, curve: Curves.easeOutCubic)));

    _orbCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    _entryCtrl.forward();

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(statusBarColor: Colors.transparent, statusBarIconBrightness: Brightness.light),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _entryCtrl.dispose();
    _orbCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _totalPages - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    } else {
      _finish();
    }
  }

  void _prev() {
    if (_page > 0) {
      _pageCtrl.previousPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOutCubic);
    }
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    _entryCtrl.reset();
    _entryCtrl.forward();
  }

  // ── Swipe-up dismiss ───────────────────────────────────────────────────────
  void _onVerticalDragUpdate(DragUpdateDetails d) {
    if (_dismissing) return;
    setState(() => _dismissDy = (_dismissDy + d.delta.dy).clamp(-double.infinity, 0));
  }

  void _onVerticalDragEnd(DragEndDetails d) {
    if (_dismissing) return;
    final h = MediaQuery.of(context).size.height;
    final velocity = d.primaryVelocity ?? 0;
    // Light swipe: 12% of screen height OR gentle flick (300 px/s)
    if (_dismissDy < -h * 0.12 || velocity < -300) {
      _dismiss();
    } else {
      // Spring back smoothly instead of snapping
      _springBack();
    }
  }

  void _springBack() {
    final start = _dismissDy;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 200));
    final anim = Tween(begin: start, end: 0.0)
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeOutCubic));
    anim.addListener(() => setState(() => _dismissDy = anim.value));
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) ctrl.dispose();
    });
    ctrl.forward();
  }

  void _dismiss() {
    setState(() => _dismissing = true);
    final h = MediaQuery.of(context).size.height;
    final start = _dismissDy;
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    final anim = Tween(begin: start, end: -h.toDouble())
        .animate(CurvedAnimation(parent: ctrl, curve: Curves.easeInCubic));
    anim.addListener(() => setState(() => _dismissDy = anim.value));
    ctrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        ctrl.dispose();
        _finish();
      }
    });
    ctrl.forward();
  }

  Future<void> _finish() async {
    await setOnboardingComplete();
    ref.read(onboardingCompleteProvider.notifier).state = true;
    try {
      await NotificationPrefs.setMealsEnabled(_mealReminders);
      await NotificationPrefs.setHydrationEnabled(_hydrationReminders);
      await NotificationPrefs.setBreakfastTime(
          NotificationPrefs.formatTime(_breakfastTime.hour, _breakfastTime.minute));
      await NotificationPrefs.setLunchTime(
          NotificationPrefs.formatTime(_lunchTime.hour, _lunchTime.minute));
      await NotificationPrefs.setDinnerTime(
          NotificationPrefs.formatTime(_dinnerTime.hour, _dinnerTime.minute));
      await NotificationService.scheduleAll();
    } catch (_) {}
    if (mounted) context.go('/dashboard');
  }

  // ── Gradient sets for dynamic pages ──────────────────────────────────────
  List<List<Color>> get _activeGradients {
    if (_showEczema) return _pageGradients;
    // Without eczema pages: Welcome, Location, Reminders, Devices, Voice, Ready
    return [
      _pageGradients[0], // Welcome
      _pageGradients[3], // Location
      _pageGradients[4], // Reminders
      _pageGradients[5], // Connect devices
      _pageGradients[6], // Voice locale
      _pageGradients[7], // Ready
    ];
  }

  // ── Interpolated gradient background ───────────────────────────────────────
  List<Color> _currentGradient() {
    final grads = _activeGradients;
    final page = _pageCtrl.hasClients ? (_pageCtrl.page ?? 0.0) : 0.0;
    final i = page.floor().clamp(0, grads.length - 2);
    final t = page - i;
    return List.generate(3, (c) => Color.lerp(grads[i][c], grads[i + 1][c], t)!);
  }

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    final dismissProgress = (_dismissDy / -screenH).clamp(0.0, 1.0);
    final scale = 1.0 - dismissProgress * 0.12;
    final opacity = 1.0 - dismissProgress;
    final radius = dismissProgress * 32;

    return AnimatedBuilder(
      animation: _pageCtrl,
      builder: (context, _) {
        final grad = _currentGradient();
        return Scaffold(
          body: GestureDetector(
            onVerticalDragUpdate: _onVerticalDragUpdate,
            onVerticalDragEnd: _onVerticalDragEnd,
            child: Transform.translate(
              offset: Offset(0, _dismissDy),
              child: Transform.scale(
                scale: scale,
                child: Opacity(
                  opacity: opacity.clamp(0.0, 1.0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(radius),
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: grad,
                        ),
                      ),
                      child: SafeArea(
                        child: Stack(
                          children: [
                            // Floating orbs
                            _FloatingOrbs(animation: _orbCtrl),
                            // Content
                            Column(
                              children: [
                                const SizedBox(height: 8),
                                // Swipe hint
                                Center(
                                  child: AnimatedOpacity(
                                    opacity: _page == 0 ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 300),
                                    child: Column(
                                      children: [
                                        Icon(Icons.keyboard_arrow_up,
                                            color: Colors.white.withValues(alpha: 0.6), size: 20),
                                        Text('Swipe up to skip',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.white.withValues(alpha: 0.4),
                                                letterSpacing: 0.5)),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Progress bar
                                _ProgressBar(page: _page, total: _totalPages),
                                const SizedBox(height: 8),
                                // Pages
                                Expanded(
                                  child: FadeTransition(
                                    opacity: _fadeIn,
                                    child: SlideTransition(
                                      position: _slideUp,
                                      child: PageView(
                                        controller: _pageCtrl,
                                        onPageChanged: _onPageChanged,
                                        physics: const BouncingScrollPhysics(),
                                        children: [
                                          _WelcomePage(orbCtrl: _orbCtrl),
                                          if (_showEczema) ...[
                                            _ProblemAreasPage(
                                              areas: _areas,
                                              selected: _problemAreas,
                                              onToggle: (a) => setState(() {
                                                _problemAreas.contains(a)
                                                    ? _problemAreas.remove(a)
                                                    : _problemAreas.add(a);
                                              }),
                                            ),
                                            _TriggersPage(
                                              triggers: _triggers,
                                              selected: _knownTriggers,
                                              onToggle: (t) => setState(() {
                                                _knownTriggers.contains(t)
                                                    ? _knownTriggers.remove(t)
                                                    : _knownTriggers.add(t);
                                              }),
                                            ),
                                          ],
                                          _LocationPage(
                                            enabled: _locationEnabled,
                                            onChanged: (v) => setState(() => _locationEnabled = v),
                                          ),
                                          _MealTimesPage(
                                            breakfastTime: _breakfastTime,
                                            lunchTime: _lunchTime,
                                            dinnerTime: _dinnerTime,
                                            hydrationEnabled: _hydrationReminders,
                                            mealsEnabled: _mealReminders,
                                            onBreakfastChanged: (t) => setState(() => _breakfastTime = t),
                                            onLunchChanged: (t) => setState(() => _lunchTime = t),
                                            onDinnerChanged: (t) => setState(() => _dinnerTime = t),
                                            onHydrationChanged: (v) => setState(() => _hydrationReminders = v),
                                            onMealsChanged: (v) => setState(() => _mealReminders = v),
                                          ),
                                          const _ConnectDevicesPage(),
                                          const _VoiceLocalePage(),
                                          _ReadyPage(orbCtrl: _orbCtrl),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                // Navigation buttons
                                _NavButtons(
                                  page: _page,
                                  totalPages: _totalPages,
                                  onNext: _next,
                                  onPrev: _prev,
                                  onSkip: _finish,
                                ),
                                SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Progress bar ─────────────────────────────────────────────────────────────
class _ProgressBar extends StatelessWidget {
  final int page;
  final int total;
  const _ProgressBar({required this.page, required this.total});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Row(
        children: List.generate(total, (i) {
          final active = i <= page;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeOutCubic,
              height: 3,
              margin: const EdgeInsets.symmetric(horizontal: 2.5),
              decoration: BoxDecoration(
                color: active ? Colors.white : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ── Navigation buttons ───────────────────────────────────────────────────────
class _NavButtons extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback onNext;
  final VoidCallback onPrev;
  final VoidCallback onSkip;
  const _NavButtons({
    required this.page, required this.totalPages,
    required this.onNext, required this.onPrev, required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = page == totalPages - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: Row(
        children: [
          if (page > 0)
            _GlassButton(label: 'Back', onTap: onPrev, outlined: true)
          else
            _GlassButton(label: 'Skip', onTap: onSkip, outlined: true),
          const Spacer(),
          _GlassButton(label: isLast ? "Let's Go!" : 'Next', onTap: onNext, outlined: false),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool outlined;
  const _GlassButton({required this.label, required this.onTap, required this.outlined});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
        decoration: BoxDecoration(
          color: outlined ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: outlined ? Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1) : null,
          boxShadow: outlined
              ? null
              : [BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: outlined ? Colors.white : _pinkDark,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}

// ── Floating orbs background ─────────────────────────────────────────────────
class _FloatingOrbs extends StatelessWidget {
  final AnimationController animation;
  const _FloatingOrbs({required this.animation});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: MediaQuery.of(context).size,
          painter: _OrbsPainter(animation.value),
        );
      },
    );
  }
}

class _OrbsPainter extends CustomPainter {
  final double t;
  _OrbsPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final orbs = [
      _Orb(0.12, 0.18, 65, Colors.white.withValues(alpha: 0.05), 1.0),
      _Orb(0.85, 0.25, 90, Colors.white.withValues(alpha: 0.04), 0.7),
      _Orb(0.5, 0.75, 110, Colors.white.withValues(alpha: 0.03), 1.3),
      _Orb(0.2, 0.6, 50, Colors.white.withValues(alpha: 0.06), 0.9),
      _Orb(0.75, 0.85, 70, Colors.white.withValues(alpha: 0.04), 1.1),
    ];
    for (final orb in orbs) {
      final dx = math.sin(t * 2 * math.pi * orb.speed) * 20;
      final dy = math.cos(t * 2 * math.pi * orb.speed * 0.7) * 15;
      final center = Offset(orb.x * size.width + dx, orb.y * size.height + dy);
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [orb.color, orb.color.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: center, radius: orb.radius));
      canvas.drawCircle(center, orb.radius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbsPainter old) => true;
}

class _Orb {
  final double x, y, radius, speed;
  final Color color;
  const _Orb(this.x, this.y, this.radius, this.color, this.speed);
}

// ── Glassmorphic card ────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  const _GlassCard({required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: child,
    );
  }
}

// ── PAGE 0: Welcome ──────────────────────────────────────────────────────────
class _WelcomePage extends StatelessWidget {
  final AnimationController orbCtrl;
  const _WelcomePage({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated logo
          AnimatedBuilder(
            animation: orbCtrl,
            builder: (context, child) {
              final pulse = 1.0 + math.sin(orbCtrl.value * 2 * math.pi * 0.5) * 0.04;
              return Transform.scale(scale: pulse, child: child);
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFFF6D00), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: _pink.withValues(alpha: 0.4), blurRadius: 40, spreadRadius: 8),
                ],
              ),
              child: const Center(
                child: Icon(Icons.favorite_rounded, size: 54, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 40),
          const Text(
            'QoreHealth',
            style: TextStyle(
              fontSize: 38, fontWeight: FontWeight.w700, color: Colors.white,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personal health intelligence',
            style: TextStyle(
              fontSize: 16, color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w300, letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 48),
          const _GlassCard(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              children: [
                _FeatureRow(icon: Icons.track_changes, text: 'Track triggers with precision'),
                SizedBox(height: 14),
                _FeatureRow(icon: Icons.insights, text: 'AI-powered health insights'),
                SizedBox(height: 14),
                _FeatureRow(icon: Icons.family_restroom, text: 'Family health dashboard'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(text, style: TextStyle(
            fontSize: 14, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w500,
          )),
        ),
      ],
    );
  }
}

// ── Shared page header ───────────────────────────────────────────────────────
class _PageHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _PageHeader({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64, height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(icon, color: Colors.white, size: 30),
        ),
        const SizedBox(height: 20),
        Text(title, style: const TextStyle(
          fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white,
        ), textAlign: TextAlign.center),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(subtitle, style: TextStyle(
            fontSize: 14, color: Colors.white.withValues(alpha: 0.65),
            fontWeight: FontWeight.w400, height: 1.4,
          ), textAlign: TextAlign.center),
        ),
      ],
    );
  }
}

// ── PAGE 1: Problem areas ────────────────────────────────────────────────────
class _ProblemAreasPage extends StatelessWidget {
  final List<String> areas;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _ProblemAreasPage({required this.areas, required this.selected, required this.onToggle});

  static const _areaIcons = {
    'Face': Icons.face, 'Neck': Icons.height, 'Arms': Icons.back_hand_outlined,
    'Hands': Icons.pan_tool_outlined, 'Legs': Icons.directions_walk,
    'Feet': Icons.do_not_step, 'Torso': Icons.accessibility_new,
    'Back': Icons.airline_seat_flat, 'Scalp': Icons.self_improvement,
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const _PageHeader(
            icon: Icons.accessibility_new,
            title: 'Problem areas',
            subtitle: 'Tap all areas where you experience symptoms',
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: areas.map((a) {
              final active = selected.contains(a);
              return GestureDetector(
                onTap: () => onToggle(a),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_areaIcons[a] ?? Icons.circle, size: 18,
                          color: active ? Colors.white : Colors.white.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Text(a, style: TextStyle(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── PAGE 2: Triggers ─────────────────────────────────────────────────────────
class _TriggersPage extends StatelessWidget {
  final List<String> triggers;
  final Set<String> selected;
  final void Function(String) onToggle;
  const _TriggersPage({required this.triggers, required this.selected, required this.onToggle});

  static const _triggerEmojis = {
    'Dairy': '🥛', 'Eggs': '🥚', 'Nuts': '🥜', 'Wheat': '🌾',
    'Soy': '🫘', 'Citrus': '🍊', 'Shellfish': '🦐', 'None / Unsure': '🤷',
  };

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const _PageHeader(
            icon: Icons.restaurant,
            title: 'Known food triggers',
            subtitle: "Select any you've noticed, or 'None / Unsure'",
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: triggers.map((t) {
              final active = selected.contains(t);
              return GestureDetector(
                onTap: () => onToggle(t),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: active ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: active ? Colors.white.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.12),
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_triggerEmojis[t] ?? '?', style: const TextStyle(fontSize: 18)),
                      const SizedBox(width: 8),
                      Text(t, style: TextStyle(
                        color: active ? Colors.white : Colors.white.withValues(alpha: 0.6),
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        fontSize: 14,
                      )),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── PAGE 3: Location ─────────────────────────────────────────────────────────
class _LocationPage extends StatelessWidget {
  final bool enabled;
  final void Function(bool) onChanged;
  const _LocationPage({required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const _PageHeader(
            icon: Icons.cloud,
            title: 'Weather tracking',
            subtitle: 'Automatically track weather, humidity and air quality alongside your logs',
          ),
          const SizedBox(height: 36),
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: Colors.white.withValues(alpha: 0.8), size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        enabled ? 'Weather tracking enabled' : 'Enable weather tracking',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9), fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Switch.adaptive(
                      value: enabled,
                      onChanged: onChanged,
                      activeColor: Colors.white,
                      activeTrackColor: Colors.white.withValues(alpha: 0.35),
                      inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
                      inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
                    ),
                  ],
                ),
                if (enabled) ...[
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      _WeatherChip(icon: Icons.thermostat, label: 'Temperature'),
                      SizedBox(width: 8),
                      _WeatherChip(icon: Icons.water_drop, label: 'Humidity'),
                      SizedBox(width: 8),
                      _WeatherChip(icon: Icons.air, label: 'AQI'),
                    ],
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'No extra work from you — it happens automatically',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.45)),
          ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _WeatherChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 18),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.6))),
          ],
        ),
      ),
    );
  }
}

// ── PAGE 4: Meal times ───────────────────────────────────────────────────────
class _MealTimesPage extends StatelessWidget {
  final TimeOfDay breakfastTime, lunchTime, dinnerTime;
  final bool hydrationEnabled, mealsEnabled;
  final ValueChanged<TimeOfDay> onBreakfastChanged, onLunchChanged, onDinnerChanged;
  final ValueChanged<bool> onHydrationChanged, onMealsChanged;

  const _MealTimesPage({
    required this.breakfastTime, required this.lunchTime, required this.dinnerTime,
    required this.hydrationEnabled, required this.mealsEnabled,
    required this.onBreakfastChanged, required this.onLunchChanged, required this.onDinnerChanged,
    required this.onHydrationChanged, required this.onMealsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 24),
          const _PageHeader(
            icon: Icons.notifications_active,
            title: 'Reminders',
            subtitle: "We'll nudge you at the right times. You can change these anytime.",
          ),
          const SizedBox(height: 24),
          _GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _GlassToggle(
                  icon: Icons.restaurant,
                  label: 'Meal reminders',
                  value: mealsEnabled,
                  onChanged: onMealsChanged,
                ),
                if (mealsEnabled) ...[
                  const SizedBox(height: 12),
                  _MealTimeRow(emoji: '🌅', label: 'Breakfast', time: breakfastTime,
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: breakfastTime);
                        if (t != null) onBreakfastChanged(t);
                      }),
                  _MealTimeRow(emoji: '☀️', label: 'Lunch', time: lunchTime,
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: lunchTime);
                        if (t != null) onLunchChanged(t);
                      }),
                  _MealTimeRow(emoji: '🌙', label: 'Dinner', time: dinnerTime,
                      onTap: () async {
                        final t = await showTimePicker(context: context, initialTime: dinnerTime);
                        if (t != null) onDinnerChanged(t);
                      }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _GlassCard(
            padding: const EdgeInsets.all(16),
            child: _GlassToggle(
              icon: Icons.water_drop,
              label: 'Hydration reminders',
              subtitle: 'Every 90 min during the day',
              value: hydrationEnabled,
              onChanged: onHydrationChanged,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _GlassToggle extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _GlassToggle({required this.icon, required this.label, this.subtitle,
    required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.7), size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 14, fontWeight: FontWeight.w500)),
              if (subtitle != null)
                Text(subtitle!, style: TextStyle(color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 12)),
            ],
          ),
        ),
        Switch.adaptive(
          value: value, onChanged: onChanged,
          activeColor: Colors.white,
          activeTrackColor: Colors.white.withValues(alpha: 0.35),
          inactiveThumbColor: Colors.white.withValues(alpha: 0.5),
          inactiveTrackColor: Colors.white.withValues(alpha: 0.1),
        ),
      ],
    );
  }
}

class _MealTimeRow extends StatelessWidget {
  final String emoji, label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _MealTimeRow({required this.emoji, required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const SizedBox(width: 34),
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7), fontSize: 14,
          ))),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$h:$m', style: const TextStyle(
                color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600,
              )),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PAGE: Voice Language ──────────────────────────────────────────────────────
// ── PAGE: Connect Devices ────────────────────────────────────────────────────
class _ConnectDevicesPage extends StatefulWidget {
  const _ConnectDevicesPage();

  @override
  State<_ConnectDevicesPage> createState() => _ConnectDevicesPageState();
}

class _ConnectDevicesPageState extends State<_ConnectDevicesPage> {
  bool _connecting = false;
  bool _connected = false;
  bool _denied = false;

  Future<void> _connectHealth() async {
    if (_connecting || _connected) return;

    if (!HealthSyncService.isAvailable) {
      if (mounted) {
        setState(() => _denied = true);
      }
      return;
    }

    setState(() {
      _connecting = true;
      _denied = false;
    });

    try {
      final granted = await HealthSyncService.requestPermissions();
      if (!mounted) return;
      if (granted) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('health_sync_connected', true);
        await prefs.setBool('health_sync_auto', true);
        if (mounted) {
          setState(() {
            _connected = true;
            _connecting = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _denied = true;
            _connecting = false;
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => _connecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSupported = HealthSyncService.isAvailable;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.watch_rounded, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          const Text(
            'Connect Your Devices',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sync data from your wearables and health apps '
            'for a complete health picture.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          // Connect button or status
          Center(
            child: _connected
                ? _GlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                          child: const Icon(Icons.check_rounded,
                              size: 32, color: Colors.white),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Health data connected!',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Your data will sync automatically.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Illustration
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.15),
                        ),
                        child: Icon(
                          isSupported
                              ? Icons.watch_rounded
                              : Icons.phone_android_rounded,
                          size: 48,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (isSupported) ...[
                        SizedBox(
                          width: double.infinity,
                          child: Material(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: _connecting ? null : _connectHealth,
                              borderRadius: BorderRadius.circular(14),
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: _connecting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2),
                                        )
                                      : Text(
                                          HealthSyncService.isAvailable
                                              ? 'Connect Health Data'
                                              : 'Connect',
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF00695C),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (_denied) ...[
                          const SizedBox(height: 12),
                          Text(
                            'Permission denied. You can enable it later in Settings.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.6),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ] else ...[
                        Text(
                          'Health sync is available on iOS and Android devices.\n'
                          'You can connect devices later from Settings.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.7),
                            height: 1.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],

                      const SizedBox(height: 20),
                      // Features list
                      const _GlassCard(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          children: [
                            _DeviceFeatureRow(
                              icon: Icons.favorite_rounded,
                              text: 'Heart rate & HRV',
                            ),
                            SizedBox(height: 10),
                            _DeviceFeatureRow(
                              icon: Icons.directions_walk_rounded,
                              text: 'Steps & distance',
                            ),
                            SizedBox(height: 10),
                            _DeviceFeatureRow(
                              icon: Icons.bedtime_rounded,
                              text: 'Sleep tracking',
                            ),
                            SizedBox(height: 10),
                            _DeviceFeatureRow(
                              icon: Icons.fitness_center_rounded,
                              text: 'Workouts & calories',
                            ),
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

class _DeviceFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _DeviceFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.8), size: 18),
        const SizedBox(width: 10),
        Text(
          text,
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withValues(alpha: 0.8),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _VoiceLocalePage extends ConsumerWidget {
  const _VoiceLocalePage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentLocale = ref.watch(voiceLocaleProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.mic, size: 48, color: Colors.white),
          const SizedBox(height: 16),
          const Text('Voice Language',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900,
                  color: Colors.white, letterSpacing: -0.5)),
          const SizedBox(height: 8),
          Text(
            'Choose your preferred language for voice meal logging. '
            'This helps the app understand your accent and food names better.',
            style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.8),
                height: 1.5),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: ListView(
              children: voiceLocaleOptions.entries.map((entry) {
                final isSelected = currentLocale == entry.key;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.25)
                        : Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      onTap: () => ref.read(voiceLocaleProvider.notifier).setLocale(entry.key),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Text(entry.value,
                                style: TextStyle(
                                  fontSize: 15, fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                  color: Colors.white,
                                )),
                            const Spacer(),
                            if (isSelected)
                              const Icon(Icons.check_circle, color: Colors.white, size: 22),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

// ── PAGE: Ready ──────────────────────────────────────────────────────────────
class _ReadyPage extends StatelessWidget {
  final AnimationController orbCtrl;
  const _ReadyPage({required this.orbCtrl});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated checkmark
          AnimatedBuilder(
            animation: orbCtrl,
            builder: (context, child) {
              final pulse = 1.0 + math.sin(orbCtrl.value * 2 * math.pi * 0.8) * 0.05;
              return Transform.scale(scale: pulse, child: child);
            },
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE91E63), Color(0xFFFF6D00), Color(0xFF7B1FA2)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(color: _pink.withValues(alpha: 0.4),
                      blurRadius: 30, spreadRadius: 5),
                ],
              ),
              child: const Icon(Icons.check_rounded, size: 50, color: Colors.white),
            ),
          ),
          const SizedBox(height: 36),
          const Text(
            "You're all set!",
            style: TextStyle(
              fontSize: 32, fontWeight: FontWeight.w700, color: Colors.white,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Start logging to unlock personalized health insights.\nThe more data you provide, the smarter QoreHealth gets.',
            style: TextStyle(
              fontSize: 15, color: Colors.white.withValues(alpha: 0.65),
              fontWeight: FontWeight.w400, height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.amber.shade300, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Tip: Log meals, symptoms, and sleep daily for the best insights',
                    style: TextStyle(
                      fontSize: 13, color: Colors.white.withValues(alpha: 0.75),
                      fontWeight: FontWeight.w400, height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'This app is for informational purposes only and does not provide medical advice. '
              'Always consult a qualified healthcare provider before making dietary or health changes.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
