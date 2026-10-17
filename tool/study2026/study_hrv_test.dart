// HRV the way the result screen computes it (feet of the pulse wave,
// HrvCalculator) against the same calculator on the ECG beats of the same
// stretch, for the 2026 study recordings cut to 20-90 s. Also at half the
// frame rate, to see how much the timing resolution matters. Not part of
// the test suite. Usage as in study_eval_test.dart, with STUDY_HRV_OUT:
//
//   STUDY_JSONL=<work dir>/study.jsonl STUDY_HRV_OUT=<work dir>/hrv.csv \
//     flutter test tool/study2026/study_hrv_test.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/hrv_calculator.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';

void main() {
  test('2026 study HRV through Tepovka', () async {
    final String? input = Platform.environment['STUDY_JSONL'];
    final String? output = Platform.environment['STUDY_HRV_OUT'];
    if (input == null || output == null) {
      markTestSkipped('Set STUDY_JSONL and STUDY_HRV_OUT.');
      return;
    }
    final IOSink sink = File(output).openWrite()
      ..writeln('id,length_s,window_s,decimation,fs,beats_app,beats_ecg,'
          'rmssd_app,rmssd_ecg,sdnn_app,sdnn_ecg,mean_rr_app,mean_rr_ecg');
    String f(double v) => v.isFinite ? v.toStringAsFixed(3) : '';
    for (final String line in File(input).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final Map<String, dynamic> rec =
          json.decode(line) as Map<String, dynamic>;
      final List? rPeaks = rec['ecg_r_s'] as List?;
      if (rPeaks == null) continue;
      final List<double> r = [for (final v in rPeaks) (v as num).toDouble()];
      final double fs0 = (rec['fs'] as num).toDouble();
      final List<double> y0 = [
        for (final v in rec['y'] as List) (v as num).toDouble()
      ];
      final double warm = (rec['warm'] as num).toDouble();
      final List<double> settled = y0.sublist((warm * fs0).toInt());
      final double length = settled.length / fs0;
      for (final int decimation in [1, 2]) {
        final double fs = fs0 / decimation;
        final List<double> y = [
          for (int i = 0; i < settled.length; i += decimation) settled[i]
        ];
        for (final int window in [20, 30, 45, 60, 90]) {
          if (window > length + 1) continue;
          final int n = (window * fs).round().clamp(0, y.length);
          final FootBeats beats = FootBeats.of(y.sublist(0, n), fs);
          final HrvResult app = HrvCalculator.compute(beats.ibisMs);
          final List<double> rIn = [
            for (final double t in r)
              if (t < n / fs) t
          ];
          final HrvResult ecg = HrvCalculator.compute([
            for (int i = 1; i < rIn.length; i++) (rIn[i] - rIn[i - 1]) * 1000
          ]);
          sink.writeln([
            rec['id'],
            f(length),
            window,
            decimation,
            f(fs),
            beats.feet.length,
            rIn.length,
            f(app.rmssd),
            f(ecg.rmssd),
            f(app.sdnn),
            f(ecg.sdnn),
            f(app.meanRrMs),
            f(ecg.meanRrMs),
          ].join(','));
        }
      }
    }
    await sink.flush();
    await sink.close();
  }, timeout: Timeout.none);
}
