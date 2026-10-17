import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/spectral_quality.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';
import 'package:tepovka/services/measurement_quality.dart';

/// A pulse wave with pulses up: a quick rise and a slower fall each beat.
List<double> pulseWave(double bpm, double fs, double seconds,
    {double width = 0.35, double noise = 0, int seed = 1}) {
  final Random rng = Random(seed);
  final double period = 60 / bpm;
  return [
    for (int i = 0; i < (seconds * fs).round(); i++)
      () {
        final double phase = (i / fs) % period / period;
        final double pulse = phase < width
            ? sin(pi / 2 * phase / width)
            : cos(pi / 2 * (phase - width) / (1 - width));
        return pulse + noise * (rng.nextDouble() - 0.5);
      }()
  ];
}

void main() {
  test('times the heart rate by the feet', () {
    final FootBeats beats = FootBeats.of(pulseWave(72, 30, 20), 30);
    expect(beats.bpm, closeTo(72, 1));
    expect(beats.ibisMs.length, greaterThanOrEqualTo(20));
  });

  test('gives no heart rate for a flat recording', () {
    expect(FootBeats.of(List.filled(600, 0.0), 30).bpm, isNull);
    expect(FootBeats.of(const [], 30).bpm, isNull);
  });

  test('a clean recording is good and keeps the foot heart rate', () {
    final SpectralQuality q = assessRecording(pulseWave(72, 30, 30), 30)!;
    expect(q.level, MeasurementQuality.good);
    expect(q.footBpm, closeTo(72, 1));
    expect(SpectralQuality.fromJson(q.toJson())!.footBpm, q.footBpm);
  });

  test('a recording the feet give no heart rate for is poor', () {
    final SpectralQuality q = assessRecording(List.filled(900, 0.0), 30)!;
    expect(q.level, MeasurementQuality.poor);
    expect(q.footBpm.isNaN, isTrue);
  });

  test('grades stored by the spectrum alone are graded again', () {
    expect(
        SpectralQuality.fromJson({
          'method': 'spectral-snr-2026',
          'level': 'good',
          'snr': 15.0,
          'goodWindowShare': 1.0,
        }),
        isNull);
  });
}
