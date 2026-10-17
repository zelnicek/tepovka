import 'dart:math';

/// The recovery test: a short bout of exercise, then two minutes measured
/// straight away. How fast the heart rate falls back says something about
/// fitness, best followed as a trend in one's own tests.
const int kRecoveryTestSeconds = 120;

/// Stored as the record's 'protocol', so the history can find the tests.
const String kRecoveryProtocol = 'recovery';

/// Heart rate over time after exercise, from the beats of the recording.
///
/// It used to come from the live estimate the measure screen kept, a
/// smoothed spectral value that lags behind a falling heart rate. Here it is
/// read from the feet of the pulse wave, the beats the result screen times
/// the heart rate by. Values are 0 where the recording is too short or has
/// too few beats.
class HeartRateRecovery {
  const HeartRateRecovery._({
    required this.hr0,
    required this.hr60,
    required this.hr120,
    required this.slope60,
    required this.tauSec,
    required this.curve,
  });

  /// [beatTimes] are seconds from the start of the recording, [durationS]
  /// its length.
  factory HeartRateRecovery.fromBeats(
      List<double> beatTimes, double durationS) {
    double between(double a, double b) => heartRateBetween(beatTimes, a, b);
    final List<(double, double)> curve = [
      for (double t = 0; t + _binSeconds <= durationS + 0.5; t += _binSeconds)
        if (between(t, t + _binSeconds) > 0)
          (t + _binSeconds / 2, between(t, t + _binSeconds)),
    ];
    final double hr0 = between(0, 10);
    final double hr60 = durationS >= 60 ? between(50, 60) : 0;
    final double hr120 = durationS >= 120 ? between(110, 120) : 0;

    double slope60 = 0;
    final List<(double, double)> first = [
      for (final p in curve)
        if (p.$1 <= 60) p
    ];
    if (durationS >= 60 && first.length >= 3) {
      slope60 =
          _slope([for (final p in first) p.$1], [for (final p in first) p.$2]) *
              60;
    }

    // Time constant of an exponential fall towards the rate of the last
    // 20 s: the slope of ln(HR - HR_end) against time.
    double tau = 0;
    final double end =
        durationS >= 120 ? between(durationS - 20, durationS) : 0;
    if (end > 0 && hr0 > end) {
      final List<double> xs = [];
      final List<double> ys = [];
      for (final (double t, double bpm) in curve) {
        if (t <= 120 && bpm - end > 1e-3) {
          xs.add(t);
          ys.add(log(bpm - end));
        }
      }
      if (xs.length >= 3) {
        final double s = _slope(xs, ys);
        if (s < 0) tau = -1 / s;
      }
    }
    return HeartRateRecovery._(
      hr0: hr0,
      hr60: hr60,
      hr120: hr120,
      slope60: slope60,
      tauSec: tau,
      curve: curve,
    );
  }

  static const double _binSeconds = 5;

  /// Heart rate in the first 10 s, and in the last 10 s of the first and
  /// second minute.
  final double hr0;
  final double hr60;
  final double hr120;

  /// How far the heart rate fell in the first and in two minutes; 0 when
  /// unknown or when it did not fall.
  double get hrr60 => hr0 > 0 && hr60 > 0 ? max(0, hr0 - hr60) : 0;
  double get hrr120 => hr0 > 0 && hr120 > 0 ? max(0, hr0 - hr120) : 0;

  /// Trend over the first minute, bpm per minute (negative when falling).
  final double slope60;

  /// Time constant of the fall, seconds.
  final double tauSec;

  /// Heart rate in 5-second steps, (time in the middle of the step, bpm).
  final List<(double, double)> curve;
}

/// Heart rate from the beats whose interval ends within [a, b) seconds:
/// 60 over the mean interval, counting only intervals of 40-200 bpm. Zero
/// with fewer than three. Intervals far from the median (below 0.7 or above
/// 1.4 times it) are left out first: right after exercise the heart is fast
/// and the hand not yet still, and a missed beat doubles an interval. In
/// the 2026 study the plain mean put the first 10 s up to 30 bpm below the
/// ECG; the plain median was robust to that but noisier everywhere else.
double heartRateBetween(List<double> beatTimes, double a, double b) {
  final List<double> intervals = [
    for (int i = 1; i < beatTimes.length; i++)
      if (beatTimes[i] >= a &&
          beatTimes[i] < b &&
          beatTimes[i] - beatTimes[i - 1] >= 0.3 &&
          beatTimes[i] - beatTimes[i - 1] <= 1.5)
        beatTimes[i] - beatTimes[i - 1]
  ];
  if (intervals.length < 3) return 0;
  final List<double> sorted = List<double>.from(intervals)..sort();
  final int m = sorted.length ~/ 2;
  final double median =
      sorted.length.isOdd ? sorted[m] : (sorted[m - 1] + sorted[m]) / 2;
  final List<double> kept = [
    for (final double v in intervals)
      if (v >= 0.7 * median && v <= 1.4 * median) v
  ];
  return 60 / (kept.reduce((x, y) => x + y) / kept.length);
}

double _slope(List<double> x, List<double> y) {
  final int n = x.length;
  final double mx = x.reduce((a, b) => a + b) / n;
  final double my = y.reduce((a, b) => a + b) / n;
  double num = 0, den = 0;
  for (int i = 0; i < n; i++) {
    num += (x[i] - mx) * (y[i] - my);
    den += (x[i] - mx) * (x[i] - mx);
  }
  return den == 0 ? 0 : num / den;
}
