import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Periodically checks internet connectivity and exposes online/offline state.
///
/// Uses debounced failure detection: requires 2 consecutive failures before
/// reporting offline, preventing false positives on app wake-up.
final connectivityProvider = StateNotifierProvider<ConnectivityNotifier, bool>((ref) {
  return ConnectivityNotifier();
});

class ConnectivityNotifier extends StateNotifier<bool> with WidgetsBindingObserver {
  Timer? _timer;
  int _consecutiveFailures = 0;
  static const _failuresBeforeOffline = 2;

  ConnectivityNotifier() : super(true) {
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App came back to foreground — check immediately
      _check();
    }
  }

  Future<void> _check() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      final online = result.isNotEmpty && result[0].rawAddress.isNotEmpty;
      if (online) {
        _consecutiveFailures = 0;
        if (mounted && state != true) state = true;
      } else {
        _onFailure();
      }
    } on SocketException catch (_) {
      _onFailure();
    } on TimeoutException catch (_) {
      _onFailure();
    }
  }

  void _onFailure() {
    _consecutiveFailures++;
    if (_consecutiveFailures >= _failuresBeforeOffline) {
      if (mounted && state != false) state = false;
    }
    // On first failure, retry quickly instead of waiting 10s
    if (_consecutiveFailures == 1) {
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) _check();
      });
    }
  }

  /// Manual refresh (e.g., after user taps "Retry")
  Future<void> refresh() => _check();

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
