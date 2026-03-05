/// In-memory queue for the one-time biometric offer shown after login.
///
/// auth_screen.dart queues credentials immediately after a successful login.
/// AppShell consumes them on its first frame and shows the offer dialog.
/// Using static state (not Riverpod) avoids any provider lifecycle race.
class BiometricOffer {
  BiometricOffer._();

  static String? _email;
  static String? _password;
  static String? _name;

  static bool get hasPending => _email != null && _password != null;

  /// Call from auth_screen right after a successful login/register.
  static void queue(String email, String password, String name) {
    _email    = email;
    _password = password;
    _name     = name;
  }

  /// Call from AppShell to read-and-clear the pending offer.
  /// Returns null if nothing is queued.
  static ({String email, String password, String name})? consume() {
    if (_email == null || _password == null) return null;
    final result = (email: _email!, password: _password!, name: _name ?? '');
    _email = _password = _name = null;
    return result;
  }
}
