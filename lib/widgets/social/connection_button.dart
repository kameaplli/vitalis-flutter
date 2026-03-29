import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hugeicons/hugeicons.dart';

/// Connection status for the button.
enum ConnectionStatus {
  none, // not connected — show "Add Friend"
  pendingSent, // request sent — show "Pending"
  pendingReceived, // request received — show "Accept / Decline"
  connected, // friends — show "Friends"
}

/// Stateful connection button that adapts appearance based on connection state.
class ConnectionButton extends StatelessWidget {
  final ConnectionStatus status;
  final VoidCallback? onAddFriend;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onRemove;

  const ConnectionButton({
    super.key,
    required this.status,
    this.onAddFriend,
    this.onAccept,
    this.onDecline,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    switch (status) {
      case ConnectionStatus.none:
        return FilledButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onAddFriend?.call();
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedUserAdd01, size: 18),
          label: const Text('Add Friend'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          ),
        );

      case ConnectionStatus.pendingSent:
        return OutlinedButton.icon(
          onPressed: null,
          icon: HugeIcon(icon: HugeIcons.strokeRoundedClock01, size: 18, color: cs.onSurfaceVariant),
          label: Text(
            'Pending',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            side: BorderSide(color: cs.outlineVariant),
          ),
        );

      case ConnectionStatus.pendingReceived:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FilledButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                onAccept?.call();
              },
              icon: HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, size: 18),
              label: const Text('Accept'),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: () {
                HapticFeedback.lightImpact();
                onDecline?.call();
              },
              style: OutlinedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                side: BorderSide(color: cs.error.withValues(alpha: 0.5)),
              ),
              child: Text(
                'Decline',
                style: TextStyle(color: cs.error),
              ),
            ),
          ],
        );

      case ConnectionStatus.connected:
        return OutlinedButton.icon(
          onPressed: () {
            HapticFeedback.lightImpact();
            onRemove?.call();
          },
          icon: HugeIcon(icon: HugeIcons.strokeRoundedUserCheck01, size: 18, color: cs.primary),
          label: Text(
            'Friends',
            style: TextStyle(color: cs.primary),
          ),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            side: BorderSide(color: cs.primary.withValues(alpha: 0.5)),
          ),
        );
    }
  }
}
