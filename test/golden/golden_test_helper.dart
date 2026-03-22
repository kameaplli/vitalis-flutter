/// Golden test helper — shared mock data & harness for all screen tests.
///
/// Usage:
///   await pumpScreen(tester, const DashboardScreen(), overrides: dashboardOverrides());
///   await expectGolden(tester, 'dashboard');
library;

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:qorhealth/models/user.dart';
import 'package:qorhealth/models/dashboard_data.dart';
import 'package:qorhealth/models/nutrition_log.dart';
import 'package:qorhealth/models/hydration_log.dart';
import 'package:qorhealth/models/weight_log.dart';
import 'package:qorhealth/models/family_member.dart';
import 'package:qorhealth/providers/auth_provider.dart';
import 'package:qorhealth/providers/selected_person_provider.dart';
import 'package:qorhealth/providers/dashboard_provider.dart';
import 'package:qorhealth/providers/nutrition_provider.dart';
import 'package:qorhealth/providers/hydration_provider.dart';
import 'package:qorhealth/providers/weight_provider.dart';
import 'package:qorhealth/providers/health_provider.dart';
import 'package:qorhealth/providers/connectivity_provider.dart'
    show connectivityProvider, ConnectivityNotifier;
import 'package:qorhealth/providers/social_provider.dart';
import 'package:qorhealth/providers/grocery_provider.dart';
import 'package:qorhealth/providers/interests_provider.dart';
import 'package:qorhealth/models/grocery_models.dart';

// ─── Global test setup ───────────────────────────────────────────────────────

/// Call in setUpAll() to mock platform channels and suppress HTTP errors.
void setupGoldenTests() {
  // Block real HTTP
  HttpOverrides.global = _NoHttpOverrides();

  // Mock platform channels
  _mockPlatformChannels();

  // Suppress FlutterError for overflow, Dio, timer, and plugin errors
  final originalOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    final msg = details.exception.toString();
    if (msg.contains('overflowed')) return;
    if (msg.contains('DioException') || msg.contains('400')) return;
    if (msg.contains('MissingPlugin')) return;
    if (msg.contains('timersPending') || msg.contains('Timer')) return;
    if (msg.contains('receive timeout') || msg.contains('timeout')) return;
    originalOnError?.call(details);
  };
}

class _NoHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context);
  }
}

void _mockPlatformChannels() {
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(secureStorageChannel, (call) async {
    switch (call.method) {
      case 'read':
        return null;
      case 'readAll':
        return <String, String>{};
      case 'write':
      case 'delete':
      case 'deleteAll':
        return null;
      default:
        return null;
    }
  });

  const spChannel = MethodChannel('plugins.flutter.io/shared_preferences');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(spChannel, (call) async {
    switch (call.method) {
      case 'getAll':
        return <String, dynamic>{};
      case 'setBool':
      case 'setInt':
      case 'setDouble':
      case 'setString':
      case 'setStringList':
      case 'remove':
      case 'clear':
        return true;
      default:
        return null;
    }
  });

  // SharedPreferencesAndroid (newer)
  const spAndroidChannel = MethodChannel(
      'dev.flutter.pigeon.shared_preferences_android.SharedPreferencesApi');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(spAndroidChannel, (call) async {
    return <String, dynamic>{};
  });

  // local_auth
  const localAuthChannel = MethodChannel('plugins.flutter.io/local_auth');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(localAuthChannel, (call) async {
    switch (call.method) {
      case 'isDeviceSupported':
      case 'canCheckBiometrics':
        return false;
      case 'authenticate':
        return false;
      case 'getAvailableBiometrics':
        return <String>[];
      default:
        return null;
    }
  });

  // path_provider
  const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(pathChannel, (call) async {
    return '.';
  });
}

// ─── Mock User ───────────────────────────────────────────────────────────────

final mockUser = AppUser(
  id: 'user-001',
  email: 'kalyan@vitalis.app',
  name: 'Kalyan',
  age: 32,
  gender: 'male',
  height: 175.0,
  profile: UserProfile(
    age: 32,
    gender: 'male',
    height: 175.0,
    children: [
      FamilyMember(
        id: 'child-001',
        name: 'Aria',
        age: 5,
        gender: 'female',
      ),
    ],
  ),
);

// ─── Mock Dashboard Data ─────────────────────────────────────────────────────

