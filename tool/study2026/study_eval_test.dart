// Runs Tepovka's heart-rate and quality code on the recordings of the 2026
// validation study (Tepovka_mereni_2026, ECG and Nonin references) and
// writes one CSV row per recording. Not part of the test suite. Usage:
//
//   python3 export_pro_aplikaci.py <work dir>/study.jsonl   (in the study folder)
//   STUDY_JSONL=<work dir>/study.jsonl STUDY_OUT=<work dir>/tepovka.csv \
//     flutter test tool/study2026/study_eval_test.dart
//
// The recordings are participant data and stay outside the repository.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/spectral_quality.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';

import '../butppg/butppg_eval_test.dart' show previousResultScreenBpm;

void main() {
  test('2026 study through Tepovka', () async {
    final String? input = Platform.environment['STUDY_JSONL'];
    final String? output = Platform.environment['STUDY_OUT'];
    if (input == null || output == null) {
      markTestSkipped('Set STUDY_JSONL and STUDY_OUT.');
      return;
    }
    final IOSink sink = File(output).openWrite()
      ..writeln('id,fs,warm,app_bpm,app_bpm_with_warmup,previous_bpm,'
          'quality,agreement,previous_quality,hr_ecg,hr_nonin,hr_app,hr_peaks_new,'
          'opravena_app');
    String f(Object? v) => v is double
        ? (v.isFinite ? v.toStringAsFixed(3) : '')
        : (v?.toString() ?? '');
    int count = 0;
    for (final String line in File(input).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final Map<String, dynamic> rec =
          json.decode(line) as Map<String, dynamic>;
      final double fs = (rec['fs'] as num).toDouble();
      final List<double> y = [
        for (final v in rec['y'] as List) (v as num).toDouble()
      ];
      // Recordings from before the August 2026 fix start with a transient
      // the app no longer records; the settled part is what it sees now.
      final double warm = (rec['warm'] as num).toDouble();
      final List<double> settled = y.sublist((warm * fs).toInt());
      double? ref(String k) => (rec[k] as num?)?.toDouble();
      sink.writeln([
        rec['id'],
        f(fs),
        f(warm),
        f(FootBeats.of(settled, fs).bpm),
        f(FootBeats.of(y, fs).bpm),
        f(previousResultScreenBpm(settled, fs)),
        assessRecording(y, fs)?.level.name ?? '',
        f(assessRecording(y, fs)?.methodAgreement),
        assessSignalQuality(settled, fs)?.level.name ?? '',
        f(ref('hr_ecg')),
        f(ref('hr_nonin')),
        f(ref('hr_app')),
        f(ref('hr_peaks_new')),
        f(rec['opravena_app']),
      ].join(','));
      count++;
    }
    await sink.flush();
    await sink.close();
    // ignore: avoid_print
    print('records: $count');
    expect(count, greaterThan(0));
  }, timeout: Timeout.none);
}
