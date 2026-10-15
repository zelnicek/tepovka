import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/services/reminder_service.dart';

void main() {
  const int eightAm = 8 * 60;

  test('plans one reminder a day at the chosen time', () {
    final plan = ReminderService.planFor(
        now: DateTime(2026, 10, 15, 6, 0), minutes: eightAm, days: 3);
    expect(plan, [
      DateTime(2026, 10, 15, 8, 0),
      DateTime(2026, 10, 16, 8, 0),
      DateTime(2026, 10, 17, 8, 0),
    ]);
  });

  test('skips today once the time has passed', () {
    final plan = ReminderService.planFor(
        now: DateTime(2026, 10, 15, 9, 0), minutes: eightAm, days: 3);
    expect(plan.first, DateTime(2026, 10, 16, 8, 0));
    expect(plan, hasLength(2));
  });

  test('skips today when already measured today', () {
    final plan = ReminderService.planFor(
      now: DateTime(2026, 10, 15, 7, 0),
      minutes: eightAm,
      lastMeasurement: DateTime(2026, 10, 15, 6, 45),
      days: 3,
    );
    expect(plan.first, DateTime(2026, 10, 16, 8, 0));
  });

  test("yesterday's measurement does not skip today", () {
    final plan = ReminderService.planFor(
      now: DateTime(2026, 10, 15, 7, 0),
      minutes: eightAm,
      lastMeasurement: DateTime(2026, 10, 14, 20, 0),
      days: 1,
    );
    expect(plan, [DateTime(2026, 10, 15, 8, 0)]);
  });

  test('keeps the wall-clock time across month ends', () {
    final plan = ReminderService.planFor(
        now: DateTime(2026, 10, 30, 6, 0), minutes: 19 * 60 + 30, days: 4);
    expect(plan.map((d) => '${d.month}/${d.day} ${d.hour}:${d.minute}'),
        ['10/30 19:30', '10/31 19:30', '11/1 19:30', '11/2 19:30']);
  });
}
