import 'package:camera/camera.dart';
import 'dart:math';
import 'dart:async';

class PPGAlgorithm {
  static const int minBpm = 40;
  static const int maxBpm = 180;
  static const double minFrameRate = 20.0; // Raised for reliability
  static const double bandPassLow = 0.7; // Hz, refined for adult HR
  static const double bandPassHigh = 3.0; // Hz
  static const int defaultStackSize = 150;
  static const double roiFraction = 0.5; // 50% center crop
  static const int downsampleFactor = 4; // Subsample for speed

  double yAxisMax = 110.0;
  double yAxisMin = 100.0;
  List<double> _intensityValues = [];
  double _frameRate = 0.0;
  List<int> _timestamps = [];
  List<double> _bpmTotal = [];
  List<double> _framesList = [];
  double _currentHeartRate = 0.0;
  double _smoothedHR = 0.0; // New: EMA smoothed
  int _stackSize = defaultStackSize;
  Stopwatch _stopwatch = Stopwatch(); // New: Precise timing
  List<double> _plotData = []; // New: For filtered plot
  List<double> _respiratoryRates = []; // Respiratory rate estimates
  double _currentRespiratoryRate = 0.0; // Current RR estimate

  // Calculate standard deviation
  double calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;
    final mean = calculateAverage(values);
    final sumOfSquaredDiff =
        values.fold(0.0, (sum, x) => sum + pow(x - mean, 2));
    return sqrt(sumOfSquaredDiff / values.length);
  }

  // SNR calculation for quality
  double calculateSNR(List<double> signal, double fs) {
    if (signal.length < 10) return 0.0;
    final filtered =
        _applyButterworthBandpass(signal, bandPassLow, bandPassHigh, fs);
    final signalPower = calculateAverage(filtered.map((x) => x * x).toList());
    final rawPower = calculateAverage(signal.map((x) => x * x).toList());
    return signalPower > 0
        ? 10 * log(rawPower / signalPower) / log(10)
        : 0.0; // dB
  }

  // Process camera image
  Future<void> processImage(CameraImage image) async {
    try {
      if (!_stopwatch.isRunning) _stopwatch.start();
      final currentTime = _stopwatch.elapsedMicroseconds; // μs precision
      if (_timestamps.isNotEmpty) {
        final lastTime = _timestamps.last;
        final interval = (currentTime - lastTime) / 1000.0; // ms
        if (interval > 0 && interval < 100) {
          // Ignore outliers
          final currentFrameRate = 1000.0 / interval;
          _frameRate = (_frameRate == 0)
              ? currentFrameRate
              : (_frameRate * 0.9 + currentFrameRate * 0.1);
          _framesList.add(_frameRate);
        }
      }
      _timestamps.add(currentTime);

      // Outlier removal: Clip to 3σ
      double avgIntensity = _calculateGreenIntensityROI(image);
      final median = calculateMedian(_intensityValues);
      final std = calculateStandardDeviation(_intensityValues);
      avgIntensity = avgIntensity.clamp(median - 3 * std, median + 3 * std);
      _intensityValues.add(avgIntensity);

      if (_frameRate < minFrameRate) {
        print('Warning: Low frame rate ($_frameRate fps). Skipping.');
        return;
      }

      // Overlapping window: Process every N frames, slide by 75%
      if (_intensityValues.length >= _stackSize) {
        await _processBatch(overlap: true);
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  // Improved: Green channel from YUV ROI
  double _calculateGreenIntensityROI(CameraImage image) {
    if (image.format.group != ImageFormatGroup.yuv420) {
      // Fallback for other formats, e.g., BGRA on iOS
      return _calculateFallbackIntensity(image);
    }

    final yPlane = image.planes[0];
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];

    final width = image.width ~/ downsampleFactor;
    final height = image.height ~/ downsampleFactor;
    final roiSize = (width * height * roiFraction * roiFraction).round();
    final centerX = image.width ~/ 2;
    final centerY = image.height ~/ 2;
    final roiW = (width * roiFraction).round();
    final roiH = (height * roiFraction).round();

    double totalGreen = 0.0;
    int count = 0;
    for (int dy = 0; dy < roiH && count < roiSize; dy++) {
      for (int dx = 0; dx < roiW && count < roiSize; dx++) {
        final fullX = ((centerX - roiW ~/ 2 + dx) * downsampleFactor)
            .clamp(0, image.width - 1)
            .toInt();
        final fullY = ((centerY - roiH ~/ 2 + dy) * downsampleFactor)
            .clamp(0, image.height - 1)
            .toInt();

        // Y index
        final yIndex = fullY * yPlane.bytesPerRow + fullX;
        if (yIndex >= yPlane.bytes.length) continue;

        // UV indices (subsampled)
        final uvX = fullX ~/ 2;
        final uvY = fullY ~/ 2;
        final uIndex = uvY * uPlane.bytesPerRow + uvX;
        final vIndex = uvY * vPlane.bytesPerRow + uvX; // Same for V plane

        if (uIndex < uPlane.bytes.length && vIndex < vPlane.bytes.length) {
          final yVal = yPlane.bytes[yIndex] / 255.0;
          final uVal = ((uPlane.bytes[uIndex] - 128) / 127.0).clamp(-1.0, 1.0);
          final vVal = ((vPlane.bytes[vIndex] - 128) / 127.0).clamp(-1.0, 1.0);

          // YUV to G (ITU BT.601)
          final g =
              (1.164 * yVal - 0.391 * uVal - 0.813 * vVal).clamp(0.0, 1.0) *
                  255.0;
          totalGreen += g;
          count++;
        }
      }
    }
    return count > 0 ? totalGreen / count : 0.0;
  }

  // Fallback for non-YUV (e.g., iOS BGRA)
  double _calculateFallbackIntensity(CameraImage image) {
    // For BGRA, average green channel (index 1 in each pixel)
    final plane = image.planes[0];
    double total = 0.0;
    int count = 0;
    final bytesPerPixel = plane.bytesPerPixel ?? 4;
    for (int i = 1; i < plane.bytes.length; i += bytesPerPixel) {
      // Green offset
      if (i < plane.bytes.length) {
        total += plane.bytes[i];
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  Future<void> _processBatch({bool overlap = false}) async {
    if (_intensityValues.length < 20) return;

    // Quality check: SNR
    final sqi = calculateSNR(_intensityValues, _frameRate);
    if (sqi < 6.0) {
      print('Low SQI ($sqi dB), skipping.');
      if (!overlap) {
        _intensityValues.clear();
        _timestamps.clear();
      }
      return;
    }

    // Detrend: Polynomial (linear fit) instead of mean
    final detrended = _polynomialDetrend(_intensityValues, order: 1);

    // Filter: Butterworth IIR
    final filtered = _applyButterworthBandpass(
        detrended, bandPassLow, bandPassHigh, _frameRate);

    // Median smooth
    final smoothed = _medianFilter(filtered, kernel: 3);

    // Update stack/window
    _stackSize = (_frameRate * 5).round().clamp(50, 300);
    if (overlap) {
      // Slide: Keep last 25%
      final keep = (_intensityValues.length * 0.25).round();
      _intensityValues =
          _intensityValues.sublist(_intensityValues.length - keep);
      _timestamps = _timestamps.sublist(_timestamps.length - keep);
    } else {
      _intensityValues.clear();
      _timestamps.clear();
    }
    _plotData = smoothed; // For plotting

    // HR: Hybrid time + freq (main thread, no isolate for lists)
    final timeHR = _calculateTimeDomainHR(smoothed, _frameRate);
    final freqHR = _calculateFreqDomainHR(smoothed, _frameRate);
    final estHR = (timeHR + freqHR) / 2; // Average for robustness
    _currentHeartRate = estHR.clamp(minBpm.toDouble(), maxBpm.toDouble());

    // EMA smooth
    _smoothedHR = (_smoothedHR == 0)
        ? _currentHeartRate
        : (_smoothedHR * 0.7 + _currentHeartRate * 0.3);
    _bpmTotal.add(_smoothedHR);

    // RR: Calculate respiratory rate from low-frequency component
    _currentRespiratoryRate = _calculateRespiratoryRate(smoothed, _frameRate);
    if (_currentRespiratoryRate > 0) {
      _respiratoryRates.add(_currentRespiratoryRate);
    }
  }

  // Linear detrend (least squares)
  List<double> _polynomialDetrend(List<double> signal, {int order = 1}) {
    if (signal.length < 3) return signal;
    final n = signal.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    for (int i = 0; i < n; i++) {
      final x = i.toDouble();
      sumX += x;
      sumY += signal[i];
      sumXY += x * signal[i];
      sumX2 += x * x;
    }
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    final intercept = (sumY - slope * sumX) / n;
    return List.generate(n, (i) => signal[i] - (slope * i + intercept));
  }

  // 2nd-order Butterworth bandpass (cascaded low+high pass)
  List<double> _applyButterworthBandpass(
      List<double> signal, double lowCut, double highCut, double fs) {
    final nyquist = fs / 2;
    final lowNorm = lowCut / nyquist;
    final highNorm = highCut / nyquist;

    // Low-pass Butterworth coeffs (2nd order)
    final wcLow = tan(pi * highNorm);
    final aLow = 1 + sqrt(2) * wcLow + wcLow * wcLow;
    final b0Low = wcLow * wcLow / aLow;
    final b1Low = 2 * b0Low;
    final b2Low = b0Low;
    final a1Low = (2 * (wcLow * wcLow - 1)) / aLow;
    final a2Low = (1 - sqrt(2) * wcLow + wcLow * wcLow) / aLow;

    // High-pass (transform low-pass)
    final wcHigh = tan(pi * lowNorm);
    final aHigh = 1 + sqrt(2) * wcHigh + wcHigh * wcHigh;
    final b0High = 1 / aHigh;
    final b1High = -2 * b0High;
    final b2High = b0High;
    final a1High = (2 * (wcHigh * wcHigh - 1)) / aHigh;
    final a2High = (1 - sqrt(2) * wcHigh + wcHigh * wcHigh) / aHigh;

    // Apply low-pass
    var lowPass = _iirFilter(signal, [b0Low, b1Low, b2Low], [1, a1Low, a2Low]);
    // Apply high-pass on low-pass output
    var filtered =
        _iirFilter(lowPass, [b0High, b1High, b2High], [1, a1High, a2High]);
    return filtered;
  }

  // Generic IIR filter
  List<double> _iirFilter(List<double> x, List<double> b, List<double> a) {
    final y = List<double>.filled(x.length, 0.0);
    final bufSize = b.length;
    final xBuf = List<double>.filled(bufSize, 0.0);
    final yBuf = List<double>.filled(bufSize - 1, 0.0);

    for (int i = 0; i < x.length; i++) {
      xBuf.insert(0, x[i]);
      xBuf.removeLast();

      double sum = 0.0;
      for (int j = 0; j < bufSize; j++) {
        sum += b[j] * xBuf[j];
      }
      for (int j = 0; j < bufSize - 1; j++) {
        sum -= a[j + 1] * yBuf[j];
      }
      y[i] = sum / a[0];
      yBuf.insert(0, y[i]);
      yBuf.removeLast();
    }
    return y;
  }

  // Median filter
  List<double> _medianFilter(List<double> signal, {int kernel = 3}) {
    if (signal.length < kernel) return signal;
    final result = <double>[];
    for (int i = 0; i < signal.length; i++) {
      final start = (i - kernel ~/ 2).clamp(0, signal.length - 1);
      final end = (start + kernel).clamp(0, signal.length);
      final window = signal.sublist(start, end)..sort();
      result.add(window[window.length ~/ 2]);
    }
    return result;
  }

  // Moving average (for envelope smoothing)
  List<double> _movingAverage(List<double> signal, int windowSize) {
    if (signal.isEmpty) return [];
    if (windowSize <= 1) return List<double>.from(signal);
    final result = <double>[];
    double sum = 0.0;
    final queue = <double>[];
    for (int i = 0; i < signal.length; i++) {
      sum += signal[i];
      queue.add(signal[i]);
      if (queue.length > windowSize) {
        sum -= queue.removeAt(0);
      }
      result.add(sum / queue.length);
    }
    return result;
  }

  // Time-domain HR (improved peaks)
  double _calculateTimeDomainHR(List<double> signal, double fs) {
    final avg = calculateAverage(signal);
    final std = calculateStandardDeviation(signal);
    final threshold = avg + 0.5 * std; // Adaptive
    final prominence = 0.2 * std; // Min height diff

    final peaks = _enhancedPeakFinder(signal,
        threshold: threshold,
        prominence: prominence,
        refractory: (60 / maxBpm) * fs);
    if (peaks.length < 2) return 0.0;

    final intervals = <double>[];
    for (int i = 0; i < peaks.length - 1; i++) {
      final diff = peaks[i + 1] - peaks[i];
      if (diff > (60 / maxBpm) * fs && diff < (60 / minBpm) * fs) {
        // Valid range
        intervals.add(diff);
      }
    }
    if (intervals.isEmpty) return 0.0;
    final avgInterval = calculateAverage(intervals);
    return 60.0 * fs / avgInterval;
  }

  // Enhanced peak finder with refractory and prominence
  List<double> _enhancedPeakFinder(List<double> signal,
      {required double threshold,
      required double prominence,
      required double refractory}) {
    final peaks = <double>[];
    var lastPeak = -refractory;
    for (int i = 1; i < signal.length - 1; i++) {
      final localAvg = i >= 5 && i < signal.length - 5
          ? calculateAverage(signal.sublist(i - 5, i + 6))
          : threshold;
      if (signal[i] > threshold &&
          signal[i] > signal[i - 1] &&
          signal[i] > signal[i + 1] &&
          (i - lastPeak) > refractory &&
          (signal[i] - localAvg) > prominence) {
        peaks.add(i.toDouble());
        lastPeak = i.toDouble();
      }
    }
    return peaks;
  }

  // Freq-domain: Simple DFT for dominant freq
  double _calculateFreqDomainHR(List<double> signal, double fs) {
    final n = signal.length;
    if (n < 4) return 0.0;
    final fft = _dft(signal); // Real part magnitudes
    final freqRes = fs / n;
    final minFreq = bandPassLow;
    final maxFreq = bandPassHigh;
    double maxPower = 0.0;
    double domFreq = 0.0;
    for (int k = 1; k < n ~/ 2; k++) {
      final f = k * freqRes;
      if (f >= minFreq && f <= maxFreq) {
        final power = fft[k] * fft[k]; // Power spectrum
        if (power > maxPower) {
          maxPower = power;
          domFreq = f;
        }
      }
    }
    return domFreq * 60.0; // BPM
  }

  // Simple DFT (real input, real output for magnitudes)
  List<double> _dft(List<double> signal) {
    final n = signal.length;
    final result = List<double>.filled(n, 0.0);
    for (int k = 0; k < n; k++) {
      double re = 0.0;
      for (int j = 0; j < n; j++) {
        re += signal[j] * cos(2 * pi * k * j / n);
      }
      result[k] = re / n; // Normalized
    }
    return result;
  }

  // Calculate respiratory rate from amplitude envelope
  // Method: extract pulse band -> envelope -> low-pass -> peak detection
  double _calculateRespiratoryRate(List<double> signal, double fs) {
    if (signal.length < (fs * 8).round()) {
      print('RR: Signal too short: ${signal.length}');
      return 0.0;
    }

    // 1) Isolate pulse component (heart band)
    final pulse =
        _applyButterworthBandpass(signal, bandPassLow, bandPassHigh, fs);
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
    final envAvg = calculateAverage(envelope);
    print('RR: Envelope - min: $envMin, max: $envMax, avg: $envAvg');

    // 3) Respiratory modulation band (0.05-0.5 Hz)
    final resp = _applyButterworthBandpass(envSmooth, 0.05, 0.5, fs);
    if (resp.length < 8) {
      print('RR: Resp band too short: ${resp.length}');
      return 0.0;
    }

    final avg = calculateAverage(resp);
    final std = calculateStandardDeviation(resp);
    print('RR: Resp signal - avg: $avg, std: $std');
    if (std < 0.0005) {
      print('RR: Std too low: $std');
      return 0.0;
    }

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
    print(
        'RR: Calculated rate: $respiratoryRate (clamped: ${respiratoryRate.clamp(6.0, 30.0)})');
    return respiratoryRate.clamp(6.0, 30.0);
  }

  double calculateAverage(List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double calculateMedian(List<double> values) {
    if (values.isEmpty) return 0.0;
    final sorted = List.from(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length % 2 == 1
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  // Getters (improved)
  double getCurrentHeartRate() => _smoothedHR; // Use smoothed
  double getCurrentRespiratoryRate() => _currentRespiratoryRate;
  List<double> getRespiratoryRates() =>
      List.from(_respiratoryRates); // For summary stats
  List<double> getIntensityValues() => List.from(_intensityValues);
  List<double> getPPGplot() => List.from(_plotData.isNotEmpty
      ? _plotData
      : _intensityValues); // Filtered for smooth plot
  double getMax() => yAxisMax > 120 ? 110 : yAxisMax;
  double getMin() => yAxisMin < 90 ? 100 : yAxisMin;
  double getSummary() {
    if (_bpmTotal.length < 3) return _smoothedHR;
    final recent = _bpmTotal.sublist(max(0, _bpmTotal.length - 3));
    return calculateMedian(recent);
  }

  List<double> get_Frames() {
    final avg = _framesList.isEmpty ? 0.0 : calculateAverage(_framesList);
    return List.from(_framesList)..add(avg);
  }

  // New: Get SQI for UI feedback
  double getSQI() => _intensityValues.isNotEmpty
      ? calculateSNR(_intensityValues, _frameRate)
      : 0.0;

  List<double> data_to_plot() {
    return getPPGplot();
  }
}
