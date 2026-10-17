// Runs Tepovka's own heart-rate code on the BUT PPG database (PhysioNet,
// butppg 2.0.0) and writes one CSV row per record. Not part of the test
// suite: `flutter test` only runs test/. Usage, from the repo root:
//
//   python3 -I tool/butppg/export_ppg.py <dataset dir> <work dir>
//   BUTPPG_JSONL=<work dir>/ppg.jsonl BUTPPG_OUT=<work dir>/tepovka.csv \
//     flutter test tool/butppg/butppg_eval_test.dart
//   python3 -I tool/butppg/report.py <dataset dir> <work dir>
//
// The dataset stays outside the repository.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/peak_detector.dart';
import 'package:tepovka/elements/spectral_quality.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';

/// The measure screen's filter (home.dart, _appendSample) run offline:
/// median of 5, minus a 2.5 s running mean, then EMA with alpha 0.4. Its
/// input is the inverted channel mean, as the app gets from the camera.
List<double> measureScreenFilter(List<double> inverted, double fs) {
  const int medianWindow = 5;
  final int baselineWindow = (2.5 * fs).round().clamp(20, 600);
  final List<double> medianRing = [];
  final List<double> baselineRing = [];
  double baselineSum = 0;
  double ema = 0;
  final List<double> out = [];
  for (final double v in inverted) {
    medianRing.add(v);
    if (medianRing.length > medianWindow) medianRing.removeAt(0);
    final List<double> sorted = List<double>.from(medianRing)..sort();
    final double median = sorted[sorted.length ~/ 2];
    baselineRing.add(median);
    baselineSum += median;
    if (baselineRing.length > baselineWindow) {
      baselineSum -= baselineRing.removeAt(0);
    }
    final double detrended = median - baselineSum / baselineRing.length;
    ema = ema * 0.6 + detrended * 0.4;
    out.add(ema);
  }
  return out;
}

/// The heart rate the result screen showed and saved until October 2026:
/// 7-sample moving average, PeakDetector, mean interval, and anything
/// outside 40-200 bpm replaced by 70. Kept here for comparison.
double previousResultScreenBpm(List<double> data, double fs) {
  final List<double> smoothed = [];
  for (int i = 0; i < data.length; i++) {
    double sum = 0;
    int n = 0;
    for (int j = max(0, i - 6); j <= i; j++) {
      sum += data[j];
      n++;
    }
    smoothed.add(sum / n);
  }
  final List<int> peaks = PeakDetector.findPeaks(smoothed, sampleRate: fs);
  if (peaks.length < 2) return 0;
  final double raw =
      60 / ((peaks.last - peaks.first) / fs / (peaks.length - 1));
  return raw < 40 || raw > 200 ? 70 : raw;
}

void main() {
  test('BUT PPG through Tepovka', () async {
    final String? input = Platform.environment['BUTPPG_JSONL'];
    final String? output = Platform.environment['BUTPPG_OUT'];
    if (input == null || output == null) {
      markTestSkipped('Set BUTPPG_JSONL and BUTPPG_OUT.');
      return;
    }
    final IOSink sink = File(output).openWrite()
      ..writeln('id,fs,n,app_bpm,previous_bpm,spectral_bpm,'
          'quality,previous_quality,snr,good_window_share');
    String f(double? v) => v != null && v.isFinite ? v.toStringAsFixed(3) : '';
    int count = 0;
    for (final String line in File(input).readAsLinesSync()) {
      if (line.trim().isEmpty) continue;
      final Map<String, dynamic> rec =
          json.decode(line) as Map<String, dynamic>;
      final double fs = (rec['fs'] as num).toDouble();
      final List<double> ppg = [
        for (final v in rec['ppg'] as List) (v as num).toDouble()
      ];
      // The app filters the negated channel mean. BUT PPG is said to store
      // the red mean inverted, but most records hold it as is (about +230,
      // slow rise and sharp drop) and a few negated (about -254), so both
      // become the negated brightness here.
      final List<double> data =
          measureScreenFilter([for (final v in ppg) -v.abs()], fs);
      // What the result screen shows and saves: the feet of the pulse wave.
      final double? app = FootBeats.of(data, fs).bpm;
      final double spectral =
          data.length >= 32 ? spectralHeartRate(data, fs).bpm : double.nan;
      final SpectralQuality? q = assessRecording(data, fs);
      // The grade before the feet had to agree with the spectrum.
      final SpectralQuality? q0 = assessSignalQuality(
          data.sublist((warmupSeconds(data, fs) * fs).toInt()), fs);
      sink.writeln([
        rec['id'],
        f(fs),
        ppg.length,
        f(app),
        f(previousResultScreenBpm(data, fs)),
        f(spectral),
        q?.level.name ?? '',
        q0?.level.name ?? '',
        q == null ? '' : f(q.snr),
        q == null ? '' : f(q.goodWindowShare),
      ].join(','));
      count++;
    }
    // The test would end before the buffered rows reach the file.
    await sink.flush();
    await sink.close();
    // ignore: avoid_print
    print('records: $count');
    expect(count, greaterThan(0));
  }, timeout: Timeout.none);
}
