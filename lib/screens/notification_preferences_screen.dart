import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
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

  // Report preferences (server-side)
  bool _weeklyReportEnabled = false;
  bool _monthlyReportEnabled = false;
  int _reportPreferredDay = 1;    // 1=Monday for weekly; 1-28 for monthly
  bool _includeFamily = true;
  bool _reportSending = false;

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

    // Load report preferences from server
    try {
      final res = await apiClient.dio.get(ApiConstants.reportPreferences);
      final d = res.data as Map<String, dynamic>;
      _weeklyReportEnabled = d['weekly_enabled'] == true;
      _monthlyReportEnabled = d['monthly_enabled'] == true;
      _reportPreferredDay = d['preferred_day'] as int? ?? 1;
      _includeFamily = d['include_family'] != false;
    } catch (_) {
      // Server may not have the endpoint yet — use defaults
    }

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

      // Save report preferences to server
      try {
        await apiClient.dio.put(ApiConstants.reportPreferences, data: {
          'weekly_enabled': _weeklyReportEnabled,
          'monthly_enabled': _monthlyReportEnabled,
          'preferred_day': _reportPreferredDay,
          'include_family': _includeFamily,
        });
      } catch (_) {
        // Server may not support reports yet — don't block
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

  static String _weekdayName(int day) {
    const names = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return names[(day - 1).clamp(0, 6)];
  }

  Future<void> _sendTestReport() async {
    setState(() => _reportSending = true);
    try {
      final type = _weeklyReportEnabled ? 'weekly' : 'monthly';
      await apiClient.dio.post(ApiConstants.reportSendNow, data: {'report_type': type});
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report sent! Check your email.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to send report. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _reportSending = false);
    }
  }

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
          if (_hydrationEnabled)
            _TestNotificationButton(
              label: 'Send test hydration notification',
              onPressed: () => NotificationService.sendTestHydration(),
            ),

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
          if (_mealsEnabled)
            _TestNotificationButton(
              label: 'Send test meal notification',
              onPressed: () => NotificationService.sendTestMeal(),
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
          if (_supplementsEnabled)
            _TestNotificationButton(
              label: 'Send test supplement notification',
              onPressed: () => NotificationService.sendTestSupplement(),
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

          if (_eczemaEnabled)
            _TestNotificationButton(
              label: 'Send test eczema alert',
              onPressed: () => NotificationService.sendTestEczema(),
            ),

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

          if (_smartEnabled)
            _TestNotificationButton(
              label: 'Send test smart suggestion',
              onPressed: () => NotificationService.sendTestSmart(),
            ),

          const Divider(height: 32),

          // ── Health Reports ──────────────────────────────────────────────
          _SectionHeader(icon: Icons.picture_as_pdf, title: 'Health Reports', color: Colors.deepPurple),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Text(
              'Receive rich PDF health reports with charts and insights by email.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
            ),
          ),
          SwitchListTile(
            title: const Text('Weekly report'),
            subtitle: Text(_weeklyReportEnabled
                ? 'Every ${_weekdayName(_reportPreferredDay)}'
                : 'Disabled'),
            value: _weeklyReportEnabled,
            onChanged: (v) => setState(() => _weeklyReportEnabled = v),
          ),
          SwitchListTile(
            title: const Text('Monthly report'),
            subtitle: Text(_monthlyReportEnabled
                ? 'On day $_reportPreferredDay of each month'
                : 'Disabled'),
            value: _monthlyReportEnabled,
            onChanged: (v) => setState(() => _monthlyReportEnabled = v),
          ),
          if (_weeklyReportEnabled || _monthlyReportEnabled) ...[
            ListTile(
              leading: const Icon(Icons.calendar_today),
              title: Text(_weeklyReportEnabled ? 'Send on' : 'Day of month'),
              trailing: DropdownButton<int>(
                value: _reportPreferredDay.clamp(1, _weeklyReportEnabled ? 7 : 28),
                underline: const SizedBox(),
                items: _weeklyReportEnabled
                    ? List.generate(7, (i) => DropdownMenuItem(
                        value: i + 1, child: Text(_weekdayName(i + 1))))
                    : List.generate(28, (i) => DropdownMenuItem(
                        value: i + 1, child: Text('${i + 1}'))),
                onChanged: (v) { if (v != null) setState(() => _reportPreferredDay = v); },
              ),
            ),
            SwitchListTile(
              title: const Text('Include family members'),
              subtitle: const Text('Add family data to the report'),
              value: _includeFamily,
              onChanged: (v) => setState(() => _includeFamily = v),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: OutlinedButton.icon(
                onPressed: _reportSending ? null : _sendTestReport,
                icon: _reportSending
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.send),
                label: Text(_reportSending ? 'Sending...' : 'Send a test report now'),
              ),
            ),
          ],

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

class _TestNotificationButton extends StatefulWidget {
  final String label;
  final Future<void> Function() onPressed;
  const _TestNotificationButton({required this.label, required this.onPressed});

  @override
  State<_TestNotificationButton> createState() => _TestNotificationButtonState();
}

class _TestNotificationButtonState extends State<_TestNotificationButton> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: OutlinedButton.icon(
        onPressed: _sent
            ? null
            : () async {
                await widget.onPressed();
                setState(() => _sent = true);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${widget.label} sent!'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                }
                // Reset after 3 seconds so it can be tapped again
                Future.delayed(const Duration(seconds: 3), () {
                  if (mounted) setState(() => _sent = false);
                });
              },
        icon: Icon(_sent ? Icons.check : Icons.notifications_active, size: 18),
        label: Text(_sent ? 'Sent!' : widget.label, style: const TextStyle(fontSize: 12)),
      ),
    );
  }
}
