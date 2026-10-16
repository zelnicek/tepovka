import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/services/achievements.dart';
import 'package:tepovka/services/measurement_tags.dart';

StatReading _at(int month, int day, int bpm,
        {List<MeasurementTag> tags = const [],
        String? quality,
        int hour = 8}) =>
    StatReading(
        at: DateTime(2026, month, day, hour),
        bpm: bpm,
        tags: tags,
        quality: quality);

void main() {
  // Friday 16 October 2026, late morning.
  final DateTime now = DateTime(2026, 10, 16, 11, 30);

  group('streaks', () {
    test('count back from today when today has a measurement', () {
      final s = HeartStats.of([
        _at(10, 14, 70),
        _at(10, 15, 70),
        _at(10, 16, 70),
        _at(10, 16, 72, hour: 9), // two on one day still one day
        _at(10, 12, 70), // gap on the 13th
      ], now: now);
      expect(s.measuredToday, isTrue);
      expect(s.currentStreak, 3);
      expect(s.bestStreak, 3);
    });

    test('stay alive through today when the last one was yesterday', () {
      final s = HeartStats.of([_at(10, 14, 70), _at(10, 15, 70)], now: now);
      expect(s.measuredToday, isFalse);
      expect(s.currentStreak, 2);
    });

    test('break after a whole day without a measurement', () {
      final s = HeartStats.of([_at(10, 13, 70), _at(10, 14, 70)], now: now);
      expect(s.currentStreak, 0);
      expect(s.bestStreak, 2);
    });

    test('run across the end of summer time', () {
      // Czech summer time ends on Sunday 25 October 2026.
      final s = HeartStats.of([
        for (int d = 22; d <= 28; d++) _at(10, d, 70),
      ], now: DateTime(2026, 10, 28, 20));
      expect(s.currentStreak, 7);
      expect(s.bestStreak, 7);
    });
  });

  group('resting heart rate and heartbeats', () {
    test('leave out exercise, coffee, stress and a poor signal', () {
      final s = HeartStats.of([
        _at(10, 16, 60),
        _at(10, 15, 64),
        _at(10, 15, 110, tags: [MeasurementTag.exercise]),
        _at(10, 14, 95, tags: [MeasurementTag.caffeine]),
        _at(10, 14, 130, quality: 'poor'),
      ], now: now);
      expect(s.restingBpm, 62);
    });

    test('estimate beats from the resting rate', () {
      final s = HeartStats.of([_at(10, 1, 72), _at(10, 16, 72)], now: now);
      // 11 h 30 min since midnight at 72 a minute.
      expect(s.beatsToday(now), 72 * (11 * 60 + 30));
      // From the start of 1 October: 15 days and 11.5 hours.
      expect(s.beatsSinceFirst(now), 72 * (15 * 24 * 60 + 11 * 60 + 30));
    });

    test('have nothing to estimate without measurements', () {
      final s = HeartStats.of([], now: now);
      expect(s.restingBpm, isNull);
      expect(s.beatsToday(now), isNull);
      expect(s.currentStreak, 0);
    });
  });

  test('daily resting average keeps days with only non-resting readings', () {
    final Map<DateTime, ({int? bpm, int count})> days = dailyResting([
      _at(10, 16, 60),
      _at(10, 16, 70, hour: 20),
      _at(10, 15, 120, tags: [MeasurementTag.exercise]),
    ]);
    expect(days[DateTime(2026, 10, 16)], (bpm: 65, count: 2));
    expect(days[DateTime(2026, 10, 15)], (bpm: null, count: 1));
  });

  test('reads stored records and skips those without a heart rate', () {
    final List<StatReading> readings = StatReading.fromStored([
      {
        'startedAt': '2026-10-16T09:10:00',
        'averageBPM': 72,
        'tags': ['morning', 'rest'],
        'signalQuality': {'level': 'good'},
      },
      {'date': '2026-10-16', 'time': '09:20:00', 'averageBPM': 0},
      {'date': '2026-10-15', 'time': '08:15:00', 'averageBPM': 70.6},
    ]);
    expect(readings, hasLength(2));
    expect(readings.first.tags, [MeasurementTag.morning, MeasurementTag.rest]);
    expect(readings.first.quality, 'good');
    expect(readings.last.bpm, 71);
  });

  group('badges', () {
    test('unlock by measurements, streaks and morning tags', () {
      final s = HeartStats.of([
        for (int d = 1; d <= 7; d++)
          _at(10, d, 70, tags: [MeasurementTag.morning]),
        for (int d = 1; d <= 4; d++) _at(10, d, 70, hour: 20),
      ], now: DateTime(2026, 10, 7, 21));
      expect(HeartBadge.firstBeat.unlockedIn(s), isTrue);
      expect(HeartBadge.tenMeasurements.unlockedIn(s), isTrue);
      expect(HeartBadge.thirtyMeasurements.progressIn(s), 11);
      expect(HeartBadge.streak7.unlockedIn(s), isTrue);
      expect(HeartBadge.streak30.unlockedIn(s), isFalse);
      expect(HeartBadge.earlyBird.unlockedIn(s), isTrue);
    });

    test('the first check notes what is unlocked without announcing it',
        () async {
      SharedPreferences.setMockInitialValues({});
      final one = HeartStats.of([_at(10, 16, 70)], now: now);
      expect(await HeartBadge.takeNew(one), isEmpty);
      expect(await HeartBadge.takeNew(one), isEmpty);
      final three = HeartStats.of(
          [_at(10, 14, 70), _at(10, 15, 70), _at(10, 16, 70)],
          now: now);
      expect(await HeartBadge.takeNew(three), [HeartBadge.streak3]);
      expect(await HeartBadge.takeNew(three), isEmpty);
    });
  });
}
