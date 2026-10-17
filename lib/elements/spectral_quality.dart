import 'dart:math';
import 'dart:typed_data';

import 'package:fftea/fftea.dart';
import 'package:tepovka/elements/unified_peak_detector.dart';
import 'package:tepovka/services/measurement_quality.dart';

/// Signal quality of a finished PPG recording, the indicator validated in the
/// 2026 study against the Faros 180 ECG (`quality()` in `tepovka_ppg.py` of
/// Tepovka_mereni_2026). On 57 recordings with an ECG reference, "good" ones
/// were within 5 bpm of the ECG in 92 % of cases with a median error of
/// 0.9 bpm; the error grew steadily below an SNR of 8.
///
/// [assessRecording] adds one check on top: the heart rate from the feet of
/// the pulse wave (the one the app shows) has to agree with the spectral one,
/// see [methodAgreement].
///
/// It is ported line by line from SciPy (Butterworth band-pass, `filtfilt`,
/// linear detrend, Hann window, zero-padded periodogram), because the
/// thresholds are only valid for exactly that computation. Changing a step
/// here invalidates the calibration.
class SpectralQuality {
  const SpectralQuality({
    required this.heartRateBpm,
    required this.snr,
    required this.goodWindowShare,
    required this.level,
    this.footBpm = double.nan,
    this.methodAgreement = double.nan,
  });

  /// Heart rate at the spectral peak.
  final double heartRateBpm;

  /// Heart rate from the feet of the pulse wave; NaN when there is none or
  /// it was not checked.
  final double footBpm;

  /// Share of the 10-second windows where the feet and the spectrum agree,
  /// see [methodAgreement]; NaN when not checked.
  final double methodAgreement;

  /// The two heart-rate methods disagreed, which alone kept the grade from
  /// being good.
  bool get methodsDisagree =>
      footBpm.isFinite && !(methodAgreement >= kMinMethodAgreement);

  /// Spectral peak over the mean power of the heart-rate band, whole record.
  final double snr;

  /// Share of 10-second windows whose own SNR passes [kSnrGate].
  final double goodWindowShare;

  final MeasurementQuality level;

  /// Identifies the method in stored records. Grades stored by the
  /// spectrum alone ('spectral-snr-2026') are not read back, so the history
  /// grades those records again with the agreement check.
  static const String method = 'spectral-snr-feet-2026';

  Map<String, Object> toJson() => {
        'method': method,
        'level': level.name,
        'snr': snr,
        'goodWindowShare': goodWindowShare,
        'heartRateBpm': heartRateBpm,
        if (footBpm.isFinite) 'footBpm': footBpm,
        if (methodAgreement.isFinite) 'methodAgreement': methodAgreement,
      };

  /// Null for anything not written by [toJson].
  static SpectralQuality? fromJson(Object? json) {
    if (json is! Map || json['method'] != method) return null;
    final Object? level = json['level'];
    final Object? snr = json['snr'];
    final Object? share = json['goodWindowShare'];
    final Object? bpm = json['heartRateBpm'];
    final Object? foot = json['footBpm'];
    final Object? agreement = json['methodAgreement'];
    if (level is! String || snr is! num || share is! num) return null;
    final MeasurementQuality? parsed =
        MeasurementQuality.values.where((q) => q.name == level).firstOrNull;
    if (parsed == null) return null;
    return SpectralQuality(
      heartRateBpm: bpm is num ? bpm.toDouble() : double.nan,
      snr: snr.toDouble(),
      goodWindowShare: share.toDouble(),
      level: parsed,
      footBpm: foot is num ? foot.toDouble() : double.nan,
      methodAgreement: agreement is num ? agreement.toDouble() : double.nan,
    );
  }
}

/// SNR a 10-second window needs to count as usable.
const double kSnrGate = 8.0;

/// SNR the whole record needs, with [kGoodWindowShare], to be "good".
const double kSnrGood = 12.0;
const double kGoodWindowShare = 0.8;

/// Physiological band searched for the fundamental, Hz.
const double _hrBandLow = 0.7;
const double _hrBandHigh = 3.2;

/// Largest gap between the heart rate from the feet and from the spectrum
/// at which the two still agree. They fail differently, so when they
/// disagree one of them is wrong.
const double kMaxMethodGapBpm = 5.0;

