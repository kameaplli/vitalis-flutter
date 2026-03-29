import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// A polished icon with a solid colored circular background and white icon.
///
/// Accepts either a Material [IconData] via [icon] or a HugeIcons
/// [List<List<dynamic>>] via [hugeIcon]. If both are provided, [hugeIcon]
/// takes precedence.
enum QoreHealthIconSize { small, medium, large }

class QoreHealthIcon extends StatelessWidget {
  final IconData? icon;
  final List<List<dynamic>>? hugeIcon;
  final Color color;
  final QoreHealthIconSize size;
  final Color? iconColor;

  const QoreHealthIcon({
    super.key,
    this.icon,
    this.hugeIcon,
    required this.color,
    this.size = QoreHealthIconSize.medium,
    this.iconColor,
  }) : assert(icon != null || hugeIcon != null, 'Either icon or hugeIcon must be provided');

  @override
  Widget build(BuildContext context) {
    final double circleSize;
    final double iconSize;

    switch (size) {
      case QoreHealthIconSize.small:
        circleSize = 32;
        iconSize = 16;
      case QoreHealthIconSize.medium:
        circleSize = 40;
        iconSize = 20;
      case QoreHealthIconSize.large:
        circleSize = 52;
        iconSize = 26;
    }

    final effectiveColor = iconColor ?? Colors.white;

    return Container(
      width: circleSize,
      height: circleSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: hugeIcon != null
          ? Center(child: HugeIcon(icon: hugeIcon!, size: iconSize, color: effectiveColor))
          : Icon(icon, size: iconSize, color: effectiveColor),
    );
  }
}
