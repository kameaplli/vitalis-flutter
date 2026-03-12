import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'providers/theme_provider.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Read onboarding pref synchronously (fast, local SharedPrefs)
  final prefs = await SharedPreferences.getInstance();
  final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
  // Launch app immediately — notification init runs in background
  NotificationService.init(); // fire-and-forget, non-blocking
  runApp(ProviderScope(
    overrides: [
      onboardingCompleteProvider.overrideWith((ref) => onboardingDone),
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
    return MaterialApp.router(
      title: 'Vitalis',
      theme: AppTheme.forSkin(skin),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
