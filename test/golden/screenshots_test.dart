/// Golden screenshot tests for all major screens.
///
/// Run: flutter test --update-goldens test/golden/screenshots_test.dart
/// PNGs saved to: test/golden/goldens/
///
/// Note: Some tests may report "Timer still pending" in teardown — this is
/// expected and does not affect golden file generation. All PNGs are saved
/// before teardown.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qorhealth/screens/auth_screen.dart';
import 'package:qorhealth/screens/dashboard_screen.dart';
import 'package:qorhealth/screens/nutrition_screen.dart';
import 'package:qorhealth/screens/hydration_screen.dart';
import 'package:qorhealth/screens/health_screen.dart';
import 'package:qorhealth/screens/more_screen.dart';
import 'package:qorhealth/screens/profile_screen.dart';
import 'package:qorhealth/screens/notification_preferences_screen.dart';
import 'package:qorhealth/screens/weight_screen.dart';
import 'package:qorhealth/screens/onboarding_screen.dart';
import 'package:qorhealth/screens/interests_screen.dart';
import 'package:qorhealth/screens/entries_screen.dart';
import 'package:qorhealth/screens/eczema_screen.dart';
import 'package:qorhealth/screens/grocery_screen.dart';
import 'package:qorhealth/screens/finance_screen.dart';
import 'package:qorhealth/screens/insights_screen.dart';
import 'package:qorhealth/screens/skin_photos_screen.dart';
import 'package:qorhealth/screens/products_screen.dart';
import 'package:qorhealth/screens/health_intelligence_screen.dart';
import 'package:qorhealth/screens/connected_devices_screen.dart';
import 'package:qorhealth/screens/health_timeline_screen.dart';
import 'package:qorhealth/screens/import_screen.dart';
import 'package:qorhealth/screens/analytics_screen.dart';
import 'package:qorhealth/screens/exercise_screen.dart';
import 'package:qorhealth/screens/sleep_screen.dart';
import 'package:qorhealth/screens/mood_screen.dart';
import 'package:qorhealth/screens/symptom_screen.dart';
import 'package:qorhealth/screens/medication_screen.dart';
import 'package:qorhealth/screens/supplement_screen.dart';
import 'package:qorhealth/screens/vitals_screen.dart';
import 'package:qorhealth/screens/family_screen.dart';
import 'package:qorhealth/screens/lab_screen.dart';
import 'package:qorhealth/screens/social/social_hub_screen.dart';

import 'golden_test_helper.dart';