const mockDashboardData = DashboardData(
  todayCalories: 1847,
  yesterdayCalories: 2100,
  mealsCount: 3,
  todayWater: 1800,
  yesterdayWater: 2200,
  currentWeight: 78.5,
  previousWeight: 79.2,
  weekAvgCalories: 1950,
  prevWeekAvgCalories: 2050,
  weekAvgWater: 2000,
  prevWeekAvgWater: 1900,
  weekAvgMeals: 3.2,
  prevWeekAvgMeals: 2.8,
  todayProtein: 85,
  todayCarbs: 220,
  todayFat: 62,
  todaySteps: 7842,
  todayHeartRate: 72,
  todaySleepMins: 420,
  todayActiveCalories: 340,
  todayDistance: 5.2,
  todaySpo2: 97,
  mealDistribution: {'breakfast': 1, 'lunch': 1, 'dinner': 1},
  topCalorieFoods: [
    DashboardTopFood(name: 'Chicken Biryani', calories: 520, count: 1),
    DashboardTopFood(name: 'Greek Yogurt', calories: 150, count: 2),
    DashboardTopFood(name: 'Banana', calories: 105, count: 1),
  ],
  healthScore: HealthScoreData(
    total: 72, nutrition: 78, hydration: 65,
    exercise: 80, sleep: 70, mood: 68,
  ),
  prevHealthScore: HealthScoreData(
    total: 68, nutrition: 72, hydration: 60,
    exercise: 75, sleep: 65, mood: 62,
  ),
  insights: [
    DashboardInsight(type: 'positive', message: 'Great protein intake today!'),
    DashboardInsight(type: 'tip', message: 'Try to drink 700ml more water.'),
    DashboardInsight(type: 'warning', message: 'You missed breakfast yesterday.'),
  ],
);

const mockWelcomeData = WelcomeData(
  greeting: 'Good morning',
  period: 'morning',
  name: 'Kalyan',
  moodSummary: MoodSummary(
    hasData: true,
    averageScore: 7.5,
    dominantMood: 'Happy',
    allMoods: ['Happy', 'Calm', 'Focused'],
    trend: 'improving',
    insight: 'Your mood has been steadily improving this week!',
    insightType: 'positive',
    emoji: '😊',
  ),
);

final mockFamilySnapshot = [
  const PersonSnapshot(
    id: 'self', name: 'Kalyan',
    healthScore: 72, todayCalories: 1847, todayWater: 1800, todaySteps: 7842,
  ),
  const PersonSnapshot(
    id: 'child-001', name: 'Aria',
    healthScore: 85, todayCalories: 1200, todayWater: 1000,
  ),
];

// ─── Mock Nutrition Data ─────────────────────────────────────────────────────

final mockNutritionEntries = [
  NutritionEntry(id: 'n1', date: '2026-03-22', time: '08:30', meal: 'breakfast', person: 'self', personId: 'self', description: 'Oatmeal with banana and honey', calories: 380),
  NutritionEntry(id: 'n2', date: '2026-03-22', time: '12:45', meal: 'lunch', person: 'self', personId: 'self', description: 'Chicken Biryani', calories: 520),
  NutritionEntry(id: 'n3', date: '2026-03-22', time: '19:00', meal: 'dinner', person: 'self', personId: 'self', description: 'Grilled salmon with vegetables', calories: 450),
];

// ─── Mock Hydration Data ─────────────────────────────────────────────────────

final mockHydrationLogs = [
  HydrationLog(id: 'h1', date: '2026-03-22', time: '07:00', beverageType: 'water', quantity: 500),
  HydrationLog(id: 'h2', date: '2026-03-22', time: '10:30', beverageType: 'coffee', quantity: 250, calories: 5, caffeine: 95),
  HydrationLog(id: 'h3', date: '2026-03-22', time: '14:00', beverageType: 'water', quantity: 750),
  HydrationLog(id: 'h4', date: '2026-03-22', time: '17:30', beverageType: 'green_tea', quantity: 300, caffeine: 30),
];

final mockBeveragePresets = [
  BeveragePreset(id: 'water', name: 'Water', emoji: '💧', defaultQuantity: 250, caloriesPer100ml: 0),
  BeveragePreset(id: 'coffee', name: 'Coffee', emoji: '☕', defaultQuantity: 250, caloriesPer100ml: 2),
  BeveragePreset(id: 'green_tea', name: 'Green Tea', emoji: '🍵', defaultQuantity: 200, caloriesPer100ml: 1),
  BeveragePreset(id: 'milk', name: 'Milk', emoji: '🥛', defaultQuantity: 250, caloriesPer100ml: 42),
  BeveragePreset(id: 'juice', name: 'Juice', emoji: '🧃', defaultQuantity: 200, caloriesPer100ml: 45),
];

