import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// True only when the device supports biometrics AND at least one is enrolled.
  /// canCheckBiometrics is true only when fingerprints/face are actually registered.
  /// Never fall back to isDeviceSupported() — that returns true even with nothing
  /// enrolled, causing the OS to show "register fingerprint" error prompts.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics;
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