/// Share of windows that must agree for a "good" grade. A 10-second
/// spectrum is coarse, so a single window may miss on a sound recording;
/// half of them may not. On BUT PPG (tool/butppg; 10-second records, one
/// window each) the check raised the share of "good" records that experts
/// also marked good from 34 to 74 %. On the 2026 study (tool/study2026) it
/// changes no grade: all 55 good recordings are within 2.8 bpm of the ECG.
/// Asking for 80 % would have demoted four of them for nothing.
const double kMinMethodAgreement = 0.5;

/// Grades a stored recording the way the study did: the start-up transient
/// of records from app versions before the August 2026 fix is cut off first
/// (see [warmupSeconds]), then [assessSignalQuality] runs on the rest. On
/// top of that, a recording the feet give no heart rate for is poor, and one
/// where the feet and the spectrum agree in fewer than
/// [kMinMethodAgreement] of its windows is at best medium.
SpectralQuality? assessRecording(List<double> signal, double fs) {
  final int start = (warmupSeconds(signal, fs) * fs).toInt();
  final List<double> settled = signal.sublist(start);
  final SpectralQuality? spectral = assessSignalQuality(settled, fs);
  if (spectral == null) return null;
  final FootBeats beats = FootBeats.of(settled, fs);
  final double agreement =
      beats.bpm == null ? double.nan : methodAgreement(settled, fs, beats.feet);
  final MeasurementQuality level = beats.bpm == null
      ? MeasurementQuality.poor
      : spectral.level == MeasurementQuality.good &&
              !(agreement >= kMinMethodAgreement)
          ? MeasurementQuality.medium
          : spectral.level;
  return SpectralQuality(
    heartRateBpm: spectral.heartRateBpm,
    snr: spectral.snr,
    goodWindowShare: spectral.goodWindowShare,
    level: level,
    footBpm: beats.bpm ?? double.nan,
    methodAgreement: agreement,
  );
}

/// Share of the 10-second windows (stepped as in [assessSignalQuality])
/// where the heart rate from [feet] agrees with the spectral one within
/// [kMaxMethodGapBpm]. Window by window, because over a long recording the
/// heart rate may change, after exercise say, and then a single spectrum
/// and a median interval differ without either being wrong. NaN when no
/// window has enough beats to compare.
double methodAgreement(List<double> signal, double fs, List<PpgPeak> feet) {
  final int window = (10 * fs).toInt();
  final int step = max(1, (5 * fs).toInt());
  int compared = 0;
  int agreed = 0;
  for (int k = 0; k < max(1, signal.length - window + 1); k += step) {
    final int end = min(signal.length, k + window);
    final List<double> times = [
      for (final PpgPeak p in feet)
        if (p.fractionalIndex >= k && p.fractionalIndex < end) p.timeSec
    ];
    // Intervals within 40-200 bpm, as the detector accepts them.
    final List<double> intervals = [
      for (int i = 1; i < times.length; i++)
        if (times[i] - times[i - 1] >= 0.3 && times[i] - times[i - 1] <= 1.5)
          times[i] - times[i - 1]
    ];
    if (intervals.length < FootBeats.minIntervals) continue;
    final double footBpm = 60 / _median(intervals);
    final double spectralBpm =
        spectralHeartRate(signal.sublist(k, end), fs).bpm;
    compared++;
    if ((footBpm - spectralBpm).abs() <= kMaxMethodGapBpm) agreed++;
  }
  return compared == 0 ? double.nan : agreed / compared;
}

/// `warmup_seconds()`: length of the start-up transient, in whole seconds.
///
/// Until the app was fixed in August 2026 the light came on, exposure locked
/// and filters reset at the moment recording started, so the first seconds
/// swing far wider than the rest. This finds the first one-second block whose
/// spread falls below twice the settled level (the median of the blocks after
/// the first six seconds). Zero when there is no transient.
double warmupSeconds(List<double> y, double fs, {double factor = 2.0}) {
  const int maxWarmup = 6;
  final int n = _roundHalfEven(fs);
  if (n < 2 || y.length < 6 * n) return 0.0;
  final List<double> blocks = [
    for (int k = 0; k + n <= y.length; k += n) _std(y.sublist(k, k + n)),
  ];
  final double settled =
      _median(blocks.length > maxWarmup ? blocks.sublist(maxWarmup) : blocks);
  if (settled <= 0) return 0.0;
  final int limit = min(maxWarmup, blocks.length);
  for (int k = 0; k < limit; k++) {
    if (blocks[k] < factor * settled) return k.toDouble();
  }
  return limit.toDouble();
}

