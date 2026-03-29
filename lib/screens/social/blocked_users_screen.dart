import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';

/// Screen to view and manage blocked users.
class BlockedUsersScreen extends ConsumerWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final blockedAsync = ref.watch(blockedUsersProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blocked Users'),
      ),
      body: blockedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline_rounded, size: 48, color: cs.error),
              const SizedBox(height: 12),
              Text('Failed to load blocked users',
                  style: tt.bodyMedium),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(blockedUsersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_outlined, size: 56,
                      color: cs.outline),
                  const SizedBox(height: 12),
                  Text('No blocked users',
                      style: tt.titleSmall?.copyWith(color: cs.outline)),
                  const SizedBox(height: 4),
                  Text(
                    'Users you block will appear here',
                    style: tt.bodySmall?.copyWith(color: cs.outline),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(
              height: 1, indent: 72,
            ),
            itemBuilder: (_, i) {
              final user = users[i];
              return _BlockedUserTile(
                user: user,
                onUnblock: () async {
                  HapticFeedback.lightImpact();
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Unblock User'),
                      content: Text(
                        'Unblock ${user.name}? They will be able to see '
                        'your posts and send you messages again.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Unblock'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true) return;

                  try {
                    await unblockUser(user.userId);
                    ref.invalidate(blockedUsersProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${user.name} unblocked'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to unblock: $e'),
                          behavior: SnackBarBehavior.floating,
                          backgroundColor: cs.error,
                        ),
                      );
                    }
                  }
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _BlockedUserTile extends StatelessWidget {
  final BlockedUser user;
  final VoidCallback onUnblock;

  const _BlockedUserTile({
    required this.user,
    required this.onUnblock,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    final daysAgo = DateTime.now().difference(user.blockedAt).inDays;
    final blockedText = daysAgo == 0
        ? 'Blocked today'
        : daysAgo == 1
            ? 'Blocked yesterday'
            : 'Blocked $daysAgo days ago';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: cs.errorContainer.withValues(alpha: 0.3),
        child: Text(initial, style: TextStyle(
          fontWeight: FontWeight.w600,
          color: cs.onErrorContainer,
        )),
      ),
      title: Text(user.name, style: tt.bodyMedium?.copyWith(
        fontWeight: FontWeight.w500,
      )),
      subtitle: Text(blockedText, style: tt.bodySmall?.copyWith(
        color: cs.outline,
        fontSize: 12,
      )),
      trailing: OutlinedButton(
        onPressed: onUnblock,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: const Size(0, 32),
          side: BorderSide(color: cs.outline.withValues(alpha: 0.3)),
        ),
        child: const Text('Unblock'),
      ),
    );
  }
}
