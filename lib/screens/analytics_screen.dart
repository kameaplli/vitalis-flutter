import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/selected_person_provider.dart';

/// Analytics dashboard — central hub linking to all analytics views.
class AnalyticsScreen extends ConsumerWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    ref.watch(selectedPersonProvider);

    final sections = [
      _AnalyticsSection(
        icon: Icons.restaurant,
        label: 'Nutrition Analytics',
        subtitle: 'Macro breakdown, calorie trends, meal patterns',
        color: const Color(0xFF059669),
        onTap: () => context.push('/nutrition'),
      ),
      _AnalyticsSection(
        icon: Icons.psychology,
        label: 'Health Intelligence',
        subtitle: 'AI-powered health analysis and correlations',
        color: const Color(0xFF7C3AED),
        onTap: () => context.push('/health-intelligence'),
      ),
      _AnalyticsSection(
        icon: Icons.insights,
        label: 'AI Insights',
        subtitle: 'Weekly summaries, flare risk, investigations',
        color: const Color(0xFFF59E0B),
        onTap: () => context.push('/insights'),
      ),
      _AnalyticsSection(
        icon: Icons.water_drop,
        label: 'Hydration Trends',
        subtitle: 'Daily intake vs goals, consistency tracking',
        color: const Color(0xFF0EA5E9),
        onTap: () => context.push('/hydration'),
      ),
      _AnalyticsSection(
        icon: Icons.monitor_weight,
        label: 'Weight Progress',
        subtitle: 'Weight chart, BMI bands, ideal line',
        color: const Color(0xFF2563EB),
        onTap: () => context.push('/health/weight'),
      ),
      _AnalyticsSection(
        icon: Icons.biotech,
        label: 'Lab Results',
        subtitle: 'Biomarker trends, reference ranges',
        color: const Color(0xFFD32F2F),
        onTap: () => context.push('/health/labs'),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics Dashboard')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final s = sections[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: s.color.withValues(alpha: 0.15),
                child: Icon(s.icon, color: s.color),
              ),
              title: Text(s.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(s.subtitle, style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
              trailing: Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
              onTap: s.onTap,
            ),
          );
        },
      ),
    );
  }
}

class _AnalyticsSection {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _AnalyticsSection({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}