/// Python's round(): halves go to the even neighbour.
int _roundHalfEven(double v) {
  final double f = v.floorToDouble();
  final double diff = v - f;
  if (diff > 0.5) return f.toInt() + 1;
  if (diff < 0.5) return f.toInt();
  return f.toInt().isEven ? f.toInt() : f.toInt() + 1;
}

/// Population standard deviation, as numpy's default.
double _std(List<double> x) {
  final double mean = x.reduce((a, b) => a + b) / x.length;
  double sum = 0.0;
  for (final double v in x) {
    sum += (v - mean) * (v - mean);
  }
  return sqrt(sum / x.length);
}

double _median(List<double> x) {
  final List<double> s = List<double>.from(x)..sort();
  final int m = s.length ~/ 2;
  return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
}

/// Grades a recording. [signal] is the stored pulse wave (pulses up), [fs]
/// its real sample rate. Null when the signal is too short to judge.
SpectralQuality? assessSignalQuality(List<double> signal, double fs) {
  if (signal.length < 32 || !(fs > 0)) return null;
  final ({double bpm, double snr}) whole = spectralHeartRate(signal, fs);
  final int window = (10 * fs).toInt();
  final int step = max(1, (5 * fs).toInt());
  int good = 0;
  int total = 0;
  for (int k = 0; k < max(1, signal.length - window + 1); k += step) {
    final List<double> part = signal.sublist(k, min(signal.length, k + window));
    total++;
    if (spectralHeartRate(part, fs).snr >= kSnrGate) good++;
  }
  final double share = total > 0 ? good / total : 0.0;
  final MeasurementQuality level =
      whole.snr >= kSnrGood && share >= kGoodWindowShare
          ? MeasurementQuality.good
          : whole.snr >= kSnrGate
              ? MeasurementQuality.medium
              : MeasurementQuality.poor;
  return SpectralQuality(
    heartRateBpm: whole.bpm,
    snr: whole.snr,
    goodWindowShare: share,
    level: level,
  );
}

/// `spectral_hr()`: heart rate from the spectrum, and how far its peak
/// stands above the rest of the band.
({double bpm, double snr}) spectralHeartRate(List<double> signal, double fs) {
  if (signal.length < 32) return (bpm: double.nan, snr: 0.0);
  final double nyq = fs / 2;
  final _Filter filter = _butterBandpass2(0.5 / nyq, min(5.0 / nyq, 0.99));
  final List<double>? filtered = _filtfilt(filter, signal);
  if (filtered == null) return (bpm: double.nan, snr: 0.0);
  final List<double> detrended = _detrendLinear(filtered);
  final int n = detrended.length;
  int nFft = 1;
  while (nFft < n * 32) {
    nFft <<= 1;
  }
  final Float64List input = Float64List(nFft);
  for (int i = 0; i < n; i++) {
    final double hann = n < 2 ? 1.0 : 0.5 - 0.5 * cos(2 * pi * i / (n - 1));
    input[i] = detrended[i] * hann;
  }
  final Float64x2List spectrum = FFT(nFft).realFft(input);
  final int bins = nFft ~/ 2 + 1;
  final Float64List power = Float64List(bins);
  for (int i = 0; i < bins; i++) {
    final Float64x2 c = spectrum[i];
    power[i] = c.x * c.x + c.y * c.y;
  }
  final double step = fs / nFft;
  int first = -1;
  int last = -1;
  for (int i = 0; i < bins; i++) {
    final double f = i * step;
    if (f >= _hrBandLow && f <= _hrBandHigh) {
      if (first < 0) first = i;
      last = i;
    }
  }
  if (first < 0) return (bpm: double.nan, snr: 0.0);
  int k = first;
  double sum = 0.0;
  for (int i = first; i <= last; i++) {
    sum += power[i];
    if (power[i] > power[k]) k = i;
  }
  double shift = 0.0;
  if (k > 0 && k < bins - 1) {
    final double a = log(power[k - 1] + 1e-30);
    final double b = log(power[k] + 1e-30);
    final double c = log(power[k + 1] + 1e-30);
    final double denom = a - 2 * b + c;
    if (denom.abs() > 1e-30) {
      shift = (0.5 * (a - c) / denom).clamp(-0.5, 0.5);
    }
  }
  final double mean = sum / (last - first + 1);
  return (
    bpm: (k + shift) * step * 60,
    snr: mean > 0 ? power[k] / mean : 0.0,
  );
}

