import 'dart:math';

/// DSP primitivy sdílené napříč PPG pipeline.
/// Bezstavové statické metody – bezpečné z izolátů.
class DspUtils {
  DspUtils._();

  // ─── Statistiky ────────────────────────────────────────────────────

  static double mean(List<double> x) {
    if (x.isEmpty) return 0.0;
    double s = 0.0;
    for (final v in x) s += v;
    return s / x.length;
  }

  static double std(List<double> x) {
    if (x.length < 2) return 0.0;
    final m = mean(x);
    double sq = 0.0;
    for (final v in x) {
      final d = v - m;
      sq += d * d;
    }
    return sqrt(sq / x.length);
  }

  static double median(List<double> x) {
    if (x.isEmpty) return 0.0;
    final s = List<double>.from(x)..sort();
    final n = s.length;
    if (n.isOdd) return s[n ~/ 2];
    return (s[n ~/ 2 - 1] + s[n ~/ 2]) / 2.0;
  }

  /// Median Absolute Deviation. Vynásobeno 1.4826 odhaduje σ pro normální data,
  /// ale je robustní vůči outlierům (na rozdíl od klasické std).
  static double mad(List<double> x) {
    if (x.isEmpty) return 0.0;
    final med = median(x);
    final dev = x.map((v) => (v - med).abs()).toList();
    return median(dev) * 1.4826;
  }

  /// Z-score normalizace pomocí median + MAD (robustní).
  static List<double> robustZ(List<double> x) {
    if (x.isEmpty) return x;
    final med = median(x);
    final m = mad(x);
    if (m < 1e-9) return List<double>.filled(x.length, 0.0);
    return x.map((v) => (v - med) / m).toList();
  }

  // ─── Okna ──────────────────────────────────────────────────────────

  static List<double> hammingWindow(int n) {
    if (n < 2) return List<double>.filled(n, 1.0);
    return List<double>.generate(
        n, (i) => 0.54 - 0.46 * cos(2 * pi * i / (n - 1)));
  }

  static List<double> hanningWindow(int n) {
    if (n < 2) return List<double>.filled(n, 1.0);
    return List<double>.generate(
        n, (i) => 0.5 - 0.5 * cos(2 * pi * i / (n - 1)));
  }

  // ─── Parabolická interpolace ────────────────────────────────────────

  /// Vrátí (refinedIndex, refinedValue) ze tří vzorků y0, y1, y2 v okolí
  /// lokálního maxima v indexu `centerIndex` (s y1 = signal[centerIndex]).
  /// Sub-sample přesnost pro polohu peaku – klíčové pro HRV při fs=30Hz.
  static ({double index, double value}) parabolicVertex(
      double y0, double y1, double y2, int centerIndex) {
    final denom = y0 - 2 * y1 + y2;
    if (denom.abs() < 1e-12) {
      return (index: centerIndex.toDouble(), value: y1);
    }
    final p = 0.5 * (y0 - y2) / denom;
    final refinedValue = y1 - 0.25 * (y0 - y2) * p;
    return (index: centerIndex + p, value: refinedValue);
  }

  // ─── Filtry ────────────────────────────────────────────────────────

  /// Biquad koeficienty pro 2nd-order Butterworth low-pass / high-pass
  /// pomocí bilineární transformace.
  static BiquadCoeffs butterLowpass(double cutoffHz, double fs) {
    final wc = tan(pi * cutoffHz / fs);
    final a = 1 + sqrt(2) * wc + wc * wc;
    return BiquadCoeffs(
      b0: wc * wc / a,
      b1: 2 * wc * wc / a,
      b2: wc * wc / a,
      a1: 2 * (wc * wc - 1) / a,
      a2: (1 - sqrt(2) * wc + wc * wc) / a,
    );
  }

  static BiquadCoeffs butterHighpass(double cutoffHz, double fs) {
    final wc = tan(pi * cutoffHz / fs);
    final a = 1 + sqrt(2) * wc + wc * wc;
    return BiquadCoeffs(
      b0: 1 / a,
      b1: -2 / a,
      b2: 1 / a,
      a1: 2 * (wc * wc - 1) / a,
      a2: (1 - sqrt(2) * wc + wc * wc) / a,
    );
  }

