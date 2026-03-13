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
import '../screens/entries_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/scanner_screen.dart';
import '../screens/grocery_screen.dart';
import '../screens/receipt_scan_screen.dart';
import '../screens/products_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/skin_photos_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/interests_screen.dart';
import '../screens/notification_preferences_screen.dart';
import '../screens/finance_screen.dart'; // ignore: unused_import — kept for v1, finance module reserved for separate app
import '../providers/interests_provider.dart';
import '../widgets/app_shell.dart';

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();
  @override
  Widget build(BuildContext context) => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
}

final _rootNavigatorKey  = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

/// Tracks whether the user has completed onboarding.
/// Initialized via provider override in main.dart.
final onboardingCompleteProvider = StateProvider<bool?>((ref) => null);

/// Fires whenever authProvider changes — triggers GoRouter redirect re-evaluation.
class _AuthRefreshNotifier extends ChangeNotifier {
  _AuthRefreshNotifier(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, __) => notifyListeners());
    ref.listen<bool?>(onboardingCompleteProvider, (_, __) => notifyListeners());
    ref.listen<bool>(interestsCompleteProvider, (_, __) => notifyListeners());
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
      final authState     = ref.read(authProvider);
      final isLoading     = authState.isLoading;
      final isAuthenticated = authState.isAuthenticated;
      final loc           = state.matchedLocation;

      if (isLoading) return loc == '/loading' ? null : '/loading';
      if (!isAuthenticated) return '/auth';

      // Check interests selection for first-time users (before onboarding)
      final interestsDone = ref.read(interestsCompleteProvider);
      if (!interestsDone && loc != '/interests') return '/interests';
      if (!interestsDone) return null; // stay on /interests until complete

      // Check onboarding for first-time users
      final onboardingDone = ref.read(onboardingCompleteProvider);
      if (onboardingDone == false && loc != '/onboarding') return '/onboarding';
      if (onboardingDone == false) return null; // stay on /onboarding until complete

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
      GoRoute(
        path: '/interests',
        builder: (context, state) => const InterestsScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          // ── 4 primary tabs ──────────────────────────────────────────────
          GoRoute(path: '/dashboard',  builder: (_, __) => const DashboardScreen()),
          GoRoute(path: '/nutrition',  builder: (_, __) => const NutritionScreen()),
          GoRoute(path: '/health',     builder: (_, __) => const HealthScreen()),
          GoRoute(path: '/grocery',    builder: (_, __) => const GroceryScreen()),

          // ── Health sub-screens (pushed from Health card grid) ───────────
          GoRoute(path: '/health/symptoms',    builder: (_, __) => const HealthSubScreen(category: 'symptoms')),
          GoRoute(path: '/health/medications', builder: (_, __) => const HealthSubScreen(category: 'medications')),
          GoRoute(path: '/health/supplements', builder: (_, __) => const HealthSubScreen(category: 'supplements')),
          GoRoute(path: '/health/mood',        builder: (_, __) => const HealthSubScreen(category: 'mood')),
          GoRoute(path: '/health/weight',      builder: (_, __) => const WeightScreen()),
          GoRoute(path: '/health/eczema',      builder: (_, __) => const EczemaScreen()),

          // ── Secondary / deep-link routes ────────────────────────────────
          GoRoute(path: '/hydration',  builder: (_, __) => const HydrationScreen()),
          GoRoute(path: '/entries',    builder: (_, __) => const EntriesScreen()),
          GoRoute(path: '/profile',    builder: (_, __) => const ProfileScreen()),
          GoRoute(path: '/scanner',    builder: (_, __) => const ScannerScreen()),
          GoRoute(path: '/grocery/scan', builder: (_, __) => const ReceiptScanScreen()),
          GoRoute(path: '/products',    builder: (_, __) => const ProductsScreen()),
          GoRoute(path: '/insights',    builder: (_, __) => const InsightsScreen()),
          GoRoute(path: '/skin-photos', builder: (_, __) => const SkinPhotosScreen()),
          GoRoute(path: '/notifications', builder: (_, __) => const NotificationPreferencesScreen()),
          // Disabled for v1 — finance module reserved for separate app
          // GoRoute(path: '/finance',       builder: (_, __) => const FinanceScreen()),
        ],
      ),
    ],
  );
});
