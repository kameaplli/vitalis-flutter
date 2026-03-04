/// Returns the device's local timezone abbreviation, e.g. "IST", "AEST", "GMT".
/// Falls back to a UTC-offset string (e.g. "UTC+05:30") when the system name
/// looks like a full IANA name ("Asia/Kolkata") rather than an abbreviation.
String localTimezone() {
  final name = DateTime.now().timeZoneName;
  // Accept short all-caps abbreviations (2–6 chars) as-is.
  if (name.length <= 6 && RegExp(r'^[A-Z]+$').hasMatch(name)) return name;
  // Build UTC±HH:MM fallback.
  final offset = DateTime.now().timeZoneOffset;
  final sign = offset.isNegative ? '-' : '+';
  final h = offset.inHours.abs().toString().padLeft(2, '0');
  final m = (offset.inMinutes.abs() % 60).toString().padLeft(2, '0');
  return 'UTC$sign$h:$m';
}
