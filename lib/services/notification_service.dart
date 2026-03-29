import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

// ─── Notification Preferences stored in SharedPreferences ─────────────────────

class NotificationPrefs {
  static const _prefix = 'notif_';

  // Keys
  static const kHydrationEnabled  = '${_prefix}hydration_enabled';
  static const kHydrationStart    = '${_prefix}hydration_start';   // "08:00"
  static const kHydrationEnd      = '${_prefix}hydration_end';     // "21:00"
  static const kHydrationInterval = '${_prefix}hydration_interval'; // minutes

  static const kMealsEnabled      = '${_prefix}meals_enabled';
  static const kBreakfastTime     = '${_prefix}breakfast_time';    // "08:00"
  static const kLunchTime         = '${_prefix}lunch_time';        // "12:30"
  static const kDinnerTime        = '${_prefix}dinner_time';       // "18:30"
  static const kSnackTime         = '${_prefix}snack_time';        // "15:00"
  static const kSnackEnabled      = '${_prefix}snack_enabled';

  static const kEczemaEnabled     = '${_prefix}eczema_enabled';
  static const kEczemaThreshold   = '${_prefix}eczema_threshold';  // 0.0 – 1.0

  static const kSmartEnabled      = '${_prefix}smart_enabled';

  // Defaults
  static const defaultHydrationStart    = '08:00';
  static const defaultHydrationEnd      = '21:00';
  static const defaultHydrationInterval = 60; // minutes
  static const defaultBreakfastTime     = '08:00';
  static const defaultLunchTime         = '12:30';
  static const defaultDinnerTime        = '18:30';
  static const defaultSnackTime         = '15:00';
  static const defaultEczemaThreshold   = 0.7;

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

  // Hydration
  static Future<bool>   hydrationEnabled()  async => (await _prefs()).getBool(kHydrationEnabled) ?? true;
  static Future<String> hydrationStart()    async => (await _prefs()).getString(kHydrationStart) ?? defaultHydrationStart;
  static Future<String> hydrationEnd()      async => (await _prefs()).getString(kHydrationEnd) ?? defaultHydrationEnd;
  static Future<int>    hydrationInterval() async => (await _prefs()).getInt(kHydrationInterval) ?? defaultHydrationInterval;

  static Future<void> setHydrationEnabled(bool v)  async => (await _prefs()).setBool(kHydrationEnabled, v);
  static Future<void> setHydrationStart(String v)   async => (await _prefs()).setString(kHydrationStart, v);
  static Future<void> setHydrationEnd(String v)     async => (await _prefs()).setString(kHydrationEnd, v);
  static Future<void> setHydrationInterval(int v)   async => (await _prefs()).setInt(kHydrationInterval, v);

  // Meals
  static Future<bool>   mealsEnabled()    async => (await _prefs()).getBool(kMealsEnabled) ?? true;
  static Future<String> breakfastTime()   async => (await _prefs()).getString(kBreakfastTime) ?? defaultBreakfastTime;
  static Future<String> lunchTime()       async => (await _prefs()).getString(kLunchTime) ?? defaultLunchTime;
  static Future<String> dinnerTime()      async => (await _prefs()).getString(kDinnerTime) ?? defaultDinnerTime;
  static Future<String> snackTime()       async => (await _prefs()).getString(kSnackTime) ?? defaultSnackTime;
  static Future<bool>   snackEnabled()    async => (await _prefs()).getBool(kSnackEnabled) ?? false;

  static Future<void> setMealsEnabled(bool v)    async => (await _prefs()).setBool(kMealsEnabled, v);
  static Future<void> setBreakfastTime(String v)  async => (await _prefs()).setString(kBreakfastTime, v);
  static Future<void> setLunchTime(String v)      async => (await _prefs()).setString(kLunchTime, v);
  static Future<void> setDinnerTime(String v)     async => (await _prefs()).setString(kDinnerTime, v);
  static Future<void> setSnackTime(String v)      async => (await _prefs()).setString(kSnackTime, v);
  static Future<void> setSnackEnabled(bool v)     async => (await _prefs()).setBool(kSnackEnabled, v);

