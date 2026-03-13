import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../core/provider_key.dart';

typedef HealthMap = Map<String, dynamic>;

final symptomsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.symptoms, queryParameters: {
    'person': person,
    'days': days,
  });
  return List<HealthMap>.from(res.data['entries']);
});

final medicationsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, _) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.medications, queryParameters: {
    'person': person,
  });
  return List<HealthMap>.from(res.data['entries']);
});

final supplementsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, _) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.supplements, queryParameters: {
    'person': person,
  });
  return List<HealthMap>.from(res.data['entries']);
});

/// All supplements across all family members — used as a shared catalogue.
final supplementsCatalogProvider = FutureProvider<List<HealthMap>>((ref) async {
  final res = await apiClient.dio.get(ApiConstants.supplements, queryParameters: {
    'person': 'all',
  });
  return List<HealthMap>.from(res.data['entries']);
});

final vitalsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.vitals, queryParameters: {
    'person': person,
    'days': days,
  });
  return List<HealthMap>.from(res.data['entries']);
});

final sleepProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.sleep, queryParameters: {
    'person': person,
    'days': days,
  });
  return List<HealthMap>.from(res.data['entries']);
});

final exerciseProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.exercise, queryParameters: {
    'person': person,
    'days': days,
  });
  return List<HealthMap>.from(res.data['entries']);
});

final moodProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final (person, days) = PK.personDays(key);
  final res = await apiClient.dio.get(ApiConstants.mood, queryParameters: {
    'person': person,
    'days': days,
  });
  return List<HealthMap>.from(res.data['entries']);
});