void main() {
  setUpAll(() => setupGoldenTests());

  // ── Auth & Onboarding ───────────────────────────────────────────────────
  testWidgets('01 Auth screen', (t) async {
    await pumpScreen(t, const AuthScreen(), overrides: authOverrides(), wrapInScaffold: false);
    await expectGolden(t, '01_auth_login');
  });

  testWidgets('02 Onboarding screen', (t) async {
    await pumpScreen(t, const OnboardingScreen(), overrides: baseOverrides(), wrapInScaffold: false);
    await expectGolden(t, '02_onboarding');
  });

  testWidgets('03 Interests screen', (t) async {
    await pumpScreen(t, const InterestsScreen(), overrides: baseOverrides(), wrapInScaffold: false);
    await expectGolden(t, '03_interests');
  });

  // ── Main Navigation Screens ─────────────────────────────────────────────
  testWidgets('04 Dashboard screen', (t) async {
    await pumpScreen(t, const DashboardScreen(), overrides: dashboardOverrides());
    await expectGolden(t, '04_dashboard');
  });

  testWidgets('05 Nutrition screen', (t) async {
    await pumpScreen(t, const NutritionScreen(), overrides: nutritionOverrides());
    await expectGolden(t, '05_nutrition');
  });

  testWidgets('06 Health screen', (t) async {
    await pumpScreen(t, const HealthScreen(), overrides: healthOverrides());
    await expectGolden(t, '06_health');
  });

  testWidgets('07 More screen', (t) async {
    await pumpScreen(t, const MoreScreen(), overrides: baseOverrides());
    await expectGolden(t, '07_more');
  });

  // ── Health Sub-screens ──────────────────────────────────────────────────
  testWidgets('08 Hydration screen', (t) async {
    await pumpScreen(t, const HydrationScreen(), overrides: hydrationOverrides());
    await expectGolden(t, '08_hydration');
  });

  testWidgets('09 Weight screen', (t) async {
    await pumpScreen(t, const WeightScreen(), overrides: weightOverrides());
    await expectGolden(t, '09_weight');
  });

  testWidgets('10 Exercise screen', (t) async {
    await pumpScreen(t, const ExerciseScreen(), overrides: healthOverrides());
    await expectGolden(t, '10_exercise');
  });

  testWidgets('11 Sleep screen', (t) async {
    await pumpScreen(t, const SleepScreen(), overrides: healthOverrides());
    await expectGolden(t, '11_sleep');
  });

  testWidgets('12 Mood screen', (t) async {
    await pumpScreen(t, const MoodScreen(), overrides: healthOverrides());
    await expectGolden(t, '12_mood');
  });

  testWidgets('13 Symptom screen', (t) async {
    await pumpScreen(t, const SymptomScreen(), overrides: healthOverrides());
    await expectGolden(t, '13_symptoms');
  });

  testWidgets('14 Medication screen', (t) async {
    await pumpScreen(t, const MedicationScreen(), overrides: healthOverrides());
    await expectGolden(t, '14_medications');
  });

  testWidgets('15 Supplement screen', (t) async {
    await pumpScreen(t, const SupplementScreen(), overrides: healthOverrides());
    await expectGolden(t, '15_supplements');
  });

  testWidgets('16 Vitals screen', (t) async {
    await pumpScreen(t, const VitalsScreen(), overrides: healthOverrides());
    await expectGolden(t, '16_vitals');
  });

  // ── Eczema & Skin ───────────────────────────────────────────────────────
  testWidgets('17 Eczema screen', (t) async {
    await pumpScreen(t, const EczemaScreen(), overrides: healthOverrides());
    await expectGolden(t, '17_eczema');
  });

  testWidgets('18 Skin Photos screen', (t) async {
    await pumpScreen(t, const SkinPhotosScreen(), overrides: baseOverrides());
    await expectGolden(t, '18_skin_photos');
  });

  testWidgets('19 Products screen', (t) async {
    await pumpScreen(t, const ProductsScreen(), overrides: baseOverrides());
    await expectGolden(t, '19_products');
  });

  testWidgets('20 Insights screen', (t) async {
    await pumpScreen(t, const InsightsScreen(), overrides: baseOverrides());
    await expectGolden(t, '20_insights');
  });

  // ── Tracking & History ──────────────────────────────────────────────────
  testWidgets('21 Entries (History) screen', (t) async {
    await pumpScreen(t, const EntriesScreen(), overrides: baseOverrides());
    await expectGolden(t, '21_entries');
  });

  testWidgets('22 Analytics screen', (t) async {
    await pumpScreen(t, const AnalyticsScreen(), overrides: baseOverrides());
    await expectGolden(t, '22_analytics');
  });

  testWidgets('23 Lab Results screen', (t) async {
    await pumpScreen(t, const LabScreen(), overrides: baseOverrides());
    await expectGolden(t, '23_lab_results');
  });

  // ── Intelligence & AI ───────────────────────────────────────────────────
  testWidgets('24 Health Twin screen', (t) async {
    await pumpScreen(t, const HealthIntelligenceScreen(), overrides: baseOverrides());
    await expectGolden(t, '24_health_twin');
  });

  testWidgets('25 Health Timeline screen', (t) async {
    await pumpScreen(t, const HealthTimelineScreen(), overrides: baseOverrides());
    await expectGolden(t, '25_health_timeline');
  });

  // ── Finance & Grocery ───────────────────────────────────────────────────
  testWidgets('26 Grocery screen', (t) async {
    await pumpScreen(t, const GroceryScreen(), overrides: baseOverrides());
    await expectGolden(t, '26_grocery');
  });

  testWidgets('27 Finance screen', (t) async {
    await pumpScreen(t, const FinanceScreen(), overrides: baseOverrides());
    await expectGolden(t, '27_finance');
  });

  // ── Social ──────────────────────────────────────────────────────────────
  testWidgets('28 Social Hub screen', (t) async {
    await pumpScreen(t, const SocialHubScreen(), overrides: baseOverrides());
    await expectGolden(t, '28_social_hub');
  });

  // ── Settings & Profile ──────────────────────────────────────────────────
  testWidgets('29 Profile screen', (t) async {
    await pumpScreen(t, const ProfileScreen(), overrides: baseOverrides());
    await expectGolden(t, '29_profile');
  });

  testWidgets('30 Family screen', (t) async {
    await pumpScreen(t, const FamilyScreen(), overrides: baseOverrides());
    await expectGolden(t, '30_family');
  });

  testWidgets('31 Notification Preferences', (t) async {
    await pumpScreen(t, const NotificationPreferencesScreen(), overrides: baseOverrides(), wrapInScaffold: false);
    await expectGolden(t, '31_notification_prefs');
  });

  testWidgets('32 Connected Devices screen', (t) async {
    await pumpScreen(t, const ConnectedDevicesScreen(), overrides: baseOverrides());
    await expectGolden(t, '32_connected_devices');
  });

  testWidgets('33 Import Data screen', (t) async {
    await pumpScreen(t, const ImportScreen(), overrides: baseOverrides());
    await expectGolden(t, '33_import_data');
  });
}
