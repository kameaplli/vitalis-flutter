import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// GitHub-style 90-day calendar heatmap for eczema severity.
class CalendarHeatmap extends StatelessWidget {
  /// Map of date string (yyyy-MM-dd) to severity (0-10).
  final Map<String, double> data;
  final int days;
  final void Function(DateTime date, double severity)? onDayTap;

  const CalendarHeatmap({
    super.key,
    required this.data,
    this.days = 90,
    this.onDayTap,
  });

  static Color _severityColor(double? severity) {
    if (severity == null) return Colors.grey.shade200;
    if (severity <= 0) return const Color(0xFFE8F5E9);
    if (severity <= 2) return const Color(0xFFA5D6A7);
    if (severity <= 4) return const Color(0xFFFFF9C4);
    if (severity <= 6) return const Color(0xFFFFCC80);
    if (severity <= 8) return const Color(0xFFEF9A9A);
    return const Color(0xFFC62828);
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final start = today.subtract(Duration(days: days - 1));

    // Build list of all dates
    final allDates = List.generate(days, (i) => start.add(Duration(days: i)));

    // Group by week (columns)
    final weeks = <List<DateTime?>>[];
    var currentWeek = <DateTime?>[];

    // Pad the first week with nulls for alignment
    final startWeekday = allDates.first.weekday % 7; // 0=Mon
    for (int i = 0; i < startWeekday; i++) {
      currentWeek.add(null);
    }

    for (final d in allDates) {
      currentWeek.add(d);
      if (currentWeek.length == 7) {
        weeks.add(currentWeek);
        currentWeek = [];
      }
    }
    if (currentWeek.isNotEmpty) {
      while (currentWeek.length < 7) {
        currentWeek.add(null);
      }
      weeks.add(currentWeek);
    }

    final dayLabels = ['M', '', 'W', '', 'F', '', 'S'];
    final cellSize = 14.0;
    final gap = 2.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month labels
        SizedBox(
          height: 16,
          child: Row(
            children: [
              SizedBox(width: 18), // space for day labels
              ...weeks.map((week) {
                final firstDay = week.firstWhere((d) => d != null, orElse: () => null);
                final showLabel = firstDay != null && firstDay.day <= 7;
                return SizedBox(
                  width: cellSize + gap,
                  child: showLabel
                      ? Text(DateFormat('MMM').format(firstDay!),
                          style: TextStyle(fontSize: 8, color: Colors.grey.shade600))
                      : null,
                );
              }),
            ],
          ),
        ),
        // Grid
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day-of-week labels
            Column(
              children: List.generate(7, (i) => SizedBox(
                width: 16,
                height: cellSize + gap,
                child: Center(
                  child: Text(dayLabels[i],
                      style: TextStyle(fontSize: 8, color: Colors.grey.shade500)),
                ),
              )),
            ),
            // Weeks
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                reverse: true,
                child: Row(
                  children: weeks.map((week) {
                    return Column(
                      children: week.map((date) {
                        if (date == null) {
                          return SizedBox(width: cellSize + gap, height: cellSize + gap);
                        }
                        final key = DateFormat('yyyy-MM-dd').format(date);
                        final severity = data[key];
                        final color = _severityColor(severity);
                        return GestureDetector(
                          onTap: severity != null && onDayTap != null
                              ? () => onDayTap!(date, severity)
                              : null,
                          child: Container(
                            width: cellSize,
                            height: cellSize,
                            margin: EdgeInsets.all(gap / 2),
                            decoration: BoxDecoration(
                              color: color,
                              borderRadius: BorderRadius.circular(2),
                              border: date.day == today.day &&
                                      date.month == today.month &&
                                      date.year == today.year
                                  ? Border.all(color: Colors.blue, width: 1.5)
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Legend
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Less', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
            const SizedBox(width: 4),
            for (final s in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0])
              Container(
                width: 10, height: 10,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(
                  color: _severityColor(s),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const SizedBox(width: 4),
            Text('More', style: TextStyle(fontSize: 9, color: Colors.grey.shade600)),
          ],
        ),
      ],
    );
  }
}
