import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/social_models.dart';
import '../../providers/social_provider.dart';
import 'package:hugeicons/hugeicons.dart';

/// Bottom sheet for reporting content or blocking a user.
/// Handles both report flow (reason selection → optional details → submit)
/// and block confirmation.
class ReportBlockSheet extends StatefulWidget {
  final String targetId;
  final ReportTargetType targetType;
  final String? targetUserId; // for block option (null if reporting own content)
  final String? targetUserName;

  const ReportBlockSheet({
    super.key,
    required this.targetId,
    required this.targetType,
    this.targetUserId,
    this.targetUserName,
  });

  /// Show as a modal bottom sheet.
  static Future<void> show(
    BuildContext context, {
    required String targetId,
    required ReportTargetType targetType,
    String? targetUserId,
    String? targetUserName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportBlockSheet(
        targetId: targetId,
        targetType: targetType,
        targetUserId: targetUserId,
        targetUserName: targetUserName,
      ),
    );
  }

  @override
  State<ReportBlockSheet> createState() => _ReportBlockSheetState();
}

class _ReportBlockSheetState extends State<ReportBlockSheet> {
  _SheetStep _step = _SheetStep.options;
  ReportReason? _selectedReason;
  final _detailsCtrl = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _detailsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) return;
    setState(() => _submitting = true);
    try {
      await submitReport(
        targetType: widget.targetType,
        targetId: widget.targetId,
        reason: _selectedReason!,
        details: _detailsCtrl.text,
      );
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report submitted. We\'ll review it shortly.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit report: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleBlock() async {
    if (widget.targetUserId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Block User'),
        content: Text(
          'Block ${widget.targetUserName ?? 'this user'}? '
          'They won\'t be able to see your posts or send you messages.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Block'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await blockUser(widget.targetUserId!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.targetUserName ?? 'User'} blocked.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to block: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          child: switch (_step) {
            _SheetStep.options => _buildOptions(cs),
            _SheetStep.reportReason => _buildReasonPicker(cs),
            _SheetStep.reportDetails => _buildDetailsStep(cs),
          },
        ),
      ),
    );
  }

  Widget _buildOptions(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 16),
        _OptionTile(
          icon: HugeIcons.strokeRoundedFlag01,
          label: 'Report',
          color: cs.error,
          onTap: () {
            HapticFeedback.lightImpact();
            setState(() => _step = _SheetStep.reportReason);
          },
        ),
        if (widget.targetUserId != null)
          _OptionTile(
            icon: HugeIcons.strokeRoundedCancel01,
            label: 'Block ${widget.targetUserName ?? 'User'}',
            color: cs.error,
            onTap: () {
              HapticFeedback.lightImpact();
              _handleBlock();
            },
          ),
        _OptionTile(
          icon: HugeIcons.strokeRoundedView,
          label: 'Hide this post',
          color: cs.onSurfaceVariant,
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Post hidden.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildReasonPicker(ColorScheme cs) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 8),
        Container(
          width: 36, height: 4,
          decoration: BoxDecoration(
            color: cs.outlineVariant.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _step = _SheetStep.options),
                child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: cs.onSurface),
              ),
              const SizedBox(width: 12),
              Text('Why are you reporting this?',
                  style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  )),
            ],
          ),
        ),
        ...ReportReason.values.map((reason) => _OptionTile(
              icon: HugeIcons.strokeRoundedCircle,
              label: reason.label,
              color: cs.onSurfaceVariant,
              trailing: _selectedReason == reason
                  ? HugeIcon(icon: HugeIcons.strokeRoundedCheckmarkCircle01, color: cs.primary, size: 20)
                  : null,
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() {
                  _selectedReason = reason;
                  _step = _SheetStep.reportDetails;
                });
              },
            )),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildDetailsStep(ColorScheme cs) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
              color: cs.outlineVariant.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => setState(() => _step = _SheetStep.reportReason),
                  child: HugeIcon(icon: HugeIcons.strokeRoundedArrowLeft01, color: cs.onSurface),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Report: ${_selectedReason?.label ?? ''}',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600,
                      color: cs.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _detailsCtrl,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                hintText: 'Add details (optional)',
                hintStyle: TextStyle(color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submitReport,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.error,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white,
                        ),
                      )
                    : const Text('Submit Report',
                        style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _SheetStep { options, reportReason, reportDetails }

class _OptionTile extends StatelessWidget {
  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: HugeIcon(icon: icon, color: color, size: 22),
      title: Text(label, style: TextStyle(
        color: color, fontWeight: FontWeight.w500, fontSize: 15,
      )),
      trailing: trailing,
      onTap: onTap,
      dense: true,
      visualDensity: const VisualDensity(vertical: -1),
    );
  }
}
