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
    expect(q.methodAgreement, 1.0);
    expect(q.methodsDisagree, isFalse);
    final SpectralQuality back = SpectralQuality.fromJson(q.toJson())!;
    expect(back.footBpm, q.footBpm);
    expect(back.methodAgreement, q.methodAgreement);
  });

  test('a recording the feet give no heart rate for is poor', () {
    final SpectralQuality q = assessRecording(List.filled(900, 0.0), 30)!;
    expect(q.level, MeasurementQuality.poor);
    expect(q.footBpm.isNaN, isTrue);
  });

  test('agreement is judged window by window', () {
    // 90 s whose rate falls from 110 to 70 bpm, as after exercise: one
    // spectrum and one median interval for the whole would differ.
    const double fs = 30;
    double phase = 0;
    final List<double> wave = [];
    for (int i = 0; i < 90 * fs; i++) {
      final double bpm = 110 - 40 * i / (90 * fs);
      phase += bpm / 60 / fs;
      final double p = phase % 1;
      wave.add(
          p < 0.35 ? sin(pi / 2 * p / 0.35) : cos(pi / 2 * (p - 0.35) / 0.65));
    }
    final List<PpgPeak> feet = FootBeats.of(wave, fs).feet;
    expect(methodAgreement(wave, fs, feet), greaterThanOrEqualTo(0.8));
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
