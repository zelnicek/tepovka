import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart'; // FFT library for frequency domain analysis
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';

/// Advanced Photoplethysmography (PPG) algorithm for heart rate estimation
/// with robust motion artifact handling and high-quality signal processing.
///
/// Improvements for 2025+ standards:
/// - Multi-stage motion artifact detection and removal
/// - Adaptive bandpass filtering with dynamic parameters
/// - Z-score normalization for consistency
/// - Median filtering for outlier rejection
/// - Cross-channel validation (green + red)
/// - Green channel focus with LED optimization
/// - Signal quality-based adaptive smoothing
class PPGAlgorithm {
  /// Maximum y-axis value for plotting (normalized).
  double get yAxisMax => _yAxisMax;
  double _yAxisMax = 2.0; // Normalized units

  /// Minimum y-axis value for plotting.
  double get yAxisMin => _yAxisMin;
  double _yAxisMin = -2.0; // Normalized units

  /// Smoothed Y-axis bounds (EMA-smoothed for stability)
  double _smoothedYAxisMax = 2.0;
  double _smoothedYAxisMin = -2.0;
  static const double _yAxisSmoothingAlpha = 0.1; // Slow change (0-1)

  /// Raw intensity values (green channel primary).
  final List<double> _intensityValues = [];

  /// Filtered intensity values with motion artifact removal.
  final List<double> _filteredIntensities = [];

  /// Derivative values for peak detection.
  final List<double> _derivativeValues = [];

  /// Current estimated heart rate in BPM.
  double get currentHeartRate => _currentHeartRate;
  double _currentHeartRate = 0.0;

  /// Current BPM confidence score (0-1, where 1 is highest confidence)
  double get currentBpmConfidence => _currentBpmConfidence;
  double _currentBpmConfidence = 0.0;

  /// Last computed RGB means for quality analysis.
  double? _lastAverageGreen;
  double? _lastAverageRed;
  double? _lastAverageBlue;

  /// Maximum display buffer size for plotting
  static const int _displayBufferSize = 200; // ~6-7 seconds at 30 FPS

  /// Frames processed since last processing.
  int _framesProcessedSinceLastUpdate = 0;

  /// Estimated frame rate in FPS.
  double _frameRate = 0.0;
  double _localFrameRate = 0.0;

  /// PPG signal for plotting (normalized for visualization).
  final List<double> _ppgSignal = [];

  /// Full record buffer for export/summary (not display-window limited).
  final List<double> _fullRecordBuffer = [];

  /// Timestamps for frame intervals.
  final List<int> _timestamps = [];

  /// Accumulated BPM values for summary.
  final List<double> _bpmHistory = [];

  /// EMA-smoothed heart rate for stability
  double _smoothedHeartRate = 0.0;
  static const double _emaAlpha = 0.25; // More smoothing for stability

  /// Motion artifact scores (0-1, where 1 is maximum artifact)
  final List<double> _motionArtifactScores = [];
  double _lastMotionArtifactScore = 0.0;

  /// Display smoothing buffer for extra stability in plot
  final List<double> _displayBuffer = [];
  static const int _displaySmoothWindow =
      7; // Moving average window (7 samples)

  /// List of frame rates for analysis.
  final List<double> _frameRates = [];

  /// Respiratory rate estimates.
  final List<double> _respiratoryRates = [];
  double _currentRespiratoryRate = 0.0;

  /// EMA-smoothed respiratory rate
  double _smoothedRespiratoryRate = 0.0;

  /// HRV (Heart Rate Variability) values - SDNN and RMSSD
  final List<double> _hrvValues = []; // SDNN values
  final List<double> _allIbiIntervals =
      []; // All IBI intervals for HRV calculation
  double _currentSdnn = 0.0; // SDNN (Standard Deviation of NN intervals)
  double _currentRmssd =
      0.0; // RMSSD (Root Mean Square of Successive Differences)
  double _currentPnn50 = 0.0; // pNN50 (% of intervals differing by >50ms)
  double _currentSd1 = 0.0; // SD1 (short-term HRV - Poincaré plot)
  double _currentSd2 = 0.0; // SD2 (long-term HRV - Poincaré plot)
  double calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final double mean = _calculateAverage(values);
    final double sumOfSquaredDifferences = values
        .map((value) => pow(value - mean, 2))
        .reduce((a, b) => a + b)
        .toDouble();

