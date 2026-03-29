import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:hugeicons/hugeicons.dart';

/// A single event in a causation chain.
class CausationEvent {
  final DateTime dateTime;
  final String title;
  final String subtitle;
  final List<String> tags;
  final bool isFlare;
  final double? severity;

  const CausationEvent({
    required this.dateTime,
    required this.title,
    this.subtitle = '',
    this.tags = const [],
    this.isFlare = false,
    this.severity,
  });
}

/// Visual timeline connecting food/environment events to flare outcomes.
class CausationChainTimeline extends StatelessWidget {
  final List<CausationEvent> events;

  const CausationChainTimeline({super.key, required this.events});

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const Center(child: Text('No causation data yet', style: TextStyle(color: Colors.grey)));
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: events.length,
      itemBuilder: (context, index) {
        final event = events[index];
        final isLast = index == events.length - 1;
        final prevEvent = index > 0 ? events[index - 1] : null;

        // Calculate lag between events
        String? lagLabel;
        if (prevEvent != null) {
          final diff = event.dateTime.difference(prevEvent.dateTime);
          if (diff.inHours < 24) {
            lagLabel = '${diff.inHours}h lag';
          } else {
            lagLabel = '${diff.inDays}d lag';
          }
        }

        return _CausationNode(
          event: event,
          isLast: isLast,
          lagLabel: lagLabel,
        );
      },
    );
  }
}

class _CausationNode extends StatelessWidget {
  final CausationEvent event;
  final bool isLast;
  final String? lagLabel;

  const _CausationNode({
    required this.event,
    required this.isLast,
    this.lagLabel,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isFlare = event.isFlare;
    final nodeColor = isFlare ? Colors.red.shade600 : cs.primary;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline spine
          SizedBox(
            width: 40,
            child: Column(
              children: [
                if (lagLabel != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(lagLabel!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  ),
                // Node dot
                Container(
                  width: isFlare ? 16 : 12,
                  height: isFlare ? 16 : 12,
                  decoration: BoxDecoration(
                    color: nodeColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: nodeColor.withValues(alpha: 0.3), blurRadius: 4)],
                  ),
                ),
                // Connecting line
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: Colors.grey.shade300,
                    ),
                  ),
              ],
            ),
          ),
          // Content card
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                margin: EdgeInsets.zero,
                color: isFlare ? Colors.red.shade50 : null,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          HugeIcon(icon: isFlare ? HugeIcons.strokeRoundedAlert02 : HugeIcons.strokeRoundedRestaurant01,
                              size: 14, color: nodeColor),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(event.title,
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold,
                                    color: isFlare ? Colors.red.shade800 : null)),
                          ),
                          Text(DateFormat('EEE HH:mm').format(event.dateTime),
                              style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                        ],
                      ),
                      if (event.subtitle.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(event.subtitle, style: const TextStyle(fontSize: 11)),
                      ],
                      if (event.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          runSpacing: 2,
                          children: event.tags.map((tag) => Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: nodeColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tag, style: TextStyle(fontSize: 11, color: nodeColor, fontWeight: FontWeight.w600)),
                          )).toList(),
                        ),
                      ],
                      if (event.severity != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('Severity: ', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                            Text('${event.severity!.toStringAsFixed(1)}/10',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: nodeColor)),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
