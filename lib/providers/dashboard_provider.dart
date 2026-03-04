import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/dashboard_data.dart';

/// Family provider — keyed by person ('self' or family_member_id).
final dashboardProvider =
    FutureProvider.family<DashboardData, String>((ref, person) async {
  ref.keepAlive(); // keep cached between navigations for instant re-render
  final today = DateTime.now().toIso8601String().substring(0, 10);
  final res = await apiClient.dio.get(
    ApiConstants.dashboard,
    queryParameters: {
      if (person != 'self') 'person': person,
      'date': today,
    },
  );
  return DashboardData.fromJson(res.data);
});
