import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A compact, stylish day-range slider that replaces fixed 7d/30d/90d buttons.
/// Lets users pick any range from 1 to 365 days with logarithmic scaling
/// so shorter periods get more granularity.
class DaysSlider extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;
  /// If true, renders as a compact inline slider with label above.
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

class _DaysSliderState extends State<DaysSlider> {
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

  String _label(int days) {
    if (days == 1) return '1 day';
    if (days < 30) return '$days days';
    if (days == 30) return '1 month';
    if (days == 60) return '2 months';
    if (days == 90) return '3 months';
    if (days == 180) return '6 months';
    if (days == 365) return '1 year';
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

  /// Compact mode: small label on top, slider on the same row as page title.
  /// No dropdown, no expand/collapse — always visible.
  Widget _buildCompact(ColorScheme cs, int days) {
    return SizedBox(
      width: 150,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Selected value label — small font above slider
          Text(
            _label(days),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: cs.primary,
            ),
          ),
          // Slider — compact height, no padding
          SizedBox(
            height: 28,
            child: _buildSliderRow(cs, days),
          ),
        ],
      ),
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
