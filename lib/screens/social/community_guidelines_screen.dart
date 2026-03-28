import 'package:flutter/material.dart';

/// Community guidelines screen — displays rules and expectations
/// for participating in the social community.
class CommunityGuidelinesScreen extends StatelessWidget {
  const CommunityGuidelinesScreen({super.key});

  static const _guidelines = [
    _Guideline(
      icon: Icons.favorite_rounded,
      title: 'Be Kind & Supportive',
      description:
          'This is a health & wellness community. Encourage others on their '
          'journey. Celebrate wins, big and small.',
      color: Color(0xFFE53935),
    ),
    _Guideline(
      icon: Icons.verified_rounded,
      title: 'Share Accurate Information',
      description:
          'Don\'t share medical advice or unverified health claims. If you\'re '
          'unsure, say so. Always recommend consulting a professional.',
      color: Color(0xFF1E88E5),
    ),
    _Guideline(
      icon: Icons.shield_rounded,
      title: 'Respect Privacy',
      description:
          'Don\'t share others\' personal health data without their consent. '
          'What\'s shared in groups stays in groups.',
      color: Color(0xFF43A047),
    ),
    _Guideline(
      icon: Icons.block_rounded,
      title: 'No Harassment or Hate',
      description:
          'Zero tolerance for bullying, hate speech, discrimination, or '
          'targeting individuals based on their health conditions.',
      color: Color(0xFFF4511E),
    ),
    _Guideline(
      icon: Icons.no_food_rounded,
      title: 'No Diet Shaming',
      description:
          'Everyone\'s nutritional needs and choices are different. Don\'t '
          'criticize others\' food choices, body size, or health approaches.',
      color: Color(0xFF8E24AA),
    ),
    _Guideline(
      icon: Icons.sell_outlined,
      title: 'No Spam or Promotion',
      description:
          'Don\'t promote products, services, or MLMs. Genuine recommendations '
          'are welcome — sales pitches are not.',
      color: Color(0xFFFF8F00),
    ),
    _Guideline(
      icon: Icons.flag_rounded,
      title: 'Report Concerns',
      description:
          'If you see content that violates these guidelines, use the report '
          'button. Our team reviews all reports within 24 hours.',
      color: Color(0xFF00897B),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Community Guidelines'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  cs.primary.withValues(alpha: 0.1),
                  cs.tertiary.withValues(alpha: 0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                Icon(Icons.groups_rounded, size: 48, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  'Our Community Values',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'QorHealth is a supportive space for everyone on their '
                  'health journey. These guidelines help us maintain a '
                  'positive, safe, and helpful community.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Guidelines
          ...List.generate(_guidelines.length, (i) {
            final g = _guidelines[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      color: g.color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(g.icon, size: 20, color: g.color),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          g.title,
                          style: tt.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          g.description,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),

          // Footer
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: cs.errorContainer.withValues(alpha: 0.3),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 20,
                    color: cs.error),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Violations may result in content removal, temporary '
                    'muting, or account suspension.',
                    style: tt.bodySmall?.copyWith(
                      color: cs.onErrorContainer,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _Guideline {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _Guideline({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}
