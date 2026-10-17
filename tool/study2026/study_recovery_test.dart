// Heart-rate recovery as the result screen computes it (HeartRateRecovery
// on the feet of the pulse wave) against the same computation on the ECG
// beats, for the 90-second recordings of the 2026 study, which were taken
// after exercise. Not part of the test suite. Usage:
//
//   STUDY_JSONL=<work dir>/study.jsonl STUDY_HRR_OUT=<work dir>/hrr.csv \
//     flutter test tool/study2026/study_recovery_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';
import 'package:tepovka/services/heart_rate_recovery.dart';

void main() {
  test('2026 study recovery through Tepovka', () async {
    final String? input = Platform.environment['STUDY_JSONL'];
    final String? output = Platform.environment['STUDY_HRR_OUT'];
    if (input == null || output == null) {
      markTestSkipped('Set STUDY_JSONL and STUDY_HRR_OUT.');
      return;
    }
    final IOSink sink = File(output).openWrite()
      ..writeln('id,length_s,hr0_app,hr0_ecg,hr60_app,hr60_ecg,'
          'hrr60_app,hrr60_ecg,slope60_app,slope60_ecg');
    String f(double v) => v.isFinite ? v.toStringAsFixed(3) : '';
    for (final String line in File(input).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final Map<String, dynamic> rec =
          json.decode(line) as Map<String, dynamic>;
      final List? rPeaks = rec['ecg_r_s'] as List?;
      final double fs = (rec['fs'] as num).toDouble();
      final List<double> y = [
        for (final v in rec['y'] as List) (v as num).toDouble()
      ];
      final List<double> settled =
          y.sublist(((rec['warm'] as num).toDouble() * fs).toInt());
      final double length = settled.length / fs;
      if (rPeaks == null || length < 60) continue;
      final HeartRateRecovery app = HeartRateRecovery.fromBeats(
          [for (final p in FootBeats.of(settled, fs).feet) p.timeSec], length);
      final HeartRateRecovery ecg = HeartRateRecovery.fromBeats(
          [for (final v in rPeaks) (v as num).toDouble()], length);
      sink.writeln([
        rec['id'],
        f(length),
        f(app.hr0),
        f(ecg.hr0),
        f(app.hr60),
        f(ecg.hr60),
        f(app.hrr60),
        f(ecg.hrr60),
        f(app.slope60),
        f(ecg.slope60),
      ].join(','));
    }
    await sink.flush();
    await sink.close();
  }, timeout: Timeout.none);
}
