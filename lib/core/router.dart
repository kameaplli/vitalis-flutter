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
import '../screens/mood_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/interests_screen.dart';
import '../screens/notification_preferences_screen.dart';
import '../screens/finance_screen.dart'; // ignore: unused_import — kept for v1, finance module reserved for separate app
import '../screens/social/social_hub_screen.dart';
import '../screens/social/social_profile_screen.dart';
import '../screens/social/challenge_detail_screen.dart';
import '../screens/social/social_notifications_screen.dart';
import '../screens/health_intelligence_screen.dart';
import '../screens/connected_devices_screen.dart';
import '../screens/import_screen.dart';
import '../screens/health_timeline_screen.dart';
import '../screens/more_screen.dart';
import '../screens/health/labs_dashboard_screen.dart';
import '../screens/health/lab_upload_screen.dart';
import '../screens/health/biomarker_detail_screen.dart';
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
          GoRoute(path: '/more',       builder: (_, __) => const MoreScreen()),

          // ── Health sub-screens (pushed from Health card grid) ───────────
          GoRoute(path: '/health/symptoms',    builder: (_, __) => const HealthSubScreen(category: 'symptoms')),
          GoRoute(path: '/health/medications', builder: (_, __) => const HealthSubScreen(category: 'medications')),
          GoRoute(path: '/health/supplements', builder: (_, __) => const HealthSubScreen(category: 'supplements')),
          GoRoute(path: '/health/mood',        builder: (_, __) => const MoodScreen()),
          GoRoute(path: '/health/sleep',       builder: (_, __) => const HealthSubScreen(category: 'sleep')),
          GoRoute(path: '/health/exercise',    builder: (_, __) => const HealthSubScreen(category: 'exercise')),
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

          // ── Social routes ─────────────────────────────────────────────
          GoRoute(path: '/social', builder: (_, __) => const SocialHubScreen()),
          GoRoute(path: '/social/notifications', builder: (_, __) => const SocialNotificationsScreen()),
          GoRoute(path: '/social/profile/:id', builder: (_, state) => SocialProfileScreen(userId: state.pathParameters['id']!)),
          GoRoute(path: '/social/challenge/:id', builder: (_, state) => ChallengeDetailScreen(challengeId: state.pathParameters['id']!)),

          // ── Blood Test Intelligence ──────────────────────────────────────
          GoRoute(path: '/health/labs', builder: (_, __) => const LabsDashboardScreen()),
          GoRoute(path: '/health/labs/upload', builder: (_, __) => const LabUploadScreen()),
          GoRoute(path: '/health/labs/biomarker/:code', builder: (_, state) => BiomarkerDetailScreen(biomarkerCode: state.pathParameters['code']!)),

          // ── Health Intelligence ──────────────────────────────────────────
          GoRoute(path: '/health-intelligence', builder: (_, __) => const HealthIntelligenceScreen()),

          // ── Connected Devices / Wearable Sync ─────────────────────────────
          GoRoute(path: '/connected-devices', builder: (_, __) => const ConnectedDevicesScreen()),

          // ── Data Import ──────────────────────────────────────────────────────
          GoRoute(path: '/import-data', builder: (_, __) => const ImportScreen()),

          // ── Health Timeline (Phase 4) ────────────────────────────────────
          GoRoute(path: '/health-timeline', builder: (_, __) => const HealthTimelineScreen()),

          // ── Short-URL redirects for deep linking ──────────────────────────
          GoRoute(path: '/labs', redirect: (_, __) => '/health/labs'),
          GoRoute(path: '/eczema', redirect: (_, __) => '/health/eczema'),
          GoRoute(path: '/weight', redirect: (_, __) => '/health/weight'),
        ],
      ),
    ],
  );
});
