import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/ppg_algo.dart';

/// Measures how long each ingested sample takes on the calling isolate.
///
/// Samples are fed at a real ~30 FPS cadence, because the algorithm derives its
/// working sample rate from wall-clock timestamps — feeding a tight loop makes
/// it compute an absurd frame rate and short-circuit the very code we want to
/// time. The interesting number is the tail: the analysis burst lands on one
/// sample out of every 30, and anything above ~8 ms there drops UI frames.
void main() {
  test('per-sample cost distribution', () async {
    final algo = PPGAlgorithm();
    // Mirrors production: the isolate is spawned before measuring starts.
    algo.warmUp();
    await Future<void>.delayed(const Duration(milliseconds: 400));
    final rand = Random(42);
    final timings = <double>[];
    final sw = Stopwatch();

    const int samples = 450; // ~15 s at 30 FPS
    for (int i = 0; i < samples; i++) {
      final t = i / 30.0;
      // Synthetic PPG: 72 BPM pulse + respiratory drift + noise on a DC level.
      final pulse = 3.0 * sin(2 * pi * 1.2 * t);
      final resp = 1.5 * sin(2 * pi * 0.25 * t);
      final noise = (rand.nextDouble() - 0.5) * 0.8;
      final green = 140.0 + pulse + resp + noise;

      sw
        ..reset()
        ..start();
      algo.processRgbSample(red: 200.0 + pulse * 0.4, green: green, blue: 90.0);
      sw.stop();
      timings.add(sw.elapsedMicroseconds / 1000.0);

      // Real pacing so the measured frame rate lands near 30 FPS.
      await Future<void>.delayed(const Duration(milliseconds: 33));
    }

    final sorted = List<double>.from(timings)..sort();
    double pct(double p) =>
        sorted[(sorted.length * p).clamp(0, sorted.length - 1).toInt()];

    final heavy = <double>[];
    final light = <double>[];
    for (final t in timings) {
      (t > 1.0 ? heavy : light).add(t);
    }
    heavy.sort();

    print('--- per-sample cost (ms) ---');
    print('measured frame rate: ${algo.measuredFrameRate.toStringAsFixed(1)}');
    print('samples: ${timings.length}');
    print('median : ${pct(0.5).toStringAsFixed(3)}');
    print('p95    : ${pct(0.95).toStringAsFixed(3)}');
    print('p99    : ${pct(0.99).toStringAsFixed(3)}');
    print('max    : ${sorted.last.toStringAsFixed(3)}');
    final burstAt = <String>[];
    for (int i = 0; i < timings.length; i++) {
      if (timings[i] > 1.0) {
        burstAt.add('#$i=${timings[i].toStringAsFixed(1)}');
      }
    }
    print('burst positions: ${burstAt.join(', ')}');
    print('--- analysis bursts (>1 ms): ${heavy.length} ---');
    if (heavy.isNotEmpty) {
      final sum = heavy.reduce((a, b) => a + b);
      print('burst mean: ${(sum / heavy.length).toStringAsFixed(3)}');
      print('burst max : ${heavy.last.toStringAsFixed(3)}');
    }
    final lightSum = light.isEmpty ? 0.0 : light.reduce((a, b) => a + b);
    print('non-burst mean: '
        '${light.isEmpty ? 0 : (lightSum / light.length).toStringAsFixed(4)}');
    print('BPM=${algo.getCurrentHeartRate().toStringAsFixed(1)} '
        'RR=${algo.getCurrentRespiratoryRate().toStringAsFixed(1)}');
  }, timeout: const Timeout(Duration(minutes: 2)));
}
