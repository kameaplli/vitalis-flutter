import 'dart:convert';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  static const defaultHydrationInterval = 90; // minutes
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
// Hydration:   1000 – 1099
// Meals:       2000 – 2010
// Eczema:      3000 – 3010
// Smart:       4000 – 4010

// ─── Notification Channels ───────────────────────────────────────────────────

const _hydrationChannel = AndroidNotificationDetails(
  'vitalis_hydration',
  'Hydration Reminders',
  channelDescription: 'Reminders to drink water throughout the day',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  icon: '@mipmap/ic_launcher',
  actions: [
    AndroidNotificationAction('hydrate_250', '250ml', showsUserInterface: false),
    AndroidNotificationAction('hydrate_500', '500ml', showsUserInterface: false),
    AndroidNotificationAction('hydrate_open', 'Open App', showsUserInterface: true),
  ],
);

const _mealChannel = AndroidNotificationDetails(
  'vitalis_meals',
  'Meal Reminders',
  channelDescription: 'Reminders to log meals at your chosen times',
  importance: Importance.defaultImportance,
  priority: Priority.defaultPriority,
  icon: '@mipmap/ic_launcher',
);

const _eczemaChannel = AndroidNotificationDetails(
  'vitalis_eczema',
  'Eczema & Weather Alerts',
  channelDescription: 'Alerts when weather conditions may trigger flare-ups',
  importance: Importance.high,
  priority: Priority.high,
  icon: '@mipmap/ic_launcher',
);

const _smartChannel = AndroidNotificationDetails(
  'vitalis_smart',
  'Smart Suggestions',
  channelDescription: 'Personalized logging suggestions based on your patterns',
  importance: Importance.low,
  priority: Priority.low,
  icon: '@mipmap/ic_launcher',
);

// ─── Main Service ────────────────────────────────────────────────────────────

class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  /// Callbacks queued from notification actions before the app is ready.
  static final List<String> pendingActions = [];

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationAction,
      onDidReceiveBackgroundNotificationResponse: _onBackgroundAction,
    );

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Handle notification tap / action button in foreground.
  static void _onNotificationAction(NotificationResponse response) {
    final actionId = response.actionId ?? '';

    if (actionId == 'hydrate_250' || actionId == 'hydrate_500') {
      // Store pending quick-log action for the app to process
      final ml = actionId == 'hydrate_250' ? 250 : 500;
      pendingActions.add(jsonEncode({'type': 'hydrate', 'ml': ml}));
    }
    // Other taps just open the app (default behavior)
  }

  /// Handle notification actions when app is in background/killed.
  @pragma('vm:entry-point')
  static void _onBackgroundAction(NotificationResponse response) {
    final actionId = response.actionId ?? '';
    if (actionId == 'hydrate_250' || actionId == 'hydrate_500') {
      final ml = actionId == 'hydrate_250' ? 250 : 500;
      pendingActions.add(jsonEncode({'type': 'hydrate', 'ml': ml}));
    }
  }

  // ── Schedule All Notifications ─────────────────────────────────────────────

  /// Re-schedule all notifications based on current preferences.
  /// Call after login, after prefs change, or on app open.
  static Future<void> scheduleAll() async {
    await _plugin.cancelAll();

    final hydrationOn = await NotificationPrefs.hydrationEnabled();
    final mealsOn     = await NotificationPrefs.mealsEnabled();

    if (hydrationOn) await _scheduleHydration();
    if (mealsOn)     await _scheduleMeals();
    // Eczema alerts are triggered by background weather check on app open,
    // not scheduled. The pref is read when the check runs.
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
    final startStr = await NotificationPrefs.hydrationStart();
    final endStr   = await NotificationPrefs.hydrationEnd();
    final interval = await NotificationPrefs.hydrationInterval();

    final (startH, startM) = NotificationPrefs.parseTime(startStr);
    final (endH, endM)     = NotificationPrefs.parseTime(endStr);

    final startMin = startH * 60 + startM;
    final endMin   = endH * 60 + endM;
    if (endMin <= startMin || interval <= 0) return;

    int id = 1000;
    int msgIdx = 0;
    for (int min = startMin; min <= endMin && id < 1099; min += interval) {
      final hour = min ~/ 60;
      final minute = min % 60;
      final msg = _hydrationMessages[msgIdx % _hydrationMessages.length];
      msgIdx++;

      final scheduled = _nextInstanceOfTime(hour, minute);
      await _plugin.zonedSchedule(
        id++,
        'Time to hydrate!',
        msg,
        scheduled,
        const NotificationDetails(android: _hydrationChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'hydration',
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
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        const NotificationDetails(android: _mealChannel),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'meal',
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
      payload: 'eczema_alert',
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
      payload: 'smart_suggestion',
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
}