  // Eczema
  static Future<bool>   eczemaEnabled()   async => (await _prefs()).getBool(kEczemaEnabled) ?? true;
  static Future<double> eczemaThreshold() async => (await _prefs()).getDouble(kEczemaThreshold) ?? defaultEczemaThreshold;

  static Future<void> setEczemaEnabled(bool v)    async => (await _prefs()).setBool(kEczemaEnabled, v);
  static Future<void> setEczemaThreshold(double v) async => (await _prefs()).setDouble(kEczemaThreshold, v);

  // Smart suggestions
  static Future<bool> smartEnabled() async => (await _prefs()).getBool(kSmartEnabled) ?? true;
  static Future<void> setSmartEnabled(bool v) async => (await _prefs()).setBool(kSmartEnabled, v);

  // Supplements
  static const kSupplementsEnabled = '${_prefix}supplements_enabled';
  static Future<bool> supplementsEnabled() async => (await _prefs()).getBool(kSupplementsEnabled) ?? true;
  static Future<void> setSupplementsEnabled(bool v) async => (await _prefs()).setBool(kSupplementsEnabled, v);

  /// Store supplement reminders as JSON list: [{"id":"...", "name":"...", "time":"09:00", "end_date":"2026-04-01"}]
  static const kSupplementReminders = '${_prefix}supplement_reminders';

  static Future<List<Map<String, dynamic>>> supplementReminders() async {
    final raw = (await _prefs()).getString(kSupplementReminders);
    if (raw == null || raw.isEmpty) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> setSupplementReminders(List<Map<String, dynamic>> reminders) async {
    (await _prefs()).setString(kSupplementReminders, jsonEncode(reminders));
  }

  static Future<void> addSupplementReminder({
    required String supplementId,
    required String name,
    required String time,
    String? endDate,
  }) async {
    final list = await supplementReminders();
    // Remove existing for same supplement
    list.removeWhere((r) => r['id'] == supplementId);
    list.add({'id': supplementId, 'name': name, 'time': time, 'end_date': endDate});
    await setSupplementReminders(list);
  }

  static Future<void> removeSupplementReminder(String supplementId) async {
    final list = await supplementReminders();
    list.removeWhere((r) => r['id'] == supplementId);
    await setSupplementReminders(list);
  }

  /// Helper: parse "HH:mm" → (hour, minute)
  static (int, int) parseTime(String t) {
    final parts = t.split(':');
    return (int.parse(parts[0]), int.parse(parts[1]));
  }

  /// Helper: format (hour, minute) → "HH:mm"
  static String formatTime(int hour, int minute) =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

// ─── Notification ID Ranges ──────────────────────────────────────────────────
// Hydration:    1000 – 1099
// Meals:        2000 – 2010
// Eczema:       3000 – 3010
// Smart:        4000 – 4010
// Supplements:  5000 – 5099

// ─── Notification Channels ───────────────────────────────────────────────────

const _hydrationChannel = AndroidNotificationDetails(
  'qorehealth_hydration',
  'Hydration Reminders',
  channelDescription: 'Reminders to drink water throughout the day',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  icon: '@drawable/ic_notification',
  actions: [
    AndroidNotificationAction('hydrate_50', '50ml', showsUserInterface: false),
    AndroidNotificationAction('hydrate_100', '100ml', showsUserInterface: false),
    AndroidNotificationAction('hydrate_200', '200ml', showsUserInterface: false),
  ],
);

const _mealChannel = AndroidNotificationDetails(
  'qorehealth_meals',
  'Meal Reminders',
  channelDescription: 'Reminders to log meals at your chosen times',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  icon: '@drawable/ic_notification',
);

const _eczemaChannel = AndroidNotificationDetails(
  'qorehealth_eczema',
  'Eczema & Weather Alerts',
  channelDescription: 'Alerts when weather conditions may trigger flare-ups',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_notification',
);

const _smartChannel = AndroidNotificationDetails(
  'qorehealth_smart',
  'Smart Suggestions',
  channelDescription: 'Personalized logging suggestions based on your patterns',
  importance: Importance.low,
  priority: Priority.low,
  icon: '@drawable/ic_notification',
);

const _supplementChannel = AndroidNotificationDetails(
  'qorehealth_supplements',
  'Supplement Reminders',
  channelDescription: 'Daily reminders to take your supplements',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  icon: '@drawable/ic_notification',
);

const _socialChannel = AndroidNotificationDetails(
  'qorehealth_social',
  'Social Notifications',
  channelDescription: 'Reactions, comments, and buddy requests',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@drawable/ic_notification',
);

// Social notification ID range: 6000 – 6099

// ─── Main Service ────────────────────────────────────────────────────────────

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static bool _canUseExactAlarms = false;

  /// Callbacks queued from notification actions before the app is ready.
  static final List<String> pendingActions = [];

  static Future<void> init() async {
    if (_initialized) return;

    // ── Timezone: set tz.local to device timezone ──────────────────────────
    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final tzName = tzInfo.identifier;
      tz.setLocalLocation(tz.getLocation(tzName));
      debugPrint('[Notifications] timezone set to $tzName');
    } catch (e) {
      // Fallback: keep UTC (better than crashing)
      debugPrint('[Notifications] timezone fallback to UTC: $e');
    }

    const android = AndroidInitializationSettings('@drawable/ic_notification');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationAction,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
    );

