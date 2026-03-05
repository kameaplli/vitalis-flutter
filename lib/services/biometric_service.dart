import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';

/// Thin wrapper around local_auth.
class BiometricService {
  static final _auth = LocalAuthentication();

  /// True when the device supports biometrics OR has a secure lock screen.
  /// Uses OR so that devices where canCheckBiometrics returns false despite
  /// having enrolled fingerprints (common on Samsung/Pixel) still work.
  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  /// Shows the OS biometric prompt (fingerprint / face / PIN fallback).
  /// Returns true on success, false on failure OR user cancellation.
  /// Never throws — all PlatformExceptions are caught.
  /// biometricOnly is false so users can fall back to device PIN/pattern if
  /// the biometric sensor is temporarily unavailable.
  static Future<bool> authenticate({
    String reason = 'Confirm your identity to continue',
  }) async {
    try {
      return await _auth.authenticate(
        localizedReason: reason,
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: false,
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
