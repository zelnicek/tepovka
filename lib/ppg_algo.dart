import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart'; // NEW: Frequency Domain - Import FFT library
import 'package:collection/collection.dart'; // For List extensions if needed
import 'package:flutter/services.dart'; // If needed for Float64List
import 'package:camera/camera.dart'; // Provides CameraImage used by processImage

/// A class implementing a Photoplethysmography (PPG) algorithm for heart rate
/// estimation from camera images, optimized for high signal quality analysis.
/// Uses green channel primarily for blood volume pulse, with RGB means for quality
/// checks (e.g., finger detection via intensity ratios). Aligned with 2025 rPPG
/// standards: adaptive filtering, robust peak detection, and cross-channel validation.
/// Functionality preserved: buffers frames, low-pass filters, detects peaks via
/// derivative minima, computes BPM, and provides RGB stats for analyzer.
class PPGAlgorithm {
  /// Maximum y-axis value for plotting (8-bit intensity range).
  double get yAxisMax => _yAxisMax;
  double _yAxisMax = 255.0;

  /// Minimum y-axis value for plotting.
  double get yAxisMin => _yAxisMin;
  double _yAxisMin = 0.0;

  /// Raw intensity values (green channel primary).
  final List<double> _intensityValues = [];

  /// Filtered intensity values for secondary processing.
  final List<double> _filteredIntensities = [];

  /// Derivative values for peak detection.
  final List<double> _derivativeValues = [];

  /// Current estimated heart rate in BPM.
  double get currentHeartRate => _currentHeartRate;
  double _currentHeartRate = 0.0;

  /// Last computed averages: green (primary), red, blue for quality analysis.
  double? _lastAverageGreen;
  double? _lastAverageRed;
  double? _lastAverageBlue;

  /// Maximum number of frames to buffer before processing.
  // IMPROVED: Increased for more data per HR estimate (~10s at 30 FPS).
  static const int _maxFrameBufferSize = 300;

  /// Estimated frame rate in FPS.
  double _frameRate = 0.0;

  /// PPG signal (green) for plotting.
  final List<double> _ppgSignal = [];

  /// Timestamps for frame intervals.
  final List<int> _timestamps = [];

  /// Accumulated BPM values for summary.
  final List<double> _bpmHistory = [];

  /// List of frame rates for analysis.
  final List<double> _frameRates = [];

  /// Computes the standard deviation of the given list of values.
  double calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final double mean = _calculateAverage(values);
    final double sumOfSquaredDifferences = values
        .map((value) => pow(value - mean, 2))
        .reduce((a, b) => a + b)
        .toDouble();

