import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/services/weekly_trend.dart';

void main() {
  // Thursday 16 October 2026; its week starts on Monday 12 October.
  final DateTime now = DateTime(2026, 10, 16, 9, 30);

  test('weeks run Monday to Sunday', () {
    expect(weekStartOf(DateTime(2026, 10, 12, 0, 0)), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 18, 23, 59)), DateTime(2026, 10, 12));
    expect(weekStartOf(DateTime(2026, 10, 11, 23, 59)), DateTime(2026, 10, 5));
  });

  test('stays on midnight across the end of summer time', () {
    // Czech summer time ends on Sunday 25 October 2026.
    expect(weekStartOf(DateTime(2026, 10, 28, 8)), DateTime(2026, 10, 26));
  });

  test('averages each week, oldest first, ending with this week', () {
    final List<WeekAverage> weeks = weeklyAverages([
      (DateTime(2026, 10, 13, 8), 70),
      (DateTime(2026, 10, 15, 8), 75),
      (DateTime(2026, 10, 6, 8), 80),
      (DateTime(2026, 8, 1, 8), 99), // older than eight weeks
    ], now: now);
    expect(weeks, hasLength(8));
    expect(weeks.first.weekStart, DateTime(2026, 8, 24));
    expect(weeks.last.weekStart, DateTime(2026, 10, 12));
    expect(weeks.last.bpm, 73); // 72.5 rounds up
    expect(weeks.last.count, 2);
    expect(weeks[6].bpm, 80);
    expect(weeks[5].bpm, isNull);
    expect(weeks[5].count, 0);
  });

  test('a reading of 0 bpm is not a reading', () {
    final List<WeekAverage> weeks = weeklyAverages([
      (DateTime(2026, 10, 13, 8), 0),
      (DateTime(2026, 10, 14, 8), 64),
    ], now: now);
    expect(weeks.last.bpm, 64);
    expect(weeks.last.count, 1);
  });
}
