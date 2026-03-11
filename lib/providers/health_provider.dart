import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';

typedef HealthMap = Map<String, dynamic>;

// key = "person:days" e.g. "self:30"
String _person(String key) => key.split(':')[0].isNotEmpty ? key.split(':')[0] : 'self';
int _days(String key) => int.tryParse(key.split(':').elementAtOrNull(1) ?? '30') ?? 30;

final symptomsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.symptoms, queryParameters: {
    'person': _person(key),
    'days': _days(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final medicationsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.medications, queryParameters: {
    'person': _person(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final supplementsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.supplements, queryParameters: {
    'person': _person(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final vitalsProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.vitals, queryParameters: {
    'person': _person(key),
    'days': _days(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final sleepProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.sleep, queryParameters: {
    'person': _person(key),
    'days': _days(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final exerciseProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.exercise, queryParameters: {
    'person': _person(key),
    'days': _days(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});

final moodProvider = FutureProvider.family<List<HealthMap>, String>((ref, key) async {
  final res = await apiClient.dio.get(ApiConstants.mood, queryParameters: {
    'person': _person(key),
    'days': _days(key),
  });
  return List<HealthMap>.from(res.data['entries']);
});