    // ── Permissions ────────────────────────────────────────────────────────
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    // Delete and recreate hydration channel to pick up updated action buttons
    await androidPlugin?.deleteNotificationChannel('qorehealth_hydration');
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_hydration',
        'Hydration Reminders',
        description: 'Reminders to drink water throughout the day',
        importance: Importance.defaultImportance,
      ),
    );

    // Meal reminders channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_meals',
        'Meal Reminders',
        description: 'Reminders to log meals at your chosen times',
        importance: Importance.defaultImportance,
      ),
    );

    // Supplement reminders channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_supplements',
        'Supplement Reminders',
        description: 'Daily reminders to take your supplements',
        importance: Importance.defaultImportance,
      ),
    );

    // Social notifications channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_social',
        'Social Notifications',
        description: 'Reactions, comments, and buddy requests',
        importance: Importance.high,
      ),
    );

    // Lab reports channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_labs',
        'Lab Reports',
        description: 'Lab report upload and analysis updates',
        importance: Importance.high,
      ),
    );

    // Eczema & weather alerts channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_eczema',
        'Eczema & Weather Alerts',
        description: 'Alerts when weather conditions may trigger flare-ups',
        importance: Importance.high,
      ),
    );

    // Smart suggestions channel
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        'qorehealth_smart',
        'Smart Suggestions',
        description: 'Personalized logging suggestions based on your patterns',
        importance: Importance.low,
      ),
    );

    // Check exact alarm capability — on Android 14+ this requires explicit permission
    try {
      _canUseExactAlarms = await androidPlugin?.canScheduleExactNotifications() ?? false;
      if (!_canUseExactAlarms) {
        // Try requesting — opens system settings on Android 14+
        await androidPlugin?.requestExactAlarmsPermission();
        // Re-check after request
        _canUseExactAlarms = await androidPlugin?.canScheduleExactNotifications() ?? false;
      }
    } catch (_) {
      _canUseExactAlarms = false;
    }
    debugPrint('[Notifications] exactAlarms=$_canUseExactAlarms');

    _initialized = true;
  }

  /// The schedule mode to use — exact if permitted, inexact otherwise.
  static AndroidScheduleMode get _scheduleMode =>
      _canUseExactAlarms
          ? AndroidScheduleMode.alarmClock
          : AndroidScheduleMode.inexactAllowWhileIdle;

  /// Route to navigate to when user taps a notification.
  /// Set this from main.dart once the router is available.
  static void Function(String route)? onNavigate;

  /// Callback fired when a hydration quick-log action is tapped in the foreground.
  /// Set this from app_shell.dart so the dashboard refreshes immediately.
  static void Function()? onHydrationLogged;

  static const _pendingActionsKey = 'pending_notification_actions';

  static const _hydrationAmounts = {
    'hydrate_50': 50,
    'hydrate_100': 100,
    'hydrate_200': 200,
  };

  /// Persist a pending action to SharedPreferences so it survives app restarts.
  static Future<void> _persistAction(String action) async {
    pendingActions.add(action);
    try {
      final prefs = await SharedPreferences.getInstance();
      final existing = prefs.getStringList(_pendingActionsKey) ?? [];
      existing.add(action);
      await prefs.setStringList(_pendingActionsKey, existing);
    } catch (_) {}
  }

  /// Load persisted pending actions (call on app start before processing).
  static Future<void> loadPersistedActions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_pendingActionsKey) ?? [];
      if (stored.isNotEmpty) {
        pendingActions.addAll(stored);
        await prefs.remove(_pendingActionsKey);
      }
    } catch (_) {}
  }

  /// Handle notification tap / action button in foreground.
  static void _onNotificationAction(NotificationResponse response) {
    final actionId = response.actionId ?? '';
    final payload = response.payload ?? '';

    if (_hydrationAmounts.containsKey(actionId)) {
      _persistAction(jsonEncode({'type': 'hydrate', 'ml': _hydrationAmounts[actionId]}));
      // Notify the app shell so it processes immediately + refreshes dashboard
      onHydrationLogged?.call();
      return;
    }

    // Deep-link: if payload starts with '/', navigate to that route
    if (payload.startsWith('/') && onNavigate != null) {
      onNavigate!(payload);
    }
  }

  /// Handle notification actions when app is in background/killed.
  @pragma('vm:entry-point')
  static void _onBackgroundAction(NotificationResponse response) {
    final actionId = response.actionId ?? '';
    final payload = response.payload ?? '';

    if (_hydrationAmounts.containsKey(actionId)) {
      _persistAction(jsonEncode({'type': 'hydrate', 'ml': _hydrationAmounts[actionId]}));
      return;
    }
    // Store deep-link for when app opens
    if (payload.startsWith('/')) {
      _persistAction(jsonEncode({'type': 'navigate', 'route': payload}));
    }
  }

  // ── Schedule All Notifications ─────────────────────────────────────────────

  /// Re-schedule all notifications based on current preferences.
  /// Call after login, after prefs change, or on app open.
  static Future<void> scheduleAll() async {
    if (!_initialized) await init();

    // Verify notification permission is granted
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final permissionGranted = await androidPlugin?.areNotificationsEnabled() ?? false;
    if (!permissionGranted) {
      debugPrint('[Notifications] WARNING: POST_NOTIFICATIONS permission NOT granted! Requesting...');
      final granted = await androidPlugin?.requestNotificationsPermission() ?? false;
      if (!granted) {
        debugPrint('[Notifications] Permission denied by user — notifications will not work');
        return;
      }
    }

    await _plugin.cancelAll();

    final hydrationOn    = await NotificationPrefs.hydrationEnabled();
    final mealsOn        = await NotificationPrefs.mealsEnabled();
    final supplementsOn  = await NotificationPrefs.supplementsEnabled();

    debugPrint('[Notifications] scheduleAll — hydration=$hydrationOn, meals=$mealsOn, '
        'supplements=$supplementsOn, tz=${tz.local.name}, exactAlarms=$_canUseExactAlarms');

    try {
      if (hydrationOn)   await _scheduleHydration();
      if (mealsOn)       await _scheduleMeals();
      if (supplementsOn) await _scheduleSupplements();
    } catch (e) {
      debugPrint('[Notifications] ERROR during scheduling: $e');
    }

    // Log scheduled count for debugging
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[Notifications] ${pending.length} notifications scheduled');
  }

  /// Legacy entry point — calls scheduleAll().
  static Future<void> scheduleHydrationReminders() async {
    await scheduleAll();
  }

  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }

  // ── Hydration ──────────────────────────────────────────────────────────────

  static final _hydrationMessages = [
    'Start your day right — have a glass of water!',
    'Mid-morning check: have you had water yet?',
    'Stay hydrated — your body will thank you!',
    'Time for a water break!',
    'Hydration check — grab a glass!',
    'Keep the energy up — drink some water!',
    "You're doing great! Keep sipping!",
    'Afternoon hydration — stay on track!',
    'Water break time!',
    'Evening reminder — stay hydrated!',
    'Winding down — one more glass!',
    'Last reminder — hydrate before bed!',
  ];

  static Future<void> _scheduleHydration() async {
    // Defensively cancel all hydration IDs (1000–1098) first.
    // cancelAll() should handle this, but some Android OEMs don't properly
    // cancel repeating AlarmManager entries — belt-and-suspenders.
    for (int i = 1000; i < 1099; i++) {
      await _plugin.cancel(i);
    }

    final startStr = await NotificationPrefs.hydrationStart();
    final endStr   = await NotificationPrefs.hydrationEnd();
    final interval = await NotificationPrefs.hydrationInterval();

    final (startH, startM) = NotificationPrefs.parseTime(startStr);
    final (endH, endM)     = NotificationPrefs.parseTime(endStr);

    final startMin = startH * 60 + startM;
    final endMin   = endH * 60 + endM;
    if (endMin <= startMin || interval <= 0) return;

    debugPrint('[Notifications] hydration window: ${startH.toString().padLeft(2,'0')}:${startM.toString().padLeft(2,'0')} – ${endH.toString().padLeft(2,'0')}:${endM.toString().padLeft(2,'0')}, interval=${interval}min');

    int id = 1000;
    int msgIdx = 0;
    for (int min = startMin; min <= endMin && id < 1099; min += interval) {
      final hour = min ~/ 60;
      final minute = min % 60;
      final msg = _hydrationMessages[msgIdx % _hydrationMessages.length];
      msgIdx++;

      // Always schedule for TOMORROW to prevent Android from delivering
      // past-due "catch-up" notifications all at once when the app opens.
      // matchDateTimeComponents: DateTimeComponents.time ensures daily repeat.
      final scheduled = _tomorrowAt(hour, minute);
      debugPrint('[Notifications] hydration #$id at ${hour.toString().padLeft(2,'0')}:${minute.toString().padLeft(2,'0')} → $scheduled');
      await _plugin.zonedSchedule(
        id++,
        'Time to hydrate!',
        msg,
        scheduled,
        const NotificationDetails(android: _hydrationChannel),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/hydration',
      );
    }
  }

  // ── Meal Reminders ─────────────────────────────────────────────────────────

  static Future<void> _scheduleMeals() async {
    final meals = <(int, String, String, String)>[]; // (id, timeStr, title, body)

    final bTime = await NotificationPrefs.breakfastTime();
    final lTime = await NotificationPrefs.lunchTime();
    final dTime = await NotificationPrefs.dinnerTime();
    meals.add((2001, bTime, 'Breakfast time!', "Don't forget to log your breakfast."));
    meals.add((2002, lTime, 'Lunch time!', 'Log your lunch to stay on track.'));
    meals.add((2003, dTime, 'Dinner time!', 'Time to log your evening meal.'));

    final snackOn = await NotificationPrefs.snackEnabled();
    if (snackOn) {
      final sTime = await NotificationPrefs.snackTime();
      meals.add((2004, sTime, 'Snack time!', 'Had a snack? Log it!'));
    }

    for (final (id, timeStr, title, body) in meals) {
      final (h, m) = NotificationPrefs.parseTime(timeStr);
      final scheduled = _nextInstanceOfTime(h, m);
      debugPrint('[Notifications] meal #$id "$title" at $timeStr → $scheduled');
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: _mealChannel),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/nutrition',
      );

      // Gentle reminder 30 minutes later
      final reminderMin = h * 60 + m + 30;
      final rH = reminderMin ~/ 60;
      final rM = reminderMin % 60;
      if (rH < 24) {
        final reminderScheduled = _nextInstanceOfTime(rH, rM);
        await _plugin.zonedSchedule(
          id + 5, // offset to avoid collision (2006, 2007, 2008, 2009)
          'Missed $title',
          "Looks like you haven't logged this meal yet. Tap to log now!",
          reminderScheduled,
          const NotificationDetails(android: _mealChannel),
          androidScheduleMode: _scheduleMode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.wallClockTime,
          matchDateTimeComponents: DateTimeComponents.time,
          payload: '/nutrition',
        );
      }
    }
  }

  // ── Supplement Reminders ──────────────────────────────────────────────────

  static Future<void> _scheduleSupplements() async {
    final reminders = await NotificationPrefs.supplementReminders();
    final today = DateTime.now().toIso8601String().substring(0, 10);

    int id = 5000;
    for (final r in reminders) {
      if (id >= 5099) break;
      // Skip expired courses
      final endDate = r['end_date'] as String?;
      if (endDate != null && endDate.compareTo(today) < 0) continue;

      final name = r['name'] as String? ?? 'Supplement';
      final timeStr = r['time'] as String? ?? '09:00';
      final (h, m) = NotificationPrefs.parseTime(timeStr);

      final scheduled = _nextInstanceOfTime(h, m);
      await _plugin.zonedSchedule(
        id++,
        'Time to take $name',
        'Your daily reminder to take $name.',
        scheduled,
        const NotificationDetails(android: _supplementChannel),
        androidScheduleMode: _scheduleMode,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '/health/supplements',
      );
    }
  }

  // ── Eczema Alert (called from background weather check or manual) ──────────

  static Future<void> showEczemaAlert({
    required double riskScore,
    required String riskFactors,
  }) async {
    final enabled = await NotificationPrefs.eczemaEnabled();
    if (!enabled) return;
    final threshold = await NotificationPrefs.eczemaThreshold();
    if (riskScore < threshold) return;

    final level = riskScore > 0.8 ? 'High' : 'Moderate';
    await _plugin.show(
      3001,
      'Eczema Flare Risk: $level',
      riskFactors.isNotEmpty
          ? riskFactors
          : 'Current weather conditions may trigger a flare-up. Consider logging your skin status.',
      const NotificationDetails(android: _eczemaChannel),
      payload: '/health/eczema',
    );
  }

  // ── Smart Suggestion (called when pattern detected) ────────────────────────

  static Future<void> showSmartSuggestion({
    required String title,
    required String body,
    int id = 4001,
  }) async {
    final enabled = await NotificationPrefs.smartEnabled();
    if (!enabled) return;

    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(android: _smartChannel),
      payload: '/dashboard',
    );
  }

  // ── Test Notifications (fire immediately for verification) ───────────────

  static Future<void> sendTestHydration() async {
    if (!_initialized) await init();
    await _plugin.show(
      9900,
      'Test: Time to hydrate!',
      'This is a test hydration notification. Quick-log buttons should appear below.',
      const NotificationDetails(android: _hydrationChannel),
      payload: '/hydration',
    );
  }

  static Future<void> sendTestMeal() async {
    if (!_initialized) await init();
    await _plugin.show(
      9901,
      'Test: Breakfast time!',
      'This is a test meal reminder notification.',
      const NotificationDetails(android: _mealChannel),
      payload: '/nutrition',
    );
  }

  static Future<void> sendTestSupplement() async {
    if (!_initialized) await init();
    await _plugin.show(
      9902,
      'Test: Time to take Vitamin D',
      'This is a test supplement reminder notification.',
      const NotificationDetails(android: _supplementChannel),
      payload: '/health/supplements',
    );
  }

  static Future<void> sendTestEczema() async {
    if (!_initialized) await init();
    await _plugin.show(
      9903,
      'Test: Eczema Flare Risk: Moderate',
      'This is a test eczema alert. Current conditions may trigger a flare-up.',
      const NotificationDetails(android: _eczemaChannel),
      payload: '/health/eczema',
    );
  }

  static Future<void> sendTestSmart() async {
    if (!_initialized) await init();
    await _plugin.show(
      9904,
      'Test: Same as yesterday?',
      'This is a test smart suggestion notification.',
      const NotificationDetails(android: _smartChannel),
      payload: '/dashboard',
    );
  }

  // ── Social Notifications (device-level alerts for in-app social events) ────

  /// Show a device notification for a social event (reaction, comment, etc.).
  /// Called by BackgroundService when new unread notifications are detected.
  static Future<void> showSocialNotification({
    required int id,
    required String title,
    String? body,
    String? payload,
  }) async {
    if (!_initialized) await init();
    await _plugin.show(
      6000 + (id.hashCode.abs() % 100), // Keep within 6000-6099 range
      title,
      body ?? '',
      const NotificationDetails(android: _socialChannel),
      payload: payload ?? '/social',
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }

  /// Always returns TOMORROW at the given time.
  /// Used for repeating notifications to prevent Android from delivering
  /// past-due "catch-up" notifications immediately on schedule.
  static tz.TZDateTime _tomorrowAt(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    final tomorrow = now.add(const Duration(days: 1));
    return tz.TZDateTime(tz.local, tomorrow.year, tomorrow.month, tomorrow.day, hour, minute);
  }

  // ── Lab Report Notifications ──────────────────────────────────────────────

  static Future<void> showLabUploaded({int fileCount = 1}) async {
    if (!_initialized) await init();
    final body = fileCount > 1
        ? '$fileCount lab reports are being uploaded and analysed.'
        : 'Your lab report is being uploaded and analysed.';
    await _plugin.show(
      5001,
      'Analysing Lab Reports',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qorehealth_labs',
          'Lab Reports',
          channelDescription: 'Lab report upload and analysis updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: '/health/labs',
    );
  }

  static Future<void> showLabAnalysisComplete({int resultsCount = 0}) async {
    if (!_initialized) await init();
    final body = resultsCount > 0
        ? '$resultsCount biomarkers analysed and added to your dashboard.'
        : 'Your biomarkers have been analysed and added to your dashboard.';
    await _plugin.show(
      5002,
      'Analysis Complete',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qorehealth_labs',
          'Lab Reports',
          channelDescription: 'Lab report upload and analysis updates',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: '/health/labs',
    );
  }

  // ── Health Connect Sync Notifications ─────────────────────────────────────

  static Future<void> showSyncStarted() async {
    if (!_initialized) await init();
    await _plugin.show(
      6001,
      'Health Connect Sync',
      'Syncing your health data in the background...',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qorehealth_smart',
          'Smart Notifications',
          channelDescription: 'Health Connect sync updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/ic_notification',
          ongoing: true,
          showProgress: true,
          indeterminate: true,
        ),
      ),
    );
  }

  static Future<void> showSyncComplete({int inserted = 0, int total = 0}) async {
    if (!_initialized) await init();
    final body = inserted > 0
        ? 'Health Connect sync complete — $inserted new records synced.'
        : 'Health Connect sync complete — all data is up to date.';
    await _plugin.show(
      6001, // Same ID replaces the "syncing..." notification
      'Health Connect Sync Complete',
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qorehealth_smart',
          'Smart Notifications',
          channelDescription: 'Health Connect sync updates',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          icon: '@drawable/ic_notification',
        ),
      ),
      payload: '/dashboard',
    );
  }

  static Future<void> showSyncFailed() async {
    if (!_initialized) await init();
    await _plugin.show(
      6001,
      'Health Connect Sync',
      'Sync could not complete — will retry next time.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'qorehealth_smart',
          'Smart Notifications',
          channelDescription: 'Health Connect sync updates',
          importance: Importance.low,
          priority: Priority.low,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  /// Diagnostic: print all pending notifications for debugging.
  static Future<void> debugPendingNotifications() async {
    if (!_initialized) await init();
    final pending = await _plugin.pendingNotificationRequests();
    debugPrint('[Notifications] ── ${pending.length} pending notifications ──');
    for (final n in pending) {
      debugPrint('[Notifications]   #${n.id}: ${n.title} | ${n.body}');
    }
    debugPrint('[Notifications] ── timezone: ${tz.local.name}, exactAlarms: $_canUseExactAlarms ──');
  }
}
