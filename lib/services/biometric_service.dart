import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// True when the device supports biometrics AND at least one is enrolled.
  /// Uses isDeviceSupported() as a fallback for devices where
  /// canCheckBiometrics returns false despite having enrolled fingerprints.
  static Future<bool> isAvailable() async {
    try {
      final supported = await _auth.isDeviceSupported();
      if (!supported) return false;
      return await _auth.canCheckBiometrics;
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS biometric prompt.
  /// Returns true on success, false on failure OR user cancellation.
  /// Never throws — all PlatformExceptions are caught.
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
    } on PlatformException {
      // Covers: NotAvailable, NotEnrolled, LockedOut, PasscodeNotSet,
      // OtherOperatingSystem, MissingPluginException, etc.
      return false;
    } catch (_) {
      return false;
    }
  }
}