/// Least-squares line removed, as `scipy.signal.detrend`.
List<double> _detrendLinear(List<double> x) {
  final int n = x.length;
  if (n < 2) return List<double>.from(x);
  double sx = 0, sy = 0, sxy = 0, sxx = 0;
  for (int i = 0; i < n; i++) {
    sx += i;
    sy += x[i];
    sxy += i * x[i];
    sxx += i * i.toDouble();
  }
  final double denom = n * sxx - sx * sx;
  if (denom.abs() < 1e-12) return List<double>.from(x);
  final double slope = (n * sxy - sx * sy) / denom;
  final double intercept = (sy - slope * sx) / n;
  return [for (int i = 0; i < n; i++) x[i] - (slope * i + intercept)];
}

// ─── SciPy filter design and zero-phase filtering ─────────────────────────

class _Filter {
  const _Filter(this.b, this.a);
  final List<double> b;
  final List<double> a;
}

class _C {
  const _C(this.re, [this.im = 0.0]);
  final double re;
  final double im;
  _C operator +(_C o) => _C(re + o.re, im + o.im);
  _C operator -(_C o) => _C(re - o.re, im - o.im);
  _C operator *(_C o) => _C(re * o.re - im * o.im, re * o.im + im * o.re);
  _C operator /(_C o) {
    final double d = o.re * o.re + o.im * o.im;
    return _C((re * o.re + im * o.im) / d, (im * o.re - re * o.im) / d);
  }

  _C scale(double s) => _C(re * s, im * s);

  /// Principal square root, as numpy's.
  _C principalSqrt() {
    final double r = sqrt(re * re + im * im);
    final double sr = sqrt(max(0.0, (r + re) / 2));
    final double si = sqrt(max(0.0, (r - re) / 2));
    return _C(sr, im < 0 ? -si : si);
  }
}

/// `scipy.signal.butter(2, [w1, w2], btype='band')`, with w1 and w2 as
/// fractions of Nyquist: analogue prototype, band-pass transform and
/// bilinear transform, in that order.
_Filter _butterBandpass2(double w1, double w2) {
  const int order = 2;
  const double fsDesign = 2.0;
  final double warped1 = 2 * fsDesign * tan(pi * w1 / fsDesign);
  final double warped2 = 2 * fsDesign * tan(pi * w2 / fsDesign);
  final double bw = warped2 - warped1;
  final double wo = sqrt(warped1 * warped2);

  // buttap: poles -exp(1j*pi*m/(2N)) for m = -N+1, -N+3, ..., N-1.
  final List<_C> prototype = [
    for (int m = -order + 1; m < order; m += 2)
      _C(-cos(pi * m / (2 * order)), -sin(pi * m / (2 * order))),
  ];

  // lp2bp_zpk: no zeros in the prototype, so N zeros at the origin.
  final _C wo2 = _C(wo * wo);
  final List<_C> lp = [for (final p in prototype) p.scale(bw / 2)];
  final List<_C> poles = [
    for (final p in lp) p + (p * p - wo2).principalSqrt(),
    for (final p in lp) p - (p * p - wo2).principalSqrt(),
  ];
  final List<_C> zeros = [for (int i = 0; i < order; i++) const _C(0)];
  double gain = pow(bw, order).toDouble();

  // bilinear_zpk with fs = 2.
  const double fs2 = 2 * fsDesign;
  const _C four = _C(fs2);
  final List<_C> zz = [
    for (final z in zeros) (four + z) / (four - z),
    for (int i = 0; i < poles.length - zeros.length; i++) const _C(-1),
  ];
  final List<_C> pz = [for (final p in poles) (four + p) / (four - p)];
  _C num = const _C(1);
  for (final z in zeros) {
    num = num * (four - z);
  }
  _C den = const _C(1);
  for (final p in poles) {
    den = den * (four - p);
  }
  gain *= (num / den).re;

  final List<double> b = [for (final c in _poly(zz)) c.re * gain];
  final List<double> a = [for (final c in _poly(pz)) c.re];
  return _Filter(b, a);
}

