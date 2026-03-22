/// Integration test that captures real screenshots of every screen.
///
/// Run:
///   flutter test integration_test/screenshot_test.dart
///
/// Screenshots are saved via IntegrationTestWidgetsFlutterBinding.
/// To pull them off the device, use flutter drive:
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_test.dart
///
/// The driver saves screenshots to the project root as PNG files.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:qorhealth/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Capture all screen screenshots', (tester) async {
    // Launch the real app
    app.main();
    await tester.pumpAndSettle(const Duration(seconds: 6));

    // ── Login if on auth screen ──────────────────────────────────────────
    if (find.text('Sign In').evaluate().isNotEmpty ||
        find.text('Login').evaluate().isNotEmpty) {
      await _login(tester);
    }

    // ── Skip interests/onboarding ────────────────────────────────────────
    await _skipOnboarding(tester);

    // Should be on dashboard now — wait for data to load
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // ── Capture each screen ──────────────────────────────────────────────
    // Navigate via GoRouter.go() for each route

    await _capture(binding, tester, '/dashboard', '01_dashboard', wait: 4);
    await _capture(binding, tester, '/nutrition', '02_nutrition', wait: 3);
    await _capture(binding, tester, '/health', '03_health', wait: 3);
    await _capture(binding, tester, '/more', '04_more', wait: 2);

    // Health sub-screens
    await _capture(binding, tester, '/hydration', '05_hydration', wait: 3);
    await _capture(binding, tester, '/health/weight', '06_weight', wait: 3);
    await _capture(binding, tester, '/health/exercise', '07_exercise', wait: 2);
    await _capture(binding, tester, '/health/sleep', '08_sleep', wait: 2);
    await _capture(binding, tester, '/health/mood', '09_mood', wait: 2);
    await _capture(binding, tester, '/health/symptoms', '10_symptoms', wait: 2);
    await _capture(binding, tester, '/health/medications', '11_medications', wait: 2);
    await _capture(binding, tester, '/health/supplements', '12_supplements', wait: 2);

    // Eczema & Skin
    await _capture(binding, tester, '/health/eczema', '13_eczema', wait: 3);
    await _capture(binding, tester, '/skin-photos', '14_skin_photos', wait: 2);
    await _capture(binding, tester, '/products', '15_products', wait: 2);
    await _capture(binding, tester, '/insights', '16_insights', wait: 3);

    // Tracking & History
    await _capture(binding, tester, '/entries', '17_entries', wait: 2);
    await _capture(binding, tester, '/health/labs', '18_lab_results', wait: 3);

    // Intelligence
    await _capture(binding, tester, '/health-intelligence', '19_health_twin', wait: 3);
    await _capture(binding, tester, '/health-timeline', '20_health_timeline', wait: 3);

    // Grocery
    await _capture(binding, tester, '/grocery', '21_grocery', wait: 3);

    // Social
    await _capture(binding, tester, '/social', '22_social', wait: 3);

    // Settings
    await _capture(binding, tester, '/profile', '23_profile', wait: 2);
    await _capture(binding, tester, '/notifications', '24_notification_prefs', wait: 2);
    await _capture(binding, tester, '/connected-devices', '25_connected_devices', wait: 2);
    await _capture(binding, tester, '/import-data', '26_import_data', wait: 2);
  });
}

/// Navigate to [route] via GoRouter, wait, then take a screenshot.
Future<void> _capture(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String route,
  String name, {
  int wait = 3,
}) async {
  // Find a BuildContext that has GoRouter above it
  final ctx = tester.element(find.byType(Scaffold).first);
  GoRouter.of(ctx).go(route);

  // Wait for navigation + data loading
  await tester.pumpAndSettle(Duration(seconds: wait));

  // Take screenshot
  await binding.takeScreenshot(name);
}

/// Login with test credentials.
Future<void> _login(WidgetTester tester) async {
  // Find text fields — email first, then password
  final fields = find.byType(TextFormField);
  if (fields.evaluate().length >= 2) {
    await tester.enterText(fields.at(0), 'kalyanpalli@gmail.com');
    await tester.enterText(fields.at(1), 'test1234');
    await tester.pumpAndSettle();

    // Tap Sign In / Login button
    final signIn = find.text('Sign In');
    final login = find.text('Login');
    if (signIn.evaluate().isNotEmpty) {
      await tester.tap(signIn.first);
    } else if (login.evaluate().isNotEmpty) {
      await tester.tap(login.first);
    }

    await tester.pumpAndSettle(const Duration(seconds: 6));
  }
}

/// Skip through interests and onboarding screens if they appear.
Future<void> _skipOnboarding(WidgetTester tester) async {
  for (var attempt = 0; attempt < 10; attempt++) {
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Try various skip/continue buttons
    for (final label in ['Skip', 'Get Started', 'Continue', 'Done']) {
      final btn = find.text(label);
      if (btn.evaluate().isNotEmpty) {
        await tester.tap(btn.first);
        await tester.pumpAndSettle(const Duration(seconds: 2));
        break;
      }
    }

    // If we see the dashboard or bottom nav, we're through
    if (find.byType(BottomNavigationBar).evaluate().isNotEmpty ||
        find.byType(NavigationBar).evaluate().isNotEmpty) {
      break;
    }
  }
}
