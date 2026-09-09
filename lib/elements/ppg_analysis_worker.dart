import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:fftea/fftea.dart';

/// Off-thread PPG analysis.
///
/// The heart-rate / respiration pipeline costs several milliseconds per run and
/// used to execute inside the camera frame callback on the UI isolate, blowing
/// the frame budget once a second. Everything here is pure: a request goes in,
/// a result comes out, and no UI state is touched.

/// One analysis window plus the caller state the pipeline needs to continue.
class PpgAnalysisRequest {
  final Float64List window;
  final double frameRate;

  /// Absolute sample index that [window] starts at, used to place detected
  /// peaks on a global timeline so overlapping windows cannot double-count.
  final int absBase;
  final double lastPeakAbsPosition;
  final double smoothedHeartRate;
  final bool computeRespiration;

  /// Longer window used only for respiration. Breathing sits around 0.2 Hz, so
  /// the heart-rate window holds barely two cycles of it — far too few to fit a
  /// rate to. Null when respiration is not being computed this run.
  final Float64List? respirationWindow;

  const PpgAnalysisRequest({
    required this.window,
    required this.frameRate,
    required this.absBase,
    required this.lastPeakAbsPosition,
    required this.smoothedHeartRate,
    required this.computeRespiration,
    this.respirationWindow,
  });
}

class PpgAnalysisResult {
  final double smoothedHeartRate;
  final double confidence;
  final double snrScore;
  final double harmonicScore;
  final double autocorrScore;

  /// Inter-beat intervals in seconds discovered in this window only.
  final List<double> newIbis;
  final double lastPeakAbsPosition;

  /// Raw respiratory rate, or -1 when it was not computed this run.
  final double respiratoryRate;

  const PpgAnalysisResult({
    required this.smoothedHeartRate,
    required this.confidence,
    required this.snrScore,
    required this.harmonicScore,
    required this.autocorrScore,
    required this.newIbis,
    required this.lastPeakAbsPosition,
    required this.respiratoryRate,
  });
}

/// Stateless-per-call analyser. Instances cache FFT twiddle tables and scratch
/// buffers, so one is kept alive per isolate.
class PpgAnalyzer {
  static const double _emaAlpha = 0.25;

  double _currentBpmSnrScore = 0.0;
  double _currentBpmHarmonicScore = 0.0;
  double _currentBpmAutocorrScore = 0.0;

  /// Scratch buffer for [_medianWindow]; the windows are tiny but were being
  /// built with sublist+sort for every sample of every analysis window.
  final Float64List _medianScratch = Float64List(64);

  /// Cached FFT instance and input buffer. Constructing an FFT precomputes
  /// twiddle tables, which used to happen twice per analysis run.
  FFT? _cachedFft;
  int _cachedFftSize = 0;
  Float64List? _fftInput;

