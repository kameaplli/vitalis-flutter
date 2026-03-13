import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/interests_provider.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read onboarding pref synchronously (fast, local SharedPrefs)
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  // Read user interests (null = not yet selected)
  final savedInterests = await loadUserInterests();
  final interestsDone = savedInterests != null;
  // Launch app immediately — notification init runs in background
  NotificationService.init(); // fire-and-forget, non-blocking
  runApp(ProviderScope(
    overrides: [
      onboardingCompleteProvider.overrideWith((ref) => onboardingDone),
      interestsCompleteProvider.overrideWith((ref) => interestsDone),
      if (savedInterests != null)
        userInterestsProvider.overrideWith((ref) => savedInterests),
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
