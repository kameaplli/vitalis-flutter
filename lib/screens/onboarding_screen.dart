import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/router.dart';
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

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _totalPages = 6;

  // User selections
  final Set<String> _problemAreas = {};
  final Set<String> _knownTriggers = {};
  bool _locationEnabled = false;

  // Meal time preferences
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

  void _next() {
    if (_page < _totalPages - 1) {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    // Save notification preferences from onboarding
    await NotificationPrefs.setMealsEnabled(_mealReminders);
    await NotificationPrefs.setHydrationEnabled(_hydrationReminders);
    await NotificationPrefs.setBreakfastTime(
        NotificationPrefs.formatTime(_breakfastTime.hour, _breakfastTime.minute));
    await NotificationPrefs.setLunchTime(
        NotificationPrefs.formatTime(_lunchTime.hour, _lunchTime.minute));
    await NotificationPrefs.setDinnerTime(
        NotificationPrefs.formatTime(_dinnerTime.hour, _dinnerTime.minute));

    // Schedule notifications with user's chosen times
    await NotificationService.scheduleAll();

    await setOnboardingComplete();
    ref.read(onboardingCompleteProvider.notifier).state = true;
    if (mounted) context.go('/dashboard');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Progress dots
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_totalPages, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: i == _page ? 24 : 8,
                  height: 8,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: i <= _page ? cs.primary : cs.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                )),
              ),
            ),
            // Pages
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  _WelcomePage(cs: cs),
                  _ProblemAreasPage(
                    cs: cs,
                    areas: _areas,
                    selected: _problemAreas,
                    onToggle: (a) => setState(() {
                      _problemAreas.contains(a) ? _problemAreas.remove(a) : _problemAreas.add(a);
                    }),
                  ),
                  _TriggersPage(
                    cs: cs,
                    triggers: _triggers,
                    selected: _knownTriggers,
                    onToggle: (t) => setState(() {
                      _knownTriggers.contains(t) ? _knownTriggers.remove(t) : _knownTriggers.add(t);
                    }),
                  ),
                  _LocationPage(
                    cs: cs,
                    enabled: _locationEnabled,
                    onChanged: (v) => setState(() => _locationEnabled = v),
                  ),
                  _MealTimesPage(
                    cs: cs,
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
                  _ReadyPage(cs: cs),
                ],
              ),
            ),
            // Navigation
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _controller.previousPage(
                          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut),
                      child: const Text('Back'),
                    )
                  else
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_page == _totalPages - 1 ? "Let's Go!" : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomePage extends StatelessWidget {
  final ColorScheme cs;
  const _WelcomePage({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.spa, size: 72, color: cs.primary),
          const SizedBox(height: 24),
          Text('Welcome to Vitalis',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: cs.primary),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            'Vitalis helps you find YOUR eczema triggers using data-driven insights. '
            'The more you log, the smarter it gets.',
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _ProblemAreasPage extends StatelessWidget {
  final ColorScheme cs;
  final List<String> areas;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _ProblemAreasPage({required this.cs, required this.areas, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.accessibility_new, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          const Text('What are your problem areas?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text('Tap all that apply', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: areas.map((a) => FilterChip(
              label: Text(a),
              selected: selected.contains(a),
              onSelected: (_) => onToggle(a),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.onPrimaryContainer,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _TriggersPage extends StatelessWidget {
  final ColorScheme cs;
  final List<String> triggers;
  final Set<String> selected;
  final void Function(String) onToggle;

  const _TriggersPage({required this.cs, required this.triggers, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          const Text('Any known food triggers?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text("Select any you've noticed, or 'None / Unsure'",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: triggers.map((t) => FilterChip(
              label: Text(t),
              selected: selected.contains(t),
              onSelected: (_) => onToggle(t),
              selectedColor: cs.primaryContainer,
              checkmarkColor: cs.onPrimaryContainer,
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _LocationPage extends StatelessWidget {
  final ColorScheme cs;
  final bool enabled;
  final void Function(bool) onChanged;

  const _LocationPage({required this.cs, required this.enabled, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_on, size: 48, color: cs.primary),
          const SizedBox(height: 16),
          const Text('Enable weather tracking?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(
            'Vitalis can automatically track weather, humidity, and air quality '
            'alongside your eczema logs. No extra work from you.',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Switch.adaptive(
            value: enabled,
            onChanged: onChanged,
          ),
          Text(enabled ? 'Enabled' : 'Disabled',
              style: TextStyle(fontSize: 12, color: enabled ? cs.primary : Colors.grey)),
        ],
      ),
    );
  }
}

class _MealTimesPage extends StatelessWidget {
  final ColorScheme cs;
  final TimeOfDay breakfastTime;
  final TimeOfDay lunchTime;
  final TimeOfDay dinnerTime;
  final bool hydrationEnabled;
  final bool mealsEnabled;
  final ValueChanged<TimeOfDay> onBreakfastChanged;
  final ValueChanged<TimeOfDay> onLunchChanged;
  final ValueChanged<TimeOfDay> onDinnerChanged;
  final ValueChanged<bool> onHydrationChanged;
  final ValueChanged<bool> onMealsChanged;

  const _MealTimesPage({
    required this.cs,
    required this.breakfastTime,
    required this.lunchTime,
    required this.dinnerTime,
    required this.hydrationEnabled,
    required this.mealsEnabled,
    required this.onBreakfastChanged,
    required this.onLunchChanged,
    required this.onDinnerChanged,
    required this.onHydrationChanged,
    required this.onMealsChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.notifications_active, size: 48, color: cs.primary),
            const SizedBox(height: 16),
            const Text('Set up your reminders',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              "We'll nudge you at the right times so logging feels effortless. You can change these anytime in Settings.",
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Meal reminders toggle + times
            SwitchListTile(
              secondary: const Icon(Icons.restaurant, color: Colors.orange),
              title: const Text('Meal reminders'),
              value: mealsEnabled,
              onChanged: onMealsChanged,
              dense: true,
            ),
            if (mealsEnabled) ...[
              _OnboardingTimeTile(
                emoji: '🌅',
                label: 'Breakfast',
                time: breakfastTime,
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: breakfastTime);
                  if (t != null) onBreakfastChanged(t);
                },
              ),
              _OnboardingTimeTile(
                emoji: '☀️',
                label: 'Lunch',
                time: lunchTime,
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: lunchTime);
                  if (t != null) onLunchChanged(t);
                },
              ),
              _OnboardingTimeTile(
                emoji: '🌙',
                label: 'Dinner',
                time: dinnerTime,
                onTap: () async {
                  final t = await showTimePicker(context: context, initialTime: dinnerTime);
                  if (t != null) onDinnerChanged(t);
                },
              ),
            ],
            const SizedBox(height: 8),

            // Hydration reminders toggle
            SwitchListTile(
              secondary: const Icon(Icons.water_drop, color: Colors.blue),
              title: const Text('Hydration reminders'),
              subtitle: const Text('Every 90 min during the day'),
              value: hydrationEnabled,
              onChanged: onHydrationChanged,
              dense: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingTimeTile extends StatelessWidget {
  final String emoji;
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _OnboardingTimeTile({required this.emoji, required this.label, required this.time, required this.onTap});

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    leading: Text(emoji, style: const TextStyle(fontSize: 20)),
    title: Text(label),
    trailing: TextButton(
      onPressed: onTap,
      child: Text(_fmt(time), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
    ),
  );
}

class _ReadyPage extends StatelessWidget {
  final ColorScheme cs;
  const _ReadyPage({required this.cs});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle, size: 72, color: cs.primary),
          const SizedBox(height: 24),
          const Text("You're all set!",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(
            "Let's log your first entry. The more data you provide, "
            "the better Vitalis can identify your personal triggers.",
            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
