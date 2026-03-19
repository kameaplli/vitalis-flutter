import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/environment_data.dart';

/// Fetch current environment conditions for a lat/lon (and store server-side).
final currentEnvironmentProvider = FutureProvider.family<EnvironmentData?, ({double lat, double lon})>(
  (ref, params) async {
    ref.keepAlive();
    try {
      final res = await apiClient.dio.get(
        ApiConstants.environmentCurrent,
        queryParameters: {'lat': params.lat, 'lon': params.lon},
      );
      return EnvironmentData.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);

/// Environment-eczema correlation analysis.
final environmentCorrelationProvider = FutureProvider.family<EnvironmentCorrelation?, ({int days, String person})>(
  (ref, params) async {
    ref.keepAlive();
    try {
      final qp = <String, dynamic>{'days': params.days};
      if (params.person != 'self') {
        qp['family_member_id'] = params.person;
      }
      final res = await apiClient.dio.get(
        ApiConstants.environmentCorrelation,
        queryParameters: qp,
      );
      return EnvironmentCorrelation.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);

/// Today's flare risk score.
final flareRiskProvider = FutureProvider.family<FlareRisk?, ({double lat, double lon})>(
  (ref, params) async {
    ref.keepAlive();
    try {
      final res = await apiClient.dio.get(
        ApiConstants.environmentFlareRisk,
        queryParameters: {'lat': params.lat, 'lon': params.lon},
      );
      return FlareRisk.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);

/// Environment history for the past N days.
final environmentHistoryProvider = FutureProvider.family<List<EnvironmentData>, int>(
  (ref, days) async {
    ref.keepAlive();
    try {
      final res = await apiClient.dio.get(
        ApiConstants.environmentHistory,
        queryParameters: {'days': days},
      );
      return (res.data as List<dynamic>)
          .map((e) => EnvironmentData.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  },
);
