/// Average heart rate per calendar week, Monday to Sunday, for the trend in
/// the history.
class WeekAverage {
  const WeekAverage(this.weekStart, this.bpm, this.count);

  /// Local midnight of the week's Monday.
  final DateTime weekStart;

  /// Rounded mean of the week's readings; null for a week without any.
  final int? bpm;
  final int count;
}

/// Local midnight of the Monday of the week [when] falls in.
DateTime weekStartOf(DateTime when) {
  final DateTime local = when.toLocal();
  // Built from the calendar date, not by subtracting hours, so a daylight
  // saving change inside the week cannot shift it off midnight.
  return DateTime(local.year, local.month, local.day - (local.weekday - 1));
}

/// The last [weeks] weeks up to and including the one [now] is in, oldest
/// first. Readings of 0 bpm (no reading) and outside the range are ignored.
List<WeekAverage> weeklyAverages(
  Iterable<(DateTime, int)> readings, {
  required DateTime now,
  int weeks = 8,
}) {
  final DateTime current = weekStartOf(now);
  final List<DateTime> starts = [
    for (int i = weeks - 1; i >= 0; i--)
      DateTime(current.year, current.month, current.day - 7 * i),
  ];
  final Map<DateTime, List<int>> byWeek = {
    for (final DateTime start in starts) start: <int>[],
  };
  for (final (DateTime at, int bpm) in readings) {
    if (bpm <= 0) continue;
    byWeek[weekStartOf(at)]?.add(bpm);
  }
  return [
    for (final DateTime start in starts)
      WeekAverage(
        start,
        byWeek[start]!.isEmpty
            ? null
            : (byWeek[start]!.reduce((a, b) => a + b) / byWeek[start]!.length)
                .round(),
        byWeek[start]!.length,
      ),
  ];
}
