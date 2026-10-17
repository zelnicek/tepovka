import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/services/heart_rate_recovery.dart';

/// Beats of a heart rate falling from 130 towards 70 bpm with a 40 s time
/// constant, as after exercise.
List<double> recoveringBeats(double seconds) {
  double bpm(double t) => 70 + 60 * exp(-t / 40);
  final List<double> beats = [0.2];
  while (beats.last < seconds) {
    beats.add(beats.last + 60 / bpm(beats.last));
  }
  return beats..removeLast();
}

void main() {
  test('reads the fall of the heart rate from the beats', () {
    final h = HeartRateRecovery.fromBeats(recoveringBeats(120), 120);
    // Means over the 10 s windows of the curve above.
    expect(h.hr0, closeTo(123, 3));
    expect(h.hr60, closeTo(85, 2));
    expect(h.hr120, closeTo(73.5, 2));
    expect(h.hrr60, closeTo(38, 4));
    expect(h.hrr120, closeTo(49.5, 4));
    expect(h.slope60, lessThan(-20));
    expect(h.tauSec, inInclusiveRange(20, 60));
    expect(h.curve.length, 24);
    expect(h.curve.first.$1, 2.5);
  });

  test('a short recording has no two-minute values', () {
    final h = HeartRateRecovery.fromBeats(recoveringBeats(30), 30);
    expect(h.hr0, greaterThan(0));
    expect(h.hr60, 0);
    expect(h.hrr60, 0);
    expect(h.hrr120, 0);
  });

  test('too few beats give nothing rather than a guess', () {
    expect(heartRateBetween([1.0, 2.0, 3.0], 0, 10), 0);
    expect(HeartRateRecovery.fromBeats(const [], 120).hr0, 0);
  });
}
