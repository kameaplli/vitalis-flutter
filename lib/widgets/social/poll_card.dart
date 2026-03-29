import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/poll_models.dart';

/// Displays a poll in the social feed with animated vote bars.
class PollCard extends StatefulWidget {
  final Poll poll;
  final ValueChanged<String> onVote;
  final VoidCallback? onComment;

  const PollCard({
    super.key,
    required this.poll,
    required this.onVote,
    this.onComment,
  });

  @override
  State<PollCard> createState() => _PollCardState();
}

class _PollCardState extends State<PollCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _barCtrl;
  String? _selectedOptionId;
  bool _voting = false;

  @override
  void initState() {
    super.initState();
    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    if (widget.poll.hasVoted) {
      _barCtrl.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(PollCard old) {
    super.didUpdateWidget(old);
    if (!old.poll.hasVoted && widget.poll.hasVoted) {
      _barCtrl.forward();
    }
  }

  @override
  void dispose() {
    _barCtrl.dispose();
    super.dispose();
  }

  void _vote(String optionId) {
    if (_voting || widget.poll.hasVoted || !widget.poll.isActive) return;
    setState(() {
      _selectedOptionId = optionId;
      _voting = true;
    });
    HapticFeedback.lightImpact();
    widget.onVote(optionId);
    _barCtrl.forward();
  }

  String _timeRemaining(DateTime expiresAt) {
    final diff = expiresAt.difference(DateTime.now());
    if (diff.isNegative) return 'Ended';
    if (diff.inDays > 0) return '${diff.inDays}d left';
    if (diff.inHours > 0) return '${diff.inHours}h left';
    if (diff.inMinutes > 0) return '${diff.inMinutes}m left';
    return 'Ending soon';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final poll = widget.poll;
    final showResults = poll.hasVoted || poll.isExpired;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: cs.primaryContainer,
                child: Text(
                  poll.creatorName.isNotEmpty
                      ? poll.creatorName[0].toUpperCase()
                      : '?',
                  style: tt.labelSmall
                      ?.copyWith(color: cs.onPrimaryContainer),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(poll.creatorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              if (poll.access == PollAccess.inviteOnly)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: cs.tertiaryContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('Invite Only',
                      style: tt.labelSmall
                          ?.copyWith(color: cs.onTertiaryContainer)),
                ),
              if (!poll.isActive) ...[
                const SizedBox(width: 8),
                Text('Closed',
                    style: tt.labelSmall?.copyWith(color: cs.outline)),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Question
          Text(poll.question,
              style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Options
          ...poll.options.map((opt) => _buildOption(context, opt, showResults)),

          const SizedBox(height: 8),
          // Footer — votes + time remaining
          Row(
            children: [
              Text(
                '${poll.totalVotes} vote${poll.totalVotes == 1 ? '' : 's'}',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(width: 8),
              Text('·', style: tt.bodySmall?.copyWith(color: cs.outline)),
              const SizedBox(width: 8),
              Text(
                poll.isActive ? _timeRemaining(poll.expiresAt) : 'Ended',
                style: tt.bodySmall?.copyWith(color: cs.outline),
              ),
              const SizedBox(width: 8),
              Text('·', style: tt.bodySmall?.copyWith(color: cs.outline)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onComment,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        size: 14, color: cs.outline),
                    const SizedBox(width: 4),
                    Text(
                      '${poll.commentCount}',
                      style: tt.bodySmall?.copyWith(color: cs.outline),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (poll.hasVoted) ...[
                Icon(Icons.check_circle_outline,
                    size: 14, color: cs.primary),
                const SizedBox(width: 4),
                Text('Voted',
                    style: tt.labelSmall?.copyWith(color: cs.primary)),
                const SizedBox(width: 8),
              ],
              GestureDetector(
                onTap: () {
                  final options = poll.options
                      .map((o) => '• ${o.text}')
                      .join('\n');
                  Share.share(
                    '📊 Poll: ${poll.question}\n$options\n\nVote on QoreHealth!',
                  );
                },
                child: Icon(Icons.share_outlined,
                    size: 16, color: cs.outline),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOption(
      BuildContext context, PollOption opt, bool showResults) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final isSelected = widget.poll.userVoteOptionId == opt.id ||
        _selectedOptionId == opt.id;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: showResults ? null : () => _vote(opt.id),
        child: AnimatedBuilder(
          animation: _barCtrl,
          builder: (context, _) {
            final barWidth = showResults
                ? opt.percentage * _barCtrl.value
                : 0.0;
            return Container(
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? cs.primary
                      : cs.outlineVariant.withValues(alpha: 0.5),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Stack(
                children: [
                  // Animated fill bar
                  FractionallySizedBox(
                    widthFactor: barWidth,
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cs.primaryContainer
                            : cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                  ),
                  // Label + percentage
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(opt.text,
                              style: tt.bodyMedium?.copyWith(
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              )),
                        ),
                        if (showResults)
                          Text(
                            '${(opt.percentage * 100).round()}%',
                            style: tt.labelMedium?.copyWith(
                              color: isSelected ? cs.primary : cs.outline,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

// Uses Flutter's built-in AnimatedBuilder for animated vote bars.
