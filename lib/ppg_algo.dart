import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:tepovka/elements/spo2_algorithm.dart';
import 'package:tepovka/elements/channel_clipping.dart';
import 'package:tepovka/elements/ppg_analysis_worker.dart';

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
  double get currentBpmSnrScore => _currentBpmSnrScore;
  double get currentBpmHarmonicScore => _currentBpmHarmonicScore;
  double get currentBpmAutocorrScore => _currentBpmAutocorrScore;
  double _currentBpmSnrScore = 0.0;
  double _currentBpmHarmonicScore = 0.0;
  double _currentBpmAutocorrScore = 0.0;

  /// Last computed RGB means for quality analysis.
  double? _lastAverageGreen;
  double? _lastAverageRed;
  double? _lastAverageBlue;

  /// Raw RGB samples captured for export.
  final List<RgbMeans> _rawRgbSamples = [];

  /// Přepálené pixely za celý záznam. Nuluje se na začátku záznamu (viz
  /// [resetRecordingClipping]), aby se nezapočítal odpočet, během kterého se
  /// expozice teprve dolaďuje.
  final ChannelClipping recordingClipping = ChannelClipping();

  /// Přepálené pixely od posledního [takeClipWindow]; podle nich se před
  /// záznamem ladí expozice.
  final ChannelClipping _clipWindow = ChannelClipping();

  void resetRecordingClipping() => recordingClipping.reset();

  /// Vrátí statistiku přepálení od posledního volání a začne počítat znovu.
  ChannelClipping takeClipWindow() {
    final window = _clipWindow.copy();
    _clipWindow.reset();
    return window;
  }

  // Okna se odvozuji z casu, ne z poctu vzorku. Kdyz se zvedne snimkovaci
  // frekvence, musi analyzovat stejne dlouhy usek signalu - jinak by se
  // s dvojnasobnym fps o polovinu zkratilo okno FFT a rozliseni v bpm by se
  // zhorsilo na dvojnasobek. Merenim 2026 se ukazalo, ze skutecne fps kolisa
  // podle telefonu a osvetleni, takze pevne pocty vzorku nedavaly smysl ani
  // predtim.

  /// Delka zobrazovaciho bufferu v sekundach.
  static const double _displayBufferSeconds = 7.0;

  /// Delka okna pro analyzu HR a dechu. Delsi okno = pouzitelne frekvencni
  /// rozliseni FFT; drivejsi 4s okno bylo hlavni pricinou skakani BPM.
  static const double _analysisWindowSeconds = 8.5;

  /// Nejkratsi okno, ktere analyza prijme, aby kratka mereni neco vratila
  /// jeste nez se buffer naplni.
  static const double _minAnalysisWindowSeconds = 4.0;

  /// Jak casto se analyza opakuje.
  static const double _analysisIntervalSeconds = 1.0;

  /// Okno pro dechovou frekvenci. Dech je kolem 0,2 Hz, takze v 8,5s okne pro
  /// tep jsou sotva dva cykly — z toho frekvenci urcit nejde. 40 s dava pri
  /// 15 dechech/min asi deset cyklu.
  static const double _respirationWindowSeconds = 40.0;

  /// Snimkovaci frekvence pouzita pro prepocet oken. Nez ji zmerime, drzi se
  /// nominalnich 30 Hz.
  double get _windowFps {
    final double measured = measuredFrameRate;
    return (measured >= 5.0 && measured <= 240.0) ? measured : 30.0;
  }

  int get _displayBufferSize =>
      (_displayBufferSeconds * _windowFps).round().clamp(60, 4000);
  int get _analysisWindowSize =>
      (_analysisWindowSeconds * _windowFps).round().clamp(64, 4096);
  int get _minAnalysisWindowSize =>
      (_minAnalysisWindowSeconds * _windowFps).round().clamp(32, 2048);
  int get _analysisIntervalSamples =>
      (_analysisIntervalSeconds * _windowFps).round().clamp(5, 240);
  int get _respirationWindowSize =>
      (_respirationWindowSeconds * _windowFps).round().clamp(256, 8192);

  /// Kolik vzorku se drzi v bufferu: dost pro dechove okno i pro to, aby se
  /// analyza tepu mela o co oprit.
  int get _retainedSamples =>
      max(_analysisWindowSize * 2, _respirationWindowSize + _analysisIntervalSamples);

  /// Total samples ingested since the last reset. Used both as a monotonic
  /// clock for throttling and to map window-local peak indices to absolute
  /// positions (so overlapping analysis windows cannot emit duplicate IBIs).
  int _sampleCount = 0;
  int get sampleCount => _sampleCount;

  /// Absolute (fractional) sample position of the last peak that produced an
  /// IBI. Fractional because peak positions are parabolically interpolated.
  double _lastPeakAbsPosition = -1.0;

  /// Frames processed since last processing.
  int _framesProcessedSinceLastUpdate = 0;

  /// Counts completed analysis runs; used to stagger HR / RR / HRV.
  int _analysisTick = 0;

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

  /// NLMS motion reference from the accelerometer.
  double _latestMotionReference = 0.0;
  bool _hasMotionReference = false;
  double _nlmsWeight = 0.0;
  static const double _nlmsStepSize = 0.05;
  static const double _nlmsEpsilon = 1e-2;

  /// Slow baselines used to strip DC before adaptive filtering.
  /// Alpha 0.05 at ~30 FPS is a ~0.25 Hz corner, safely below the 0.7 Hz
  /// lower edge of the heart-rate band, so the pulse itself is preserved.
  static const double _baselineAlpha = 0.05;

  /// Below this reference amplitude the phone is effectively still and the
  /// NLMS update would be dominated by its own regulariser.
  static const double _motionDeadband = 0.15;
  double _signalBaseline = 0.0;
  bool _hasSignalBaseline = false;
  double _motionBaseline = 0.0;

  /// Display smoothing buffer for extra stability in plot
  final List<double> _displayBuffer = [];
  static const int _displaySmoothWindow =
      7; // Moving average window (7 samples)

  /// List of frame rates for analysis.
  final List<double> _frameRates = [];

  /// Respiratory rate estimates.
  final List<double> _respiratoryRates = [];

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

  /// SpO2 estimator (smartphone approximation).
  final SpO2Algorithm _spo2Algorithm = SpO2Algorithm();

  /// Background isolate running the HR / respiration pipeline.
  late final PpgAnalysisWorker _worker = PpgAnalysisWorker()
    ..onResult = _applyAnalysisResult;

  /// Applies a result that came back from the worker. Runs on this isolate, so
  /// it must stay cheap — the expensive part already happened elsewhere.
  void _applyAnalysisResult(PpgAnalysisResult result) {
    _smoothedHeartRate = result.smoothedHeartRate;
    _currentHeartRate = _smoothedHeartRate;
    if (_smoothedHeartRate > 0) {
      _bpmHistory.add(_smoothedHeartRate);
    }
    _currentBpmConfidence = result.confidence;
    _currentBpmSnrScore = result.snrScore;
    _currentBpmHarmonicScore = result.harmonicScore;
    _currentBpmAutocorrScore = result.autocorrScore;
    _lastPeakAbsPosition = result.lastPeakAbsPosition;

    if (result.newIbis.isNotEmpty) {
      _allIbiIntervals.addAll(result.newIbis);
      _updateContinuousHrv();
    }

    if (result.respiratoryRate > 0) {
      _smoothedRespiratoryRate = _smoothedRespiratoryRate == 0.0
          ? result.respiratoryRate
          : (_smoothedRespiratoryRate * (1 - _emaAlpha)) +
              (result.respiratoryRate * _emaAlpha);
      _respiratoryRates.add(_smoothedRespiratoryRate);
    }
  }

  /// Spawns the analysis isolate ahead of time. Without this the spawn lands on
  /// the first analysis run — mid-measurement — and costs a dropped frame.
  void warmUp() => _worker.warmUp();

  /// Shuts down the analysis isolate. Call when the algorithm is no longer used.
  void dispose() => _worker.dispose();

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
    final RgbMeans rgbMeans = _calculateRgbMeans(image);
    _processRgbMeans(rgbMeans);
  }

  /// Processes an already-extracted RGB sample.
  /// This is used by any non-camera frame source that feeds the same PPG pipeline.
  void processRgbSample({
    required double red,
    required double green,
    required double blue,
  }) {
    _processRgbMeans(RgbMeans(red: red, green: green, blue: blue));
  }

  /// Updates the accelerometer reference used by the NLMS motion canceller.
  void processAccelerometerSample({
    required double x,
    required double y,
    required double z,
  }) {
    final double magnitude = sqrt(x * x + y * y + z * z);
    _latestMotionReference = magnitude;
    _hasMotionReference = true;
  }

  void _processRgbMeans(final RgbMeans rgbMeans) {
    final int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (_timestamps.isNotEmpty) {
      final int intervalMs = currentTime - _timestamps.last;
      if (intervalMs > 0) {
        final double currentFps = 1000.0 / intervalMs;
        _frameRate =
            _frameRate == 0.0 ? currentFps : (_frameRate + currentFps) / 2;
      }
    }
    _timestamps.add(currentTime);

    _lastAverageGreen = rgbMeans.green;
    _lastAverageRed = rgbMeans.red;
    _lastAverageBlue = rgbMeans.blue;
    _rawRgbSamples.add(rgbMeans);
    _spo2Algorithm.addSample(rgbMeans.red, rgbMeans.green);

    double primarySignal = rgbMeans.green;
    if (primarySignal < 10.0) {
      primarySignal = rgbMeans.red;
    }

    final double motionCancelledSignal =
        _applyNlmsMotionCancellation(primarySignal);

    final double motionScore =
        _detectMotionArtifacts(motionCancelledSignal, rgbMeans);
    if (_motionArtifactScores.length > 50) {
      _motionArtifactScores.removeAt(0);
    }
    _motionArtifactScores.add(motionScore);

    _intensityValues.add(motionCancelledSignal);
    _ppgSignal.add(motionCancelledSignal);
    _fullRecordBuffer.add(motionCancelledSignal);
    _sampleCount++;

    _filteredIntensities.add(_processRawSignal(motionCancelledSignal));

    if (_filteredIntensities.length > _displayBufferSize) {
      final int removeCount = _filteredIntensities.length - _displayBufferSize;
      _filteredIntensities.removeRange(0, removeCount);
    }

    _framesProcessedSinceLastUpdate++;

    if (_framesProcessedSinceLastUpdate >= _analysisIntervalSamples &&
        _intensityValues.length >= _minAnalysisWindowSize) {
      _framesProcessedSinceLastUpdate = 0;

      // Grow the window up to _analysisWindowSize as data becomes available.
      final int windowSize = min(_intensityValues.length, _analysisWindowSize);
      final List<double> analysisWindow =
          _intensityValues.sublist(_intensityValues.length - windowSize);

      _localFrameRate = _calculateLocalFrameRate();
      if (_localFrameRate >= 15.0) {
        _frameRates.add(_localFrameRate);
        _analysisTick++;

        // Hand the window to the background isolate. Respiration is staggered
        // onto every third run because it roughly doubles the cost and changes
        // far too slowly to justify running it every second.
        // Respiration gets its own, much longer window and only once enough
        // of it has accumulated; before that it reports nothing rather than a
        // number fitted to two breathing cycles.
        final bool wantRespiration = _analysisTick % 3 == 1 &&
            _intensityValues.length >= _respirationWindowSize;
        _worker.submit(PpgAnalysisRequest(
          window: Float64List.fromList(analysisWindow),
          frameRate: _localFrameRate,
          absBase: _sampleCount - windowSize,
          lastPeakAbsPosition: _lastPeakAbsPosition,
          smoothedHeartRate: _smoothedHeartRate,
          computeRespiration: wantRespiration,
          respirationWindow: wantRespiration
              ? Float64List.fromList(_intensityValues
                  .sublist(_intensityValues.length - _respirationWindowSize))
              : null,
        ));
      }

      if (_intensityValues.length > _retainedSamples) {
        final removeCount = _intensityValues.length - _retainedSamples;
        _intensityValues.removeRange(0, removeCount);
        _timestamps.removeRange(0, min(removeCount, _timestamps.length));
        _ppgSignal.removeRange(0, min(removeCount, _ppgSignal.length));
      }
    }
  }

  /// Process a single raw sample with strong smoothing for stable display
  /// Uses exponential moving average + display buffer smoothing
  double _processRawSignal(double rawSample) {
    if (_intensityValues.isEmpty) {
      _displayBuffer.add(rawSample);
      return rawSample;
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

    return displaySmoothed;
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

  /// Simple one-tap NLMS motion canceller driven by accelerometer magnitude.
  ///
  /// Both the PPG sample and the accelerometer reference are high-passed first.
  /// Subtracting a weighted reference straight from the raw (DC-dominated)
  /// channel mean forced the weight to chase the DC level, and with a step size
  /// of 0.05 that adaptation sits right inside the 0.7-3.5 Hz pulse band —
  /// i.e. the "motion canceller" was cancelling the heartbeat. The DC level is
  /// added back on the way out so downstream intensity checks still see
  /// camera-scale values.
  double _applyNlmsMotionCancellation(double sample) {
    if (!_hasSignalBaseline) {
      _signalBaseline = sample;
      _hasSignalBaseline = true;
    } else {
      _signalBaseline += _baselineAlpha * (sample - _signalBaseline);
    }

    if (!_hasMotionReference) return sample;

    _motionBaseline +=
        _baselineAlpha * (_latestMotionReference - _motionBaseline);
    final double reference = _latestMotionReference - _motionBaseline;

    // Phone is still: leave the signal untouched rather than adapting on noise.
    if (reference.abs() < _motionDeadband) return sample;

    final double ac = sample - _signalBaseline;
    final double estimate = _nlmsWeight * reference;
    final double error = ac - estimate;
    final double norm = _nlmsEpsilon + reference * reference;

    _nlmsWeight += (_nlmsStepSize * error * reference) / norm;
    _nlmsWeight = _nlmsWeight.clamp(-50.0, 50.0).toDouble();

    return _signalBaseline + error;
  }

  /// Calculate LOCAL frame rate over the current analysis window only, so the
  /// rate used for BPM matches the samples actually being analysed.
  double _calculateLocalFrameRate() {
    if (_timestamps.length < 2) return 0.0;

    final int startIndex = max(0, _timestamps.length - _analysisWindowSize);
    final int timeDiff = _timestamps.last - _timestamps[startIndex];
    if (timeDiff <= 0) return 0.0;

    final int frameCount = _timestamps.length - 1 - startIndex;
    return (frameCount * 1000.0) / timeDiff;
  }

  /// Measured capture rate in FPS (0 until enough frames have arrived).
  double get measuredFrameRate =>
      _localFrameRate > 0 ? _localFrameRate : _frameRate;

  /// Target number of pixels actually read per frame.
  /// The ROI mean converges long before this many samples, so reading more only
  /// burns UI-isolate time. A stride is derived from the real frame size so the
  /// per-frame cost stays constant no matter what resolution the camera hands us.
  static const int _roiSampleTarget = 1600;

  /// Calculates mean intensities for R, G, B channels with optimized ROI.
  /// Crops to center frame (50% size) to focus on finger contact area,
  /// then subsamples that ROI on a fixed grid.
  RgbMeans _calculateRgbMeans(final CameraImage image) {
    int totalRed = 0, totalGreen = 0, totalBlue = 0;
    int pixelCount = 0;
    int clippedRed = 0, clippedGreen = 0, clippedBlue = 0;
    const int clipLevel = ChannelClipping.level;

    final int width = image.width;
    final int height = image.height;
    if (width <= 0 || height <= 0) {
      return const RgbMeans(red: 0.0, green: 0.0, blue: 0.0);
    }

    // Use center 50% of image for better finger coverage
    final int cropSize = (min(width, height) * 0.5).round();
    if (cropSize < 2) return const RgbMeans(red: 0.0, green: 0.0, blue: 0.0);
    final int startX = (width - cropSize) ~/ 2;
    final int startY = (height - cropSize) ~/ 2;
    final int endX = startX + cropSize;
    final int endY = startY + cropSize;

    // Grid stride: cropSize/stride squared samples ~= _roiSampleTarget.
    final int stride =
        max(1, (cropSize / sqrt(_roiSampleTarget.toDouble())).floor());

    if (image.format.group == ImageFormatGroup.bgra8888) {
      // iOS: BGRA8888
      final Plane plane = image.planes[0];
      final Uint8List bytes = plane.bytes;
      final int bytesPerRow = plane.bytesPerRow;
      final int maxIndex = bytes.length - 3;

      for (int h = startY; h < endY; h += stride) {
        final int rowStart = h * bytesPerRow;
        for (int w = startX; w < endX; w += stride) {
          final int i = rowStart + (w << 2);
          if (i > maxIndex) break;
          final int b = bytes[i];
          final int g = bytes[i + 1];
          final int r = bytes[i + 2];
          totalBlue += b;
          totalGreen += g;
          totalRed += r;
          if (r >= clipLevel) clippedRed++;
          if (g >= clipLevel) clippedGreen++;
          if (b >= clipLevel) clippedBlue++;
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
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;
      final int uvMaxIndex = min(uBuffer.length, vBuffer.length) - 1;
      final int yMaxIndex = yBuffer.length - 1;

      const int offset = 128;

      for (int h = startY; h < endY; h += stride) {
        final int yRowStart = h * yRowStride;
        final int uvRowStart = (h >> 1) * uvRowStride;
        for (int w = startX; w < endX; w += stride) {
          final int yIndex = yRowStart + w;
          if (yIndex > yMaxIndex) break;
          final int uvIndex = uvRowStart + uvPixelStride * (w >> 1);
          if (uvIndex > uvMaxIndex) break;
          final int y = yBuffer[yIndex];
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
          if (r >= clipLevel) clippedRed++;
          if (g >= clipLevel) clippedGreen++;
          if (b >= clipLevel) clippedBlue++;
          pixelCount++;
        }
      }
    }

    if (pixelCount == 0) {
      return const RgbMeans(red: 0.0, green: 0.0, blue: 0.0);
    }
    // Přepálení se počítá tady, protože jen tady jsou vidět jednotlivé
    // pixely; průměr ROI ho neprozradí, dokud není přepálená většina.
    recordingClipping.addFrame(
        samples: pixelCount,
        red: clippedRed,
        green: clippedGreen,
        blue: clippedBlue);
    _clipWindow.addFrame(
        samples: pixelCount,
        red: clippedRed,
        green: clippedGreen,
        blue: clippedBlue);
    return RgbMeans(
      red: totalRed / pixelCount,
      green: totalGreen / pixelCount,
      blue: totalBlue / pixelCount,
    );
  }

  double getCurrentHeartRate() => _currentHeartRate;

  double getCurrentRespiratoryRate() => _smoothedRespiratoryRate;

  double getSdnn() => _currentSdnn;

  double getRmssd() => _currentRmssd;

  double getPnn50() => _currentPnn50;

  double getSd1() => _currentSd1;

  double getSd2() => _currentSd2;

  double getSpO2() => _spo2Algorithm.currentSpO2;

  double getSummarySpO2() => _spo2Algorithm.getSummarySpO2();

  double getAverageIntensity() => _lastAverageGreen ?? 0.0;

  RgbMeans getLastRgbMeans() => RgbMeans(
        red: _lastAverageRed ?? 0.0,
        green: _lastAverageGreen ?? 0.0,
        blue: _lastAverageBlue ?? 0.0,
      );

  List<RgbMeans> getRawRgbSamples() => List.unmodifiable(_rawRgbSamples);

  /// Wall-clock timestamp (ms since epoch) of every processed frame, in the
  /// same order as `dataToPlot()`. Ukládá se se záznamem, aby export nemusel
  /// předpokládat pevnou snímkovací frekvenci — kamera reálně dodává kolem
  /// 24 fps, ne 30, a s předpokladem 30 Hz je časová osa o ~25 % zrychlená.
  List<int> getFrameTimestamps() => List.unmodifiable(_timestamps);

  List<int> getIntensityValues() =>
      _intensityValues.map((e) => e.toInt()).toList();

  List<double> dataToPlot() => List.unmodifiable(_fullRecordBuffer);

  List<double> getPpgPlot() => List.unmodifiable(_ppgSignal);

  /// Newest plot sample, or null if nothing has been captured yet.
  /// Use this on the per-frame path — [getPpgPlot] copies the whole buffer.
  double? get lastPpgSample => _ppgSignal.isEmpty ? null : _ppgSignal.last;

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
    final double meanSqDiff = sumSquaredDiff / (_allIbiIntervals.length - 1);
    _currentSd1 = sqrt(0.5 * meanSqDiff) * 1000.0; // Convert to ms
    // Clamp at zero: when RMSSD exceeds sqrt(2)*SDNN the radicand goes negative
    // and sqrt() yields NaN, which then propagates into the saved record.
    final double sd2Squared =
        2 * pow(_currentSdnn / 1000.0, 2).toDouble() - 0.5 * meanSqDiff;
    _currentSd2 = sqrt(max(0.0, sd2Squared)) * 1000.0; // Convert to ms

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
      final double meanSqDiff = sumSquaredDiff / (recentIbis.length - 1);
      _currentSd1 = sqrt(0.5 * meanSqDiff) * 1000.0;
      final double sd2Squared =
          2 * pow(_currentSdnn / 1000.0, 2).toDouble() - 0.5 * meanSqDiff;
      _currentSd2 = sqrt(max(0.0, sd2Squared)) * 1000.0;

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
    _rawRgbSamples.clear();
    recordingClipping.reset();
    _clipWindow.reset();
    _timestamps.clear();
    _bpmHistory.clear();
    _frameRates.clear();
    _respiratoryRates.clear();
    _hrvValues.clear();
    _allIbiIntervals.clear();
    _spo2Algorithm.reset();
    _motionArtifactScores.clear();
    _displayBuffer.clear();
    _framesProcessedSinceLastUpdate = 0;
    _analysisTick = 0;
    _sampleCount = 0;
    _lastPeakAbsPosition = -1.0;
    _signalBaseline = 0.0;
    _hasSignalBaseline = false;
    _motionBaseline = 0.0;
    _currentHeartRate = 0.0;
    _smoothedHeartRate = 0.0;
    _smoothedRespiratoryRate = 0.0;
    _currentSdnn = 0.0;
    _currentRmssd = 0.0;
    _currentPnn50 = 0.0;
    _currentSd1 = 0.0;
    _currentSd2 = 0.0;
    _frameRate = 0.0;
    _localFrameRate = 0.0;
    _currentBpmConfidence = 0.0;
    _latestMotionReference = 0.0;
    _hasMotionReference = false;
    _nlmsWeight = 0.0;
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
