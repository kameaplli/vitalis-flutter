import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Encrypted key-value storage.
/// Android: AES-256 via Android Keystore (EncryptedSharedPreferences).
/// iOS: Keychain.
class SecureStorage {
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── JWT token (replaces SharedPreferences) ────────────────────────────────

  static Future<void> saveToken(String token) =>
      _storage.write(key: 'jwt_token', value: token);

  static Future<String?> getToken() =>
      _storage.read(key: 'jwt_token');

  static Future<void> clearToken() =>
      _storage.delete(key: 'jwt_token');

  // ── Biometric flags ───────────────────────────────────────────────────────

  static Future<bool> getBiometricsEnabled() async =>
      (await _storage.read(key: 'biometrics_enabled')) == 'true';

  static Future<void> setBiometricsEnabled(bool v) =>
      _storage.write(key: 'biometrics_enabled', value: v ? 'true' : 'false');

  /// True once the "Enable biometrics?" dialog has been shown (never re-ask).
  static Future<bool> getBiometricsPrompted() async =>
      (await _storage.read(key: 'biometrics_prompted')) == 'true';

  static Future<void> setBiometricsPrompted(bool v) =>
      _storage.write(key: 'biometrics_prompted', value: v ? 'true' : 'false');

  // ── Stored credentials for biometric re-auth ─────────────────────────────

  static Future<void> saveBioCredentials({
    required String email,
    required String password,
    required String name,
  }) async {
    await Future.wait([
      _storage.write(key: 'biometrics_email', value: email),
      _storage.write(key: 'biometrics_password', value: password),
      _storage.write(key: 'biometrics_user_name', value: name),
    ]);
  }

  static Future<({String? email, String? password, String? name})>
      getBioCredentials() async {
    final email    = await _storage.read(key: 'biometrics_email');
    final password = await _storage.read(key: 'biometrics_password');
    final name     = await _storage.read(key: 'biometrics_user_name');
    return (email: email, password: password, name: name);
  }

  static Future<void> clearBioCredentials() => Future.wait([
        _storage.delete(key: 'biometrics_email'),
        _storage.delete(key: 'biometrics_password'),
        _storage.delete(key: 'biometrics_user_name'),
        _storage.write(key: 'biometrics_enabled', value: 'false'),
      ]);

  // ── Notification preferences ──────────────────────────────────────────────

  static Future<bool> getNotificationsEnabled() async {
    final v = await _storage.read(key: 'notifications_enabled');
    return v == 'true';
  }

  static Future<void> setNotificationsEnabled(bool enabled) async {
    await _storage.write(key: 'notifications_enabled', value: enabled ? 'true' : 'false');
  }
}