    return sqrt(sumOfSquaredDifferences / values.length);
  }

  /// Processes a camera image with enhanced motion artifact detection.
  /// Extracts RGB means, applies motion detection, updates buffers continuously
  /// with smooth scrolling animation (sliding window).
  void processImage(final CameraImage image) {
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    // Update frame rate estimate
    if (_timestamps.isNotEmpty) {
      final int intervalMs = currentTime - _timestamps.last;
      if (intervalMs > 0) {
        final double currentFps = 1000.0 / intervalMs;
        _frameRate =
            _frameRate == 0.0 ? currentFps : (_frameRate + currentFps) / 2;
      }
    }
    _timestamps.add(currentTime);

    // Extract RGB means from center ROI with optimized cropping
    final RgbMeans rgbMeans = _calculateRgbMeans(image);
    _lastAverageGreen = rgbMeans.green;
    _lastAverageRed = rgbMeans.red;
    _lastAverageBlue = rgbMeans.blue;

    // Select primary signal (prefer green for better perfusion detection)
    double primarySignal = rgbMeans.green;
    if (primarySignal < 10.0) {
      primarySignal = rgbMeans.red; // Fallback to red if green too low
    }

    // Detect motion artifacts before adding to buffer
    final double motionScore = _detectMotionArtifacts(primarySignal, rgbMeans);
    _lastMotionArtifactScore = motionScore;
    if (_motionArtifactScores.length > 50) {
      _motionArtifactScores.removeAt(0);
    }
    _motionArtifactScores.add(motionScore);

    // Add raw signal to buffer
    _intensityValues.add(primarySignal);
    _ppgSignal.add(primarySignal);
    _fullRecordBuffer.add(primarySignal);

    // Process and add filtered signal continuously (smooth scrolling)
    final List<double> currentProcessed = _processRawSignal(primarySignal);
    for (double sample in currentProcessed) {
      _filteredIntensities.add(sample);
    }

    // Keep display buffer at fixed size (smooth scrolling window)
    if (_filteredIntensities.length > _displayBufferSize) {
      final int removeCount = _filteredIntensities.length - _displayBufferSize;
      _filteredIntensities.removeRange(0, removeCount);
    }

    // PERIODIC ANALYSIS: Process every 30 frames for HR calculation
    _framesProcessedSinceLastUpdate++;

    if (_framesProcessedSinceLastUpdate >= 30 &&
        _intensityValues.length >= 120) {
      _framesProcessedSinceLastUpdate = 0;

      // Use last 120 frames for HR calculation
      final List<double> analysisWindow = _intensityValues.length >= 120
          ? _intensityValues.sublist(_intensityValues.length - 120)
          : _intensityValues;

      // Calculate LOCAL frame rate
      _localFrameRate = _calculateLocalFrameRate();
      if (_localFrameRate >= 20.0) {
        _frameRates.add(_localFrameRate);

        // Calculate heart rate
        _currentHeartRate =
            _calculateHeartRate(analysisWindow, _localFrameRate);

        // Calculate respiratory rate
        _currentRespiratoryRate =
            _calculateRespiratoryRate(analysisWindow, _localFrameRate);
        if (_currentRespiratoryRate > 0) {
          _respiratoryRates.add(_currentRespiratoryRate);
        }

        // Update continuous HRV
        _updateContinuousHrv();
      }

      // Maintain sliding window for analysis
      if (_intensityValues.length > 300) {
        final removeCount = _intensityValues.length - 120;
        _intensityValues.removeRange(0, removeCount);
        _timestamps.removeRange(0, min(removeCount, _timestamps.length));
        _ppgSignal.removeRange(0, min(removeCount, _ppgSignal.length));
      }
    }
  }

  /// Process a single raw sample with strong smoothing for stable display
  /// Uses exponential moving average + display buffer smoothing
  List<double> _processRawSignal(double rawSample) {
    if (_intensityValues.isEmpty) {
      _displayBuffer.add(rawSample);
      return [rawSample];
    }

    // Stage 1: Exponential smoothing (stronger alpha for stability)
    final double prevFiltered =
        _filteredIntensities.isNotEmpty ? _filteredIntensities.last : rawSample;

    // Stronger smoothing (alpha=0.4 for more stable display without lag)
    final double smoothedSample = prevFiltered * 0.6 + rawSample * 0.4;

    // Stage 2: Add to display buffer and apply moving average for extra stability
    _displayBuffer.add(smoothedSample);
    if (_displayBuffer.length > _displaySmoothWindow) {
      _displayBuffer.removeAt(0);
    }

    // Calculate moving average of last N samples
    final double displaySmoothed = _calculateAverage(_displayBuffer);

    // Stage 3: Update Y-axis bounds (smooth, based on actual display data)
    _updateYAxisBounds();

    return [displaySmoothed];
  }

  /// Update Y-axis bounds smoothly based on percentiles of displayed data
  /// Uses EMA to avoid sudden jumps in display
  void _updateYAxisBounds() {
    if (_filteredIntensities.isEmpty) return;

    // Calculate percentiles from actual display data (robust to outliers)
    List<double> sortedData = List.from(_filteredIntensities)..sort();
    final int len = sortedData.length;

    // Use 15th and 85th percentiles for better robustness
    final int p15Index = max(0, ((len * 0.15).floor()));
    final int p85Index = min(len - 1, ((len * 0.85).ceil()));

    final double p15 = sortedData[p15Index];
    final double p85 = sortedData[p85Index];

    // Calculate target bounds with padding
    final double dataRange = (p85 - p15).abs();
    final double padding = dataRange * 0.25; // 25% padding above/below

    double targetMax = p85 + padding;
    double targetMin = p15 - padding;

    // Ensure minimum bounds
    if ((targetMax - targetMin).abs() < 0.5) {
      targetMax = targetMax + 0.25;
      targetMin = targetMin - 0.25;
    }

    // EMA smoothing: gradual update to avoid visual jumps
    _smoothedYAxisMax = _smoothedYAxisMax * (1 - _yAxisSmoothingAlpha) +
        targetMax * _yAxisSmoothingAlpha;
    _smoothedYAxisMin = _smoothedYAxisMin * (1 - _yAxisSmoothingAlpha) +
        targetMin * _yAxisSmoothingAlpha;

    // Update actual display bounds
    _yAxisMax = _smoothedYAxisMax;
    _yAxisMin = _smoothedYAxisMin;
  }

  /// Detect motion artifacts using velocity and acceleration analysis
  double _detectMotionArtifacts(double currentSample, RgbMeans rgb) {
    if (_intensityValues.length < 2) return 0.0;

    final double prev1 = _intensityValues.last;
    final double prev2 = _intensityValues.length > 1
        ? _intensityValues[_intensityValues.length - 2]
        : prev1;

    // Velocity: rate of change
    final double velocity = (currentSample - prev1).abs();

    // Acceleration: change in velocity
    final double acceleration =
        ((currentSample - prev1) - (prev1 - prev2)).abs();

    // RGB channel consistency (motion causes different changes in R and G)
    final double grRatio = rgb.red > 0 ? rgb.green / rgb.red : 1.0;
    final double rgbConsistency =
        ((grRatio - 1.0).abs() * 0.5).clamp(0.0, 1.0); // 0.9-1.1 is good

    // High velocity or acceleration indicates motion
    final double velocityScore = (velocity / 10.0).clamp(0.0, 1.0);
    final double accelerationScore = (acceleration / 5.0).clamp(0.0, 1.0);

    // Combined motion artifact score (0-1, where 1 is maximum artifact)
    final double motionScore =
        (0.4 * velocityScore + 0.4 * accelerationScore + 0.2 * rgbConsistency)
            .clamp(0.0, 1.0);

    return motionScore;
  }

  /// Calculate LOCAL frame rate for current batch (not running average).
  /// Uses timestamps from current batch only.
  double _calculateLocalFrameRate() {
    if (_timestamps.length < 2) return 0.0;

    final int timeDiff = _timestamps.last - _timestamps.first;
    if (timeDiff <= 0) return 0.0;

    final int frameCount = _timestamps.length - 1;
    return (frameCount * 1000.0) / timeDiff;
  }

  /// Calculates mean intensities for R, G, B channels with optimized ROI.
  /// Crops to center frame (50% size) to focus on finger contact area.
  /// Applies histogram equalization concept to normalize against lighting changes.
  RgbMeans _calculateRgbMeans(final CameraImage image) {
    double totalRed = 0.0, totalGreen = 0.0, totalBlue = 0.0;
    int pixelCount = 0;

    final int width = image.width;
    final int height = image.height;

    // Use center 50% of image for better finger coverage
    final int cropSize = (min(width, height) * 0.5).round();
    final int startX = (width - cropSize) ~/ 2;
    final int startY = (height - cropSize) ~/ 2;

    if (image.format.group == ImageFormatGroup.bgra8888) {
      // iOS: BGRA8888
      final Plane plane = image.planes[0];
      final Uint8List bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;

      for (int h = startY; h < startY + cropSize; h++) {
        final int rowStart = h * bytesPerRow;
        for (int w = startX; w < startX + cropSize; w++) {
          final int i = rowStart + (w * 4);
          if (i + 2 >= bytes.length) continue;
          final int b = bytes[i];
          final int g = bytes[i + 1];
          final int r = bytes[i + 2];
          totalRed += r;
          totalGreen += g;
          totalBlue += b;
          pixelCount++;
        }
      }
    } else {
      // Android: YUV420
      final Uint8List yBuffer = image.planes[0].bytes;
      final Uint8List uBuffer = image.planes[1].bytes;
      final Uint8List vBuffer = image.planes[2].bytes;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int? uvPixelStride = image.planes[1].bytesPerPixel;

      const int offset = 128;

      for (int h = startY; h < startY + cropSize; h++) {
        final int uvh = (h ~/ 2) + (startY ~/ 2);
        for (int w = startX; w < startX + cropSize; w++) {
          final int uvw = w ~/ 2;
          final int yIndex = h * yRowStride + w;
          if (yIndex >= yBuffer.length) continue;
          final int y = yBuffer[yIndex];
          final int uvIndex = uvh * uvRowStride + (uvPixelStride ?? 1) * uvw;
          if (uvIndex >= uBuffer.length || uvIndex >= vBuffer.length) continue;
          final int u = uBuffer[uvIndex] - offset;
          final int v = vBuffer[uvIndex] - offset;
          final int r = ((y + (v * 1436 ~/ 1024)) - 179).clamp(0, 255);
          final int g =
              ((y - (u * 46549 ~/ 131072) + 44 - (v * 93604 ~/ 131072) + 91))
                  .clamp(0, 255);
          final int b = ((y + (u * 1814 ~/ 1024)) - 227).clamp(0, 255);
          totalRed += r;
          totalGreen += g;
          totalBlue += b;
          pixelCount++;
        }
      }
    }

    // Calculate normalized means
    final double avgRed = pixelCount > 0 ? totalRed / pixelCount : 0.0;
    final double avgGreen = pixelCount > 0 ? totalGreen / pixelCount : 0.0;
    final double avgBlue = pixelCount > 0 ? totalBlue / pixelCount : 0.0;

    return RgbMeans(red: avgRed, green: avgGreen, blue: avgBlue);
  }

  /// Calculate heart rate with advanced signal processing and motion artifact handling
  /// NOTE: Does NOT modify _filteredIntensities (that's continuous display buffer)
  double _calculateHeartRate(List<double> signal, double localFrameRate) {
    if (signal.isEmpty || localFrameRate <= 0) return 0.0;
    if (localFrameRate < 20.0) return 0.0;

    // Stage 1: Remove DC component and normalize
    final List<double> normalized = _robustNormalization(signal);
    if (normalized.isEmpty) return 0.0;

    // Stage 2: Apply adaptive motion artifact removal
    final List<double> motionCleaned =
        _removeMotionArtifacts(normalized, localFrameRate);

    // Stage 3: Median filter for outlier rejection
    final List<double> medianFiltered = _medianFilter(motionCleaned, 3);

    // Stage 4: Bandpass filter for HR range (0.7–3.5 Hz = 42–210 BPM)
    final List<double> bandPassed =
        _applyButterworthBandpass(medianFiltered, 0.7, 3.5, localFrameRate);

    // Stage 5: Skip initial transient (filter settling)
    final int transientSamples = (localFrameRate * 0.5).round();
    final List<double> stable = transientSamples < bandPassed.length
        ? bandPassed.sublist(transientSamples)
        : bandPassed;
    if (stable.length < 30) return 0.0;

    // Stage 6: Z-score normalization for consistent amplitude
    final List<double> zScored = _zScore(stable);

    // Quality check: signal variability
    final double signalStd = calculateStandardDeviation(stable);
    if (signalStd < 1e-6) return 0.0;

    // NOTE: Y-axis bounds are now updated smoothly by updateYAxisBounds()
    // not abruptly here, avoiding display artifacts

    // Stage 7: Estimate HR using FFT (primary) and autocorrelation (validation)
    final double fftBpm = _estimateHrFrequencyDomain(zScored, localFrameRate);
    final double acBpm = _estimateHrAutocorrelation(zScored, localFrameRate);

    // Stage 8: Fuse estimates with confidence weighting
    double bpm;
    if (fftBpm > 0 && acBpm > 0) {
      final double diff = (fftBpm - acBpm).abs() / max(fftBpm, acBpm);
      if (diff < 0.10) {
        bpm = (fftBpm + acBpm) / 2.0;
      } else if (diff < 0.20) {
        bpm = fftBpm * 0.7 + acBpm * 0.3;
      } else {
        bpm = fftBpm;
      }
    } else {
      bpm = fftBpm > 0 ? fftBpm : acBpm;
    }

    // Clamp artifacts before extracting IBIs.
    if (bpm > 200 || bpm < 40) bpm = 0.0;

    // Stage 9: Extract IBIs from detected peaks in the main HR pipeline.
    if (bpm > 0) {
      final double expectedLagSamples = localFrameRate * 60.0 / bpm;
      final int minDist =
          (expectedLagSamples * 0.7).round().clamp(3, zScored.length);
      final int maxDist =
          (expectedLagSamples * 1.3).round().clamp(minDist + 1, zScored.length);

      final double mean = _calculateAverage(zScored);
      final double std = calculateStandardDeviation(zScored);
      final double threshold = mean + 0.3 * std;

      int lastPeakIdx = -minDist;
      for (int i = 1; i < zScored.length - 1; i++) {
        final bool isPeak =
            zScored[i - 1] < zScored[i] && zScored[i] > zScored[i + 1];
        final bool above = zScored[i] > threshold;
        final int dist = i - lastPeakIdx;
        if (isPeak && above && dist >= minDist) {
          if (lastPeakIdx >= 0 && dist <= maxDist) {
            final double ibiSec = dist / localFrameRate;
            if (ibiSec >= 0.3 && ibiSec <= 1.5) {
              _allIbiIntervals.add(ibiSec);
            }
          }
          lastPeakIdx = i;
        }
      }
    }

    final double confidence =
        _calculateBpmConfidence(zScored, localFrameRate, bpm);
    _currentBpmConfidence = confidence;

    // Apply EMA smoothing for stability
    if (bpm > 0) {
      if (_smoothedHeartRate == 0.0) {
        _smoothedHeartRate = bpm;
      } else {
        _smoothedHeartRate =
            (_smoothedHeartRate * (1 - _emaAlpha)) + (bpm * _emaAlpha);
      }
    }

    _bpmHistory.add(_smoothedHeartRate);
    return _smoothedHeartRate;
  }

  /// Robust normalization: remove DC component and zero-center
  List<double> _robustNormalization(List<double> signal) {
    if (signal.isEmpty) return signal;

    // Calculate baseline using median (robust to outliers)
    final List<double> sorted = List.from(signal)..sort();
    final double baseline = sorted[sorted.length ~/ 2];

    // Remove baseline
    final List<double> centered = signal.map((v) => v - baseline).toList();

    // Calculate robust standard deviation (using median absolute deviation)
    final List<double> absDevs = centered.map((v) => (v - 0).abs()).toList();
    absDevs.sort();
    final double mad = absDevs[absDevs.length ~/ 2] * 1.4826; // Convert to std

    if (mad < 1e-6) return List.filled(signal.length, 0.0);

    // Normalize to unit variance
    return centered.map((v) => v / mad).toList();
  }

  /// Remove motion artifacts using adaptive threshold
  List<double> _removeMotionArtifacts(List<double> signal, double fs) {
    if (signal.length < 5) return signal;

    final List<double> result = [];
    final int windowSize = (fs * 0.5).round().clamp(3, 20); // 0.5s window

    for (int i = 0; i < signal.length; i++) {
      final int start = max(0, i - windowSize ~/ 2);
      final int end = min(signal.length - 1, i + windowSize ~/ 2);

      double localMedian = _medianWindow(signal, start, end);
      double localStd = 0.0;

      for (int j = start; j <= end; j++) {
        localStd += (signal[j] - localMedian) * (signal[j] - localMedian);
      }
      localStd = sqrt(localStd / max(1, end - start + 1));

      // Keep sample if close to local median (not an outlier)
      final double sample = signal[i];

      if ((sample - localMedian).abs() <= 3.0 * localStd) {
        result.add(sample);
      } else {
        // Replace outlier with local median
        result.add(localMedian);
      }
    }

    return result;
  }

  /// Median filter for outlier rejection
  List<double> _medianFilter(List<double> signal, int windowSize) {
    if (signal.length < windowSize) return signal;

    final List<double> result = [];
    for (int i = 0; i < signal.length; i++) {
      final int start = max(0, i - windowSize ~/ 2);
      final int end = min(signal.length - 1, i + windowSize ~/ 2);
      result.add(_medianWindow(signal, start, end));
    }
    return result;
  }

  double _medianWindow(List<double> signal, int start, int end) {
    final List<double> window = signal.sublist(start, end + 1);
    window.sort();
    return window[window.length ~/ 2];
  }

  // IMPROVED: Frequency Domain HR estimation with zero-padding and parabolic interpolation
  double _estimateHrFrequencyDomain(
      List<double> signal, double localFrameRate) {
    final int origN = signal.length;
    if (origN < 30) return 0.0;

    // Zero-pad to next power of 2 (at least 256) for better frequency resolution
    int N = 256;
    while (N < origN) N *= 2;
    if (N < 256) N = 256;

    final List<double> windowed = _applyHammingWindow(signal);
    final List<double> padded = List<double>.filled(N, 0.0);
    for (int i = 0; i < windowed.length; i++) {
      padded[i] = windowed[i];
    }

    try {
      final fft = FFT(N);
      final freqDomain = fft.realFft(Float64List.fromList(padded));
      final magnitudes = freqDomain.magnitudes();

      final double freqRes = localFrameRate / N;

      // Find indices in HR range (0.7-3.5 Hz)
      final int lowIdx = (0.7 / freqRes).ceil();
      final int highIdx = min((3.5 / freqRes).floor(), magnitudes.length - 1);
      if (lowIdx >= highIdx || lowIdx >= magnitudes.length) return 0.0;

      // Find peak magnitude
      double maxMag = -1.0;
      int peakIdx = lowIdx;
      for (int i = lowIdx; i <= highIdx; i++) {
        if (magnitudes[i] > maxMag) {
          maxMag = magnitudes[i];
          peakIdx = i;
        }
      }

      // Parabolic interpolation for sub-bin accuracy
      double peakFreq = peakIdx * freqRes;
      if (peakIdx > lowIdx && peakIdx < highIdx) {
        final double alpha = magnitudes[peakIdx - 1];
        final double beta = magnitudes[peakIdx];
        final double gamma = magnitudes[peakIdx + 1];
        final double denom = alpha - 2 * beta + gamma;
        if (denom.abs() > 1e-10) {
          final double p = 0.5 * (alpha - gamma) / denom;
          peakFreq = (peakIdx + p) * freqRes;
        }
      }

      return peakFreq * 60.0;
    } catch (e) {
      if (kDebugMode) print('FFT error: $e');
      return 0.0;
    }
  }

  /// IMPROVED: Confidence score with SNR + harmonic validation + autocorrelation
  double _calculateBpmConfidence(
      List<double> signal, double localFrameRate, double bpm) {
    if (bpm <= 0 || signal.length < 30) return 0.0;

    final int origN = signal.length;
    int N = 256;
    while (N < origN) N *= 2;
    if (N < 256) N = 256;

    try {
      final List<double> windowed = _applyHammingWindow(signal);
      final List<double> padded = List<double>.filled(N, 0.0);
      for (int i = 0; i < windowed.length; i++) {
        padded[i] = windowed[i];
      }

      final fft = FFT(N);
      final freqDomain = fft.realFft(Float64List.fromList(padded));
      final magnitudes = freqDomain.magnitudes();
      final double freqRes = localFrameRate / N;

      // 1. SNR score
      final double peakFreqHz = bpm / 60.0;
      final int peakBin =
          (peakFreqHz / freqRes).round().clamp(0, magnitudes.length - 1);

      double peakMag = 0.0;
      for (int i = max(0, peakBin - 1);
          i <= min(magnitudes.length - 1, peakBin + 1);
          i++) {
        peakMag = max(peakMag, magnitudes[i]);
      }

      final int lowIdx = (0.7 / freqRes).ceil();
      final int highIdx = min((3.5 / freqRes).floor(), magnitudes.length - 1);

      double sumMag = 0.0;
      int count = 0;
      for (int i = lowIdx; i <= highIdx; i++) {
        if ((i - peakBin).abs() > 2) {
          sumMag += magnitudes[i];
          count++;
        }
      }
      final double noiseMag = count > 0 ? sumMag / count : 1.0;
      final double snr = peakMag / max(noiseMag, 1e-10);
      final double snrScore = (snr / 8.0).clamp(0.0, 1.0);

      // 2. Harmonic score
      double harmonicScore = 0.0;
      final int harmonic2Bin = (2 * peakFreqHz / freqRes).round();
      if (harmonic2Bin > 0 && harmonic2Bin < magnitudes.length) {
        double harm2Mag = 0.0;
        for (int i = max(0, harmonic2Bin - 1);
            i <= min(magnitudes.length - 1, harmonic2Bin + 1);
            i++) {
          harm2Mag = max(harm2Mag, magnitudes[i]);
        }
        if (harm2Mag > noiseMag * 1.5) {
          harmonicScore = (harm2Mag / peakMag).clamp(0.0, 1.0);
          harmonicScore = min(harmonicScore * 2.0, 1.0);
        }
      }

      // 3. Autocorrelation score
      double acScore = _autocorrelationScore(signal, localFrameRate, bpm);

      // Combined confidence
      final double confidence =
          (0.5 * snrScore + 0.2 * harmonicScore + 0.3 * acScore)
              .clamp(0.0, 1.0);

      return confidence;
    } catch (e) {
      if (kDebugMode) print('Confidence calculation error: $e');
      return 0.0;
    }
  }

  /// Autocorrelation-based periodicity score.
  /// Calculates normalized autocorrelation at the expected lag for the given BPM.
  /// Returns 0-1: high means strong periodic component at expected HR.
  double _autocorrelationScore(
      List<double> signal, double sampleRate, double bpm) {
    if (bpm <= 0 || signal.length < 30) return 0.0;

    final double expectedPeriodSamples = sampleRate * 60.0 / bpm;
    final int lag = expectedPeriodSamples.round();
    if (lag <= 0 || lag >= signal.length ~/ 2) return 0.0;

    // Subtract mean
    final double mean = _calculateAverage(signal);
    final List<double> centered = signal.map((v) => v - mean).toList();

    // Autocorrelation at lag 0 (energy) and at expected lag
    double r0 = 0.0;
    double rLag = 0.0;
    final int len = centered.length - lag;
    for (int i = 0; i < len; i++) {
      r0 += centered[i] * centered[i];
      rLag += centered[i] * centered[i + lag];
    }

    if (r0 < 1e-10) return 0.0;
    final double normalizedAc = rLag / r0;

    // Good cardiac signal: autocorrelation at expected lag > 0.3
    return normalizedAc.clamp(0.0, 1.0);
  }

  /// Autocorrelation-based HR estimation.
  /// Finds the lag with maximum autocorrelation in the HR range (0.7-3.5 Hz).
  /// More robust than FFT for short signals and handles non-stationary signals better.
  double _estimateHrAutocorrelation(List<double> signal, double sampleRate) {
    if (signal.length < 30) return 0.0;

    // Subtract mean
    final double mean = _calculateAverage(signal);
    final List<double> centered = signal.map((v) => v - mean).toList();

    // Compute autocorrelation at lag 0 for normalization
    double r0 = 0.0;
    for (final v in centered) r0 += v * v;
    if (r0 < 1e-10) return 0.0;

    // Search lags corresponding to 42-210 BPM (0.7-3.5 Hz)
    final int minLag = (sampleRate / 3.5).ceil(); // 3.5 Hz = 210 BPM
    final int maxLag =
        min((sampleRate / 0.7).floor(), signal.length ~/ 2); // 0.7 Hz = 42 BPM
    if (minLag >= maxLag) return 0.0;

    // Find lag with maximum normalized autocorrelation
    double bestAc = -1.0;
    int bestLag = minLag;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double rLag = 0.0;
      final int len = centered.length - lag;
      for (int i = 0; i < len; i++) {
        rLag += centered[i] * centered[i + lag];
      }
      final double normalizedAc = rLag / r0;
      if (normalizedAc > bestAc) {
        bestAc = normalizedAc;
        bestLag = lag;
      }
    }

    // Parabolic interpolation around peak lag for sub-sample accuracy
    double refinedLag = bestLag.toDouble();
    if (bestLag > minLag && bestLag < maxLag) {
      double rPrev = 0.0, rNext = 0.0;
      final int prevLen = centered.length - (bestLag - 1);
      final int nextLen = centered.length - (bestLag + 1);
      for (int i = 0; i < prevLen; i++) {
        rPrev += centered[i] * centered[i + bestLag - 1];
      }
      for (int i = 0; i < nextLen; i++) {
        rNext += centered[i] * centered[i + bestLag + 1];
      }
      rPrev /= r0;
      rNext /= r0;
      final double denom = rPrev - 2 * bestAc + rNext;
      if (denom.abs() > 1e-10) {
        final double p = 0.5 * (rPrev - rNext) / denom;
        refinedLag = bestLag + p;
      }
    }

    if (refinedLag <= 0) return 0.0;
    final double bpm = sampleRate * 60.0 / refinedLag;

    if (kDebugMode) {
      print('Debug: Autocorrelation: lag=${refinedLag.toStringAsFixed(1)}, '
          'AC=${bestAc.toStringAsFixed(3)}, BPM=${bpm.toStringAsFixed(1)}');
    }

    return (bpm >= 40 && bpm <= 210) ? bpm : 0.0;
  }

  // IMPROVED: Time-domain peak detection with LOCAL framerate (kept for reference, not used in main calculation).
  // ignore: unused_element
  double _estimateHrTimeDomain(List<double> signal, double localFrameRate) {
    // Adaptive threshold for peaks (mean + 0.4 * std - more sensitive).
    final double mean = _calculateAverage(signal);
    final double std = calculateStandardDeviation(signal);
    final double adaptiveThreshold = mean + 0.4 * std;

    // Higher min distance to reject dicrotic notch (~0.4s to block second peak)
    final double minDistance = (localFrameRate * 0.4)
        .clamp(localFrameRate * 0.3, localFrameRate * 0.8);

    // Higher prominence requirement (0.5 * std) to filter low-amplitude artifacts
    final double prominence = 0.5 * std;
    final int promWindow = (localFrameRate * 0.3).round().clamp(5, 40);

    // Find peaks with adaptive threshold and min distance.
    final List<List<double>> peaks = _findPeaks(signal,
        threshold: adaptiveThreshold,
        minDistance: minDistance,
        prominence: prominence,
        promWindow: promWindow);

    var peakIndices = peaks[0];
    final List<double> peakValues = peaks[1];
    if (peakIndices.length < 2) return 0.0;

    // Filter peaks by amplitude - keep only those > 0.3*std from mean
    final double amplitudeThreshold = mean + 0.3 * std;
    final List<int> validIndices = [];
    for (int i = 0; i < peakValues.length; i++) {
      if (peakValues[i] > amplitudeThreshold) {
        validIndices.add(i);
      }
    }
    if (validIndices.length < 2) return 0.0;

    peakIndices = [for (int idx in validIndices) peakIndices[idx]];

    // Inter-peak intervals (IBIs) in seconds.
    final List<double> ibis = [];
    for (int i = 0; i < peakIndices.length - 1; i++) {
      final double samplesDiff = peakIndices[i + 1] - peakIndices[i];
      final double ibiSec = samplesDiff / localFrameRate;
      ibis.add(ibiSec);
    }

    if (ibis.isEmpty) return 0.0;

    // Filter invalid IBIs (outliers outside 0.3-1.5s for 40-200 BPM).
    final List<double> validIbis =
        ibis.where((ibi) => ibi >= 0.3 && ibi <= 1.5).toList();
    if (validIbis.isEmpty) return 0.0;

    // Store valid IBIs for full-measurement HRV calculation
    _allIbiIntervals.addAll(validIbis);
    if (kDebugMode) {
      print(
          'Debug: Added ${validIbis.length} IBIs, total now: ${_allIbiIntervals.length}');
    }

    // Use median IBI for robustness.
    final double medianIbiSec = _calculateMedian(validIbis);
    return 60.0 / medianIbiSec;
  }

  // IMPROVED: Enhanced peak finder with optional threshold, minDistance, and prominence.
  // ignore: unused_element
  List<List<double>> _findPeaks(final List<double> signal,
      {double? threshold,
      double minDistance = 0.0,
      double? prominence,
      int promWindow = 5}) {
    final int n = signal.length - 2;
    final List<double> indices = [];
    final List<double> values = [];
    double lastIndex = -double.infinity;

    for (int i = 1; i <= n; i++) {
      final bool isPeak =
          signal[i - 1] <= signal[i] && signal[i] >= signal[i + 1];
      final bool aboveThreshold = threshold == null || signal[i] >= threshold;
      final bool farEnough = (i - lastIndex) >= minDistance;
      bool passesProminence = true;
      if (prominence != null) {
        final int start = max(0, i - promWindow);
        final int end = min(signal.length - 1, i + promWindow);
        double localMin = signal[start];
        for (int j = start + 1; j <= end; j++) {
          if (signal[j] < localMin) localMin = signal[j];
        }
        passesProminence = (signal[i] - localMin) >= prominence;
      }

      if (isPeak && aboveThreshold && farEnough && passesProminence) {
        indices.add(i.toDouble());
        values.add(signal[i]);
        lastIndex = i.toDouble();
      }
    }
    return [indices, values];
  }

  List<double> _applyHammingWindow(List<double> signal) {
    final int n = signal.length;
    if (n < 2) return signal;
    final List<double> windowed = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      final double w = 0.54 - 0.46 * cos(2 * pi * i / (n - 1));
      windowed[i] = signal[i] * w;
    }
    return windowed;
  }

  List<double> _zScore(List<double> signal) {
    if (signal.isEmpty) return signal;
    final double mean = _calculateAverage(signal);
    final double std = calculateStandardDeviation(signal);
    if (std == 0) return List<double>.filled(signal.length, 0.0);
    return signal.map((v) => (v - mean) / std).toList();
  }

  // (Unused now, but kept for reference) Minima finder.
  // ignore: unused_element
  List<List<double>> _findMinima(final List<double> signal) {
    final double globalMin = signal.reduce(min);
    final double threshold = globalMin * 0.2; // Relaxed for mild signals.
    final int n = signal.length - 2;
    final List<double> indices = [];
    final List<double> values = [];

    for (int i = 1; i <= n; i++) {
      final bool isMin =
          signal[i - 1] >= signal[i] && signal[i] <= signal[i + 1];
      if (isMin && signal[i] <= threshold) {
        indices.add(i.toDouble());
        values.add(signal[i]);
      }
    }
    return [indices, values];
  }

  double getCurrentHeartRate() => _currentHeartRate;

  double getCurrentRespiratoryRate() => _smoothedRespiratoryRate;

  double getSdnn() => _currentSdnn;

  double getRmssd() => _currentRmssd;

  double getPnn50() => _currentPnn50;

  double getSd1() => _currentSd1;

  double getSd2() => _currentSd2;

  double getAverageIntensity() => _lastAverageGreen ?? 0.0;

  RgbMeans getLastRgbMeans() => RgbMeans(
        red: _lastAverageRed ?? 0.0,
        green: _lastAverageGreen ?? 0.0,
        blue: _lastAverageBlue ?? 0.0,
      );

  List<int> getIntensityValues() =>
      _intensityValues.map((e) => e.toInt()).toList();

  List<double> _computeMovingAverage(
      final List<double> values, final int windowSize) {
    if (values.length < windowSize) return values;

    final List<double> averages = [];
    for (int i = 0; i <= values.length - windowSize; i++) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        sum += values[i + j];
      }
      averages.add(sum / windowSize);
    }
    while (averages.length < values.length) {
      averages.add(averages.last);
    }
    return averages;
  }

  // ignore: unused_element
  List<double> _computeDerivative(final List<double> data) {
    // ignore: unused_element
    if (data.length < 2) return data;

    final List<double> derivative = [];
    for (int i = 0; i < data.length - 1; i++) {
      derivative.add(data[i + 1] - data[i]);
    }
    return derivative;
  }

  List<double> dataToPlot() => List.unmodifiable(_fullRecordBuffer);

  List<double> getPpgPlot() => List.unmodifiable(_ppgSignal);

  double getMax() => _yAxisMax > 255 ? 255.0 : _yAxisMax;

  double getMin() => _yAxisMin < 0 ? 0.0 : _yAxisMin;

  double getSummary() {
    if (_bpmHistory.length < 2) return 0.0;

    final List<double> validBpms = List.from(_bpmHistory)
      ..removeWhere((bpm) => bpm == 0.0);

    // Remove first BPM (calibration phase) if we have enough data
    if (validBpms.length > 2) {
      validBpms.removeAt(0);
    }

    if (validBpms.isEmpty) return 0.0;

    // Calculate HRV from all accumulated IBI intervals
    _calculateFinalHrv();

    return _calculateMedian(validBpms);
  }

  void _calculateFinalHrv() {
    if (_allIbiIntervals.length < 2) {
      if (kDebugMode) {
        print('HRV: Not enough IBIs (${_allIbiIntervals.length})');
      }
      return;
    }

    if (kDebugMode) {
      print(
          'Debug: Calculating HRV from ${_allIbiIntervals.length} IBI intervals');
      print(
          'Debug: IBI range: ${_allIbiIntervals.reduce(min).toStringAsFixed(3)}s - ${_allIbiIntervals.reduce(max).toStringAsFixed(3)}s');
    }
    // SDNN: Standard Deviation of NN intervals
    _currentSdnn =
        calculateStandardDeviation(_allIbiIntervals) * 1000.0; // Convert to ms

    // RMSSD: Root Mean Square of Successive Differences
    double sumSquaredDiff = 0.0;
    List<double> successiveDiffs = [];
    for (int i = 0; i < _allIbiIntervals.length - 1; i++) {
      final double diff = _allIbiIntervals[i + 1] - _allIbiIntervals[i];
      successiveDiffs.add(diff);
      sumSquaredDiff += diff * diff;
    }
    _currentRmssd = sqrt(sumSquaredDiff / (_allIbiIntervals.length - 1)) *
        1000.0; // Convert to ms

    // pNN50: Percentage of successive NN intervals that differ by more than 50ms
    int nn50Count = successiveDiffs.where((diff) => diff.abs() > 0.05).length;
    _currentPnn50 = (nn50Count / successiveDiffs.length) * 100.0;

    // SD1 and SD2: Poincaré plot parameters
    // SD1 represents short-term HRV (beat-to-beat variability)
    // SD2 represents long-term HRV (continuous variability)
    _currentSd1 = sqrt(0.5 * sumSquaredDiff / (_allIbiIntervals.length - 1)) *
        1000.0; // Convert to ms
    _currentSd2 = sqrt(2 * pow(_currentSdnn / 1000.0, 2) -
            0.5 * sumSquaredDiff / (_allIbiIntervals.length - 1)) *
        1000.0; // Convert to ms

    final double meanIbi = _calculateAverage(_allIbiIntervals) * 1000.0;
    final double meanHr = 60.0 / _calculateAverage(_allIbiIntervals);

    if (kDebugMode) {
      print('HRV Summary:');
      print('  Total IBIs: ${_allIbiIntervals.length}');
      print('  Mean IBI: ${meanIbi.toStringAsFixed(1)} ms');
      print('  Mean HR: ${meanHr.toStringAsFixed(1)} bpm');
      print('  SDNN: ${_currentSdnn.toStringAsFixed(2)} ms');
      print('  RMSSD: ${_currentRmssd.toStringAsFixed(2)} ms');
      print('  pNN50: ${_currentPnn50.toStringAsFixed(1)}%');
      print('  SD1: ${_currentSd1.toStringAsFixed(2)} ms (short-term)');
      print('  SD2: ${_currentSd2.toStringAsFixed(2)} ms (long-term)');
      print(
          '  Max successive diff: ${(successiveDiffs.map((d) => d.abs()).reduce(max) * 1000).toStringAsFixed(1)} ms');
    }
  }

  /// NEW: Update HRV metrics continuously from accumulated IBIs.
  /// This allows real-time monitoring of HRV during measurement without waiting for summary.
  /// Called after each sliding window processing.
  void _updateContinuousHrv() {
    if (_allIbiIntervals.length < 2) {
      return; // Not enough data yet
    }

    // Use only recent IBIs (keep max 300 for HRV = ~5 min of data at 60 BPM)
    final List<double> recentIbis = _allIbiIntervals.length > 300
        ? _allIbiIntervals.sublist(_allIbiIntervals.length - 300)
        : _allIbiIntervals;

    // SDNN: Standard Deviation of NN intervals
    _currentSdnn =
        calculateStandardDeviation(recentIbis) * 1000.0; // Convert to ms

    // RMSSD: Root Mean Square of Successive Differences
    if (recentIbis.length >= 2) {
      double sumSquaredDiff = 0.0;
      List<double> successiveDiffs = [];
      for (int i = 0; i < recentIbis.length - 1; i++) {
        final double diff = recentIbis[i + 1] - recentIbis[i];
        successiveDiffs.add(diff);
        sumSquaredDiff += diff * diff;
      }
      _currentRmssd = sqrt(sumSquaredDiff / (recentIbis.length - 1)) *
          1000.0; // Convert to ms

      // pNN50: Percentage of successive NN intervals that differ by more than 50ms
      int nn50Count = successiveDiffs.where((diff) => diff.abs() > 0.05).length;
      _currentPnn50 = successiveDiffs.isNotEmpty
          ? (nn50Count / successiveDiffs.length) * 100.0
          : 0.0;

      // SD1 and SD2: Poincaré plot parameters
      _currentSd1 =
          sqrt(0.5 * sumSquaredDiff / (recentIbis.length - 1)) * 1000.0;
      _currentSd2 = sqrt(2 * pow(_currentSdnn / 1000.0, 2) -
              0.5 * sumSquaredDiff / (recentIbis.length - 1)) *
          1000.0;

      if (kDebugMode) {
        print(
            'HRV (continuous): SDNN=${_currentSdnn.toStringAsFixed(1)} ms, RMSSD=${_currentRmssd.toStringAsFixed(1)} ms, pNN50=${_currentPnn50.toStringAsFixed(1)}%, SD1=${_currentSd1.toStringAsFixed(1)} ms, SD2=${_currentSd2.toStringAsFixed(1)} ms (from ${recentIbis.length} IBIs)');
      }
    }
  }

  /// Reset algorithm state for new measurement
  void reset() {
    _intensityValues.clear();
    _filteredIntensities.clear();
    _derivativeValues.clear();
    _ppgSignal.clear();
    _fullRecordBuffer.clear();
    _timestamps.clear();
    _bpmHistory.clear();
    _frameRates.clear();
    _respiratoryRates.clear();
    _hrvValues.clear();
    _allIbiIntervals.clear();
    _motionArtifactScores.clear();
    _displayBuffer.clear();
    _framesProcessedSinceLastUpdate = 0;
    _currentHeartRate = 0.0;
    _smoothedHeartRate = 0.0;
    _currentRespiratoryRate = 0.0;
    _smoothedRespiratoryRate = 0.0;
    _currentSdnn = 0.0;
    _currentRmssd = 0.0;
    _currentPnn50 = 0.0;
    _currentSd1 = 0.0;
    _currentSd2 = 0.0;
    _frameRate = 0.0;
    _localFrameRate = 0.0;
    _currentBpmConfidence = 0.0;
    _lastMotionArtifactScore = 0.0;
    _yAxisMax = 2.0;
    _yAxisMin = -2.0;
    _smoothedYAxisMax = 2.0;
    _smoothedYAxisMin = -2.0;
  }

  // ignore: unused_element
  List<double> _applyLowPassFilter(
    final List<double> signal,
    final double cutoffFrequencyHz,
    final double samplingRateHz,
  ) {
    if (signal.isEmpty) return signal;

    final double rc = 1.0 / (2 * pi * cutoffFrequencyHz);
    final double dt = 1.0 / samplingRateHz;
    final double alpha = dt / (rc + dt);

    final List<double> filtered = [];
    double previous = signal[0];

    for (final double sample in signal) {
      final double output = previous + alpha * (sample - previous);
      filtered.add(output);
      previous = output;
    }
    return filtered;
  }

  // ignore: unused_element
  List<double> _applyHighPassFilter(
    final List<double> signal,
    final double cutoffFrequencyHz,
    final double samplingRateHz,
  ) {
    if (signal.isEmpty) return signal;

    final double rc = 1.0 / (2 * pi * cutoffFrequencyHz);
    final double dt = 1.0 / samplingRateHz;
    final double alpha = rc / (rc + dt);

    final List<double> filtered = [];
    double previousOutput = signal[0];
    double previousSample = signal[0];

    filtered.add(previousOutput); // First value unchanged.

    for (int i = 1; i < signal.length; i++) {
      final double sample = signal[i];
      final double output = alpha * (previousOutput + sample - previousSample);
      filtered.add(output);
      previousOutput = output;
      previousSample = sample;
    }
    return filtered;
  }

  List<double> getFrames() {
    if (kDebugMode) {
      print(_frameRates);
    }
    if (_frameRates.isEmpty) return [];

    final double avgFrameRate = _calculateAverage(_frameRates);
    return List<double>.from(_frameRates)..add(avgFrameRate);
  }

  List<double> getRespiratoryRates() {
    return List<double>.from(_respiratoryRates);
  }

  List<double> getBpmHistory() => List.unmodifiable(_bpmHistory);

  double _calculateAverage(final List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double _calculateMedian(final List<double> values) {
    if (values.isEmpty) return 0.0;

    final List<double> sorted = List<double>.from(values)..sort();
    final int mid = sorted.length ~/ 2;

    return sorted.length % 2 == 1
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Calculate respiratory rate from amplitude envelope
  /// Method: extract pulse band -> envelope -> respiratory band filter -> peak detection
  ///
  /// CHANGED: Now accepts signal and local frame rate as parameters.
  double _calculateRespiratoryRate(List<double> signal, double fs) {
    if (signal.length < (fs * 4).round()) {
      if (kDebugMode) {
        print('RR: Signal too short: ${signal.length}');
      }
      return 0.0;
    }

    // 1) Isolate pulse component (0.7-3.0 Hz heart band)
    final pulse = _applyButterworthBandpass(signal, 0.7, 3.0, fs);
    if (pulse.length < 8) {
      if (kDebugMode) {
        print('RR: Pulse band too short: ${pulse.length}');
      }
      return 0.0;
    }

    // 2) Envelope via absolute value + moving average (~1s)
    final envelope = pulse.map((v) => v.abs()).toList();
    final envSmooth =
        _movingAverage(envelope, (fs * 1.0).round().clamp(5, 120));

    final envMin = envelope.isEmpty ? 0.0 : envelope.reduce(min);
    final envMax = envelope.isEmpty ? 0.0 : envelope.reduce(max);
    final envAvg = _calculateAverage(envelope);
    if (kDebugMode) {
      print('RR: Envelope - min: $envMin, max: $envMax, avg: $envAvg');
    }

    // 3) Respiratory modulation band (0.05-0.5 Hz = 3-30 breaths/min)
    final resp = _applyButterworthBandpass(envSmooth, 0.05, 0.5, fs);
    if (resp.length < 8) {
      if (kDebugMode) {
        print('RR: Resp band too short: ${resp.length}');
      }
      return 0.0;
    }

    final avg = _calculateAverage(resp);
    final std = calculateStandardDeviation(resp);
    if (kDebugMode) {
      print('RR: Resp signal - avg: $avg, std: $std');
    }
    if (std < 0.0005) {
      if (kDebugMode) {
        print('RR: Std too low: $std');
      }
      return 0.0;
    }

    // 4) Peak detection with threshold
    final threshold = avg + 0.2 * std;
    if (kDebugMode) {
      print('RR: Threshold: $threshold');
    }
    final peaks = <int>[];
    int lastIndex = -(fs * 1.5).round(); // refractory ~1.5s

    for (int i = 1; i < resp.length - 1; i++) {
      final isPeak = resp[i - 1] < resp[i] && resp[i] > resp[i + 1];
      final aboveThreshold = resp[i] > threshold;
      final farEnough = (i - lastIndex) >= (fs * 1.2).round();
      if (isPeak && aboveThreshold && farEnough) {
        peaks.add(i);
        lastIndex = i;
      }
    }

    if (kDebugMode) {
      print('RR: Peaks detected: ${peaks.length}');
    }
    if (peaks.length < 2) {
      if (kDebugMode) {
        print('RR: Too few peaks: ${peaks.length}');
      }
      return 0.0;
    }

    // 5) Calculate breath rate from valid intervals
    double totalInterval = 0.0;
    int validIntervals = 0;
    for (int i = 1; i < peaks.length; i++) {
      final intervalSeconds = (peaks[i] - peaks[i - 1]) / fs;
      if (intervalSeconds >= 1.5 && intervalSeconds <= 12.0) {
        totalInterval += intervalSeconds;
        validIntervals++;
      }
    }

    if (kDebugMode) {
      print('RR: Valid intervals: $validIntervals / ${peaks.length - 1}');
    }
    if (validIntervals == 0) {
      if (kDebugMode) {
        print('RR: No valid intervals');
      }
      return 0.0;
    }

    final avgInterval = totalInterval / validIntervals;
    final respiratoryRate = 60.0 / avgInterval;
    final clampedRR = respiratoryRate.clamp(6.0, 30.0);
    if (kDebugMode) {
      print('RR: Calculated rate: $respiratoryRate (clamped: $clampedRR)');
    }

    // Apply EMA smoothing to RR (same as HR)
    if (clampedRR > 0) {
      if (_smoothedRespiratoryRate == 0.0) {
        _smoothedRespiratoryRate = clampedRR;
      } else {
        _smoothedRespiratoryRate =
            (_smoothedRespiratoryRate * (1 - _emaAlpha)) +
                (clampedRR * _emaAlpha);
      }
    }
    if (kDebugMode) {
      print(
          'RR: Raw = ${clampedRR.toStringAsFixed(2)}, EMA-smoothed = ${_smoothedRespiratoryRate.toStringAsFixed(2)}');
    }

    return _smoothedRespiratoryRate;
  }

  /// Butterworth bandpass filter (2nd order cascade)
  List<double> _applyButterworthBandpass(
      List<double> signal, double lowFreq, double highFreq, double fs) {
    if (signal.length < 3) return signal;

    final nyquist = fs / 2.0;
    final lowNorm = lowFreq / nyquist;
    final highNorm = highFreq / nyquist;

    // Low-pass coefficients (cutoff = highFreq)
    final wcLow = tan(pi * highNorm);
    final aLow = 1 + sqrt(2) * wcLow + wcLow * wcLow;
    final b0Low = wcLow * wcLow / aLow;
    final b1Low = 2 * b0Low;
    final b2Low = b0Low;
    final a1Low = (2 * (wcLow * wcLow - 1)) / aLow;
    final a2Low = (1 - sqrt(2) * wcLow + wcLow * wcLow) / aLow;

    // High-pass coefficients (cutoff = lowFreq)
    final wcHigh = tan(pi * lowNorm);
    final aHigh = 1 + sqrt(2) * wcHigh + wcHigh * wcHigh;
    final b0High = 1 / aHigh;
    final b1High = -2 * b0High;
    final b2High = b0High;
    final a1High = (2 * (wcHigh * wcHigh - 1)) / aHigh;
    final a2High = (1 - sqrt(2) * wcHigh + wcHigh * wcHigh) / aHigh;

    // Apply low-pass filter
    List<double> out1 = List<double>.filled(signal.length, 0.0);
    double xn1 = 0, xn2 = 0, yn1 = 0, yn2 = 0;
    for (int i = 0; i < signal.length; i++) {
      final xn = signal[i];
      final yn =
          b0Low * xn + b1Low * xn1 + b2Low * xn2 - a1Low * yn1 - a2Low * yn2;
      out1[i] = yn;
      xn2 = xn1;
      xn1 = xn;
      yn2 = yn1;
      yn1 = yn;
    }

    // Apply high-pass filter
    List<double> out2 = List<double>.filled(out1.length, 0.0);
    xn1 = 0;
    xn2 = 0;
    yn1 = 0;
    yn2 = 0;
    for (int i = 0; i < out1.length; i++) {
      final xn = out1[i];
      final yn = b0High * xn +
          b1High * xn1 +
          b2High * xn2 -
          a1High * yn1 -
          a2High * yn2;
      out2[i] = yn;
      xn2 = xn1;
      xn1 = xn;
      yn2 = yn1;
      yn1 = yn;
    }

    return out2;
  }

  /// Moving average filter
  List<double> _movingAverage(List<double> signal, int windowSize) {
    if (signal.length <= windowSize) {
      final avg = _calculateAverage(signal);
      return List<double>.filled(signal.length, avg);
    }

    final result = <double>[];
    double sum = 0.0;
    for (int i = 0; i < windowSize; i++) {
      sum += signal[i];
    }

    for (int i = 0; i < signal.length; i++) {
      if (i >= windowSize) {
        sum = sum - signal[i - windowSize] + signal[i];
      }
      result.add(sum / windowSize);
    }

    return result;
  }
}

/// Simple struct for RGB means (for quality analyzer integration).
class RgbMeans {
  final double red;
  final double green;
  final double blue;

  const RgbMeans({
    required this.red,
    required this.green,
    required this.blue,
  });
}
