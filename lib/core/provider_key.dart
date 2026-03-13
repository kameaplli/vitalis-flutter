/// Unified key parsing for `.family()` providers.
///
/// Person IDs may contain underscores (e.g. "child_1771650775904"),
/// so we always split from the END of the key, not the beginning.
///
/// Supported key formats:
///   "person"                       → personOnly()
///   "person_days"                  → personDays()
///   "person_days_date"             → personDaysDate()
///   "person_startDate_endDate"     → personDateRange()
class PK {
  PK._();

  /// Parse "person_days" → (person, days).
  /// Splits at the LAST underscore so person IDs with underscores are preserved.
  static (String person, int days) personDays(String key, [int defaultDays = 30]) {
    final idx = key.lastIndexOf('_');
    if (idx <= 0) return (key.isNotEmpty ? key : 'self', defaultDays);
    final tail = key.substring(idx + 1);
    final parsed = int.tryParse(tail);
    if (parsed == null) {
      // Tail isn't a number — treat entire key as person
      return (key, defaultDays);
    }
    return (key.substring(0, idx), parsed);
  }

  /// Parse "person_days_date" → (person, days, date).
  /// Date is YYYY-MM-DD (contains dashes, never underscores).
  /// Peels off date from end first, then days.
  static (String person, int days, String date) personDaysDate(
    String key, [int defaultDays = 7]
  ) {
    final today = DateTime.now().toIso8601String().substring(0, 10);

    final last = key.lastIndexOf('_');
    if (last <= 0) return (key.isNotEmpty ? key : 'self', defaultDays, today);

    final tail = key.substring(last + 1);
    final prefix = key.substring(0, last);

    // If tail looks like a date (contains '-'), peel it off and parse days from prefix
    if (tail.contains('-')) {
      final (person, days) = personDays(prefix, defaultDays);
      return (person, days, tail);
    }

    // tail is days, no date provided
    final parsed = int.tryParse(tail);
    if (parsed != null) {
      return (prefix, parsed, today);
    }

    return (key, defaultDays, today);
  }

  /// Parse "person_startDate_endDate" → (person, startDate, endDate).
  /// Dates are YYYY-MM-DD. Peels off from the end twice.
  static (String person, String? startDate, String? endDate) personDateRange(String key) {
    // Peel off endDate
    final last = key.lastIndexOf('_');
    if (last <= 0) return (key, null, null);
    final endDate = key.substring(last + 1);
    final rest = key.substring(0, last);

    // Peel off startDate
    final secondLast = rest.lastIndexOf('_');
    if (secondLast <= 0) return (rest, endDate.isNotEmpty ? endDate : null, null);
    final startDate = rest.substring(secondLast + 1);
    final person = rest.substring(0, secondLast);

    return (
      person.isNotEmpty ? person : 'self',
      startDate.isNotEmpty ? startDate : null,
      endDate.isNotEmpty ? endDate : null,
    );
  }

  /// Parse "first_second" where second is a known string (not an int).
  /// Used for "person_period" or "category_period" keys.
  static (String first, String second) firstSecond(String key, [String defaultSecond = 'month']) {
    final idx = key.lastIndexOf('_');
    if (idx <= 0) return (key, defaultSecond);
    return (key.substring(0, idx), key.substring(idx + 1));
  }
}
