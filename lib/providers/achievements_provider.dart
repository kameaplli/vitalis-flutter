import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/constants.dart';
import '../widgets/achievement_badges.dart';

class AchievementsData {
  final List<AchievementBadge> badges;
  final AchievementStats stats;

  const AchievementsData({required this.badges, required this.stats});
}

final achievementsProvider = FutureProvider<AchievementsData>((ref) async {
  ref.keepAlive();
  final resp = await apiClient.dio.get(ApiConstants.achievements);
  final data = resp.data as Map<String, dynamic>;
  final badges = (data['badges'] as List)
      .map((b) => AchievementBadge.fromJson(b as Map<String, dynamic>))
      .toList();
  final stats = AchievementStats.fromJson(data['stats'] as Map<String, dynamic>);
  return AchievementsData(badges: badges, stats: stats);
});
