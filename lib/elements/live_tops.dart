import 'package:tepovka/elements/unified_peak_detector.dart';

/// Tops of the pulses for the dots on the live chart, found in the live
/// window by the detector the result screen marks them with. Each top has a
/// foot the live heart rate is timed by, so the dots and the number agree;
/// they used to come from an older peak detector that on BUT PPG missed a
/// third of the beats (tool/butppg).
///
/// [values] are the latest samples of the filtered wave and [times] their
/// chart times. Returns the tops not yet placed, as (time, value): only
/// those the wave has already come down from (older than [settleSeconds]
/// before [now]), so a dot never moves once shown, and only those after
/// [lastPlaced], so a top found again a little shifted is not doubled.
List<(double, double)> newLiveTops(
  List<double> values,
  List<double> times,
  double fs, {
  required double now,
  required double? lastPlaced,
  double settleSeconds = 0.3,
}) {
  if (values.length < (2 * fs).round() || times.length != values.length) {
    return const [];
  }
  final List<(double, double)> out = [];
  double? last = lastPlaced;
  for (final PpgPeak top
      in UnifiedPpgPeakDetector(fs: fs).detect(values, zeroPhase: true)) {
    final int i = top.fractionalIndex.round().clamp(0, values.length - 1);
    final double t = times[i];
    if (t > now - settleSeconds) break;
    // No two tops closer than the 200 bpm the detector allows.
    if (last != null && t < last + 0.3) continue;
    out.add((t, values[i]));
    last = t;
  }
  return out;
}
