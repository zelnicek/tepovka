import 'dart:math';

class PeakDetector {
  static List<int> findPeaks(
    List<double> signal, {
    double sampleRate = 30.0,
    int maxHeartRate = 200,
    double thresholdMultiplier = 0.1,
    double prominenceMultiplier = 0.15,
    double fallbackThresholdMultiplier = 0.15,
    double localWindowSeconds = 1.0,
  }) {
    final List<int> peaks = [];
    if (signal.length < 3) return peaks;

    final globalMean = signal.reduce((a, b) => a + b) / signal.length;
    final globalSumSq = signal
        .map((v) => (v - globalMean) * (v - globalMean))
        .reduce((a, b) => a + b);
    final globalStd = sqrt(globalSumSq / signal.length);

    final int minDistance =
        (sampleRate * 60 / maxHeartRate).round().clamp(3, signal.length);
    final int localWindow =
        (sampleRate * localWindowSeconds).round().clamp(5, 120);

    int lastIndex = -minDistance;
    for (int i = 1; i < signal.length - 1; i++) {
      final isPeak = signal[i - 1] < signal[i] && signal[i] > signal[i + 1];
      if (!isPeak) continue;

      final start = (i - localWindow).clamp(0, signal.length - 1);
      final end = (i + localWindow).clamp(0, signal.length - 1);
      double localSum = 0.0;
      double localSumSq = 0.0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        localSum += signal[j];
        localSumSq += signal[j] * signal[j];
        count++;
      }

      final localMean = localSum / count;
      final localVar = (localSumSq / count) - (localMean * localMean);
      final localStd = sqrt(localVar.abs());

      final threshold = localMean + thresholdMultiplier * localStd;
      final prominence = signal[i] - localMean;
      final aboveThreshold = signal[i] > threshold;
      final strongEnough =
          prominence > (prominenceMultiplier * localStd).clamp(0.001, 999.0);
      final farEnough = (i - lastIndex) >= minDistance;

      if (!aboveThreshold || !strongEnough) continue;

      if (!farEnough) {
        if (peaks.isNotEmpty && signal[i] > signal[peaks.last]) {
          peaks[peaks.length - 1] = i;
          lastIndex = i;
        }
        continue;
      }

      peaks.add(i);
      lastIndex = i;
    }

    if (peaks.isEmpty && globalStd > 0) {
      final fallbackThreshold =
          globalMean + fallbackThresholdMultiplier * globalStd;
      lastIndex = -minDistance;
      for (int i = 1; i < signal.length - 1; i++) {
        final isPeak = signal[i - 1] < signal[i] && signal[i] > signal[i + 1];
        final aboveThreshold = signal[i] > fallbackThreshold;
        final farEnough = (i - lastIndex) >= minDistance;
        if (isPeak && aboveThreshold && farEnough) {
          peaks.add(i);
          lastIndex = i;
        }
      }
    }

    return peaks;
  }
}
