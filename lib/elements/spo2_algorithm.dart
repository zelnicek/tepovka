import 'dart:math';
import 'package:flutter/foundation.dart';

class SpO2Algorithm {
  // Smartphone-only empirical calibration (not clinical-grade oximeter).
  static const double _calA = 110.0;
  static const double _calB = 25.0;

  final List<double> _redSamples = [];
  final List<double> _greenSamples = [];
  final List<double> _spo2History = [];

  double _currentSpO2 = 0.0;
  double get currentSpO2 => _currentSpO2;

  void addSample(double red, double green) {
    _redSamples.add(red);
    _greenSamples.add(green);

    // ~3 s window at 30 FPS
    if (_redSamples.length > 90) {
      _redSamples.removeAt(0);
      _greenSamples.removeAt(0);
    }

    if (_redSamples.length >= 60) {
      _calculate();
    }
  }

  void _calculate() {
    if (_redSamples.length < 60) return;

    final double dcRed = _average(_redSamples);
    final double dcGreen = _average(_greenSamples);

    if (dcRed < 10.0 || dcGreen < 10.0) return;

    // Strong guard for missing finger contact/flashlight.
    if (dcRed < 100.0) {
      debugPrint(
          'SPO2: baterka vypnuta nebo prst neni prilozen (dcRed=${dcRed.toStringAsFixed(1)})');
      return;
    }

    // Remove baseline and isolate pulsatile component.
    final List<double> centeredRed = _redSamples.map((v) => v - dcRed).toList();
    final List<double> centeredGreen =
        _greenSamples.map((v) => v - dcGreen).toList();

    final List<double> filteredRed = _bandpass(centeredRed, 0.7, 3.5, 30.0);
    final List<double> filteredGreen = _bandpass(centeredGreen, 0.7, 3.5, 30.0);

    final List<double> redUsed =
        filteredRed.length > 10 ? filteredRed.sublist(10) : filteredRed;
    final List<double> greenUsed =
        filteredGreen.length > 10 ? filteredGreen.sublist(10) : filteredGreen;

    if (redUsed.isEmpty || greenUsed.isEmpty) return;

    // AC amplitude from peak-to-valley envelope.
    final double acRed = (_max(redUsed) - _min(redUsed)) / 2.0;
    final double acGreen = (_max(greenUsed) - _min(greenUsed)) / 2.0;

    if (acRed < 0.5 || acGreen < 0.5) return;

    final double ratio = (acRed / dcRed) / (acGreen / dcGreen);
    if (ratio < 0.3 || ratio > 1.8) return;

    debugPrint('SPO2_CAL: R=${ratio.toStringAsFixed(4)}, spo2_ref=???');

    double spo2 = _calA - _calB * ratio;
    spo2 = spo2.clamp(70.0, 100.0);

    // EMA smoothing for stable UI.
    if (_currentSpO2 == 0.0) {
      _currentSpO2 = spo2;
    } else {
      _currentSpO2 = _currentSpO2 * 0.8 + spo2 * 0.2;
    }

    _spo2History.add(_currentSpO2);
  }

  double getSummarySpO2() {
    if (_spo2History.isEmpty) return 0.0;
    final sorted = List<double>.from(_spo2History)..sort();
    return sorted[sorted.length ~/ 2];
  }

  void reset() {
    _redSamples.clear();
    _greenSamples.clear();
    _spo2History.clear();
    _currentSpO2 = 0.0;
  }

  double _average(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  List<double> _bandpass(
      List<double> signal, double low, double high, double fs) {
    if (signal.length < 4) return signal;

    final nyq = fs / 2.0;

    // 2nd-order low-pass with cutoff=high
    final wcL = tan(pi * high / nyq);
    final aL = 1 + sqrt(2) * wcL + wcL * wcL;
    final b0L = wcL * wcL / aL;
    final b1L = 2 * b0L;
    final b2L = b0L;
    final a1L = 2 * (wcL * wcL - 1) / aL;
    final a2L = (1 - sqrt(2) * wcL + wcL * wcL) / aL;

    final List<double> lp = List<double>.filled(signal.length, 0.0);
    double x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0;
    for (int i = 0; i < signal.length; i++) {
      final x = signal[i];
      final y = b0L * x + b1L * x1 + b2L * x2 - a1L * y1 - a2L * y2;
      lp[i] = y;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
    }

    // 2nd-order high-pass with cutoff=low
    final wcH = tan(pi * low / nyq);
    final aH = 1 + sqrt(2) * wcH + wcH * wcH;
    final b0H = 1 / aH;
    final b1H = -2 * b0H;
    final b2H = b0H;
    final a1H = 2 * (wcH * wcH - 1) / aH;
    final a2H = (1 - sqrt(2) * wcH + wcH * wcH) / aH;

    final List<double> bp = List<double>.filled(lp.length, 0.0);
    x1 = 0.0;
    x2 = 0.0;
    y1 = 0.0;
    y2 = 0.0;
    for (int i = 0; i < lp.length; i++) {
      final x = lp[i];
      final y = b0H * x + b1H * x1 + b2H * x2 - a1H * y1 - a2H * y2;
      bp[i] = y;
      x2 = x1;
      x1 = x;
      y2 = y1;
      y1 = y;
    }
    return bp;
  }

  double _max(List<double> values) => values.reduce(max);

  double _min(List<double> values) => values.reduce(min);
}
