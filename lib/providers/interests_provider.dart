import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Available interest modules the user can select during onboarding.
class UserInterest {
  final String id;
  final String label;
  final String description;
  final bool alwaysOn; // Cannot be deselected (e.g. Nutrition)

  const UserInterest({
    required this.id,
    required this.label,
    required this.description,
    this.alwaysOn = false,
  });
}

const kAllInterests = [
  UserInterest(
    id: 'nutrition',
    label: 'Nutrition Tracking',
    description: 'Log meals, track calories & macros',
    alwaysOn: true,
  ),
  UserInterest(
    id: 'eczema',
    label: 'Eczema Tracking',
    description: 'Track flares, triggers & skin photos',
  ),
  UserInterest(
    id: 'family',
    label: 'Family Health',
    description: 'Manage health for family members',
  ),
  UserInterest(
    id: 'weight',
    label: 'Weight Tracking',
    description: 'Monitor weight trends over time',
  ),
  UserInterest(
    id: 'hydration',
    label: 'Hydration Tracking',
    description: 'Track daily water intake',
  ),
];

const _kPrefsKey = 'user_interests';

/// Whether the user has completed the interests selection step.
/// Initialized via provider override in main.dart.
final interestsCompleteProvider = StateProvider<bool>((ref) => false);

/// The set of selected interest IDs.
/// Initialized via provider override in main.dart.
final userInterestsProvider = StateProvider<Set<String>>((ref) => {'nutrition'});

/// Read interests from SharedPreferences. Returns null if not yet set.
Future<Set<String>?> loadUserInterests() async {
  final prefs = await SharedPreferences.getInstance();
  final json = prefs.getString(_kPrefsKey);
  if (json == null) return null;
  final list = (jsonDecode(json) as List).cast<String>();
  return list.toSet();
}

/// Save interests to SharedPreferences.
Future<void> saveUserInterests(Set<String> interests) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_kPrefsKey, jsonEncode(interests.toList()));
}

/// Check if a specific interest is enabled.
bool hasInterest(Set<String> interests, String id) {
  return interests.contains(id);
}