  PpgAnalysisResult analyze(PpgAnalysisRequest req) {
    final List<double> signal = req.window;
    final double fs = req.frameRate;
    final List<double> newIbis = <double>[];
    double lastPeakAbsPosition = req.lastPeakAbsPosition;
    double smoothedHeartRate = req.smoothedHeartRate;

    double respiratoryRate = -1.0;
    if (req.computeRespiration) {
      final List<double>? respSignal = req.respirationWindow;
      if (respSignal != null) {
        respiratoryRate = _calculateRespiratoryRate(respSignal, fs);
      }
    }

    if (signal.isEmpty || fs < 20.0) {
      return PpgAnalysisResult(
        smoothedHeartRate: smoothedHeartRate,
        confidence: 0.0,
        snrScore: 0.0,
        harmonicScore: 0.0,
        autocorrScore: 0.0,
        newIbis: newIbis,
        lastPeakAbsPosition: lastPeakAbsPosition,
        respiratoryRate: respiratoryRate,
      );
    }

    // Stage 1-6: condition the window.
    final List<double> normalized = _robustNormalization(signal);
    final List<double> motionCleaned = _removeMotionArtifacts(normalized, fs);
    final List<double> medianFiltered = _medianFilter(motionCleaned, 3);
    final List<double> bandPassed =
        _applyButterworthBandpass(medianFiltered, 0.7, 3.5, fs);

    final int transientSamples = (fs * 0.5).round();
    final List<double> stable = transientSamples < bandPassed.length
        ? bandPassed.sublist(transientSamples)
        : bandPassed;

    double confidence = 0.0;
    if (stable.length >= 30 && _standardDeviation(stable) >= 1e-6) {
      final List<double> zScored = _zScore(stable);

      // Stage 7: one spectrum, shared by the estimator and the confidence score.
      final _Spectrum? spectrum = _magnitudeSpectrum(zScored, fs);
      final double fftBpm = _estimateHrFrequencyDomain(spectrum);
      final double acBpm = _estimateHrAutocorrelation(zScored, fs);

      // Stage 8: fuse the two estimates.
      double bpm;
      if (fftBpm > 0 && acBpm > 0) {
        final double ratio = fftBpm / acBpm;
        final double diff = (fftBpm - acBpm).abs() / max(fftBpm, acBpm);
        if (ratio > 1.8 && ratio < 2.2 || ratio > 0.45 && ratio < 0.56) {
          // The two disagree by a factor of two: one of them locked onto a
          // harmonic. The fundamental is the lower of the pair. Falling through
          // to the branch below would have taken the FFT value unconditionally,
          // which is precisely the wrong choice here.
          bpm = min(fftBpm, acBpm);
        } else if (diff < 0.10) {
          bpm = (fftBpm + acBpm) / 2.0;
        } else if (diff < 0.20) {
          bpm = fftBpm * 0.7 + acBpm * 0.3;
        } else {
          bpm = fftBpm;
        }
      } else {
        bpm = fftBpm > 0 ? fftBpm : acBpm;
      }
      if (bpm > 200 || bpm < 40) bpm = 0.0;

      // Stage 9: inter-beat intervals from interpolated peak positions.
      if (bpm > 0) {
        final double expectedLagSamples = fs * 60.0 / bpm;
        final int minDist =
            (expectedLagSamples * 0.7).round().clamp(3, zScored.length);
        final int maxDist = (expectedLagSamples * 1.3)
            .round()
            .clamp(minDist + 1, zScored.length);
        final int absBase = req.absBase + transientSamples;

        final double mean = _average(zScored);
        final double std = _standardDeviation(zScored);
        final double threshold = mean + 0.3 * std;

        int lastLocalPeakIdx = -minDist;
        for (int i = 1; i < zScored.length - 1; i++) {
          final double prev = zScored[i - 1];
          final double curr = zScored[i];
          final double next = zScored[i + 1];
          if (!(prev < curr && curr > next) || curr <= threshold) continue;
          if (i - lastLocalPeakIdx < minDist) continue;
          lastLocalPeakIdx = i;

          // Parabolic sub-sample refinement: without it every interval is
          // quantised to a whole frame (33 ms at 30 FPS), which alone inflates
          // RMSSD by tens of milliseconds.
          final double denom = prev - 2 * curr + next;
          final double delta = denom.abs() > 1e-12
              ? (0.5 * (prev - next) / denom).clamp(-0.5, 0.5)
              : 0.0;
          final double absPos = absBase + i + delta;

          if (lastPeakAbsPosition >= 0) {
            final double gap = absPos - lastPeakAbsPosition;
            if (gap < minDist) continue; // already-counted beat
            if (gap <= maxDist) {
              final double ibiSec = gap / fs;
              if (ibiSec >= 0.3 && ibiSec <= 1.5) newIbis.add(ibiSec);
            }
          }
          lastPeakAbsPosition = absPos;
        }
      }

      confidence = _calculateBpmConfidence(zScored, fs, bpm, spectrum);

      if (bpm > 0) {
        smoothedHeartRate = smoothedHeartRate == 0.0
            ? bpm
            : (smoothedHeartRate * (1 - _emaAlpha)) + (bpm * _emaAlpha);
      }
    }

    return PpgAnalysisResult(
      smoothedHeartRate: smoothedHeartRate,
      confidence: confidence,
      snrScore: _currentBpmSnrScore,
      harmonicScore: _currentBpmHarmonicScore,
      autocorrScore: _currentBpmAutocorrScore,
      newIbis: newIbis,
      lastPeakAbsPosition: lastPeakAbsPosition,
      respiratoryRate: respiratoryRate,
    );
  }

