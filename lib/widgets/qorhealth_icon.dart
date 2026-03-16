import 'package:flutter/material.dart';

/// A polished icon with a solid colored circular background and white icon.
///
/// Matches the modern app icon style: fully opaque colored circle with a
/// contrasting white (or custom) icon inside. Supports two sizes:
/// - [QorhealthIconSize.medium] — 40px circle, 20px icon (for list tiles, cards)
/// - [QorhealthIconSize.large] — 52px circle, 26px icon (for action tiles, grids)
///
/// Usage:
/// ```dart
/// QorhealthIcon(icon: Icons.restaurant, color: Colors.blue)
/// QorhealthIcon(icon: Icons.water_drop, color: Colors.cyan, size: QorhealthIconSize.large)
/// ```
enum QorhealthIconSize { small, medium, large }

class QorhealthIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final QorhealthIconSize size;
  final Color? iconColor;

  const QorhealthIcon({
    super.key,
    required this.icon,
    required this.color,
    this.size = QorhealthIconSize.medium,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final double circleSize;
    final double iconSize;

    switch (size) {
      case QorhealthIconSize.small:
        circleSize = 32;
        iconSize = 16;
      case QorhealthIconSize.medium:
        circleSize = 40;
        iconSize = 20;
      case QorhealthIconSize.large:
        circleSize = 52;
        iconSize = 26;
    }

    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: iconSize,
        color: iconColor ?? Colors.white,
      ),
    );
  }
}
