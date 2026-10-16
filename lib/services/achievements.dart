import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/measurement_tags.dart';

/// One measurement as the statistics see it.
class StatReading {
  const StatReading({
    required this.at,
    required this.bpm,
    this.tags = const [],
    this.quality,
  });

  /// From a stored record; null when it has no time or no heart rate.
  static StatReading? fromJson(Map<String, dynamic> r) {
    final DateTime? at = DateTime.tryParse('${r['startedAt'] ?? ''}') ??
        DateTime.tryParse('${r['date']} ${r['time']}');
    final int bpm =
        r['averageBPM'] is num ? (r['averageBPM'] as num).round() : 0;
    if (at == null || bpm <= 0) return null;
    final Object? q = r['signalQuality'];
    return StatReading(
      at: at,
      bpm: bpm,
      tags: r['tags'] is List
          ? MeasurementTag.fromNames([for (final v in r['tags'] as List) '$v'])
          : const [],
      quality: q is Map ? q['level'] as String? : null,
    );
  }

  static List<StatReading> fromStored(Iterable<Map<String, dynamic>> records) =>
      records.map(fromJson).whereType<StatReading>().toList();

  final DateTime at;
  final int bpm;
  final List<MeasurementTag> tags;

  /// 'good', 'medium', 'poor' or null when not graded.
  final String? quality;

  /// Says something about the resting heart rate: not after exercise,
  /// coffee or stress, and not from a poor signal.
  bool get resting => quality != 'poor' && !tags.any((t) => t.raisesHeartRate);
}

/// Local midnight of the day [at] falls on, from the calendar date so a
/// daylight saving change cannot shift it.
DateTime dayOf(DateTime at) {
  final DateTime local = at.toLocal();
  return DateTime(local.year, local.month, local.day);
}

DateTime _previousDay(DateTime day) =>
    DateTime(day.year, day.month, day.day - 1);

/// Counts, streaks and the resting heart rate the estimates are based on.
class HeartStats {
  HeartStats._({
    required this.measurements,
    required this.currentStreak,
    required this.measuredToday,
    required this.bestStreak,
    required this.restingBpm,
    required this.firstDay,
    required this.morningCount,
  });

  factory HeartStats.of(List<StatReading> readings, {required DateTime now}) {
    final Set<DateTime> days = {for (final r in readings) dayOf(r.at)};
    int runFrom(DateTime day) {
      int n = 0;
      for (DateTime d = day; days.contains(d); d = _previousDay(d)) {
        n++;
      }
      return n;
    }

    final DateTime today = dayOf(now);
    final bool measuredToday = days.contains(today);
    // A streak survives until the end of the day after the last measurement.
    final int current =
        measuredToday ? runFrom(today) : runFrom(_previousDay(today));

    int best = 0;
    for (final DateTime d in days) {
      // Only count from the first day of each run.
      if (!days.contains(_previousDay(d))) {
        best = max(best, _runForward(days, d));
      }
    }

    // The resting rate: resting readings of the last 30 days, else any
    // resting reading, else anything at all.
    final DateTime monthAgo = DateTime(today.year, today.month, today.day - 30);
    final List<int> recent = [
      for (final r in readings)
        if (r.resting && !r.at.isBefore(monthAgo)) r.bpm
    ];
    final List<int> resting = [
      for (final r in readings)
        if (r.resting) r.bpm
    ];
    final List<int> pool = recent.isNotEmpty
        ? recent
        : resting.isNotEmpty
            ? resting
            : [for (final r in readings) r.bpm];

    return HeartStats._(
      measurements: readings.length,
      currentStreak: current,
      measuredToday: measuredToday,
      bestStreak: best,
      restingBpm: pool.isEmpty
          ? null
          : (pool.reduce((a, b) => a + b) / pool.length).round(),
      firstDay:
          days.isEmpty ? null : days.reduce((a, b) => a.isBefore(b) ? a : b),
      morningCount:
          readings.where((r) => r.tags.contains(MeasurementTag.morning)).length,
    );
  }

  /// Length of the run of consecutive days starting at [first].
  static int _runForward(Set<DateTime> days, DateTime first) {
    int n = 0;
    for (DateTime d = first;
        days.contains(d);
        d = DateTime(d.year, d.month, d.day + 1)) {
      n++;
    }
    return n;
  }

  final int measurements;

  /// Days in a row up to today, or up to yesterday while today is still open.
  final int currentStreak;
  final bool measuredToday;
  final int bestStreak;
  final int? restingBpm;
  final DateTime? firstDay;
  final int morningCount;

