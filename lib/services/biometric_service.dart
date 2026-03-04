import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// True when the device supports biometrics AND at least one method is enrolled.
  /// Uses canCheckBiometrics which is more reliable than getAvailableBiometrics
  /// on Android (especially Samsung and some Pixel devices).
  static Future<bool> isAvailable() async {
    try {
      final canCheck = await _auth.canCheckBiometrics;
      if (canCheck) return true;
      // Fall back: device supported but may not have biometrics enrolled yet
      return await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS biometric prompt.
  /// Returns true if the user authenticates successfully.
  static Future<bool> authenticate({
    String reason = 'Confirm your identity to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }
}
