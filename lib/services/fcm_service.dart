import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import 'notification_service.dart';

/// Top-level background handler — MUST be a top-level function (not a method).
/// Runs in its own isolate when the app is killed/background.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background message: ${message.messageId}');
  // The notification payload is auto-displayed by the system when the app
  // is in background/killed, so we don't need to show a local notification here.
}

class FcmService {
  static bool _initialized = false;

  /// Initialize FCM listeners. Call once after Firebase.initializeApp().
  static Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    // Request permission (Android 13+ requires this)
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('[FCM] Permission: ${settings.authorizationStatus}');

    // Foreground messages — show as local notification
    FirebaseMessaging.onMessage.listen(_onForegroundMessage);

    // Message tap (app was in background, user tapped notification)
    FirebaseMessaging.onMessageOpenedApp.listen(_onMessageTap);

    // Check if app was opened from a terminated state via notification
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial != null) {
      debugPrint('[FCM] App opened from terminated via notification');
    }

    // Token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen(_onTokenRefresh);

    debugPrint('[FCM] Initialized');
  }

  /// Get current FCM token and register it with the backend.
  /// Call after login/register and on app restore.
  static Future<void> getAndRegisterToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('[FCM] No token available');
        return;
      }

      // Check if token changed since last registration
      final stored = await SecureStorage.getFcmToken();
      if (stored == token) {
        debugPrint('[FCM] Token unchanged, skipping registration');
        return;
      }

      // Register with backend
      await apiClient.dio.post(
        ApiConstants.registerDevice,
        data: {'fcm_token': token, 'platform': 'android'},
      );
      await SecureStorage.saveFcmToken(token);
      debugPrint('[FCM] Token registered with backend');
    } catch (e) {
      debugPrint('[FCM] Token registration failed: $e');
    }
  }

  /// Unregister FCM token on logout. Must be called BEFORE clearing auth token.
  static Future<void> unregisterToken() async {
    try {
      final token = await SecureStorage.getFcmToken();
      if (token == null) return;

      await apiClient.dio.post(
        ApiConstants.unregisterDevice,
        data: {'fcm_token': token},
      );
      await SecureStorage.clearFcmToken();
      debugPrint('[FCM] Token unregistered');
    } catch (e) {
      debugPrint('[FCM] Token unregister failed: $e');
    }
  }

  /// Handle foreground messages — show a local notification.
  static void _onForegroundMessage(RemoteMessage message) {
    debugPrint('[FCM] Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification == null) return;

    // Determine channel from data payload
    final channel = message.data['channel'] ?? 'social';

    // Use the existing NotificationService to show a local notification
    NotificationService.showSocialNotification(
      id: message.hashCode,
      title: notification.title ?? 'QoreHealth',
      body: notification.body,
      payload: message.data['route'] ?? channel,
    );
  }

  /// Handle notification tap when app was in background.
  static void _onMessageTap(RemoteMessage message) {
    debugPrint('[FCM] Message tap: ${message.data}');
    // Deep linking could be added here based on message.data['route']
  }

  /// Handle token refresh — re-register with backend.
  static void _onTokenRefresh(String newToken) {
    debugPrint('[FCM] Token refreshed');
    getAndRegisterToken();
  }
}