  /// Heartbeats since midnight at the resting rate: a rough estimate, the
  /// heart beats slower asleep and faster on the move.
  int? beatsToday(DateTime now) => restingBpm == null
      ? null
      : (restingBpm! * now.difference(dayOf(now)).inSeconds / 60).round();

  /// Heartbeats since the start of the first day with a measurement.
  int? beatsSinceFirst(DateTime now) => restingBpm == null || firstDay == null
      ? null
      : (restingBpm! * now.difference(firstDay!).inSeconds / 60).round();
}

/// Average resting heart rate of each day, with how many readings it is
/// from; a day with readings but none at rest maps to (null, count).
Map<DateTime, ({int? bpm, int count})> dailyResting(
    List<StatReading> readings) {
  final Map<DateTime, List<StatReading>> byDay = {};
  for (final StatReading r in readings) {
    byDay.putIfAbsent(dayOf(r.at), () => []).add(r);
  }
  return {
    for (final MapEntry<DateTime, List<StatReading>> e in byDay.entries)
      e.key: (
        bpm: () {
          final List<int> rest = [
            for (final r in e.value)
              if (r.resting) r.bpm
          ];
          return rest.isEmpty
              ? null
              : (rest.reduce((a, b) => a + b) / rest.length).round();
        }(),
        count: e.value.length,
      ),
  };
}

/// What there is to collect. [goal] is reached by the count each one
/// measures in [HeartStats].
enum HeartBadge {
  firstBeat(1),
  tenMeasurements(10),
  thirtyMeasurements(30),
  hundredMeasurements(100),
  streak3(3),
  streak7(7),
  streak30(30),
  earlyBird(7);

  const HeartBadge(this.goal);

  final int goal;

  int progressIn(HeartStats s) => switch (this) {
        firstBeat ||
        tenMeasurements ||
        thirtyMeasurements ||
        hundredMeasurements =>
          s.measurements,
        streak3 || streak7 || streak30 => s.bestStreak,
        earlyBird => s.morningCount,
      };

  bool unlockedIn(HeartStats s) => progressIn(s) >= goal;

  static const String _seenKey = 'badges_seen';

  /// Badges unlocked since the last call. The first call ever only notes
  /// what is unlocked already, so an update does not shower someone who has
  /// measured for months with a pile of badges at once.
  static Future<List<HeartBadge>> takeNew(HeartStats s) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? seen = prefs.getStringList(_seenKey);
    final List<HeartBadge> unlocked = [
      for (final HeartBadge b in values)
        if (b.unlockedIn(s)) b
    ];
    await prefs.setStringList(_seenKey, [
      ...{...?seen, for (final b in unlocked) b.name}
    ]);
    if (seen == null) return const [];
    return [
      for (final b in unlocked)
        if (!seen.contains(b.name)) b
    ];
  }
}

extension HeartBadgeX on HeartBadge {
  String title(L10n t) => switch (this) {
        HeartBadge.firstBeat => t.badgeFirstBeat,
        HeartBadge.tenMeasurements => t.badgeTen,
        HeartBadge.thirtyMeasurements => t.badgeThirty,
        HeartBadge.hundredMeasurements => t.badgeHundred,
        HeartBadge.streak3 => t.badgeStreak3,
        HeartBadge.streak7 => t.badgeStreak7,
        HeartBadge.streak30 => t.badgeStreak30,
        HeartBadge.earlyBird => t.badgeEarlyBird,
      };

  String description(L10n t) => switch (this) {
        HeartBadge.firstBeat => t.badgeFirstBeatHint,
        HeartBadge.tenMeasurements ||
        HeartBadge.thirtyMeasurements ||
        HeartBadge.hundredMeasurements =>
          t.badgeMeasurementsHint(goal),
        HeartBadge.streak3 ||
        HeartBadge.streak7 ||
        HeartBadge.streak30 =>
          t.badgeStreakHint(goal),
        HeartBadge.earlyBird => t.badgeEarlyBirdHint(goal),
      };

  IconData get icon => switch (this) {
        HeartBadge.firstBeat => Symbols.favorite,
        HeartBadge.tenMeasurements => Symbols.star,
        HeartBadge.thirtyMeasurements => Symbols.military_tech,
        HeartBadge.hundredMeasurements => Symbols.workspace_premium,
        HeartBadge.streak3 => Symbols.local_fire_department,
        HeartBadge.streak7 => Symbols.event_available,
        HeartBadge.streak30 => Symbols.emoji_events,
        HeartBadge.earlyBird => Symbols.wb_twilight,
      };
}
