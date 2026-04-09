import 'package:flutter/material.dart';

/// A shimmer effect widget that sweeps a gradient across its child.
class _ShimmerEffect extends StatefulWidget {
  final Widget child;
  const _ShimmerEffect({required this.child});

  @override
  State<_ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<_ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
    final highlightColor =
        isDark ? const Color(0xFF3A3A3A) : const Color(0xFFF5F5F5);

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [baseColor, highlightColor, baseColor],
              stops: [
                (_ctrl.value - 0.3).clamp(0.0, 1.0),
                _ctrl.value,
                (_ctrl.value + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(bounds);
          },
          blendMode: BlendMode.srcATop,
          child: widget.child,
        );
      },
    );
  }
}

/// A single skeleton card — rounded rectangle with shimmer.
class SkeletonCard extends StatelessWidget {
  final double height;
  final double? width;
  final EdgeInsets margin;
  final BorderRadius? borderRadius;

  const SkeletonCard({
    super.key,
    this.height = 80,
    this.width,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _ShimmerEffect(
      child: Container(
        height: height,
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
          borderRadius: borderRadius ?? BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// Skeleton that mimics the dashboard layout:
/// 2 small cards + 1 large card + 2 small cards + 1 large card.
class SkeletonDashboard extends StatelessWidget {
  const SkeletonDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 12),
      children: [
        // Quick actions placeholder
        const SkeletonCard(height: 48),

        // Daily progress rings placeholder
        const SkeletonCard(height: 140),

        // 2 small stat cards (row 1)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _ShimmerEffect(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _baseColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerEffect(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _baseColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2 small stat cards (row 2)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: _ShimmerEffect(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _baseColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ShimmerEffect(
                  child: Container(
                    height: 110,
                    decoration: BoxDecoration(
                      color: _baseColor(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Hydration quick log placeholder
        const SkeletonCard(height: 80),

        // Macros card placeholder
        const SkeletonCard(height: 120),

        // Health score placeholder
        const SkeletonCard(height: 100),
      ],
    );
  }

  static Color _baseColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);
  }
}

/// Skeleton that mimics a list with 5 placeholder items (circle + 2 lines).
class SkeletonList extends StatelessWidget {
  final int itemCount;

  const SkeletonList({super.key, this.itemCount = 5});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: itemCount,
      itemBuilder: (context, index) => _SkeletonListItem(),
    );
  }
}

class _SkeletonListItem extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: _ShimmerEffect(
        child: Row(
          children: [
            // Circle avatar placeholder
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Two text line placeholders
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 10,
                    width: 160,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
