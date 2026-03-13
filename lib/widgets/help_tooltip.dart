import 'package:flutter/material.dart';

/// A small (i) icon button that shows a help tooltip when tapped.
class HelpTooltip extends StatelessWidget {
  final String message;
  final double iconSize;

  const HelpTooltip({
    super.key,
    required this.message,
    this.iconSize = 16,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return IconButton(
      icon: Icon(Icons.help_outline, size: iconSize, color: cs.outline),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
      tooltip: message,
      onPressed: () {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            content: Text(message, style: const TextStyle(fontSize: 14, height: 1.5)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
      },
    );
  }
}
