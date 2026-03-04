import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/user.dart';
import '../services/notification_service.dart';

enum AuthStatus { loading, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final AppUser? user;
  final String? error;

  const AuthState({required this.status, this.user, this.error});

  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isLoading => status == AuthStatus.loading;
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
      NotificationService.scheduleHydrationReminders();
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
      final user = AppUser.fromJson(res.data['user']);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      NotificationService.scheduleHydrationReminders();
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Login failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: 'Login error: $e');
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
      final user = AppUser.fromJson(res.data['user']);
      state = AuthState(status: AuthStatus.authenticated, user: user);
      return true;
    } on DioException catch (e) {
      final msg = e.response?.data?['detail'] ?? 'Registration failed';
      state = AuthState(status: AuthStatus.unauthenticated, error: msg);
      return false;
    } catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: 'Registration error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await apiClient.dio.post(ApiConstants.logout);
    } catch (_) {}
    await apiClient.clearToken();
    NotificationService.cancelAll();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  void updateUser(AppUser user) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});