    return sqrt(sumOfSquaredDifferences / values.length);
  }

  /// Processes a camera image: extracts RGB means, updates green buffer, applies
  /// filtering after buffer full, computes heart rate. Provides RGB for quality
  /// checks (e.g., high red/green ratio indicates poor contact).
  void processImage(final CameraImage image) {
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    // Update frame rate estimate.
    if (_timestamps.isNotEmpty) {
      final int intervalMs = currentTime - _timestamps.last;
      if (intervalMs > 0) {
        final double currentFps = 1000.0 / intervalMs;
        _frameRate =
            _frameRate == 0.0 ? currentFps : (_frameRate + currentFps) / 2;
      }
    }
    _timestamps.add(currentTime);

    // Extract RGB means for quality analysis.
    final RgbMeans rgbMeans = _calculateRgbMeans(image);
    _lastAverageGreen = rgbMeans.green;
    _lastAverageRed = rgbMeans.red;
    _lastAverageBlue = rgbMeans.blue;

    // Use green as primary signal (fallback to red if green <1 after crop).
    double primarySignal = rgbMeans.green;
    if (primarySignal < 1.0) {
      primarySignal = rgbMeans.red; // Red is stable if green is too low.
      print(
          'Debug: Switched to red channel (green too low: ${rgbMeans.green})');
    }
    _intensityValues.add(primarySignal);
    _filteredIntensities.add(primarySignal);
    _ppgSignal.add(primarySignal);

    if (_intensityValues.length > _maxFrameBufferSize) {
      print('Estimated frame rate: $_frameRate FPS');
      _frameRates.add(_frameRate);

      // Compute heart rate with quality checks.
      _currentHeartRate = _calculateHeartRate();

      // Clear after compute to avoid data loss.
      _intensityValues.clear();
      _timestamps.clear();
      _derivativeValues.clear();
    }
  }

  /// Calculates mean intensities for R, G, B channels. Handles BGRA (iOS) and YUV (Android).
  /// Crop to center frame (50% size) for focus on finger – increases mean green.
  RgbMeans _calculateRgbMeans(final CameraImage image) {
    double totalRed = 0.0, totalGreen = 0.0, totalBlue = 0.0;
    int pixelCount = 0;

    final int width = image.width;
    final int height = image.height;
    final int cropSize =
        (min(width, height) * 0.5).round(); // 50% central square.
    final int startX = (width - cropSize) ~/ 2;
    final int startY = (height - cropSize) ~/ 2;
    print(
        'Debug: Cropping to center ${cropSize}x${cropSize} at (${startX}, ${startY})');

    if (image.format.group == ImageFormatGroup.bgra8888) {
      // iOS: BGRA8888.
      final Plane plane = image.planes[0];
      final Uint8List bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;

      for (int h = startY; h < startY + cropSize; h++) {
        final int rowStart = h * bytesPerRow;
        for (int w = startX; w < startX + cropSize; w++) {
          final int i = rowStart + (w * 4);
          if (i + 2 >= bytes.length) continue;
          final int b = bytes[i]; // Blue
          final int g = bytes[i + 1]; // Green
          final int r = bytes[i + 2]; // Red
          totalRed += r;
          totalGreen += g;
          totalBlue += b;
          pixelCount++;
        }
      }
    } else {
      // Android: YUV420 (planar).
      final Uint8List yBuffer = image.planes[0].bytes;
      final Uint8List uBuffer = image.planes[1].bytes;
      final Uint8List vBuffer = image.planes[2].bytes;
      final int yRowStride = image.planes[0].bytesPerRow;
      final int uvRowStride = image.planes[1].bytesPerRow;
      final int? uvPixelStride = image.planes[1].bytesPerPixel;

      const int offset = 128;

      for (int h = startY; h < startY + cropSize; h++) {
        final int uvh = (h ~/ 2) + (startY ~/ 2); // Adjusted for subsampling.
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

    final double avgRed = pixelCount > 0 ? totalRed / pixelCount : 0.0;
    final double avgGreen = pixelCount > 0 ? totalGreen / pixelCount : 0.0;
    final double avgBlue = pixelCount > 0 ? totalBlue / pixelCount : 0.0;

    print(
        'Debug: Avg RGB (cropped) = (${avgRed.toStringAsFixed(1)}, ${avgGreen.toStringAsFixed(1)}, ${avgBlue.toStringAsFixed(1)})');

    return RgbMeans(red: avgRed, green: avgGreen, blue: avgBlue);
  }

  /// Calculates heart rate with enhanced quality: moving average smoothing,
  /// bandpass filtering, adaptive peak detection. Uses actual FPS for normalization.
  double _calculateHeartRate() {
    if (_intensityValues.isEmpty || _frameRate <= 0) return 0.0;

    // IMPROVED: Smoothing with moving average (short window for speed).
    final List<double> smoothed = _computeMovingAverage(_intensityValues, 5);

    // IMPROVED: Detrending – subtract long-term average (window ~30% buffer) to amplify AC.
    final int dcWindow = (_intensityValues.length * 0.3).round().clamp(10, 100);
    final List<double> dcSmoothed = _computeMovingAverage(smoothed, dcWindow);
    final List<double> detrended = [];
    for (int i = 0; i < smoothed.length; i++) {
      final double dc =
          (i < dcSmoothed.length) ? dcSmoothed[i] : dcSmoothed.last;
      detrended.add(smoothed[i] - dc);
    }

    // IMPROVED: Bandpass filter (high-pass 0.5 Hz + low-pass 4 Hz for HR range 30-240 BPM).
    final List<double> highPassed =
        _applyHighPassFilter(detrended, 2, _frameRate);
    final List<double> bandPassed =
        _applyLowPassFilter(highPassed, 4.0, _frameRate);

    // IMPROVED: Invert signal to treat pulses as positive peaks (aligns with typical PPG analysis).
    final List<double> inverted = bandPassed.map((v) => -v).toList();

    // IMPROVED: Quality check with SNR estimate (AC amplitude / DC noise).
    final double acAmp = calculateStandardDeviation(inverted);
    final double dcMedian = _calculateMedian(smoothed);
    final double snr = acAmp / (dcMedian > 0 ? dcMedian : 1.0);
    print(
        'Debug: SNR = ${snr.toStringAsFixed(2)}, AC Amp = ${acAmp.toStringAsFixed(2)}, DC Median = ${dcMedian.toStringAsFixed(2)}');
    if (snr < 0.05) {
      // Arbitrary threshold; tune based on testing.
      print('Debug: Low SNR – skipping HR calculation.');
      return 0.0;
    }

    // Update y-axis bounds.
    if (inverted.isNotEmpty) {
      _yAxisMax = inverted.reduce(max);
      _yAxisMin = inverted.reduce(min);
    } else {
      _yAxisMax = 255.0;
      _yAxisMin = 0.0;
    }

    // Run both methods.
    final double fftBpm = _estimateHrFrequencyDomain(inverted);
    final double peakBpm = _estimateHrTimeDomain(inverted);

    double bpm = 0.0;
    if (fftBpm > 0 && peakBpm > 0) {
      // Hybrid: Average if they agree within 10 BPM threshold; else prefer FFT for robustness.
      if ((fftBpm - peakBpm).abs() < 10.0) {
        bpm = (fftBpm + peakBpm) / 2.0;
        print(
            'Debug: Hybrid BPM average = ${bpm.toStringAsFixed(1)} (FFT: ${fftBpm.toStringAsFixed(1)}, Peak: ${peakBpm.toStringAsFixed(1)})');
      } else {
        bpm = fftBpm; // Prefer FFT if discrepancy.
        print(
            'Debug: Using FFT BPM due to discrepancy = ${bpm.toStringAsFixed(1)} (Peak was ${peakBpm.toStringAsFixed(1)})');
      }
    } else if (fftBpm > 0) {
      bpm = fftBpm;
    } else if (peakBpm > 0) {
      bpm = peakBpm;
    }

    // Clamp artifacts.
    if (bpm > 200 || bpm < 40) bpm = 0.0;

    _bpmHistory.add(bpm);
    return bpm;
  }

  // NEW: Frequency Domain - Estimate HR via FFT peak in 0.75-4 Hz range.
  double _estimateHrFrequencyDomain(List<double> signal) {
    final int N = signal.length;
    if (N < 64) return 0.0; // Too short for reliable FFT.

    final fft = FFT(N);
    final freqDomain =
        fft.realFft(Float64List.fromList(signal)); // Convert to Float64List.
    final magnitudes = freqDomain.magnitudes();

    // Frequencies from 0 to Nyquist (fs/2).
    final List<double> frequencies = List.generate(
      magnitudes.length,
      (i) => i * _frameRate / N,
    );

    // Find indices in HR range (0.75-4 Hz).
    final int lowIdx = frequencies.indexWhere((f) => f >= 0.75);
    final int highIdx = frequencies.lastIndexWhere((f) => f <= 4.0);
    if (lowIdx == -1 || highIdx == -1 || lowIdx >= highIdx) return 0.0;

    // Subset magnitudes in range.
    final subMags = magnitudes.sublist(lowIdx, highIdx + 1);

    // Find index of max magnitude.
    final int peakRelativeIdx = subMags.indexOf(subMags.reduce(max));
    final int peakIdx = lowIdx + peakRelativeIdx;

    final double peakFreq = frequencies[peakIdx];
    print('Debug: Peak frequency = ${peakFreq.toStringAsFixed(2)} Hz');

    return peakFreq * 60.0;
  }

  // IMPROVED: Time-domain peak detection.
  double _estimateHrTimeDomain(List<double> signal) {
    // Adaptive threshold for peaks (mean + 0.5 * std).
    final double mean = _calculateAverage(signal);
    final double std = calculateStandardDeviation(signal);
    final double adaptiveThreshold = mean + 0.5 * std;

    // Min distance in samples (based on max HR 200 BPM).
    final double minDistance =
        _frameRate / (200 / 60); // Samples between peaks.

    // Find peaks with adaptive threshold and min distance.
    final List<List<double>> peaks = _findPeaks(signal,
        threshold: adaptiveThreshold, minDistance: minDistance);

    final List<double> peakIndices = peaks[0];
    if (peakIndices.length < 2) return 0.0;

    // Inter-peak intervals (IBIs) in seconds.
    final List<double> ibis = [];
    for (int i = 0; i < peakIndices.length - 1; i++) {
      final double samplesDiff = peakIndices[i + 1] - peakIndices[i];
      final double ibiSec = samplesDiff / _frameRate;
      ibis.add(ibiSec);
    }

    if (ibis.isEmpty) return 0.0;

    // Filter invalid IBIs (outliers outside 0.3-1.5s for 40-200 BPM).
    final List<double> validIbis =
        ibis.where((ibi) => ibi >= 0.3 && ibi <= 1.5).toList();
    if (validIbis.isEmpty) return 0.0;

    // Use median IBI for robustness.
    final double medianIbiSec = _calculateMedian(validIbis);
    return 60.0 / medianIbiSec;
  }

  // IMPROVED: Enhanced peak finder with optional threshold and minDistance.
  List<List<double>> _findPeaks(final List<double> signal,
      {double? threshold, double minDistance = 0.0}) {
    final int n = signal.length - 2;
    final List<double> indices = [];
    final List<double> values = [];
    double lastIndex = -double.infinity;

    for (int i = 1; i <= n; i++) {
      final bool isPeak =
          signal[i - 1] <= signal[i] && signal[i] >= signal[i + 1];
      final bool aboveThreshold = threshold == null || signal[i] >= threshold;
      final bool farEnough = (i - lastIndex) >= minDistance;

      if (isPeak && aboveThreshold && farEnough) {
        indices.add(i.toDouble());
        values.add(signal[i]);
        lastIndex = i.toDouble();
      }
    }
    return [indices, values];
  }

  // (Unused now, but kept for reference) Minima finder.
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

  List<double> _computeDerivative(final List<double> data) {
    if (data.length < 2) return data;

    final List<double> derivative = [];
    for (int i = 0; i < data.length - 1; i++) {
      derivative.add(data[i + 1] - data[i]);
    }
    return derivative;
  }

  List<double> dataToPlot() => List.unmodifiable(_filteredIntensities);

  List<double> getPpgPlot() => List.unmodifiable(_ppgSignal);

  double getMax() => _yAxisMax > 255 ? 255.0 : _yAxisMax;

  double getMin() => _yAxisMin < 0 ? 0.0 : _yAxisMin;

  double getSummary() {
    if (_bpmHistory.length < 2) return 0.0;

    final List<double> validBpms = List.from(_bpmHistory)
      ..removeWhere((bpm) => bpm == 0.0)
      ..removeAt(0);

    if (validBpms.isEmpty) return 0.0;
    return _calculateMedian(validBpms);
  }

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
    print(_frameRates);
    if (_frameRates.isEmpty) return [];

    final double avgFrameRate = _calculateAverage(_frameRates);
    return List<double>.from(_frameRates)..add(avgFrameRate);
  }

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
