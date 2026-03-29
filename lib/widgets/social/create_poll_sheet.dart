import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/poll_models.dart';
import '../../providers/poll_provider.dart';

/// Bottom sheet for creating a new poll.
class CreatePollSheet extends ConsumerStatefulWidget {
  const CreatePollSheet({super.key});

  @override
  ConsumerState<CreatePollSheet> createState() => _CreatePollSheetState();
}

class _CreatePollSheetState extends ConsumerState<CreatePollSheet> {
  final _questionCtrl = TextEditingController();
  final _optionCtrls = [TextEditingController(), TextEditingController()];
  var _access = PollAccess.public_;
  var _durationHours = 24;
  var _posting = false;

  @override
  void dispose() {
    _questionCtrl.dispose();
    for (final c in _optionCtrls) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _isValid =>
      _questionCtrl.text.trim().isNotEmpty &&
      _optionCtrls
              .where((c) => c.text.trim().isNotEmpty)
              .length >=
          2;

  void _addOption() {
    if (_optionCtrls.length >= 6) return;
    setState(() => _optionCtrls.add(TextEditingController()));
  }

  void _removeOption(int i) {
    if (_optionCtrls.length <= 2) return;
    setState(() {
      _optionCtrls[i].dispose();
      _optionCtrls.removeAt(i);
    });
  }

  Future<void> _create() async {
    if (!_isValid || _posting) return;
    setState(() => _posting = true);
    HapticFeedback.lightImpact();

    try {
      await createPoll(
        question: _questionCtrl.text.trim(),
        options:
            _optionCtrls.map((c) => c.text.trim()).where((t) => t.isNotEmpty).toList(),
        access: _access,
        durationHours: _durationHours,
      );
      ref.invalidate(pollsProvider);
      ref.invalidate(myPollsProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create poll: $e')),
        );
        setState(() => _posting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: cs.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Create Poll',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),

            // Question
            TextField(
              controller: _questionCtrl,
              maxLength: 200,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'Question',
                hintText: 'Ask your community something...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Options
            ...List.generate(_optionCtrls.length, (i) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _optionCtrls[i],
                        maxLength: 80,
                        decoration: InputDecoration(
                          labelText: 'Option ${i + 1}',
                          counterText: '',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          suffixIcon: _optionCtrls.length > 2
                              ? IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () => _removeOption(i),
                                )
                              : null,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
              );
            }),

            if (_optionCtrls.length < 6)
              TextButton.icon(
                onPressed: _addOption,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Add option'),
              ),

            const SizedBox(height: 12),

            // Access + Duration row
            Row(
              children: [
                // Access
                Expanded(
                  child: SegmentedButton<PollAccess>(
                    segments: [
                      ButtonSegment(
                        value: PollAccess.public_,
                        label: const Text('Public'),
                        icon: const Icon(Icons.public, size: 16),
                      ),
                      ButtonSegment(
                        value: PollAccess.inviteOnly,
                        label: const Text('Invite'),
                        icon: const Icon(Icons.lock_outline, size: 16),
                      ),
                    ],
                    selected: {_access},
                    onSelectionChanged: (s) =>
                        setState(() => _access = s.first),
                  ),
                ),
                const SizedBox(width: 12),
                // Duration
                DropdownButton<int>(
                  value: _durationHours,
                  underline: const SizedBox.shrink(),
                  items: const [
                    DropdownMenuItem(value: 1, child: Text('1h')),
                    DropdownMenuItem(value: 6, child: Text('6h')),
                    DropdownMenuItem(value: 24, child: Text('1d')),
                    DropdownMenuItem(value: 72, child: Text('3d')),
                    DropdownMenuItem(value: 168, child: Text('7d')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _durationHours = v);
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Create button
            FilledButton(
              onPressed: _isValid && !_posting ? _create : null,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _posting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Poll'),
            ),
          ],
        ),
      ),
    );
  }
}
