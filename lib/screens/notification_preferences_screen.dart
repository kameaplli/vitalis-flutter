import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/notification_service.dart';

class NotificationPreferencesScreen extends StatefulWidget {
  const NotificationPreferencesScreen({super.key});
  @override
  State<NotificationPreferencesScreen> createState() => _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState extends State<NotificationPreferencesScreen> {
  bool _hydrationEnabled = true;
  TimeOfDay _hydrationStart = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _hydrationEnd = const TimeOfDay(hour: 21, minute: 0);
  int _hydrationInterval = 60;

  bool _mealsEnabled = true;
  TimeOfDay _breakfastTime = const TimeOfDay(hour: 8, minute: 0);
  TimeOfDay _lunchTime = const TimeOfDay(hour: 12, minute: 30);
  TimeOfDay _dinnerTime = const TimeOfDay(hour: 18, minute: 30);
  TimeOfDay _snackTime = const TimeOfDay(hour: 15, minute: 0);
  bool _snackEnabled = false;

  bool _eczemaEnabled = true;
  double _eczemaThreshold = 0.7;

  bool _smartEnabled = true;
  bool _supplementsEnabled = true;
  List<Map<String, dynamic>> _supplementReminders = [];

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    _hydrationEnabled = await NotificationPrefs.hydrationEnabled();
    _hydrationInterval = await NotificationPrefs.hydrationInterval();

    var t = await NotificationPrefs.hydrationStart();
    var (h, m) = NotificationPrefs.parseTime(t);
    _hydrationStart = TimeOfDay(hour: h, minute: m);

    t = await NotificationPrefs.hydrationEnd();
    (h, m) = NotificationPrefs.parseTime(t);
    _hydrationEnd = TimeOfDay(hour: h, minute: m);

    _mealsEnabled = await NotificationPrefs.mealsEnabled();
    t = await NotificationPrefs.breakfastTime();
    (h, m) = NotificationPrefs.parseTime(t);
    _breakfastTime = TimeOfDay(hour: h, minute: m);

    t = await NotificationPrefs.lunchTime();
    (h, m) = NotificationPrefs.parseTime(t);
    _lunchTime = TimeOfDay(hour: h, minute: m);

    t = await NotificationPrefs.dinnerTime();
    (h, m) = NotificationPrefs.parseTime(t);
    _dinnerTime = TimeOfDay(hour: h, minute: m);

    t = await NotificationPrefs.snackTime();
    (h, m) = NotificationPrefs.parseTime(t);
    _snackTime = TimeOfDay(hour: h, minute: m);

    _snackEnabled = await NotificationPrefs.snackEnabled();
    _eczemaEnabled = await NotificationPrefs.eczemaEnabled();
    _eczemaThreshold = await NotificationPrefs.eczemaThreshold();
    _smartEnabled = await NotificationPrefs.smartEnabled();
    _supplementsEnabled = await NotificationPrefs.supplementsEnabled();
    _supplementReminders = await NotificationPrefs.supplementReminders();

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    try {
      await NotificationPrefs.setHydrationEnabled(_hydrationEnabled);
      await NotificationPrefs.setHydrationStart(
          NotificationPrefs.formatTime(_hydrationStart.hour, _hydrationStart.minute));
      await NotificationPrefs.setHydrationEnd(
          NotificationPrefs.formatTime(_hydrationEnd.hour, _hydrationEnd.minute));
      await NotificationPrefs.setHydrationInterval(_hydrationInterval);

      await NotificationPrefs.setMealsEnabled(_mealsEnabled);
      await NotificationPrefs.setBreakfastTime(
          NotificationPrefs.formatTime(_breakfastTime.hour, _breakfastTime.minute));
      await NotificationPrefs.setLunchTime(
          NotificationPrefs.formatTime(_lunchTime.hour, _lunchTime.minute));
      await NotificationPrefs.setDinnerTime(
          NotificationPrefs.formatTime(_dinnerTime.hour, _dinnerTime.minute));
      await NotificationPrefs.setSnackTime(
          NotificationPrefs.formatTime(_snackTime.hour, _snackTime.minute));
      await NotificationPrefs.setSnackEnabled(_snackEnabled);

      await NotificationPrefs.setEczemaEnabled(_eczemaEnabled);
      await NotificationPrefs.setEczemaThreshold(_eczemaThreshold);
      await NotificationPrefs.setSmartEnabled(_smartEnabled);
      await NotificationPrefs.setSupplementsEnabled(_supplementsEnabled);
      await NotificationPrefs.setSupplementReminders(_supplementReminders);

      try {
        await NotificationService.scheduleAll();
      } catch (_) {
        // Scheduling may fail on some devices — don't block save+navigate
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save preferences. Please try again.')),
        );
      }
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Notification preferences saved!'), duration: Duration(seconds: 1)),
    );
    context.go('/profile');
  }

  Future<TimeOfDay?> _pickTime(TimeOfDay initial) {
    return showTimePicker(context: context, initialTime: initial);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Hydration ──────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.water_drop, title: 'Hydration Reminders', color: Colors.blue),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable hydration reminders'),
            subtitle: Text(_hydrationEnabled
                ? 'Every $_hydrationInterval min, ${_fmt(_hydrationStart)} – ${_fmt(_hydrationEnd)}'
                : 'Disabled'),
            value: _hydrationEnabled,
            onChanged: (v) => setState(() => _hydrationEnabled = v),
          ),
          if (_hydrationEnabled) ...[
            _TimeTile(
              label: 'Start time',
              time: _hydrationStart,
              onTap: () async {
                final t = await _pickTime(_hydrationStart);
                if (t != null) setState(() => _hydrationStart = t);
              },
            ),
            _TimeTile(
              label: 'End time',
              time: _hydrationEnd,
              onTap: () async {
                final t = await _pickTime(_hydrationEnd);
                if (t != null) setState(() => _hydrationEnd = t);
              },
            ),
            ListTile(
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Reminder interval'),
              trailing: DropdownButton<int>(
                value: _hydrationInterval,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 30, child: Text('30 min')),
                  DropdownMenuItem(value: 45, child: Text('45 min')),
                  DropdownMenuItem(value: 60, child: Text('1 hour')),
                  DropdownMenuItem(value: 90, child: Text('1.5 hours')),
                  DropdownMenuItem(value: 120, child: Text('2 hours')),
                ],
                onChanged: (v) { if (v != null) setState(() => _hydrationInterval = v); },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Tap 250ml or 500ml directly from the notification to log without opening the app.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),
          ],

          const Divider(height: 32),

          // ── Meals ──────────────────────────────────────────────────────────
          _SectionHeader(icon: Icons.restaurant, title: 'Meal Reminders', color: Colors.orange),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable meal reminders'),
            subtitle: const Text('Daily reminders at your meal times'),
            value: _mealsEnabled,
            onChanged: (v) => setState(() => _mealsEnabled = v),
          ),
          if (_mealsEnabled) ...[
            _TimeTile(
              label: 'Breakfast',
              time: _breakfastTime,
              onTap: () async {
                final t = await _pickTime(_breakfastTime);
                if (t != null) setState(() => _breakfastTime = t);
              },
            ),
            _TimeTile(
              label: 'Lunch',
              time: _lunchTime,
              onTap: () async {
                final t = await _pickTime(_lunchTime);
                if (t != null) setState(() => _lunchTime = t);
              },
            ),
            _TimeTile(
              label: 'Dinner',
              time: _dinnerTime,
              onTap: () async {
                final t = await _pickTime(_dinnerTime);
                if (t != null) setState(() => _dinnerTime = t);
              },
            ),
            SwitchListTile(
              title: const Text('Snack reminder'),
              value: _snackEnabled,
              onChanged: (v) => setState(() => _snackEnabled = v),
            ),
            if (_snackEnabled)
              _TimeTile(
                label: 'Snack',
                time: _snackTime,
                onTap: () async {
                  final t = await _pickTime(_snackTime);
                  if (t != null) setState(() => _snackTime = t);
                },
              ),
          ],

          if (_mealsEnabled)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'A gentle reminder is also sent 30 minutes after each meal time if not logged.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),

          const Divider(height: 32),

          // ── Supplement Reminders ───────────────────────────────────────────
          _SectionHeader(icon: Icons.spa, title: 'Supplement Reminders', color: Colors.amber.shade700),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable supplement reminders'),
            subtitle: Text(_supplementsEnabled
                ? '${_supplementReminders.length} supplement reminder(s) configured'
                : 'Disabled'),
            value: _supplementsEnabled,
            onChanged: (v) => setState(() => _supplementsEnabled = v),
          ),
          if (_supplementsEnabled && _supplementReminders.isNotEmpty)
            ..._supplementReminders.asMap().entries.map((entry) {
              final i = entry.key;
              final r = entry.value;
              final name = r['name'] as String? ?? 'Supplement';
              final time = r['time'] as String? ?? '09:00';
              final endDate = r['end_date'] as String?;
              return ListTile(
                leading: Icon(Icons.spa_outlined, color: Colors.amber.shade600),
                title: Text(name),
                subtitle: Text([
                  'Daily at $time',
                  if (endDate != null) 'Until $endDate',
                ].join(' · ')),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                  onPressed: () {
                    setState(() => _supplementReminders.removeAt(i));
                  },
                ),
              );
            }),
          if (_supplementsEnabled && _supplementReminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Add supplement reminders from the Supplements page when adding or editing a supplement.',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
              ),
            ),

          const Divider(height: 32),

          // ── Eczema Alerts ──────────────────────────────────────────────────
          _SectionHeader(icon: Icons.warning_amber, title: 'Eczema & Weather Alerts', color: Colors.red),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable flare-risk alerts'),
            subtitle: const Text('Get notified when weather may trigger flare-ups'),
            value: _eczemaEnabled,
            onChanged: (v) => setState(() => _eczemaEnabled = v),
          ),
          if (_eczemaEnabled) ...[
            ListTile(
              leading: const Icon(Icons.tune),
              title: const Text('Alert sensitivity'),
              subtitle: Text(_eczemaThreshold <= 0.5
                  ? 'High (alert more often)'
                  : _eczemaThreshold <= 0.7
                      ? 'Medium'
                      : 'Low (only high risk)'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('More', style: TextStyle(fontSize: 11)),
                  Expanded(
                    child: Slider(
                      value: _eczemaThreshold,
                      min: 0.3,
                      max: 0.9,
                      divisions: 6,
                      label: (_eczemaThreshold * 100).toInt().toString(),
                      onChanged: (v) => setState(() => _eczemaThreshold = v),
                    ),
                  ),
                  const Text('Less', style: TextStyle(fontSize: 11)),
                ],
              ),
            ),
          ],

          const Divider(height: 32),

          // ── Smart Suggestions ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.auto_awesome, title: 'Smart Suggestions', color: cs.tertiary),
          const SizedBox(height: 8),
          SwitchListTile(
            title: const Text('Enable smart suggestions'),
            subtitle: const Text('Pattern-based nudges like "Same as yesterday?"'),
            value: _smartEnabled,
            onChanged: (v) => setState(() => _smartEnabled = v),
          ),

          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.check),
            label: const Text('Save Preferences'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  const _SectionHeader({required this.icon, required this.title, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: color,
      )),
    ],
  );
}

class _TimeTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeTile({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.schedule),
    title: Text(label),
    trailing: TextButton(
      onPressed: onTap,
      child: Text(
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
  );
}
