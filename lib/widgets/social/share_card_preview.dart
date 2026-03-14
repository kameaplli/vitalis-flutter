import 'package:flutter/material.dart';

/// Auto-generated gradient preview card for different shareable content types.
/// Used inside the share sheet to show what will be shared.
class ShareCardPreview extends StatelessWidget {
  final String contentType; // streak, meal, recipe, achievement
  final String title;
  final String? subtitle;
  final String? userName;

  const ShareCardPreview({
    super.key,
    required this.contentType,
    required this.title,
    this.subtitle,
    this.userName,
  });

  static const _gradients = <String, List<Color>>{
    'streak': [Color(0xFFF97316), Color(0xFFFBBF24)],
    'meal': [Color(0xFF22C55E), Color(0xFF10B981)],
    'recipe': [Color(0xFF10B981), Color(0xFF059669)],
    'achievement': [Color(0xFFFBBF24), Color(0xFFEAB308)],
    'challenge': [Color(0xFF8B5CF6), Color(0xFF6366F1)],
  };

  static const _icons = <String, IconData>{
    'streak': Icons.local_fire_department,
    'meal': Icons.restaurant,
    'recipe': Icons.menu_book,
    'achievement': Icons.emoji_events,
    'challenge': Icons.flag,
  };

  @override
  Widget build(BuildContext context) {
    final gradient = _gradients[contentType] ??
        const [Color(0xFF64748B), Color(0xFF94A3B8)];
    final icon = _icons[contentType] ?? Icons.share;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: gradient.first.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.85),
                            fontSize: 13,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (userName != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: Colors.white.withOpacity(0.7)),
                const SizedBox(width: 4),
                Text(
                  userName!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  'Vitalis',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
