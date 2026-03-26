import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/secure_storage.dart';
import '../models/user.dart';
import '../services/biometric_service.dart';
import '../services/fcm_service.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import '../services/notification_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;
  // Biometric offer — set when login/register succeeds and the user hasn't
  // been offered biometrics yet.  AppShell reads these fields after mounting.
  // Because they are set inside login()/register() BEFORE the authenticated
  // state is published, AppShell is guaranteed to see them on first build.
  final bool showBioOffer;
  final String? bioOfferEmail;
  final String? bioOfferPassword;

  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.showBioOffer = false,
    this.bioOfferEmail,
    this.bioOfferPassword,
  });

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading       => status == AuthStatus.loading;
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier() : super(const AuthState(status: AuthStatus.loading)) {
    _init();
  }

  Future<void> _init() async {
    final token = await apiClient.getToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final res = await apiClient.dio.get(ApiConstants.user);
      final user = AppUser.fromJson(res.data);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      try { await NotificationService.scheduleAll(); } catch (_) {}
      try { await FcmService.getAndRegisterToken(); } catch (_) {}
      try { await _syncTimezone(); } catch (_) {}
      SecureStorage.setNotificationsEnabled(true);
    } catch (_) {
      await apiClient.clearToken();
      state = const AuthState(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final res = await apiClient.dio.post(
        ApiConstants.login,
        data: {'email': email, 'password': password},
      );
      await apiClient.saveToken(res.data['access_token']);
      final refreshToken = res.data['refresh_token'] as String?;
      if (refreshToken != null) await SecureStorage.saveRefreshToken(refreshToken);
      final user = AppUser.fromJson(res.data['user']);
      try { await NotificationService.scheduleAll(); } catch (_) {}
      try { await FcmService.getAndRegisterToken(); } catch (_) {}
      try { await _syncTimezone(); } catch (_) {}
      SecureStorage.setNotificationsEnabled(true);

      // ── Biometric setup ───────────────────────────────────────────────────
      // All async work is done HERE, before the authenticated state is set.
      // GoRouter only redirects after the state changes, so when AppShell
      // mounts it always sees the already-populated showBioOffer flag.
      // This permanently eliminates the race condition from the old approach
      // of queuing in BiometricOffer after login() returned.
      final available = await BiometricService.isAvailable();
      final enabled   = await SecureStorage.getBiometricsEnabled();
      final prompted  = await SecureStorage.getBiometricsPrompted();

      if (available && !enabled && !prompted) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          showBioOffer: true,
          bioOfferEmail: email,
          bioOfferPassword: password,
        );
      } else {
        if (enabled) {
          // Biometrics already on — silently save credentials if missing
          final creds = await SecureStorage.getBioCredentials();
          if (creds.password == null || creds.password!.isEmpty) {
            await SecureStorage.saveBioCredentials(
                email: email, password: password, name: user.name);
          }
        }
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Login failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated, error: 'Login error: $e');
      return false;
    }
  }

  Future<bool> register(String name, String email, String password) async {
    state = const AuthState(status: AuthStatus.loading);
    try {
      final res = await apiClient.dio.post(
        ApiConstants.register,
        data: {'name': name, 'email': email, 'password': password},
      );
      await apiClient.saveToken(res.data['access_token']);
      final refreshToken = res.data['refresh_token'] as String?;
      if (refreshToken != null) await SecureStorage.saveRefreshToken(refreshToken);
      final user = AppUser.fromJson(res.data['user']);
      try { await FcmService.getAndRegisterToken(); } catch (_) {}
      try { await _syncTimezone(); } catch (_) {}

      final available = await BiometricService.isAvailable();
      final prompted  = await SecureStorage.getBiometricsPrompted();

      if (available && !prompted) {
        state = AuthState(
          status: AuthStatus.authenticated,
          user: user,
          showBioOffer: true,
          bioOfferEmail: email,
          bioOfferPassword: password,
        );
      } else {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      }
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Registration failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    } catch (e) {
      state = AuthState(
          status: AuthStatus.unauthenticated, error: 'Registration error: $e');
      return false;
    }
  }

  /// Called by AppShell immediately after showing (or deciding to skip) the
  /// biometric offer dialog, so the flag doesn't linger in state.
  void clearBioOffer() {
    if (state.showBioOffer) {
      state = AuthState(status: state.status, user: state.user, error: state.error);
    }
  }

  /// Send the device's IANA timezone to the backend so server-side jobs
  /// (hydration reminders, daily summaries) respect the user's local time.
  Future<void> _syncTimezone() async {
    final tz = await FlutterTimezone.getLocalTimezone(); // e.g. "Australia/Sydney"
    await apiClient.dio.put(ApiConstants.profile, data: {'timezone': tz});
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post(ApiConstants.logout);
    } catch (_) {}
    try { await FcmService.unregisterToken(); } catch (_) {}
    await apiClient.clearToken();
    await SecureStorage.clearRefreshToken();
    NotificationService.cancelAll();
    SecureStorage.setNotificationsEnabled(false);
    // Reset "prompted" if biometrics were never actually enabled, so the
    // offer re-appears on the next explicit login.
    final bioEnabled = await SecureStorage.getBiometricsEnabled();
    if (!bioEnabled) {
      await SecureStorage.setBiometricsPrompted(false);
    }
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(AppUser user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  ref.keepAlive();
  return AuthNotifier();
});
