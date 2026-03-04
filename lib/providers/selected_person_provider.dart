import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Global selected person context.
/// 'self' = logged-in user; any other string = family_member.id.
/// Changing this causes all person-aware screens to rebuild/refetch.
final selectedPersonProvider = StateProvider<String>((ref) => 'self');
