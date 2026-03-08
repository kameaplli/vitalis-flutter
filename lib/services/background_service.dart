import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import 'notification_service.dart';

/// Processes pending notification quick-actions (e.g., "250ml" hydration tap).
/// Call on app open / resume.
class BackgroundService {
  static Future<void> processPendingActions() async {
    if (NotificationService.pendingActions.isEmpty) return;

    final actions = List<String>.from(NotificationService.pendingActions);
    NotificationService.pendingActions.clear();

    for (final raw in actions) {
      try {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        if (data['type'] == 'hydrate') {
          final ml = data['ml'] as int;
          await _logHydrationQuick(ml);
        }
      } catch (_) {}
    }
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
    } catch (_) {}
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

      final res = await apiClient.dio.get(ApiConstants.environmentFlareRisk);
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
