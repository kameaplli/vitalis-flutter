import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks internet connectivity and exposes online/offline state.
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> {
  Timer? _timer;

  ConnectivityNotifier() : super(true) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (mounted && state != online) state = online;
    } on SocketException catch (_) {
      if (mounted && state != false) state = false;
    } on TimeoutException catch (_) {
      if (mounted && state != false) state = false;
    }
  }

  /// Manual refresh (e.g., after user taps "Retry")
  Future<void> refresh() => _check();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
