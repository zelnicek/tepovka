import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/ppg_analysis_worker.dart';

/// Breathing modulates the PPG amplitude at roughly 0.2 Hz. Estimating that
/// from the 8.5 s heart-rate window meant fitting a rate to about two cycles,
/// which is why the reported value used to sit well away from the truth.
List<double> _syntheticPpg({
  required double bpm,
  required double breathsPerMin,
  required double fs,
  required double seconds,
  int seed = 3,
}) {
  final rand = Random(seed);
  final int n = (fs * seconds).round();
  final double fPulse = bpm / 60.0;
  final double fResp = breathsPerMin / 60.0;
  return <double>[
    for (int i = 0; i < n; i++)
      () {
        final t = i / fs;
        // Amplitude of the pulse is modulated by breathing, which is how the
        // respiratory rate actually shows up in a PPG trace.
        final envelope = 1.0 + 0.4 * sin(2 * pi * fResp * t);
        return 140.0 +
            3.0 * envelope * sin(2 * pi * fPulse * t) +
            (rand.nextDouble() - 0.5) * 0.2;
      }()
  ];
}

PpgAnalysisResult _analyse(List<double> window, double fs) {
  return PpgAnalyzer().analyze(PpgAnalysisRequest(
    window: Float64List.fromList(window.sublist(window.length - (fs * 8.5).round())),
    frameRate: fs,
    absBase: 0,
    lastPeakAbsPosition: -1.0,
    smoothedHeartRate: 0.0,
    computeRespiration: true,
    respirationWindow: Float64List.fromList(window),
  ));
}

void main() {
  const double fs = 30.0;

  test('recovers a normal respiratory rate from a 40 s window', () {
    const double breaths = 15.0;
    final signal =
        _syntheticPpg(bpm: 72, breathsPerMin: breaths, fs: fs, seconds: 40);

    final result = _analyse(signal, fs);
    expect(result.respiratoryRate, closeTo(breaths, 3.0),
        reason: 'expected about $breaths breaths/min');
  });

  test('recovers a slow respiratory rate', () {
    const double breaths = 9.0;
    final signal =
        _syntheticPpg(bpm: 64, breathsPerMin: breaths, fs: fs, seconds: 40);

    final result = _analyse(signal, fs);
    expect(result.respiratoryRate, closeTo(breaths, 3.0));
  });

  test('reports nothing rather than guessing from too short a window', () {
    // Ten seconds holds barely one and a half breathing cycles.
    final short =
        _syntheticPpg(bpm: 72, breathsPerMin: 15, fs: fs, seconds: 10);

    final result = PpgAnalyzer().analyze(PpgAnalysisRequest(
      window: Float64List.fromList(short),
      frameRate: fs,
      absBase: 0,
      lastPeakAbsPosition: -1.0,
      smoothedHeartRate: 0.0,
      computeRespiration: true,
      respirationWindow: Float64List.fromList(short),
    ));
    expect(result.respiratoryRate, lessThanOrEqualTo(0.0),
        reason: 'a window this short must not produce a rate');
  });
}
