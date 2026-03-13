import 'package:flutter/material.dart';

/// A single insight for the swipeable card stack.
class SwipeableInsight {
  final String title;
  final String body;
  final IconData icon;
  final Color? color;

  const SwipeableInsight({
    required this.title,
    required this.body,
    this.icon = Icons.insights,
    this.color,
  });
}

/// Tinder-style swipeable insight card stack.
class SwipeableInsightCards extends StatefulWidget {
  final List<SwipeableInsight> insights;
  final void Function(SwipeableInsight insight, bool helpful)? onSwipe;

  const SwipeableInsightCards({
    super.key,
    required this.insights,
    this.onSwipe,
  });

  @override
  State<SwipeableInsightCards> createState() => _SwipeableInsightCardsState();
}

class _SwipeableInsightCardsState extends State<SwipeableInsightCards> {
  int _currentIndex = 0;
  double _dragX = 0;

  @override
  Widget build(BuildContext context) {
    if (_currentIndex >= widget.insights.length) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text("You've seen all insights!", style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    final remaining = widget.insights.length - _currentIndex;
    return SizedBox(
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background cards (max 2 visible behind)
          for (int i = (remaining > 2 ? 2 : remaining - 1); i >= 1; i--)
            if (_currentIndex + i < widget.insights.length)
              Positioned(
                top: i * 6.0,
                left: i * 4.0,
                right: i * 4.0,
                child: Opacity(
                  opacity: 1 - (i * 0.2),
                  child: _InsightCardContent(
                    insight: widget.insights[_currentIndex + i],
                  ),
                ),
              ),
          // Top card (draggable)
          GestureDetector(
            onHorizontalDragUpdate: (d) => setState(() => _dragX += d.delta.dx),
            onHorizontalDragEnd: (d) {
              if (_dragX.abs() > 80) {
                final helpful = _dragX > 0;
                widget.onSwipe?.call(widget.insights[_currentIndex], helpful);
                setState(() {
                  _currentIndex++;
                  _dragX = 0;
                });
              } else {
                setState(() => _dragX = 0);
              }
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              transform: Matrix4.identity()
                ..translate(_dragX, 0)
                ..rotateZ(_dragX * 0.001),
              child: Stack(
                children: [
                  _InsightCardContent(insight: widget.insights[_currentIndex]),
                  // Swipe indicators
                  if (_dragX > 30)
                    Positioned(
                      left: 16, top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('HELPFUL', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  if (_dragX < -30)
                    Positioned(
                      right: 16, top: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('DISMISS', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCardContent extends StatelessWidget {
  final SwipeableInsight insight;
  const _InsightCardContent({required this.insight});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = insight.color ?? cs.primary;
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(insight.icon, size: 24, color: color),
                const SizedBox(width: 10),
                Expanded(child: Text(insight.title,
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color))),
              ],
            ),
            const SizedBox(height: 12),
            Text(insight.body, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.swipe, size: 14, color: Colors.grey.shade400),
                const SizedBox(width: 4),
                Text('Swipe right = helpful, left = dismiss',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade400)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
