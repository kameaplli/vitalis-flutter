import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../models/smart_correlation_data.dart';

/// Smart multi-factor food-eczema correlation (Phase 2).
final smartCorrelationProvider = FutureProvider.family<SmartCorrelationResult?, ({int days, String person})>(
  (ref, params) async {
    ref.keepAlive();
    try {
      final res = await apiClient.dio.get(
        ApiConstants.eczemaSmartCorrelation,
        queryParameters: {'days': params.days, 'person': params.person},
      );
      return SmartCorrelationResult.fromJson(res.data as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  },
);
