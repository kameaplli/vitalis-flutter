import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/app_cache.dart';
import '../core/constants.dart';
import 'notification_service.dart';

/// Processes pending notification quick-actions (e.g., "250ml" hydration tap).
/// Call on app open / resume.
class BackgroundService {
  /// Process pending actions. Returns true if any hydration was logged
  /// (caller should invalidate hydration/dashboard providers).
  static Future<bool> processPendingActions() async {
    // Load any actions persisted to disk (survives app kill)
    await NotificationService.loadPersistedActions();

    if (NotificationService.pendingActions.isEmpty) return false;

    final actions = List<String>.from(NotificationService.pendingActions);
    NotificationService.pendingActions.clear();

    bool hydrationLogged = false;
    for (final raw in actions) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['type'] == 'hydrate') {
          final ml = data['ml'] as int;
          await _logHydrationQuick(ml);
          hydrationLogged = true;
        }
      } catch (_) {}
    }
    return hydrationLogged;
  }

  static Future<void> _logHydrationQuick(int ml) async {
    try {
      final now = DateTime.now();
      final time = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      final date = now.toIso8601String().substring(0, 10);
      await apiClient.dio.post(ApiConstants.hydrationLog, data: {
        'beverage_type': 'water',
        'quantity': ml.toDouble(),
        'time': time,
        'date': date,
      });
      // Clear cached dashboard so invalidation fetches fresh data
      await AppCache.clearDashboard('self', date: date);
    } catch (_) {}
  }

  /// Check for new social notifications and show them as device notifications.
  /// Tracks last-seen notification ID to avoid duplicates.
  static Future<void> checkSocialNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastSeenId = prefs.getString('last_seen_social_notif_id') ?? '';

      final res = await apiClient.dio.get(ApiConstants.socialNotifications);
      final data = res.data;
      final List<dynamic> notifications;
      if (data is List) {
        notifications = data;
      } else if (data is Map) {
        notifications = (data['notifications'] as List<dynamic>?) ?? [];
      } else {
        return;
      }

      if (notifications.isEmpty) return;

      // Find new unread notifications since last check
      final newNotifs = <Map<String, dynamic>>[];
      for (final n in notifications) {
        if (n is! Map<String, dynamic>) continue;
        final id = n['id']?.toString() ?? '';
        final isRead = n['is_read'] == true;
        if (id == lastSeenId) break; // Already seen everything from here
        if (!isRead) {
          newNotifs.add(n);
        }
      }

      if (newNotifs.isEmpty) return;

      // Save the newest notification ID
      final newestId = (notifications.first as Map<String, dynamic>)['id']?.toString() ?? '';
      if (newestId.isNotEmpty) {
        await prefs.setString('last_seen_social_notif_id', newestId);
      }

      // Show device notifications for up to 5 newest
      for (final n in newNotifs.take(5)) {
        final title = n['title']?.toString() ?? 'QoreHealth';
        final body = n['body']?.toString();
        final id = n['id']?.toString() ?? '';
        await NotificationService.showSocialNotification(
          id: id.hashCode,
          title: title,
          body: body,
          payload: 'social',
        );
      }
    } catch (_) {
      // Silently fail — don't disrupt user's app experience
    }
  }

  /// Check current flare risk and show notification if above threshold.
  /// Call on app open as a lightweight weather check.
  static Future<void> checkFlareRisk() async {
    try {
      final enabled = await NotificationPrefs.eczemaEnabled();
      if (!enabled) return;

      // Check if we already alerted today to avoid spam
      final prefs = await SharedPreferences.getInstance();
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final lastAlert = prefs.getString('last_eczema_alert_date');
      if (lastAlert == today) return;

      // Get device location for weather-based flare risk
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      final pos = await Geolocator.getLastKnownPosition() ??
          await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.low,
          );
      final res = await apiClient.dio.get(
        ApiConstants.environmentFlareRisk,
        queryParameters: {'lat': pos.latitude, 'lon': pos.longitude},
      );
      if (res.statusCode == 200) {
        final data = res.data as Map<String, dynamic>;
        final risk = (data['overall_risk'] as num?)?.toDouble() ?? 0.0;
        final factors = <String>[];
        if (data['factors'] != null) {
          for (final f in (data['factors'] as List)) {
            if (f is Map && f['description'] != null) {
              factors.add(f['description'].toString());
            }
          }
        }

        final threshold = await NotificationPrefs.eczemaThreshold();
        if (risk >= threshold) {
          await NotificationService.showEczemaAlert(
            riskScore: risk,
            riskFactors: factors.take(2).join('. '),
          );
          await prefs.setString('last_eczema_alert_date', today);
        }
      }
    } catch (_) {
      // Silently fail — don't disrupt user's app experience
    }
  }
}
