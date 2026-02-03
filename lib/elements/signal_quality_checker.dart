import 'package:fl_chart/fl_chart.dart';
import 'dart:math';
import 'dart:collection'; // Pro Queue
import 'package:tepovka/ppg_algo.dart'; // Import PPGAlgorithm for RgbMeans

/// Enhanced class for PPG signal quality assessment using moving STD on green channel,
/// mean intensity for lighting/finger detection, and RGB ratios for contact validation.
/// Uses queue for sliding average STD (window=5) to adapt to short-term changes without
/// full history. Thresholds are dynamic based on moving STD and RGB means.
/// Logic: First, check finger presence via green mean and RGB ratios (e.g., G/R ~0.8-1.2 for skin).
/// Then, lighting (too dark/bright). Finally, variability: 'Dobrá' if low STD (stable, no motion),
/// else 'Špatná'. New: 'Špatný kontakt' if RGB ratios indicate poor tissue contact.
/// Aligned with 2025 rPPG standards: SNR-inspired checks, adaptive thresholds for robustness.
class SignalQualityChecker {
  final Queue<double> _stdQueue =
      Queue<double>(); // Queue for sliding STD average
  final Queue<String> _qualityQueue =
      Queue<String>(); // Queue for stabilized quality labels
  static const int _windowSize =
      5; // Window for moving average (last 5 computations)
  static const int _qualityWindow = 5; // Window for majority-vote stabilization
  static const int _sampleWindow =
      50; // Use last 50 points for fast STD computation
  static const double _initialThreshold = 5.0; // Initial stability threshold
  static const double _adaptFactor =
      0.9; // Adaptation factor: threshold = _adaptFactor * moving_STD
  static const double _tooDarkThreshold =
      80; // Too dark signal (effective intensity)
  // OPRACENA: Zvýšen threshold pro no finger (>200 místo 150) – saturace ~220 je teď OK pro prst s flashem.
  static const double _noFingerThreshold =
      230.0; // No finger (high green >200 bez variability)
  static const double _minSkinRatioGR =
      0.4; // Min G/R ratio for skin (low = poor absorption)
  static const double _maxSkinRatioGR =
      2.2; // Max G/R ratio for skin (high = overexposed)
  // NOVÁ: Threshold pro low variability + high intensity (stabilní prázdný signál).
  static const double _lowVariabilityThreshold =
      2.0; // Low STD <2 (uvolněno pro lepší detekci)

  /// Computes signal quality from FlSpot data (green-based plot) and optional RGB means.
  /// Uses STD for motion robustness. First validates finger/lighting via green mean and G/R ratio.
  /// If OK, assesses variability: 'Dobrá' for low STD, else 'Špatná'.
  /// Optimized: Computes on last 50 points; integrates RGB for contact quality.
  String calculateQuality(List<FlSpot> data, {RgbMeans? rgbMeans}) {
    if (data.isEmpty) return 'Špatná';

    // Use last _sampleWindow points for fast computation
    final int effectiveLength =
        data.length < _sampleWindow ? data.length : _sampleWindow;
    final List<double> yValues = data
        .sublist(data.length - effectiveLength)
        .map((spot) => spot.y)
        .toList();

    // Fast mean/variance with for loops
    double sum = 0.0;
    for (final double y in yValues) {
      sum += y;
    }
    final double meanY = sum / yValues.length;
    final double meanGreenIntensity =
        -meanY; // Invert for actual green (plot is -intensity)

    // Use provided RGB or fallback to green mean only
    final double currentGreen = rgbMeans?.green ?? meanGreenIntensity;
    final double currentRed =
        rgbMeans?.red ?? meanGreenIntensity * 1.0; // Fallback assume equal
    final bool useRedAsPrimary = currentGreen < 1.0 && currentRed > 20.0;
    final double effectiveIntensity =
        max(currentGreen, currentRed); // tolerate red-channel fallback
    final double grRatio = currentRed > 0 ? currentGreen / currentRed : 1.0;

    // OPRACENA: Obrácená logika pro no finger: Low green (<50) = tmavý/prázdno, OR (high green >200 A low STD <2) = stabilní prázdný frame bez pulzu.
    // Pokud high green A high STD (>5) = saturace s pulzem → dobrý signál.
    final bool lowIntensity =
        effectiveIntensity < _tooDarkThreshold; // NOVÁ: Použito pro no finger.
    final bool highIntensity = effectiveIntensity > _noFingerThreshold;
    final bool neutralRatio =
        grRatio >= 0.9 && grRatio <= 1.1; // Bílé světlo bez absorpce.

    // Compute STD for motion/variability
    double sumSquaredDiff = 0.0;
    for (final double y in yValues) {
      final double diff = y - meanY;
      sumSquaredDiff += diff * diff;
    }
    final double variance = sumSquaredDiff / yValues.length;
    final double currentStd = sqrt(variance);
    final bool lowVariability = currentStd < _lowVariabilityThreshold;
    final bool highVariability =
        currentStd > 5.0; // NOVÁ: Pro detekci pulzu v saturaci.

    // OPRACENA: 'Žádný prst' jen pokud low intensity NEBO (high intensity A low variability A neutral ratio).
    if (lowIntensity || (highIntensity && lowVariability && neutralRatio)) {
      return _stabilizeQuality('Žádný prst');
    }

    // NOVÁ: Pokud high intensity A high variability = dobrý pulz v saturaci → přeskoč a jdi na variability check.
    if (highIntensity && highVariability) {
      // Přejdi přímo k variability check – dobrý signál.
    }

    // Detect too dark: Low green (poor lighting/contact) – teď integrováno výše.
    // Detect poor contact: G/R ratio out of skin range (e.g., not absorbing blood properly)
    if (!useRedAsPrimary &&
        currentGreen > 5.0 &&
        currentRed > 5.0 &&
        (grRatio < _minSkinRatioGR || grRatio > _maxSkinRatioGR)) {
      return _stabilizeQuality('Špatný kontakt');
    }

    // Add to sliding queue
    _stdQueue.add(currentStd);
    if (_stdQueue.length > _windowSize) {
      _stdQueue.removeFirst();
    }

    // Moving average STD
    final movingAverageStd = _stdQueue.isEmpty
        ? _initialThreshold
        : _stdQueue.reduce((a, b) => a + b) / _stdQueue.length;

    // Dynamic threshold (adapt to recent variability)
    final dynamicThreshold =
        max(_initialThreshold * 0.5, _adaptFactor * movingAverageStd);

    // Simple SNR proxy: If mean > 3x STD (signal dominates noise), boost to 'Dobrá'
    final bool highSnr = meanGreenIntensity > 3 * currentStd;

    return _stabilizeQuality(
        (currentStd < dynamicThreshold || highSnr) ? 'Dobrá' : 'Špatná');
  }

  String _stabilizeQuality(String quality) {
    _qualityQueue.add(quality);
    if (_qualityQueue.length > _qualityWindow) {
      _qualityQueue.removeFirst();
    }

    if (_qualityQueue.length < _qualityWindow) {
      return quality; // Not enough samples yet
    }

    final counts = <String, int>{};
    for (final value in _qualityQueue) {
      counts[value] = (counts[value] ?? 0) + 1;
    }

    String best = quality;
    int bestCount = -1;
    counts.forEach((key, value) {
      if (value > bestCount) {
        best = key;
        bestCount = value;
      }
    });

    return best;
  }

  /// Resets queue (e.g., new measurement).
  void reset() {
    _stdQueue.clear();
    _qualityQueue.clear();
  }
}
