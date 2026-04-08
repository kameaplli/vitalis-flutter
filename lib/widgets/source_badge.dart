import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Small inline badge showing the data source icon and name.
///
/// Usage:
/// ```dart
/// SourceBadge(sourceId: 'fitbit')
/// SourceBadge(sourceId: 'apple_health', sourceName: 'Apple Health')
/// SourceBadge(sourceId: 'manual')
/// ```
class SourceBadge extends StatelessWidget {
  final String sourceId;
  final String? sourceName;
  final double fontSize;

  const SourceBadge({
    super.key,
    required this.sourceId,
    this.sourceName,
    this.fontSize = 11,
  });

  @override
  Widget build(BuildContext context) {
    final info = _sourceInfo(sourceId);
    final displayName = sourceName ?? info.name;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: info.color.withValues(alpha: 0.25),
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          HugeIcon(icon: info.icon, size: fontSize + 1, color: info.color),
          const SizedBox(width: 3),
          Text(
            displayName,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: info.color,
            ),
          ),
        ],
      ),
    );
  }

  static _SourceDisplayInfo _sourceInfo(String sourceId) {
    switch (sourceId.toLowerCase()) {
      case 'apple_health':
      case 'apple-health':
        return _SourceDisplayInfo(
          name: 'Apple Health',
          icon: HugeIcons.strokeRoundedFavourite,
          color: const Color(0xFFFF2D55),
        );
      case 'health_connect':
      case 'health-connect':
        return _SourceDisplayInfo(
          name: 'Health Connect',
          icon: HugeIcons.strokeRoundedFavourite,
          color: const Color(0xFF4285F4),
        );
      case 'fitbit':
        return _SourceDisplayInfo(
          name: 'Fitbit',
          icon: HugeIcons.strokeRoundedSmartWatch01,
          color: const Color(0xFF00B0B9),
        );
      case 'garmin':
        return _SourceDisplayInfo(
          name: 'Garmin',
          icon: HugeIcons.strokeRoundedSmartWatch01,
          color: const Color(0xFF007CC3),
        );
      case 'withings':
        return _SourceDisplayInfo(
          name: 'Withings',
          icon: HugeIcons.strokeRoundedBodyWeight,
          color: const Color(0xFF00C9B7),
        );
      case 'oura':
        return _SourceDisplayInfo(
          name: 'Oura',
          icon: HugeIcons.strokeRoundedNotification01,
          color: const Color(0xFFD4AF37),
        );
      case 'whoop':
        return _SourceDisplayInfo(
          name: 'WHOOP',
          icon: HugeIcons.strokeRoundedDumbbell01,
          color: const Color(0xFF1A1A1A),
        );
      case 'manual':
        return _SourceDisplayInfo(
          name: 'Manual',
          icon: HugeIcons.strokeRoundedEdit01,
          color: const Color(0xFF6B7280),
        );
      default:
        return _SourceDisplayInfo(
          name: sourceId,
          icon: HugeIcons.strokeRoundedSmartPhone01,
          color: const Color(0xFF6B7280),
        );
    }
  }
}

class _SourceDisplayInfo {
  final String name;
  final List<List<dynamic>> icon;
  final Color color;

  const _SourceDisplayInfo({
    required this.name,
    required this.icon,
    required this.color,
  });
}
