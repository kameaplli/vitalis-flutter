import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

class PersonSelector extends ConsumerWidget {
  final String? selectedId;
  final ValueChanged<String?> onChanged;
  final bool includeAll;

  const PersonSelector({
    super.key,
    required this.selectedId,
    required this.onChanged,
    this.includeAll = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).user;
    if (user == null) return const SizedBox();

    final items = <DropdownMenuItem<String?>>[
      if (includeAll)
        const DropdownMenuItem(value: 'all', child: Text('All people')),
      const DropdownMenuItem(value: 'self', child: Text('Me')),
      ...user.profile.children.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))),
    ];

    return DropdownButtonFormField<String?>(
      value: selectedId ?? 'self',
      decoration: const InputDecoration(labelText: 'For', isDense: true),
      items: items,
      onChanged: onChanged,
    );
  }
}
