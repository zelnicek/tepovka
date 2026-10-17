import 'dart:collection';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/live_tops.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';

void main() {
  test('every beat gets one dot as the wave streams in', () {
    // 72 bpm at 30 frames a second for 30 s, pulses up, scanned the way the
    // measure screen does: an 8 s window, four times a second.
    const double fs = 30;
    const double period = 60 / 72;
    final ListQueue<double> values = ListQueue();
    final ListQueue<double> times = ListQueue();
    final List<double> dots = [];
    for (int i = 0; i < 30 * fs; i++) {
      final double t = i / fs;
      final double p = t % period / period;
      values.add(
          p < 0.35 ? sin(pi / 2 * p / 0.35) : cos(pi / 2 * (p - 0.35) / 0.65));
      times.add(t);
      while (values.length > kLiveWindowSeconds * fs) {
        values.removeFirst();
        times.removeFirst();
      }
      if (i % 7 == 0) {
        for (final (double at, double _) in newLiveTops(
            values.toList(), times.toList(), fs,
            now: t, lastPlaced: dots.isEmpty ? null : dots.last)) {
          dots.add(at);
        }
      }
    }
    // Every beat of the 30 s; the last top may not have settled yet.
    final int beats = (30 / period).floor();
    expect(dots.length, inInclusiveRange(beats - 1, beats));
    for (int i = 1; i < dots.length; i++) {
      expect(dots[i] - dots[i - 1], closeTo(period, 0.1));
    }
  });
}
