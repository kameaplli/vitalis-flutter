import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// A shimmer placeholder card for loading states.
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final EdgeInsets margin;

  const ShimmerCard({
    super.key,
    this.height = 80,
    this.width,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Shimmer.fromColors(
      baseColor: cs.surfaceContainerHighest,
      highlightColor: cs.surface,
      child: Container(
        height: height,
        width: width,
        margin: margin,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

/// A column of shimmer cards for list loading states.
class ShimmerList extends StatelessWidget {
  final int itemCount;
  final double itemHeight;

  const ShimmerList({
    super.key,
    this.itemCount = 4,
    this.itemHeight = 72,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(itemCount, (_) => ShimmerCard(height: itemHeight)),
    );
  }
}