  /// Aplikace biquadu na celý signál (causal, forward only).
  static List<double> applyBiquad(List<double> x, BiquadCoeffs c) {
    if (x.length < 3) return List<double>.from(x);
    final y = List<double>.filled(x.length, 0.0);
    double x1 = 0, x2 = 0, y1 = 0, y2 = 0;
    for (int i = 0; i < x.length; i++) {
      final xn = x[i];
      final yn = c.b0 * xn + c.b1 * x1 + c.b2 * x2 - c.a1 * y1 - c.a2 * y2;
      y[i] = yn;
      x2 = x1;
      x1 = xn;
      y2 = y1;
      y1 = yn;
    }
    return y;
  }

  /// Zero-phase forward-backward filtering (Octave / SciPy filtfilt analog).
  /// Eliminuje fázové zpoždění – kritické pro retrospektivní HRV, kde
  /// pozice peaků nesmí být posunutá. Reflexe signálu na okrajích
  /// minimalizuje transient.
  static List<double> filtfilt(List<double> x, BiquadCoeffs c) {
    if (x.length < 6) return List<double>.from(x);

    final padLen = min(x.length - 1, 30);
    final padded = <double>[
      for (int i = padLen; i > 0; i--) 2 * x.first - x[i],
      ...x,
      for (int i = 1; i <= padLen; i++) 2 * x.last - x[x.length - 1 - i],
    ];

    final fwd = applyBiquad(padded, c);
    final rev = applyBiquad(fwd.reversed.toList(), c);
    final backToOrig = rev.reversed.toList();
    return backToOrig.sublist(padLen, padLen + x.length);
  }

  /// Bandpass = aplikace high-pass následovaná low-pass.
  /// `zeroPhase: true` pro retrospektivu, `false` pro real-time.
  static List<double> bandpass(
    List<double> x,
    double lowHz,
    double highHz,
    double fs, {
    bool zeroPhase = false,
  }) {
    final hp = butterHighpass(lowHz, fs);
    final lp = butterLowpass(highHz, fs);
    if (zeroPhase) {
      return filtfilt(filtfilt(x, hp), lp);
    }
    return applyBiquad(applyBiquad(x, hp), lp);
  }

  // ─── Median filter ────────────────────────────────────────────────

  static List<double> medianFilter(List<double> x, int windowSize) {
    if (x.length < windowSize || windowSize < 3) return List<double>.from(x);
    final half = windowSize ~/ 2;
    final result = List<double>.filled(x.length, 0.0);
    for (int i = 0; i < x.length; i++) {
      final start = max(0, i - half);
      final end = min(x.length, i + half + 1);
      final win = x.sublist(start, end)..sort();
      result[i] = win[win.length ~/ 2];
    }
    return result;
  }

  // ─── Detrend ──────────────────────────────────────────────────────

  /// Lineární detrend (odečte fitnutou přímku – odstraní pomalý drift).
  static List<double> detrendLinear(List<double> x) {
    final n = x.length;
    if (n < 2) return List<double>.from(x);
    double sumX = 0, sumY = 0, sumXY = 0, sumXX = 0;
    for (int i = 0; i < n; i++) {
      sumX += i;
      sumY += x[i];
      sumXY += i * x[i];
      sumXX += i * i;
    }
    final denom = n * sumXX - sumX * sumX;
    if (denom.abs() < 1e-12) return List<double>.from(x);
    final slope = (n * sumXY - sumX * sumY) / denom;
    final intercept = (sumY - slope * sumX) / n;
    return List<double>.generate(n, (i) => x[i] - (slope * i + intercept));
  }

  // ─── Pomocné ──────────────────────────────────────────────────────

  /// Lineární interpolace yp v bodech xp z (x, y).
  /// xp i x musí být seřazené vzestupně.
  static List<double> interpLinear(
      List<double> x, List<double> y, List<double> xp) {
    final out = List<double>.filled(xp.length, 0.0);
    int j = 0;
    for (int i = 0; i < xp.length; i++) {
      final t = xp[i];
      if (t <= x.first) {
        out[i] = y.first;
        continue;
      }
      if (t >= x.last) {
        out[i] = y.last;
        continue;
      }
      while (j < x.length - 1 && x[j + 1] < t) {
        j++;
      }
      final span = x[j + 1] - x[j];
      if (span.abs() < 1e-12) {
        out[i] = y[j];
      } else {
        final frac = (t - x[j]) / span;
        out[i] = y[j] + frac * (y[j + 1] - y[j]);
      }
    }
    return out;
  }
}

class BiquadCoeffs {
  final double b0, b1, b2, a1, a2;
  const BiquadCoeffs({
    required this.b0,
    required this.b1,
    required this.b2,
    required this.a1,
    required this.a2,
  });
}