/// Coefficients of the monic polynomial with the given roots, highest power
/// first, as `numpy.poly`.
List<_C> _poly(List<_C> roots) {
  List<_C> c = [const _C(1)];
  for (final r in roots) {
    final List<_C> next = List<_C>.filled(c.length + 1, const _C(0));
    for (int i = 0; i < c.length; i++) {
      next[i] = next[i] + c[i];
      next[i + 1] = next[i + 1] - c[i] * r;
    }
    c = next;
  }
  return c;
}

/// `scipy.signal.lfilter_zi`: the state that makes a step input settle
/// immediately.
List<double> _lfilterZi(_Filter f) {
  final List<double> a = [for (final v in f.a) v / f.a[0]];
  final List<double> b = [for (final v in f.b) v / f.a[0]];
  final int n = a.length - 1;
  // I - companion(a).T, where companion's first row is -a[1:].
  final List<List<double>> m = List.generate(n, (i) => List.filled(n, 0.0));
  for (int i = 0; i < n; i++) {
    for (int j = 0; j < n; j++) {
      double companionT = 0.0; // companion(a)[j][i]
      if (j == 0) {
        companionT = -a[i + 1];
      } else if (i == j - 1) {
        companionT = 1.0;
      }
      m[i][j] = (i == j ? 1.0 : 0.0) - companionT;
    }
  }
  final List<double> rhs = [for (int i = 1; i <= n; i++) b[i] - a[i] * b[0]];
  return _solve(m, rhs);
}

/// Gaussian elimination with partial pivoting.
List<double> _solve(List<List<double>> m, List<double> rhs) {
  final int n = rhs.length;
  final List<List<double>> a = [
    for (int i = 0; i < n; i++) [...m[i], rhs[i]],
  ];
  for (int col = 0; col < n; col++) {
    int pivot = col;
    for (int r = col + 1; r < n; r++) {
      if (a[r][col].abs() > a[pivot][col].abs()) pivot = r;
    }
    final List<double> tmp = a[col];
    a[col] = a[pivot];
    a[pivot] = tmp;
    for (int r = col + 1; r < n; r++) {
      final double factor = a[r][col] / a[col][col];
      for (int c = col; c <= n; c++) {
        a[r][c] -= factor * a[col][c];
      }
    }
  }
  final List<double> x = List.filled(n, 0.0);
  for (int r = n - 1; r >= 0; r--) {
    double s = a[r][n];
    for (int c = r + 1; c < n; c++) {
      s -= a[r][c] * x[c];
    }
    x[r] = s / a[r][r];
  }
  return x;
}

/// `scipy.signal.lfilter` with an initial state, direct form II transposed.
List<double> _lfilter(_Filter f, List<double> x, List<double> zi) {
  final List<double> a = [for (final v in f.a) v / f.a[0]];
  final List<double> b = [for (final v in f.b) v / f.a[0]];
  final int order = a.length - 1;
  final List<double> z = List<double>.from(zi);
  final List<double> y = List<double>.filled(x.length, 0.0);
  for (int n = 0; n < x.length; n++) {
    final double xn = x[n];
    final double yn = b[0] * xn + z[0];
    for (int i = 1; i < order; i++) {
      z[i - 1] = b[i] * xn + z[i] - a[i] * yn;
    }
    z[order - 1] = b[order] * xn - a[order] * yn;
    y[n] = yn;
  }
  return y;
}

/// `scipy.signal.filtfilt` with its defaults: odd extension of
/// 3 * max(len(a), len(b)) samples and `lfilter_zi` initial states. Null
/// when the signal is too short to pad, where SciPy raises.
List<double>? _filtfilt(_Filter f, List<double> x) {
  final int padLen = 3 * max(f.a.length, f.b.length);
  if (x.length <= padLen) return null;
  final int n = x.length;
  final List<double> ext = [
    for (int i = padLen; i >= 1; i--) 2 * x[0] - x[i],
    ...x,
    for (int i = 1; i <= padLen; i++) 2 * x[n - 1] - x[n - 1 - i],
  ];
  final List<double> zi = _lfilterZi(f);
  final List<double> forward =
      _lfilter(f, ext, [for (final v in zi) v * ext.first]);
  final List<double> reversed = forward.reversed.toList();
  final List<double> backward =
      _lfilter(f, reversed, [for (final v in zi) v * reversed.first]);
  final List<double> out = backward.reversed.toList();
  return out.sublist(padLen, padLen + n);
}
