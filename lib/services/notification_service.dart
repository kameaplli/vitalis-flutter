import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

/// Manages local push notifications for the primary user.
/// Schedules hourly hydration reminders from 8 AM to 10 PM daily.
class NotificationService {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static const _channelId = 'vitalis_hydration';
  static const _channelName = 'Hydration Reminders';
  static const _channelDesc = 'Hourly reminders to drink water throughout the day';

  static Future<void> init() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    // Request Android 13+ notification permission
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();

    _initialized = true;
  }

  /// Schedule daily repeating notifications at 8 AM, 9 AM, …, 10 PM.
  static Future<void> scheduleHydrationReminders() async {
    await _plugin.cancelAll();

    final messages = [
      'Start your day right — have a glass of water! 🌅',
      'Mid-morning check: have you had water yet? 💧',
      'Halfway through the morning — stay hydrated! 🚰',
      'Lunchtime! Don\'t forget to drink water with your meal. 🥗',
      'Post-lunch slump? Water helps more than coffee! ☕',
      'Afternoon hydration check — drink up! 💧',
      'Keep the energy up — time for another glass! ⚡',
      'You\'re doing great! Stay consistent with your water intake. 🏆',
      'Evening is here — have you hit your 2.5 L goal? 🌙',
      'Winding down — last hydration reminder of the day! 🌛',
      'Final check: top up before bed for overnight recovery! 💧',
      'Night owl? Don\'t forget water before you sleep! 🦉',
      'Late night hydration reminder — just a small glass! 🥤',
      'Almost midnight — final sip check! 💧',
      'One last reminder — you\'ve got this! 🌟',
    ];

    for (int i = 0; i <= 14; i++) {
      final hour = 8 + i; // 8 AM to 10 PM
      final msg = messages[i];

      final now = tz.TZDateTime.now(tz.local);
      var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, 0);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        hour, // unique id per hour slot
        '💧 Time to hydrate!',
        msg,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDesc,
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
            icon: '@mipmap/ic_launcher',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.wallClockTime,
        matchDateTimeComponents: DateTimeComponents.time, // repeat daily
      );
    }
  }

  /// Cancel all scheduled notifications (call on logout).
  static Future<void> cancelAll() async {
    await _plugin.cancelAll();
  }
}
