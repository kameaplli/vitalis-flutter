import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/interests_provider.dart';
import 'providers/theme_provider.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase first (required by Crashlytics, FCM)
  await Firebase.initializeApp();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Parallelize all remaining startup work for faster launch
  late final SharedPreferences prefs;
  late final Set<String>? savedInterests;
  await Future.wait([
    SharedPreferences.getInstance().then((p) => prefs = p),
    loadUserInterests().then((i) => savedInterests = i),
    NotificationService.init().catchError((_) {}),
    FcmService.init().catchError((_) {}),
  ]);

  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  final interestsDone = savedInterests != null;
  runApp(ProviderScope(
    overrides: [
      onboardingCompleteProvider.overrideWith((ref) => onboardingDone),
      interestsCompleteProvider.overrideWith((ref) => interestsDone),
      if (savedInterests != null)
        userInterestsProvider.overrideWith((ref) => savedInterests!),
    ],
    child: const VitalisApp(),
  ));
}

class VitalisApp extends ConsumerWidget {
  const VitalisApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final skin = ref.watch(themeProvider);
    final isDark = ref.watch(darkModeProvider);
    return MaterialApp.router(
      title: 'Vitalis',
      theme: AppTheme.forSkin(skin, darkMode: isDark),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
