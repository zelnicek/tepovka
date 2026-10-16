import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/spectral_quality.dart';
import 'package:tepovka/services/measurement_quality.dart';

/// The quality thresholds were validated against ECG for exactly the Python
/// computation in the 2026 study, so the port has to reproduce it, not just
/// resemble it. The fixture holds synthetic signals with the values Python
/// produced for them. (Checked separately against all 61 study recordings:
/// same level on every one.)
void main() {
  final Map<String, dynamic> fixture = json.decode(
      File('test/fixtures/spectral_quality_synthetic.json')
          .readAsStringSync()) as Map<String, dynamic>;

  for (final Map<String, dynamic> c
      in (fixture['cases'] as List).cast<Map<String, dynamic>>()) {
    test('reproduces tepovka_ppg.quality() on ${c['name']}', () {
      final List<double> signal = [
        for (final v in c['signal'] as List) (v as num).toDouble()
      ];
      final SpectralQuality q =
          assessSignalQuality(signal, (c['fs'] as num).toDouble())!;
      expect(q.snr, closeTo(c['snr'] as num, (c['snr'] as num) * 1e-6));
      expect(q.goodWindowShare, closeTo(c['goodWindowShare'] as num, 1e-9));
      expect(q.heartRateBpm, closeTo(c['heartRateBpm'] as num, 1e-6));
      expect(q.level.name, c['level']);
    });
  }

  test('cuts the start-up transient like the study before grading', () {
    final Map<String, dynamic> c = fixture['warmup'] as Map<String, dynamic>;
    final List<double> signal = [
      for (final v in c['signal'] as List) (v as num).toDouble()
    ];
    final double fs = (c['fs'] as num).toDouble();
    expect(warmupSeconds(signal, fs), (c['warmupSeconds'] as num).toDouble());
    final SpectralQuality q = assessRecording(signal, fs)!;
    expect(q.snr, closeTo(c['snr'] as num, (c['snr'] as num) * 1e-6));
    expect(q.level.name, c['level']);
  });

  test('round-trips through the stored record', () {
    const q = SpectralQuality(
      heartRateBpm: 72.5,
      snr: 15.2,
      goodWindowShare: 0.9,
      level: MeasurementQuality.good,
    );
    final SpectralQuality? back =
        SpectralQuality.fromJson(json.decode(json.encode(q.toJson())));
    expect(back?.level, MeasurementQuality.good);
    expect(back?.snr, 15.2);
    expect(SpectralQuality.fromJson({'level': 'good'}), isNull);
  });

  test('too short to judge', () {
    expect(assessSignalQuality(List.filled(20, 0.0), 24), isNull);
  });
}
