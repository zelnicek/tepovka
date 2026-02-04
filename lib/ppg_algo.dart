import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart'; // NEW: Frequency Domain - Import FFT library
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

  /// EMA-smoothed heart rate for stability
  double _smoothedHeartRate = 0.0;
  static const double _emaAlpha =
      0.3; // EMA factor (0-1, lower = more smoothing)

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

      // Compute respiratory rate from PPG amplitude envelope
      _currentRespiratoryRate =
          _calculateRespiratoryRate(_intensityValues, _frameRate);
      if (_currentRespiratoryRate > 0) {
        _respiratoryRates.add(_currentRespiratoryRate);
      }

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
    if (_frameRate < 20.0) return 0.0; // Too low FPS for reliable HR

    // Adaptive smoothing - longer window to eliminate dicrotic notch (~250 ms)
    final int smoothWindow = (_frameRate * 0.25).round().clamp(5, 25);
    final List<double> smoothed =
        _computeMovingAverage(_intensityValues, smoothWindow);
    // Extra pass to further smooth out dicrotic notch
    final List<double> extraSmoothed = _computeMovingAverage(
        smoothed, (_frameRate * 0.12).round().clamp(3, 10));

    // Detrending – subtract long-term average (~1.5 s window)
    final int dcWindow = (_frameRate * 1.5).round().clamp(20, 150);
    final List<double> dcSmoothed =
        _computeMovingAverage(extraSmoothed, dcWindow);
    final List<double> detrended = [];
    for (int i = 0; i < extraSmoothed.length; i++) {
      final double dc =
          (i < dcSmoothed.length) ? dcSmoothed[i] : dcSmoothed.last;
      detrended.add(extraSmoothed[i] - dc);
    }

    // Bandpass filter for HR range (0.7–3.5 Hz = 42–210 BPM)
    final List<double> bandPassed =
        _applyButterworthBandpass(detrended, 0.7, 3.5, _frameRate);

    // Normalize & invert so pulses are positive peaks
    final List<double> normalized = _zScore(bandPassed);
    final List<double> inverted = normalized.map((v) => -v).toList();

    // Quality check with signal variability proxy
    // Use max of red/green for SNR since we may fallback to red
    final double effectiveRed = _lastAverageRed ?? 100.0;
    final double effectiveGreen = _lastAverageGreen ?? 1.0;
    final double effectiveIntensity = max(effectiveRed, effectiveGreen);
    final double signalStd = calculateStandardDeviation(bandPassed);
    final double snrEstimate =
        signalStd / (effectiveIntensity > 0 ? effectiveIntensity / 100.0 : 1.0);
    print(
        'Debug: SNR = ${snrEstimate.toStringAsFixed(2)}, Signal STD = ${signalStd.toStringAsFixed(3)}, Intensity = ${effectiveIntensity.toStringAsFixed(1)}');
    if (snrEstimate < 0.01) {
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

    // Apply EMA smoothing for stability
    if (bpm > 0) {
      if (_smoothedHeartRate == 0.0) {
        _smoothedHeartRate = bpm;
      } else {
        _smoothedHeartRate =
            (_smoothedHeartRate * (1 - _emaAlpha)) + (bpm * _emaAlpha);
      }
    }
    print(
        'Debug: Raw BPM = ${bpm.toStringAsFixed(1)}, EMA-smoothed = ${_smoothedHeartRate.toStringAsFixed(1)}');

    _bpmHistory.add(_smoothedHeartRate);
    return _smoothedHeartRate;
  }

  // NEW: Frequency Domain - Estimate HR via FFT peak in 0.7-3.5 Hz range.
  double _estimateHrFrequencyDomain(List<double> signal) {
    final int N = signal.length;
    if (N < 64) return 0.0; // Too short for reliable FFT.

    final List<double> windowed = _applyHammingWindow(signal);

    final fft = FFT(N);
    final freqDomain =
        fft.realFft(Float64List.fromList(windowed)); // Convert to Float64List.
    final magnitudes = freqDomain.magnitudes();

    // Frequencies from 0 to Nyquist (fs/2).
    final List<double> frequencies = List.generate(
      magnitudes.length,
      (i) => i * _frameRate / N,
    );

    // Find indices in HR range (0.7-3.5 Hz).
    final int lowIdx = frequencies.indexWhere((f) => f >= 0.7);
    final int highIdx = frequencies.lastIndexWhere((f) => f <= 3.5);
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
    // Adaptive threshold for peaks (mean + 0.4 * std - more sensitive).
    final double mean = _calculateAverage(signal);
    final double std = calculateStandardDeviation(signal);
    final double adaptiveThreshold = mean + 0.4 * std;

    // Higher min distance to reject dicrotic notch (~0.4s to block second peak)
    final double minDistance =
        (_frameRate * 0.4).clamp(_frameRate * 0.3, _frameRate * 0.8);

    // Higher prominence requirement (0.5 * std) to filter low-amplitude artifacts
    final double prominence = 0.5 * std;
    final int promWindow = (_frameRate * 0.3).round().clamp(5, 40);

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
      final double ibiSec = samplesDiff / _frameRate;
      ibis.add(ibiSec);
    }

    if (ibis.isEmpty) return 0.0;

    // Filter invalid IBIs (outliers outside 0.3-1.5s for 40-200 BPM).
    final List<double> validIbis =
        ibis.where((ibi) => ibi >= 0.3 && ibi <= 1.5).toList();
    if (validIbis.isEmpty) return 0.0;

    // Store valid IBIs for full-measurement HRV calculation
    _allIbiIntervals.addAll(validIbis);
    print(
        'Debug: Added ${validIbis.length} IBIs, total now: ${_allIbiIntervals.length}');

    // Use median IBI for robustness.
    final double medianIbiSec = _calculateMedian(validIbis);
    return 60.0 / medianIbiSec;
  }

  // IMPROVED: Enhanced peak finder with optional threshold, minDistance, and prominence.
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

    // Calculate HRV from all accumulated IBI intervals
    _calculateFinalHrv();

    return _calculateMedian(validBpms);
  }

  void _calculateFinalHrv() {
    if (_allIbiIntervals.length < 2) {
      print('HRV: Not enough IBIs (${_allIbiIntervals.length})');
      return;
    }

    print(
        'Debug: Calculating HRV from ${_allIbiIntervals.length} IBI intervals');
    print(
        'Debug: IBI range: ${_allIbiIntervals.reduce(min).toStringAsFixed(3)}s - ${_allIbiIntervals.reduce(max).toStringAsFixed(3)}s');

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

  /// Reset algorithm state for new measurement
  void reset() {
    _intensityValues.clear();
    _filteredIntensities.clear();
    _derivativeValues.clear();
    _ppgSignal.clear();
    _timestamps.clear();
    _bpmHistory.clear();
    _frameRates.clear();
    _respiratoryRates.clear();
    _hrvValues.clear();
    _allIbiIntervals.clear();
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
    print('PPGAlgorithm: Reset for new measurement');
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
    print(_frameRates);
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
  double _calculateRespiratoryRate(List<double> signal, double fs) {
    if (signal.length < (fs * 8).round()) {
      print('RR: Signal too short: ${signal.length}');
      return 0.0;
    }

    // 1) Isolate pulse component (0.7-3.0 Hz heart band)
    final pulse = _applyButterworthBandpass(signal, 0.7, 3.0, fs);
    if (pulse.length < 8) {
      print('RR: Pulse band too short: ${pulse.length}');
      return 0.0;
    }

    // 2) Envelope via absolute value + moving average (~1s)
    final envelope = pulse.map((v) => v.abs()).toList();
    final envSmooth =
        _movingAverage(envelope, (fs * 1.0).round().clamp(5, 120));

    final envMin = envelope.isEmpty ? 0.0 : envelope.reduce(min);
    final envMax = envelope.isEmpty ? 0.0 : envelope.reduce(max);
    final envAvg = _calculateAverage(envelope);
    print('RR: Envelope - min: $envMin, max: $envMax, avg: $envAvg');

    // 3) Respiratory modulation band (0.05-0.5 Hz = 3-30 breaths/min)
    final resp = _applyButterworthBandpass(envSmooth, 0.05, 0.5, fs);
    if (resp.length < 8) {
      print('RR: Resp band too short: ${resp.length}');
      return 0.0;
    }

    final avg = _calculateAverage(resp);
    final std = calculateStandardDeviation(resp);
    print('RR: Resp signal - avg: $avg, std: $std');
    if (std < 0.0005) {
      print('RR: Std too low: $std');
      return 0.0;
    }

    // 4) Peak detection with threshold
    final threshold = avg + 0.2 * std;
    print('RR: Threshold: $threshold');
    final peaks = <int>[];
    int lastIndex = -(fs * 2).round(); // refractory ~2s

    for (int i = 1; i < resp.length - 1; i++) {
      final isPeak = resp[i - 1] < resp[i] && resp[i] > resp[i + 1];
      final aboveThreshold = resp[i] > threshold;
      final farEnough = (i - lastIndex) >= (fs * 1.5).round();
      if (isPeak && aboveThreshold && farEnough) {
        peaks.add(i);
        lastIndex = i;
      }
    }

    print('RR: Peaks detected: ${peaks.length}');
    if (peaks.length < 2) {
      print('RR: Too few peaks: ${peaks.length}');
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

    print('RR: Valid intervals: $validIntervals / ${peaks.length - 1}');
    if (validIntervals == 0) {
      print('RR: No valid intervals');
      return 0.0;
    }

    final avgInterval = totalInterval / validIntervals;
    final respiratoryRate = 60.0 / avgInterval;
    final clampedRR = respiratoryRate.clamp(6.0, 30.0);
    print('RR: Calculated rate: $respiratoryRate (clamped: $clampedRR)');

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
    print(
        'RR: Raw = ${clampedRR.toStringAsFixed(2)}, EMA-smoothed = ${_smoothedRespiratoryRate.toStringAsFixed(2)}');

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
