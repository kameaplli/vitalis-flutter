import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks whether the user has completed onboarding.
/// Initialized via provider override in main.dart.
final onboardingCompleteProvider = StateProvider<bool?>((ref) => null);