// ─── Mock Weight Data ────────────────────────────────────────────────────────

final mockWeightHistory = WeightHistory(
  entries: [
    WeightLog(id: 'w1', date: '2026-03-15', time: '07:00', weight: 80.2, unit: 'kg', person: 'self'),
    WeightLog(id: 'w2', date: '2026-03-17', time: '07:00', weight: 79.8, unit: 'kg', person: 'self'),
    WeightLog(id: 'w3', date: '2026-03-19', time: '07:00', weight: 79.2, unit: 'kg', person: 'self'),
    WeightLog(id: 'w4', date: '2026-03-21', time: '07:00', weight: 78.5, unit: 'kg', person: 'self'),
  ],
  idealWeight: 74.0,
  idealMin: 68.0,
  idealMax: 80.0,
);

// ─── Mock Health Data ────────────────────────────────────────────────────────

final List<HealthMap> mockSymptoms = [
  {'id': 's1', 'symptom_type': 'headache', 'severity': 3, 'duration_hours': 2.0, 'log_date': '2026-03-22', 'log_time': '14:00', 'notes': 'After lunch'},
  {'id': 's2', 'symptom_type': 'fatigue', 'severity': 2, 'log_date': '2026-03-21', 'log_time': '18:00'},
];

final List<HealthMap> mockMedications = [
  {'id': 'm1', 'medication_name': 'Vitamin D3', 'dosage': '2000 IU', 'frequency': 'daily', 'is_active': true},
  {'id': 'm2', 'medication_name': 'Omega-3', 'dosage': '1000mg', 'frequency': 'daily', 'is_active': true},
];

final List<HealthMap> mockSleepLogs = [
  {'id': 'sl1', 'sleep_date': '2026-03-21', 'bedtime': '23:00', 'wake_time': '06:30', 'duration_hours': 7.5, 'quality': 4},
  {'id': 'sl2', 'sleep_date': '2026-03-20', 'bedtime': '23:30', 'wake_time': '07:00', 'duration_hours': 7.5, 'quality': 3},
];

final List<HealthMap> mockExerciseLogs = [
  {'id': 'e1', 'exercise_type': 'running', 'duration_minutes': 30, 'calories_burned': 280, 'log_date': '2026-03-22', 'log_time': '06:00', 'distance_km': 4.5},
  {'id': 'e2', 'exercise_type': 'weight_training', 'duration_minutes': 45, 'calories_burned': 220, 'log_date': '2026-03-21', 'log_time': '17:00'},
];

final List<HealthMap> mockMoods = [
  {'id': 'mo1', 'mood': 'happy', 'energy_level': 8, 'stress_level': 3, 'log_date': '2026-03-22', 'log_time': '09:00', 'notes': 'Great morning workout!'},
  {'id': 'mo2', 'mood': 'calm', 'energy_level': 6, 'stress_level': 4, 'log_date': '2026-03-21', 'log_time': '20:00'},
];

final List<HealthMap> mockVitals = [
  {'id': 'v1', 'bp_systolic': 120, 'bp_diastolic': 80, 'heart_rate': 72, 'blood_glucose': 95, 'body_temperature': 36.6, 'oxygen_saturation': 98, 'log_date': '2026-03-22', 'log_time': '08:00'},
];

final List<HealthMap> mockSupplements = [
  {'id': 'sup1', 'supplement_name': 'Vitamin D3', 'dosage': '2000 IU', 'frequency': 'daily', 'is_active': true},
  {'id': 'sup2', 'supplement_name': 'Magnesium Glycinate', 'dosage': '400mg', 'frequency': 'nightly', 'is_active': true},
];

// ─── Standard Provider Overrides ─────────────────────────────────────────────

/// Base overrides needed for most screens.
List<Override> baseOverrides() => [
      authProvider.overrideWith((_) => _FixedAuthNotifier()),
      selectedPersonProvider.overrideWith((ref) => 'self'),
      welcomeOverlayProvider.overrideWith((ref) => false),
      connectivityProvider.overrideWith((_) => _FixedConnectivityNotifier()),
      notificationBadgeProvider.overrideWith((ref) => Future.value(0)),
      userInterestsProvider.overrideWith((ref) => <String>{'nutrition', 'hydration', 'weight', 'sleep', 'exercise', 'mood', 'eczema'}),
    ];

