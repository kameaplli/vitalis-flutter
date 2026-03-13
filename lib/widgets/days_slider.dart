import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact, stylish day-range slider that replaces fixed 7d/30d/90d buttons.
/// Lets users pick any range from 1 to 365 days with logarithmic scaling
/// so shorter periods get more granularity.
class DaysSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  /// If true, renders as a compact chip that expands on tap.
  final bool compact;

  const DaysSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  @override
  State<DaysSlider> createState() => _DaysSliderState();
}

class _DaysSliderState extends State<DaysSlider>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _anim;
  late final Animation<double> _sizeAnim;

  // Snap points for common ranges — slider snaps near these
  static const _snaps = [7, 14, 30, 60, 90, 180, 365];

  // Log scale: position 0..1 → days 1..365
  static double _daysToSlider(int days) =>
      log(days.clamp(1, 365)) / log(365);

  static int _sliderToDays(double v) =>
      pow(365, v).round().clamp(1, 365);

  static int _snapIfClose(int days) {
    for (final s in _snaps) {
      if ((days - s).abs() <= (s < 30 ? 1 : (s < 90 ? 2 : 5))) return s;
    }
    return days;
  }

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _sizeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  String _label(int days) {
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    if (days == 30) return '1 month';
    if (days == 60) return '2 months';
    if (days == 90) return '3 months';
    if (days == 180) return '6 months';
    if (days == 365) return '1 year';
    if (days > 30 && days < 365) return '$days days';
    return '$days days';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final days = widget.value;

    if (widget.compact) {
      return _buildCompact(cs, days);
    }
    return _buildInline(cs, days);
  }

  Widget _buildCompact(ColorScheme cs, int days) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        GestureDetector(
          onTap: _toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.calendar_today_rounded,
                    size: 14, color: cs.onPrimaryContainer),
                const SizedBox(width: 4),
                Text(
                  _label(days),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: cs.onPrimaryContainer,
                  ),
                ),
                const SizedBox(width: 2),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(Icons.expand_more,
                      size: 16, color: cs.onPrimaryContainer),
                ),
              ],
            ),
          ),
        ),
        SizeTransition(
          sizeFactor: _sizeAnim,
          axisAlignment: -1,
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              width: 200,
              child: _buildSliderRow(cs, days),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInline(ColorScheme cs, int days) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.calendar_today_rounded, size: 14, color: cs.outline),
        const SizedBox(width: 4),
        SizedBox(
          width: 160,
          child: _buildSliderRow(cs, days),
        ),
        const SizedBox(width: 4),
        Text(
          _label(days),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: cs.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildSliderRow(ColorScheme cs, int days) {
    return SliderTheme(
      data: SliderThemeData(
        trackHeight: 3,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
        activeTrackColor: cs.primary,
        inactiveTrackColor: cs.outline.withValues(alpha: 0.2),
        thumbColor: cs.primary,
        overlayColor: cs.primary.withValues(alpha: 0.12),
      ),
      child: Slider(
        value: _daysToSlider(days),
        onChanged: (v) {
          final raw = _sliderToDays(v);
          final snapped = _snapIfClose(raw);
          if (snapped != widget.value) {
            HapticFeedback.selectionClick();
            widget.onChanged(snapped);
          }
        },
      ),
    );
  }
}