  double _average(List<double> values) => _calculateAverage(values);

  double _standardDeviation(List<double> values) =>
      calculateStandardDeviation(values);

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
    final int len = end - start + 1;
    if (len <= 0) return 0.0;
    if (len == 1) return signal[start];
    if (len > _medianScratch.length) {
      final List<double> window = signal.sublist(start, end + 1)..sort();
      return window[window.length ~/ 2];
    }
    for (int i = 0; i < len; i++) {
      _medianScratch[i] = signal[start + i];
    }
    // Insertion sort: allocation-free and faster than a generic sort at this size.
    for (int i = 1; i < len; i++) {
      final double v = _medianScratch[i];
      int j = i - 1;
      while (j >= 0 && _medianScratch[j] > v) {
        _medianScratch[j + 1] = _medianScratch[j];
        j--;
      }
      _medianScratch[j + 1] = v;
    }
    return _medianScratch[len ~/ 2];
  }

  FFT _fftFor(int n) {
    if (_cachedFft == null || _cachedFftSize != n) {
      _cachedFft = FFT(n);
      _cachedFftSize = n;
      _fftInput = Float64List(n);
    }
    return _cachedFft!;
  }

  /// Hamming-windows, zero-pads and transforms [signal] once. The result feeds
  /// both the HR estimate and the confidence scorer.
  _Spectrum? _magnitudeSpectrum(List<double> signal, double localFrameRate) {
    final int origN = signal.length;
    if (origN < 30 || localFrameRate <= 0) return null;

    int n = 256;
    while (n < origN) {
      n *= 2;
    }

    try {
      final FFT fft = _fftFor(n);
      final Float64List buffer = _fftInput!;
      final double denom = (origN - 1).toDouble();
      for (int i = 0; i < origN; i++) {
        buffer[i] = signal[i] * (0.54 - 0.46 * cos(2 * pi * i / denom));
      }
      for (int i = origN; i < n; i++) {
        buffer[i] = 0.0;
      }
      // realFft copies its input, so reusing the buffer across calls is safe.
      final magnitudes = fft.realFft(buffer).magnitudes();
      return _Spectrum(magnitudes, localFrameRate / n);
    } catch (e) {
      if (kDebugMode) print('FFT error: $e');
      return null;
    }
  }

  // IMPROVED: Frequency Domain HR estimation with zero-padding and parabolic interpolation
  double _estimateHrFrequencyDomain(_Spectrum? spectrum) {
    if (spectrum == null) return 0.0;
    final Float64List magnitudes = spectrum.magnitudes;
    final double freqRes = spectrum.freqRes;
    if (freqRes <= 0) return 0.0;

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

    // Octave check. A pulse with a weak fundamental and a strong dicrotic
    // notch puts more energy in the second harmonic than in the beat rate
    // itself, so the tallest bin sits at twice the true rate — this is what
    // produced readings like 160 BPM for an 80 BPM pulse. If half the peak
    // frequency is still in band and carries real energy, that is the
    // fundamental and the tall bin is its harmonic.
    final double halfFreq = (peakIdx * freqRes) / 2.0;
    if (halfFreq >= 0.7) {
      final int halfBin = (halfFreq / freqRes).round();
      if (halfBin > lowIdx && halfBin < highIdx) {
        double halfMag = 0.0;
        int halfPeakIdx = halfBin;
        for (int i = max(lowIdx, halfBin - 1);
            i <= min(highIdx, halfBin + 1);
            i++) {
          if (magnitudes[i] > halfMag) {
            halfMag = magnitudes[i];
            halfPeakIdx = i;
          }
        }

        // Noise floor of the band, ignoring both candidate peaks.
        double sum = 0.0;
        int count = 0;
        for (int i = lowIdx; i <= highIdx; i++) {
          if ((i - peakIdx).abs() > 2 && (i - halfBin).abs() > 2) {
            sum += magnitudes[i];
            count++;
          }
        }
        final double noise = count > 0 ? sum / count : 0.0;

        // Require the sub-harmonic to stand clearly above the noise and to be
        // a substantial fraction of the taller peak before trusting it.
        if (halfMag > noise * 3.0 && halfMag > maxMag * 0.4) {
          peakIdx = halfPeakIdx;
          maxMag = halfMag;
        }
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
  }

  /// IMPROVED: Confidence score with SNR + harmonic validation + autocorrelation
  double _calculateBpmConfidence(List<double> signal, double localFrameRate,
      double bpm, _Spectrum? spectrum) {
    if (bpm <= 0 || signal.length < 30 || spectrum == null) {
      _currentBpmSnrScore = 0.0;
      _currentBpmHarmonicScore = 0.0;
      _currentBpmAutocorrScore = 0.0;
      return 0.0;
    }

    try {
      // Reuses the spectrum already computed for the HR estimate.
      final Float64List magnitudes = spectrum.magnitudes;
      final double freqRes = spectrum.freqRes;

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

      _currentBpmSnrScore = snrScore;
      _currentBpmHarmonicScore = harmonicScore;
      _currentBpmAutocorrScore = acScore;

      // Combined confidence
      final double confidence =
          (0.5 * snrScore + 0.2 * harmonicScore + 0.3 * acScore)
              .clamp(0.0, 1.0);

      return confidence;
    } catch (e) {
      _currentBpmSnrScore = 0.0;
      _currentBpmHarmonicScore = 0.0;
      _currentBpmAutocorrScore = 0.0;
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

  List<double> _zScore(List<double> signal) {
    if (signal.isEmpty) return signal;
    final double mean = _calculateAverage(signal);
    final double std = calculateStandardDeviation(signal);
    if (std == 0) return List<double>.filled(signal.length, 0.0);
    return signal.map((v) => (v - mean) / std).toList();
  }

  /// Calculate respiratory rate from amplitude envelope
  /// Method: extract pulse band -> envelope -> respiratory band filter -> peak detection
  ///
  /// CHANGED: Now accepts signal and local frame rate as parameters.
  /// Shortest window that can carry a believable respiratory rate. At the slow
  /// end of normal breathing (6/min, one cycle per 10 s) 25 s is about two and
  /// a half cycles; below that the estimate is guesswork.
  static const double _minRespirationSeconds = 25.0;

  double _calculateRespiratoryRate(List<double> signal, double fs) {
    if (signal.length < (fs * _minRespirationSeconds).round()) {
      return 0.0;
    }

    // 1) Isolate pulse component (0.7-3.0 Hz heart band)
    final pulse = _applyButterworthBandpass(signal, 0.7, 3.0, fs);
    if (pulse.length < 8) {
      return 0.0;
    }

    // 2) Envelope via absolute value + moving average (~1s)
    final envelope = pulse.map((v) => v.abs()).toList();
    final envSmooth =
        _movingAverage(envelope, (fs * 1.0).round().clamp(5, 120));


    // 3) Respiratory modulation band (0.05-0.5 Hz = 3-30 breaths/min)
    final resp = _applyButterworthBandpass(envSmooth, 0.05, 0.5, fs);
    if (resp.length < 8) {
      return 0.0;
    }

    final avg = _calculateAverage(resp);
    final std = calculateStandardDeviation(resp);
    if (std < 0.0005) {
      return 0.0;
    }

    // 4) Peak detection with threshold
    final threshold = avg + 0.2 * std;
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

    if (peaks.length < 2) {
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

    if (validIntervals == 0) {
      return 0.0;
    }

    final avgInterval = totalInterval / validIntervals;
    final respiratoryRate = 60.0 / avgInterval;
    final clampedRR = respiratoryRate.clamp(6.0, 30.0);

    // EMA smoothing is applied by the caller, which owns that state.
    return clampedRR;
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

  double _calculateAverage(final List<double> values) {
    if (values.isEmpty) return 0.0;
    return values.reduce((a, b) => a + b) / values.length;
  }

  double calculateStandardDeviation(List<double> values) {
    if (values.isEmpty) return 0.0;

    final double mean = _calculateAverage(values);
    final double sumOfSquaredDifferences = values
        .map((value) => pow(value - mean, 2))
        .reduce((a, b) => a + b)
        .toDouble();

    return sqrt(sumOfSquaredDifferences / values.length);
  }
}

/// Magnitude spectrum plus the frequency step per bin.
class _Spectrum {
  final Float64List magnitudes;
  final double freqRes;
  const _Spectrum(this.magnitudes, this.freqRes);
}

// --- Isolate plumbing -------------------------------------------------------

class _WorkerReady {
  final SendPort port;
  const _WorkerReady(this.port);
}

void _workerEntry(SendPort toOwner) {
  final ReceivePort inbox = ReceivePort();
  toOwner.send(_WorkerReady(inbox.sendPort));
  final PpgAnalyzer analyzer = PpgAnalyzer();
  inbox.listen((Object? message) {
    if (message is PpgAnalysisRequest) {
      toOwner.send(analyzer.analyze(message));
    } else if (message == 'shutdown') {
      inbox.close();
    }
  });
}

/// Owns a long-lived analysis isolate. One request is in flight at a time:
/// windows overlap heavily, so a late result is worth less than a fresh one.
class PpgAnalysisWorker {
  Isolate? _isolate;
  SendPort? _toWorker;
  ReceivePort? _fromWorker;
  Future<void>? _starting;
  bool _busy = false;
  bool _disposed = false;
  final List<PpgAnalysisRequest> _pending = <PpgAnalysisRequest>[];

  /// Invoked on the owning isolate when a result arrives.
  void Function(PpgAnalysisResult result)? onResult;

  bool get isBusy => _busy;

  /// Starts the isolate before the first request, so its spawn cost does not
  /// land inside a measurement.
  void warmUp() {
    if (_disposed) return;
    unawaited(_ensureStarted());
  }

  Future<void> _ensureStarted() {
    return _starting ??= () async {
      final ReceivePort inbox = ReceivePort();
      _fromWorker = inbox;
      inbox.listen((Object? message) {
        if (message is _WorkerReady) {
          _toWorker = message.port;
          _drain();
        } else if (message is PpgAnalysisResult) {
          _busy = false;
          onResult?.call(message);
          _drain();
        }
      });
      _isolate = await Isolate.spawn(_workerEntry, inbox.sendPort);
    }();
  }

  void _drain() {
    if (_disposed || _busy || _pending.isEmpty) return;
    final SendPort? port = _toWorker;
    if (port == null) return;
    // Only the newest window matters; drop anything that queued up behind it.
    final PpgAnalysisRequest request = _pending.removeLast();
    _pending.clear();
    _busy = true;
    port.send(request);
  }

  /// Queues [request]. Returns false when a run is already in flight, so the
  /// caller can keep its own state unchanged until a result comes back.
  bool submit(PpgAnalysisRequest request) {
    if (_disposed) return false;
    if (_busy) return false;
    _pending
      ..clear()
      ..add(request);
    if (_toWorker == null) {
      unawaited(_ensureStarted());
      return true;
    }
    _drain();
    return true;
  }

  void dispose() {
    _disposed = true;
    try {
      _toWorker?.send('shutdown');
    } catch (e) {
      // Expected when the isolate is already gone.
      debugPrint('Worker shutdown message not delivered: $e');
    }
    _fromWorker?.close();
    _isolate?.kill(priority: Isolate.immediate);
    _isolate = null;
    _toWorker = null;
  }
}
