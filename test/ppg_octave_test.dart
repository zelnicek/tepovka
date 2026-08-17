import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/ppg_analysis_worker.dart';

/// A real pulse waveform is not a sine: the dicrotic notch puts a lot of energy
/// into the second harmonic, and when perfusion is poor that harmonic can be
/// taller than the fundamental. The estimator must still report the beat rate,
/// not twice it.
PpgAnalysisRequest _request(List<double> samples, double fs) {
  return PpgAnalysisRequest(
    window: Float64List.fromList(samples),
    frameRate: fs,
    absBase: 0,
    lastPeakAbsPosition: -1.0,
    smoothedHeartRate: 0.0,
    computeRespiration: false,
  );
}

void main() {
  const double fs = 30.0;
  const int n = 256;

  test('reports the fundamental when the second harmonic dominates', () {
    const double trueBpm = 80.0;
    final double f = trueBpm / 60.0;
    final rand = Random(7);

    final samples = <double>[
      for (int i = 0; i < n; i++)
        () {
          final t = i / fs;
          // Second harmonic deliberately three times the fundamental.
          return 1.0 * sin(2 * pi * f * t) +
              3.0 * sin(2 * pi * 2 * f * t) +
              (rand.nextDouble() - 0.5) * 0.1;
        }()
    ];

    final result = PpgAnalyzer().analyze(_request(samples, fs));
    expect(
      result.smoothedHeartRate,
      closeTo(trueBpm, 6.0),
      reason: 'should lock onto ${trueBpm}bpm, not its 160bpm harmonic',
    );
  });

  test('leaves a clean single-tone pulse alone', () {
    const double trueBpm = 72.0;
    final double f = trueBpm / 60.0;
    final rand = Random(11);

    final samples = <double>[
      for (int i = 0; i < n; i++)
        () {
          final t = i / fs;
          return 3.0 * sin(2 * pi * f * t) + (rand.nextDouble() - 0.5) * 0.1;
        }()
    ];

    final result = PpgAnalyzer().analyze(_request(samples, fs));
    expect(result.smoothedHeartRate, closeTo(trueBpm, 5.0));
  });

  test('does not halve a genuinely fast pulse', () {
    const double trueBpm = 150.0;
    final double f = trueBpm / 60.0;
    final rand = Random(13);

    final samples = <double>[
      for (int i = 0; i < n; i++)
        () {
          final t = i / fs;
          return 3.0 * sin(2 * pi * f * t) + (rand.nextDouble() - 0.5) * 0.1;
        }()
    ];

    final result = PpgAnalyzer().analyze(_request(samples, fs));
    expect(
      result.smoothedHeartRate,
      closeTo(trueBpm, 8.0),
      reason: 'a real 150bpm pulse must not be reported as 75bpm',
    );
  });
}
