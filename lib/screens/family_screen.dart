import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/selected_person_provider.dart';
import '../core/constants.dart';

/// Family profiles management screen — view and switch between family members.
class FamilyScreen extends ConsumerWidget {
  const FamilyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.user;
    final children = user?.profile.children ?? [];
    final cs = Theme.of(context).colorScheme;
    final selectedPerson = ref.watch(selectedPersonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Family Profiles'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            tooltip: 'Add family member',
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Primary user
          _FamilyMemberCard(
            name: user?.name ?? 'You',
            avatarUrl: user?.avatarUrl != null ? ApiConstants.resolveUrl(user!.avatarUrl) : null,
            isSelected: selectedPerson == 'self',
            onTap: () {
              ref.read(selectedPersonProvider.notifier).state = 'self';
              context.go('/dashboard');
            },
            isPrimary: true,
          ),

          if (children.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Family Members', style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: cs.onSurfaceVariant,
              )),
            ),
            ...children.map((child) => _FamilyMemberCard(
              name: child.name,
              avatarUrl: child.avatarUrl != null ? ApiConstants.resolveUrl(child.avatarUrl!) : null,
              isSelected: selectedPerson == child.id,
              onTap: () {
                ref.read(selectedPersonProvider.notifier).state = child.id;
                context.go('/dashboard');
              },
            )),
          ],

          if (children.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  Icon(Icons.family_restroom, size: 64, color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  Text(
                    'No family members added yet',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/profile'),
                    icon: const Icon(Icons.person_add),
                    label: const Text('Add Family Member'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _FamilyMemberCard extends StatelessWidget {
  final String name;
  final String? avatarUrl;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _FamilyMemberCard({
    required this.name,
    required this.avatarUrl,
    required this.isSelected,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      color: isSelected ? cs.primaryContainer.withValues(alpha: 0.3) : null,
      child: ListTile(
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: cs.primaryContainer,
          backgroundImage: avatarUrl != null ? CachedNetworkImageProvider(avatarUrl!) : null,
          child: avatarUrl == null
              ? Text(name.substring(0, 1).toUpperCase(), style: TextStyle(
                  fontWeight: FontWeight.w700, color: cs.onPrimaryContainer))
              : null,
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(isPrimary ? 'Primary account' : 'Family member'),
        trailing: isSelected
            ? Icon(Icons.check_circle, color: cs.primary)
            : Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
        onTap: onTap,
      ),
    );
  }
}