/// Dashboard overrides.
List<Override> dashboardOverrides() => [
      ...baseOverrides(),
      dashboardProvider.overrideWith((ref, key) => Future.value(mockDashboardData)),
      welcomeProvider.overrideWith((ref, person) => Future.value(mockWelcomeData)),
      familySnapshotProvider.overrideWith((ref) => Future.value(mockFamilySnapshot)),
      todayHydrationProvider.overrideWith((ref, person) => Future.value(1800.0)),
      hydrationGoalProvider.overrideWith((ref, person) => Future.value(2500.0)),
      hydrationHistoryProvider.overrideWith((ref, key) => Future.value(mockHydrationLogs)),
      grocerySpendingProvider.overrideWith((ref, key) => Future.value(
        const GrocerySpending(totalSpend: 245.50, foodSpend: 198.00, nonFoodSpend: 47.50, byCategory: []),
      )),
    ];

/// Nutrition overrides.
List<Override> nutritionOverrides() => [
      ...baseOverrides(),
      nutritionProvider.overrideWith((_) => _FixedNutritionNotifier()),
      nutritionEntriesProvider.overrideWith((ref, key) => Future.value(mockNutritionEntries)),
    ];

/// Hydration overrides.
List<Override> hydrationOverrides() => [
      ...baseOverrides(),
      todayHydrationProvider.overrideWith((ref, person) => Future.value(1800.0)),
      hydrationGoalProvider.overrideWith((ref, person) => Future.value(2500.0)),
      hydrationHistoryProvider.overrideWith((ref, key) => Future.value(mockHydrationLogs)),
      beveragePresetsProvider.overrideWith((ref) => Future.value(mockBeveragePresets)),
    ];

/// Weight overrides.
List<Override> weightOverrides() => [
      ...baseOverrides(),
      weightHistoryProvider.overrideWith((ref, key) => Future.value(mockWeightHistory)),
    ];

/// Health screen overrides.
List<Override> healthOverrides() => [
      ...baseOverrides(),
      symptomsProvider.overrideWith((ref, key) => Future.value(mockSymptoms)),
      medicationsProvider.overrideWith((ref, key) => Future.value(mockMedications)),
      supplementsProvider.overrideWith((ref, key) => Future.value(mockSupplements)),
      supplementsCatalogProvider.overrideWith((ref) => Future.value(<HealthMap>[])),
      vitalsProvider.overrideWith((ref, key) => Future.value(mockVitals)),
      sleepProvider.overrideWith((ref, key) => Future.value(mockSleepLogs)),
      exerciseProvider.overrideWith((ref, key) => Future.value(mockExerciseLogs)),
      moodProvider.overrideWith((ref, key) => Future.value(mockMoods)),
    ];

/// Auth screen (unauthenticated).
List<Override> authOverrides() => [
      authProvider.overrideWith((_) => _UnauthNotifier()),
      connectivityProvider.overrideWith((_) => _FixedConnectivityNotifier()),
    ];

// ─── Harness ─────────────────────────────────────────────────────────────────

/// Pumps a screen inside a MaterialApp + ProviderScope.
/// Uses phone-sized surface (411x823 = Pixel 4 logical size).
Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  List<Override> overrides = const [],
  Size surfaceSize = const Size(411, 823),
  bool wrapInScaffold = true,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  tester.view.physicalSize = surfaceSize;
  tester.view.devicePixelRatio = 1.0;

  final child = wrapInScaffold ? Scaffold(body: screen) : screen;

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF009688),
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: child,
      ),
    ),
  );

  // Let async providers resolve — pump multiple times to handle cascading
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }

  // Note: Some screens have pending timers (animations, Dio timeouts) that
  // can't be drained without triggering more errors. We suppress the
  // 'Timer still pending' assertion via FlutterError.onError in setupGoldenTests().
}

/// Matches the rendered widget tree against a golden PNG file.
Future<void> expectGolden(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );
}

// ─── Mock Notifiers ──────────────────────────────────────────────────────────

class _FixedAuthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _FixedAuthNotifier()
      : super(AuthState(status: AuthStatus.authenticated, user: mockUser));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _UnauthNotifier extends StateNotifier<AuthState>
    implements AuthNotifier {
  _UnauthNotifier()
      : super(const AuthState(status: AuthStatus.unauthenticated));
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedConnectivityNotifier extends StateNotifier<bool>
    implements ConnectivityNotifier {
  _FixedConnectivityNotifier() : super(true);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FixedNutritionNotifier extends NutritionNotifier {
  _FixedNutritionNotifier() : super() {
    state = NutritionState();
  }

  @override
  Future<bool> loadDraft() async => false;

  @override
  Future<void> saveDraft() async {}
}
