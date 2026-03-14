import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/constants.dart';
import '../../providers/social_provider.dart';
import '../../widgets/social/share_card_preview.dart';

/// Bottom sheet for sharing content to the social feed.
class ShareSheet extends ConsumerStatefulWidget {
  final String contentType; // streak, meal, recipe, achievement
  final String title;
  final String? subtitle;
  final String? contentId;
  final Map<String, dynamic>? contentSnapshot;

  const ShareSheet({
    super.key,
    required this.contentType,
    required this.title,
    this.subtitle,
    this.contentId,
    this.contentSnapshot,
  });

  /// Show the share sheet as a modal bottom sheet.
  static Future<bool?> show(
    BuildContext context, {
    required String contentType,
    required String title,
    String? subtitle,
    String? contentId,
    Map<String, dynamic>? contentSnapshot,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareSheet(
        contentType: contentType,
        title: title,
        subtitle: subtitle,
        contentId: contentId,
        contentSnapshot: contentSnapshot,
      ),
    );
  }

  @override
  ConsumerState<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends ConsumerState<ShareSheet> {
  final _noteCtrl = TextEditingController();
  String _audience = 'connections'; // connections, everyone, specific
  bool _sharing = false;

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    HapticFeedback.lightImpact();

    try {
      await apiClient.dio.post(
        ApiConstants.socialShare,
        data: {
          'content_type': widget.contentType,
          if (widget.contentId != null) 'content_id': widget.contentId,
          'audience': _audience,
          'content_snapshot': {
            'title': widget.title,
            if (widget.subtitle != null) 'subtitle': widget.subtitle,
            if (_noteCtrl.text.trim().isNotEmpty) 'note': _noteCtrl.text.trim(),
            ...?widget.contentSnapshot,
          },
        },
      );
      ref.invalidate(socialFeedProvider(null));
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Shared successfully!')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to share. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      margin: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: cs.outlineVariant,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Text(
              'Share',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Preview card
            ShareCardPreview(
              contentType: widget.contentType,
              title: widget.title,
              subtitle: widget.subtitle,
            ),
            const SizedBox(height: 16),

            // Optional note
            TextField(
              controller: _noteCtrl,
              maxLines: 2,
              maxLength: 200,
              decoration: InputDecoration(
                hintText: 'Add a note (optional)',
                hintStyle: TextStyle(color: cs.onSurfaceVariant),
                filled: true,
                fillColor: cs.surfaceContainerHighest.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                counterStyle: TextStyle(
                    color: cs.onSurfaceVariant, fontSize: 11),
              ),
            ),
            const SizedBox(height: 12),

            // Privacy picker
            Text(
              'Who can see this?',
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _PrivacyOption(
              label: 'Friends only',
              icon: Icons.people_outline,
              selected: _audience == 'connections',
              onTap: () => setState(() => _audience = 'connections'),
            ),
            _PrivacyOption(
              label: 'Everyone',
              icon: Icons.public,
              selected: _audience == 'everyone',
              onTap: () => setState(() => _audience = 'everyone'),
            ),
            _PrivacyOption(
              label: 'Specific people',
              icon: Icons.person_outline,
              selected: _audience == 'specific',
              onTap: () => setState(() => _audience = 'specific'),
            ),
            const SizedBox(height: 16),

            // Share button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _sharing ? null : _share,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _sharing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Share',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 8),

            // External share (disabled for now)
            Center(
              child: Text(
                'Also share externally',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant.withOpacity(0.4),
                  decoration: TextDecoration.underline,
                  decorationColor: cs.onSurfaceVariant.withOpacity(0.4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _PrivacyOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 20,
              color: selected ? cs.primary : cs.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Icon(icon, size: 18, color: cs.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: selected ? cs.onSurface : cs.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
