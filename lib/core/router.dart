import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/nutrition_screen.dart';
import '../screens/hydration_screen.dart';
import '../screens/health_screen.dart';
import '../screens/weight_screen.dart';
import '../screens/eczema_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/entries_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scanner_screen.dart';
import '../screens/grocery_screen.dart';
import '../screens/receipt_scan_screen.dart';
import '../widgets/app_shell.dart';

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// ChangeNotifier that fires whenever authProvider state changes,
/// allowing GoRouter to re-evaluate its redirect without being recreated.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthRefreshNotifier(ref);
  ref.onDispose(notifier.dispose);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/loading',
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final isLoading = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final loc = state.matchedLocation;

      if (isLoading) return loc == '/loading' ? null : '/loading';
      if (!isAuthenticated) return '/auth';
      if (loc == '/auth' || loc == '/loading') return '/dashboard';
      return null;
    },
    routes: [
      GoRoute(
        path: '/loading',
        builder: (context, state) => const _LoadingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/nutrition', builder: (_, __) => const NutritionScreen()),
          GoRoute(path: '/hydration', builder: (_, __) => const HydrationScreen()),
          GoRoute(path: '/health', builder: (_, __) => const HealthScreen()),
          GoRoute(path: '/more', builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/weight', builder: (_, __) => const WeightScreen()),
          GoRoute(path: '/eczema', builder: (_, __) => const EczemaScreen()),
          GoRoute(path: '/analytics', builder: (_, __) => const AnalyticsScreen()),
          GoRoute(path: '/entries', builder: (_, __) => const EntriesScreen()),
          GoRoute(path: '/profile', builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/scanner', builder: (_, __) => const ScannerScreen()),
          GoRoute(path: '/grocery', builder: (_, __) => const GroceryScreen()),
          GoRoute(path: '/grocery/scan', builder: (_, __) => const ReceiptScanScreen()),
        ],
      ),
    ],
  );
});
