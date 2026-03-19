import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global selected person context.
/// 'self' = logged-in user; any other string = family_member.id.
/// Changing this causes all person-aware screens to rebuild/refetch.
final selectedPersonProvider = StateProvider<String>((ref) {
  ref.keepAlive();
  return 'self';
});

/// When true, AppShell hides avatar bar + bottom nav so welcome screen
/// can render edge-to-edge with its gradient background.
final welcomeOverlayProvider = StateProvider<bool>((ref) {
  ref.keepAlive();
  return true;
});
