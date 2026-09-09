import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tepovka/elements/camera_body.dart';
import 'package:tepovka/ppg_algo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:tepovka/pages/summary_page.dart';
import 'dart:math';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/about.dart';
import 'package:flutter/services.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:tepovka/elements/research_metadata_dialog.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/elements/signal_quality_checker.dart'; // Import samostatné třídy pro kvalitu
import 'package:tepovka/elements/peak_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:collection';

class TimeLabel {
  double x;
  String time;
  TimeLabel(this.x, this.time);
}

class Home extends StatefulWidget {
  const Home({super.key});
  @override
  State<Home> createState() => _HomeState();
}

class _HomeState extends State<Home>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late CameraController _cameraController; // Definice proměnné pro kameru
  PPGAlgorithm? _ppgAlgorithm;
  Timer? _navigationTimer;
  Timer? _countdownTimer; // Timer for countdown display
  StreamSubscription<UserAccelerometerEvent>? _accelerometerSubscription;
  List<FlSpot> _data = [];
  List<FlSpot> _smoothedData = [];
  List<FlSpot> _fullRecordData =
      []; // Full record for Summary, never window-pruned
  List<TimeLabel> _labels = [];
  List<FlSpot> _peakSpots = []; // FlSpot instances for detected peaks
  bool _isPlottingStarted = false;
  int _selectedIndex = 1;
  late AnimationController _progressController;
  bool _isRecording = false; // Tracks whether recording is active
  final bool _showBPM = true; // Determines whether BPM is displayed
  bool _isFlashOn = false; // Tracks flashlight state
  String appbar_text = '';
  List<int> bpm_list = [];
  int _recordingDuration = 30; // Default recording duration in seconds
  int _remainingTime = 30; // Remaining time for countdown display
  double _currentTime = 0.0; // Kumulativní čas pro legendu
  int _lastLabelSecond = 0;
  SignalQuality _signalQuality = SignalQuality.bad;
  late SignalQualityChecker _signalQualityChecker; // Instance samostatné třídy
  List<CameraDescription> _backCameras = [];
  int _currentBackCameraIndex = 0;
  late AnimationController _heartAnimationController;
  static const double _windowTime = 5.0; // Window duration in seconds
  static const double _sampleRate =
      30.0; // Předpokládaná frekvence vzorkování v Hz
  static const double _bufferTime =
      0.5; // Buffer time for left overflow (in seconds)
  bool _isCountdownRunning = false;
  String _buttonLabel = '';
  double _lastBpmUpdateTime = 0.0; // New: Time of last BPM update
  double _yAxisHalfRange =
      1.5; // Symmetric Y axis around 0 for stable oscilloscope view
  int _samplesSinceLastScaleUpdate = 0;
  double _emaState = 0.0; // Persistent EMA state across samples
  bool _isTeardown = false;
  bool _isSwitchingCamera = false;

  // --- Live pipeline state -------------------------------------------------
  // The graph is now driven by real camera frames instead of a blind 33 ms
  // timer. The old timer resampled whatever the last value happened to be, so
  // whenever the camera ran below 30 FPS the plot (and every time-based BPM
  // derived from it) silently stretched.
  bool _isProcessingFrame = false;

  /// Wall-clock instant the current measurement started. This — not the moment
  /// the user taps save on the summary — is what stamps the stored record.
  DateTime? _measurementStartedAt;
  final Stopwatch _elapsed = Stopwatch();
  int _lastChartRepaintMs = 0;
  int _samplesSinceLastPeakScan = 0;
  int _lastConsumedSampleCount = 0;

  /// Bezici priprava kamery a analyzy, spustena behem odpoctu.
  Future<void>? _preparation;

  /// Metadata vyplnena ve vyzkumnem rezimu pred merenim.
  Map<String, String> _measurementMetadata = const {};

  /// Jak dlouho se ceka, nez se po zapnuti svetla ustali automatika kamery.
  /// Merenim 2026 se ukazalo, ze zapnout svetlo az v okamziku startu zaznamu
  /// vyrobi na zacatku kazdeho zaznamu velky prechodovy jev.
  static const Duration _torchSettleDelay = Duration(milliseconds: 900);

  /// Kratsi cekani, kdyz uz svitilna sviti a jde jen o to, aby se expozice
  /// dorovnala na prave prilozeny prst.
  static const Duration _fingerSettleDelay = Duration(milliseconds: 400);

  /// Doba na ustaleni filtru v analyze po jejim resetu, jeste pred zaznamem.
  static const Duration _analysisWarmupDelay = Duration(milliseconds: 700);

  /// Incremental filter state, so each new sample is O(1) instead of
  /// re-filtering the whole visible window on every update.
  final ListQueue<double> _medianRing = ListQueue<double>();
  final ListQueue<double> _baselineRing = ListQueue<double>();
  double _baselineSum = 0.0;
  static const int _medianWindowSize = 5;

  /// Delka okna pro odecteni baseline v sekundach. Musi zustat delsi nez
  /// jeden tep, jinak by filtr ukrajoval z pulzu; drzi se casu, ne poctu
  /// vzorku, aby prezila zmenu snimkovaci frekvence.
  static const double _baselineWindowSeconds = 2.5;
  int get _baselineWindow =>
      (_baselineWindowSeconds * _effectiveSampleRate).round().clamp(20, 600);

  /// Repaint triggers. Bumping these rebuilds only the chart / BPM / quality
  /// subtrees instead of the whole Scaffold (camera preview, NumberPicker,
  /// nav bar and buttons were all being rebuilt 30x per second).
  final ValueNotifier<int> _chartRevision = ValueNotifier<int>(0);
  final ValueNotifier<double> _bpmNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<SignalQuality> _qualityNotifier =
      ValueNotifier<SignalQuality>(SignalQuality.bad);
  final ValueNotifier<int> _remainingTimeNotifier = ValueNotifier<int>(30);

  /// Effective sample rate, measured from the camera rather than assumed.
  double get _effectiveSampleRate {
    final double measured = _ppgAlgorithm?.measuredFrameRate ?? 0.0;
    return measured >= 5.0 ? measured : _sampleRate;
  }

  /// Localised label for the quality indicator.
  String _qualityLabel(SignalQuality quality) {
    final L10n t = L10n.of(context);
    return switch (quality) {
      SignalQuality.good => t.qualityGood,
      SignalQuality.bad => t.qualityBad,
      SignalQuality.poorContact => t.qualityPoorContact,
      SignalQuality.noFinger => t.qualityNoFinger,
    };
  }

  /// Localised phrase spoken in senior mode.
  String _qualitySpeech(SignalQuality quality) {
    final L10n t = L10n.of(context);
    return switch (quality) {
      SignalQuality.good => t.ttsSignalGood,
      SignalQuality.bad => t.ttsSignalWorse,
      SignalQuality.poorContact => t.ttsPoorContact,
      SignalQuality.noFinger => t.ttsPlaceFinger,
    };
  }

  bool get _hasInitializedCameraController {
    try {
      return _cameraController.value.isInitialized;
    } catch (_) {
      return false;
    }
  }

  bool get _isStreamingImages {
    try {
      return _cameraController.value.isStreamingImages;
    } catch (_) {
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Inicializace samostatné třídy pro kvalitu
    _signalQualityChecker = SignalQualityChecker();
    // Initialize back cameras list
    _initializeBackCameras();
    // Initialize camera and algorithm
    _ppgAlgorithm = PPGAlgorithm();
    // Spawn the analysis isolate now, not on the first analysis run mid-measurement.
    _ppgAlgorithm!.warmUp();
    // Set up animation controllers
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: _recordingDuration),
    );
    _heartAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
      lowerBound: 0.9,
      upperBound: 1.3,
    )..repeat(reverse: true);
  }

  Future<void> _initializeBackCameras() async {
    try {
      final allCameras = await availableCameras();
      final backCameras = allCameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();

      // Some Android devices expose only one rear camera. In that case,
      // allow cycling through all available cameras as a fallback.
      _backCameras = backCameras.length >= 2 ? backCameras : allCameras;

      if (_backCameras.isNotEmpty) {
        // Prefer rear camera as default if present.
        final firstBackIndex = _backCameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        _currentBackCameraIndex = firstBackIndex >= 0 ? firstBackIndex : 0;
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error loading back cameras: $e');
    }
  }

  Future<void> _switchBackCamera() async {
    if (_backCameras.length < 2 || _isSwitchingCamera) return;
    _isSwitchingCamera = true;
    try {
      if (_isStreamingImages) {
        await _cameraController.stopImageStream();
      }
      _elapsed.stop();
      if (_hasInitializedCameraController) {
        await _cameraController.dispose();
      }
      if (_isFlashOn) {
        _isFlashOn = false;
      }
      _currentBackCameraIndex =
          (_currentBackCameraIndex + 1) % _backCameras.length;
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      debugPrint('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).homeCameraSwitchFailed),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      _isSwitchingCamera = false;
    }
  }

  Future<void> _toggleFlashlight() async {
    if (_hasInitializedCameraController) {
      if (_isFlashOn) {
        await _cameraController.setFlashMode(FlashMode.off);
        setState(() {
          _isFlashOn = false;
        });
      } else {
        await _cameraController.setFlashMode(FlashMode.torch);
        setState(() {
          _isFlashOn = true;
        });
      }
    }
  }

  void _startImageStream() {
    if (_hasInitializedCameraController && !_isStreamingImages) {
      _cameraController.startImageStream((image) {
        final PPGAlgorithm? algorithm = _ppgAlgorithm;
        if (algorithm == null) return;
        // Drop frames instead of queueing them: if we ever fall behind, a
        // backlog of stale frames is worse than a slightly lower sample rate.
        if (_isProcessingFrame) return;
        _isProcessingFrame = true;
        try {
          algorithm.processImage(image);
          if (algorithm.sampleCount != _lastConsumedSampleCount) {
            _lastConsumedSampleCount = algorithm.sampleCount;
            _appendSample(algorithm);
          }
        } finally {
          _isProcessingFrame = false;
        }
      });
    }
  }

  void _startAccelerometerStream() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription =
        userAccelerometerEventStream().listen((UserAccelerometerEvent event) {
      if (!_isRecording || _ppgAlgorithm == null) return;
      _ppgAlgorithm!.processAccelerometerSample(
        x: event.x,
        y: event.y,
        z: event.z,
      );
    });
  }

  /// Called once per accepted camera frame. Everything here is O(1) in the
  /// window length except the throttled peak scan, so it can safely run inside
  /// the image-stream callback.
  void _appendSample(PPGAlgorithm algorithm) {
    final double? latest = algorithm.lastPpgSample;
    if (latest == null) return;

    // Real elapsed time, not an assumed 1/30 s step.
    _currentTime = _elapsed.elapsedMicroseconds / 1e6;
    final double minX = _currentTime - _windowTime;

    // Inverze: surový signál se invertuje pro zobrazení
    final double newValue = -latest;
    _data.add(FlSpot(_currentTime, newValue));
    _pruneLeading(_data, minX - _bufferTime);

    // FILTERING PIPELINE (incremental, causal):
    // 1. Median filter (spike removal) → 2. Baseline removal → 3. EMA smoothing
    // Step 1: causal median over the last _medianWindowSize raw samples.
    _medianRing.addLast(newValue);
    if (_medianRing.length > _medianWindowSize) _medianRing.removeFirst();
    final List<double> sortWindow = _medianRing.toList()..sort();
    final double medianValue = sortWindow[sortWindow.length ~/ 2];

    // Step 2: causal baseline removal via a running-sum moving average.
    _baselineRing.addLast(medianValue);
    _baselineSum += medianValue;
    if (_baselineRing.length > _baselineWindow) {
      _baselineSum -= _baselineRing.removeFirst();
    }
    final double detrended =
        medianValue - (_baselineSum / _baselineRing.length);

    // Step 3: causal EMA on the newest sample only.
    const double emaAlpha = 0.4;
    _emaState = _emaState * (1 - emaAlpha) + detrended * emaAlpha;

    _smoothedData.add(FlSpot(_currentTime, _emaState));
    if (_isRecording) {
      _fullRecordData.add(FlSpot(_currentTime, _emaState));
    }
    _pruneLeading(_smoothedData, minX - _bufferTime);
    _updateYAxisScale();

    _samplesSinceLastPeakScan++;
    if (_samplesSinceLastPeakScan >= 3) {
      _samplesSinceLastPeakScan = 0;
      _detectDisplayPeaks(minX);
    }
    _pruneLeading(_peakSpots, minX - _bufferTime);

    _updateLiveBpm(algorithm);

    // Posuň časové značky – no shift needed, remove old
    _pruneLeading(_labels, minX, keyOf: (TimeLabel l) => l.x);
    final int currentSecond = _currentTime.floor();
    if (currentSecond > _lastLabelSecond) {
      final DateTime now = DateTime.now();
      final String formattedTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _labels.add(TimeLabel(_currentTime, formattedTime));
      _lastLabelSecond = currentSecond;
    }

    // Aktualizuj kvalitu signálu pomocí samostatné třídy
    final RgbMeans rgbMeans = algorithm.getLastRgbMeans();
    _signalQuality =
        _signalQualityChecker.calculateQuality(_data, rgbMeans: rgbMeans);
    if (_qualityNotifier.value != _signalQuality) {
      _qualityNotifier.value = _signalQuality;
      // Announce quality changes in senior mode. The phrase is resolved here
      // because TtsService has no BuildContext of its own.
      TtsService.instance
          .announceQuality(_signalQuality, _qualitySpeech(_signalQuality));
    }

    if (!_isPlottingStarted && _data.length >= 30) {
      _isPlottingStarted = true;
    }

    // Repaint the chart at ~25 Hz at most, and only the chart subtree.
    final int nowMs = _elapsed.elapsedMilliseconds;
    if (nowMs - _lastChartRepaintMs >= 40) {
      _lastChartRepaintMs = nowMs;
      _chartRevision.value++;
    }
  }

  /// Drops leading entries whose x is below [minX]. The lists are always
  /// time-ordered, so this is O(dropped) instead of removeWhere's O(n).
  static void _pruneLeading<T>(List<T> items, double minX,
      {double Function(T)? keyOf}) {
    int drop = 0;
    while (drop < items.length) {
      final T item = items[drop];
      final double x = keyOf != null ? keyOf(item) : (item as FlSpot).x;
      if (x >= minX) break;
      drop++;
    }
    if (drop > 0) items.removeRange(0, drop);
  }

  void _detectDisplayPeaks(double minX) {
    if (_smoothedData.length < 3) return;
    final List<double> smoothedYValues = [
      for (final FlSpot spot in _smoothedData) spot.y
    ];
    final List<int> allPeaks = PeakDetector.findPeaks(smoothedYValues,
        sampleRate: _effectiveSampleRate);
    if (allPeaks.isEmpty) return;

    final double rightThresh = minX + (_currentTime - minX) * 0.7;
    const double minDistTime = 60.0 / 150.0; // 0.4 s min spacing for max HR 150

    double sum = 0.0;
    for (final double v in smoothedYValues) {
      sum += v;
    }
    final double mean = sum / smoothedYValues.length;
    double sumSq = 0.0;
    for (final double v in smoothedYValues) {
      sumSq += (v - mean) * (v - mean);
    }
    final double std = sqrt(sumSq / smoothedYValues.length);
    final double prominenceThreshold = 0.5 * std;

    for (final int idx in allPeaks) {
      final FlSpot newPeak = _smoothedData[idx];
      if (newPeak.x <= rightThresh) continue;
      if (smoothedYValues[idx] - mean <= prominenceThreshold) continue;
      if (_peakSpots.isNotEmpty) {
        // A peak can surface late: PeakDetector's local threshold needs about a
        // second of following data to settle, so a candidate older than the
        // last accepted one may only now qualify. Appending it would leave
        // _peakSpots out of chronological order, and the fallback BPM would
        // then compute negative inter-beat intervals.
        if (newPeak.x <= _peakSpots.last.x) continue;
        if (newPeak.x - _peakSpots.last.x < minDistTime) continue;
      }
      _peakSpots.add(newPeak);
    }
  }

  /// Live BPM: prefer the FFT/autocorrelation estimate from PPGAlgorithm once
  /// it is confident, and fall back to counting displayed peaks. Previously the
  /// screen only ever showed the peak count, and silently displayed a
  /// hard-coded 70 whenever that failed.
  void _updateLiveBpm(PPGAlgorithm algorithm) {
    final double algoBpm = algorithm.getCurrentHeartRate();
    if (algoBpm >= 40 &&
        algoBpm <= 200 &&
        algorithm.currentBpmConfidence >= 0.3) {
      _publishBpm(algoBpm);
      return;
    }

    if (_currentTime - _lastBpmUpdateTime >= 3.0 && _peakSpots.length >= 4) {
      final List<double> intervals = [
        for (int i = 1; i < _peakSpots.length; i++)
          _peakSpots[i].x - _peakSpots[i - 1].x
      ];
      final double avgInterval =
          intervals.reduce((a, b) => a + b) / intervals.length;
      final double candidate = avgInterval > 0 ? 60.0 / avgInterval : 0.0;
      // Out-of-range means the peaks were noise; report "no reading" rather
      // than substituting a plausible-looking number.
      _lastBpmUpdateTime = _currentTime;
      _publishBpm((candidate >= 40 && candidate <= 200) ? candidate : 0.0);
    }
  }

  void _publishBpm(double bpm) {
    if (_bpmNotifier.value.round() == bpm.round()) return;
    _bpmNotifier.value = bpm;

    // Haptics and the heartbeat animation used to be driven from build(), so
    // they fired on every unrelated rebuild. They belong here, where the value
    // actually changes.
    if (bpm > 0) {
      HapticFeedback.selectionClick();
      final double heartRateFactor = (bpm - 30) / (220 - 30);
      if (heartRateFactor > 0) {
        _heartAnimationController.duration =
            Duration(milliseconds: max(300, (600 / heartRateFactor).round()));
      }
    }
  }

  Future<void> _stopRecording() async {
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _progressController.reset();
    _signalQualityChecker.reset(); // Reset historie kvality při stopu
    setState(() {
      _isRecording = false;
      _isCountdownRunning = false;
      appbar_text = L10n.of(context).homeReady;
      _remainingTime = _recordingDuration;
      _signalQuality = SignalQuality.bad; // Reset kvality
      _buttonLabel = L10n.of(context).homeStartButton;
      _yAxisHalfRange = 1.5;
      _samplesSinceLastScaleUpdate = 0;
    });
    _qualityNotifier.value = SignalQuality.bad;
    _resetLiveBuffers();

    // Ensure camera stream and torch are stopped when user manually stops measuring
    await _stopAllActivity(disposeCamera: false);

    // A hned obrazovku vratit do stavu, v jakem je po prichodu: bezici nahled
    // a rozsvicena svitilna. Bez toho zustane stream zastaveny, graf zamrzly
    // a dalsi spustene mereni by nedostalo ani jeden snimek.
    if (!mounted || _selectedIndex != 1) return;
    _startImageStream();
    _startGraphUpdates();
    await _setTorch(true);
  }

  void _onItemTapped(int index) async {
    if (_selectedIndex == index) {
      return;
    }
    // Stop recording if active
    if (_isRecording) {
      _stopRecording();
    }
    // Stop camera + timers before leaving measurement
    await _stopAllActivity(disposeCamera: true);
    // Tearing down the camera takes long enough that the user can leave this
    // screen first; touching setState or the Navigator afterwards throws.
    if (!mounted) return;
    setState(() {
      _selectedIndex = index;
    });
    // Navigate to the selected page
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
        break;
    }
  }

  Future<void> _stopAllActivity({bool disposeCamera = false}) async {
    if (_isTeardown) return;
    _isTeardown = true;
    try {
      _elapsed.stop();
      _navigationTimer?.cancel();
      _countdownTimer?.cancel();
      await _accelerometerSubscription?.cancel();
      _accelerometerSubscription = null;
      _progressController.stop();
      _heartAnimationController.stop();
      if (_hasInitializedCameraController) {
        await _cameraController.setFlashMode(FlashMode.off);
        _isFlashOn = false;
        await _unlockCaptureSettings();
      }
      if (_isStreamingImages) {
        await _cameraController.stopImageStream();
      }
      if (disposeCamera && _hasInitializedCameraController) {
        await _cameraController.dispose();
      }
      _isRecording = false;
    } catch (e) {
      debugPrint('StopAllActivity error: $e');
    } finally {
      _isTeardown = false;
    }
  }

  /// Starts the live plot clock. Updates themselves are driven by the camera
  /// image stream (see [_startImageStream]) rather than a fixed timer.
  void _startGraphUpdates() {
    _elapsed
      ..reset()
      ..start();
    _lastChartRepaintMs = 0;
    setState(() {
      _isPlottingStarted = true;
    });
  }

  /// Freezes focus and exposure so auto-adjustment cannot track the pulse.
  /// Failures are non-fatal: not every device exposes these controls.
  /// Zapne nebo zhasne svitilnu a udrzi [_isFlashOn] v souladu se skutecnosti.
  Future<void> _setTorch(bool on) async {
    if (!_hasInitializedCameraController || _isTeardown) return;
    if (_isFlashOn == on) return;
    try {
      await _cameraController
          .setFlashMode(on ? FlashMode.torch : FlashMode.off);
      if (mounted) {
        setState(() {
          _isFlashOn = on;
        });
      } else {
        _isFlashOn = on;
      }
    } catch (e) {
      debugPrint('Torch ${on ? 'enable' : 'disable'} failed: $e');
    }
  }

  Future<void> _lockCaptureSettings() async {
    if (!_hasInitializedCameraController) return;
    try {
      await _cameraController.setFocusMode(FocusMode.locked);
    } catch (e) {
      debugPrint('Focus lock unavailable: $e');
    }
    try {
      await _cameraController.setExposureMode(ExposureMode.locked);
    } catch (e) {
      debugPrint('Exposure lock unavailable: $e');
    }
  }

  /// Restores auto focus/exposure once a measurement ends.
  Future<void> _unlockCaptureSettings() async {
    if (!_hasInitializedCameraController) return;
    try {
      await _cameraController.setFocusMode(FocusMode.auto);
    } catch (e) {
      debugPrint('Focus unlock unavailable: $e');
    }
    try {
      await _cameraController.setExposureMode(ExposureMode.auto);
    } catch (e) {
      debugPrint('Exposure unlock unavailable: $e');
    }
  }

  /// Clears the incremental filter/plot state between measurements.
  void _resetLiveBuffers() {
    _data = [];
    _smoothedData = [];
    _peakSpots = [];
    _labels = [];
    _fullRecordData = [];
    _medianRing.clear();
    _baselineRing.clear();
    _baselineSum = 0.0;
    _emaState = 0.0;
    _currentTime = 0.0;
    _lastLabelSecond = 0;
    _samplesSinceLastPeakScan = 0;
    _lastConsumedSampleCount = 0;
    _lastBpmUpdateTime = 0.0;
    _bpmNotifier.value = 0.0;
    _elapsed
      ..reset()
      ..start();
  }

  void _initializeTimers() {
    _navigationTimer = Timer(Duration(seconds: _recordingDuration), () {
      _navigateToSummaryPage();
    });
    // Countdown timer for display. This used to call setState once a second,
    // rebuilding the whole Scaffold — NumberPicker, nav bar, camera preview and
    // chart included — which produced a visible 1 Hz hitch during measurement.
    _remainingTime = _recordingDuration;
    _remainingTimeNotifier.value = _recordingDuration;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingTime > 0) {
        _remainingTime--;
        _remainingTimeNotifier.value = _remainingTime;
      } else {
        timer.cancel();
      }
    });
  }

  /// Připraví kameru a analýzu ještě před začátkem záznamu.
  ///
  /// Tohle všechno se dřív dělo až v okamžiku startu měření: reset analýzy,
  /// rozsvícení světla a zamknutí expozice. Kamera na to reaguje skokem jasu
  /// a filtry se rozjíždějí od nuly, takže na začátku každého záznamu vznikl
  /// velký přechodový jev — v datech z měření 2026 mělo 68 % záznamů v první
  /// sekundě víc než dvojnásobný rozkmit a ustálení trvalo 2–4 s. Teď to celé
  /// proběhne během odpočtu, takže záznam začíná na ustáleném signálu.
  Future<void> _prepareCapture() async {
    _signalQualityChecker.reset();
    _ppgAlgorithm?.reset();

    // Pojistka pro pripad, ze stream neni v chodu - jinak by zaznam bezel
    // naprazdno a vysledkem by byl prazdny soubor.
    if (_hasInitializedCameraController && !_isStreamingImages) {
      _startImageStream();
    }

    // Svitilna uz obvykle sviti od prichodu na obrazovku mereni. Kdyz ji
    // uzivatel zhasnul, rozsviti se tady a da se automatice kamery cas;
    // jinak staci kratke doladeni na prst, ktery uzivatel prave prilozil.
    if (_hasInitializedCameraController && !_isFlashOn) {
      await _setTorch(true);
      await Future.delayed(_torchSettleDelay);
    } else {
      await Future.delayed(_fingerSettleDelay);
    }

    // Lock focus/exposure now that the torch is on and the finger is in place.
    // Auto-exposure otherwise keeps chasing the pulse-driven brightness change
    // and cancels out the very modulation we are trying to measure. Locking at
    // camera init instead would freeze the settings of the empty scene.
    await _lockCaptureSettings();
    await Future.delayed(_analysisWarmupDelay);
  }

  void _startRecording() async {
    if (_isRecording) return; // Prevent multiple recordings
    // Validate recording duration
    if (_recordingDuration < 10 || _recordingDuration > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).homeDurationOutOfRange),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_recordingDuration < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              L10n.of(context).homeHrvDurationHint),
          duration: Duration(seconds: 3),
        ),
      );
    }

    // Příprava normálně doběhla během odpočtu; když se sem přijde jinudy,
    // dožene se tady.
    await (_preparation ??= _prepareCapture());
    _preparation = null;
    if (!mounted || _isRecording) return;

    _measurementStartedAt = DateTime.now();
    setState(() {
      _progressController.duration = Duration(seconds: _recordingDuration);
      _isRecording = true;
      appbar_text = L10n.of(context).homeMeasuring;
      _remainingTime = _recordingDuration;
      _buttonLabel = L10n.of(context).homeStopButton;
    });
    _startRecordBuffer();
    _initializeTimers();
    _startAccelerometerStream();
    _progressController.forward();
  }

  /// Otevře buffer nového záznamu. Zobrazovací pipeline i stav filtrů zůstávají
  /// běžet: kdyby se tu čistilo všechno jako dřív, graf by na okamžik zmizel
  /// a do začátku záznamu by se propsal náběh mediánu, baseline a EMA od nuly
  /// (proto starší exporty začínají nulami a hned za nimi velkým výkyvem).
  void _startRecordBuffer() {
    _fullRecordData = [];
  }

  Future<void> _startCountdown() async {
    // Ve vyzkumnem rezimu se nejdriv vyplni udaje k mereni. Zrusenim dialogu
    // se mereni nespusti, aby zaznam nikdy nezustal bez identifikace.
    if (AppSettings.value.researchMode) {
      final values = await ResearchMetadataDialog.show(
        context,
        fields: AppSettings.value.researchFields,
        initialValues: _measurementMetadata,
      );
      if (values == null || !mounted) return;
      _measurementMetadata = values;
    } else {
      _measurementMetadata = const {};
    }

    setState(() {
      _isCountdownRunning = true;
      appbar_text = L10n.of(context).homeGetReady;
      _buttonLabel = '3';
    });
    // Kamera i analýza se připraví na pozadí, zatímco běží odpočet.
    _preparation = _prepareCapture();
    // Voice announcement for seniors
    TtsService.instance.announceCountdown(L10n.of(context).ttsCountdown);
    int count = 3;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      count--;
      if (count > 0) {
        setState(() {
          _buttonLabel = '$count';
        });
      } else {
        timer.cancel();
        setState(() {
          _isCountdownRunning = false;
        });
        _startRecording();
      }
    });
  }

  Future<void> _navigateToSummaryPage() async {
    double averageBPM = _ppgAlgorithm?.getSummary() ?? 0;
    bpm_list.add(averageBPM.toInt());
    List<double> framesList = _ppgAlgorithm?.getFrames() ?? [];
    List<double> respiratoryRates = _ppgAlgorithm?.getRespiratoryRates() ?? [];


    double averageRR = 0.0;
    if (respiratoryRates.isNotEmpty) {
      // Filter out zero values and calculate average of valid measurements
      final validRates = respiratoryRates.where((r) => r > 0).toList();
      if (validRates.isNotEmpty) {
        averageRR = validRates.reduce((a, b) => a + b) / validRates.length;
      } else {
        averageRR = 0.0; // validRates empty -> unknown RR
      }
    } else {
      averageRR = 0.0; // no RR available
    }
    if (_hasInitializedCameraController) {
      await _cameraController.setFlashMode(FlashMode.off);
    }
    // The torch call is a platform round-trip; the user may have navigated away
    // in the meantime, and everything below touches context.
    if (!mounted) return;
    setState(() {
      _isFlashOn = false;
      _isRecording = false; // Ensure recording state is reset
      appbar_text = L10n.of(context).homeReady;
      _remainingTime = _recordingDuration;
      _signalQuality = SignalQuality.bad; // Reset kvality
    });
    // Haptics for UX: signal completion
    HapticFeedback.lightImpact();
    // Voice announcement for seniors (do not block navigation)
    // Fire-and-forget to avoid getting stuck on awaitSpeakCompletion
    // ignore: unawaited_futures
    TtsService.instance.announceMeasurementEnd(L10n.of(context).ttsMeasurementEnd);
    // Log measurement completion locally and increment local counter
    try {
      // Local logger (non-blocking)
      // ignore: unawaited_futures
      Future(() async {
        try {
          final prefs = await SharedPreferences.getInstance();
          final count = prefs.getInt('measurements_count') ?? 0;
          await prefs.setInt('measurements_count', count + 1);
          await prefs.setString(
              'last_measurement_time', DateTime.now().toIso8601String());
        } catch (e) {
          debugPrint('Failed to update measurement counter: $e');
        }
      });
    } catch (e) {
      debugPrint('Failed to schedule counter update: $e');
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Summary(
          averageBPM: averageBPM,
          data: _fullRecordData.map((s) => s.y).toList(),
          bpm_list: bpm_list,
          frames: framesList,
          recordingDuration:
              _recordingDuration, // Přidáno: Předání délky měření
          startedAt: _measurementStartedAt ??
              DateTime.now().subtract(Duration(seconds: _recordingDuration)),
          respiratoryRate: averageRR, // Přidáno: Předání RR
          sdnn: _ppgAlgorithm?.getSdnn() ?? 0.0,
          rmssd: _ppgAlgorithm?.getRmssd() ?? 0.0,
          pnn50: _ppgAlgorithm?.getPnn50() ?? 0.0,
          sd1: _ppgAlgorithm?.getSd1() ?? 0.0,
          sd2: _ppgAlgorithm?.getSd2() ?? 0.0,
          spo2: _ppgAlgorithm?.getSummarySpO2() ?? 0.0,
          bpmHistory: _ppgAlgorithm?.getBpmHistory() ?? const [],
          rawRgbSamples: _ppgAlgorithm?.getRawRgbSamples() ?? const [],
          frameTimestampsMs: _ppgAlgorithm?.getFrameTimestamps() ?? const [],
          metadata: _measurementMetadata,
          bpmConfidence: _ppgAlgorithm?.currentBpmConfidence ?? 0.0,
          bpmSnrScore: _ppgAlgorithm?.currentBpmSnrScore ?? 0.0,
          bpmHarmonicScore: _ppgAlgorithm?.currentBpmHarmonicScore ?? 0.0,
          bpmAutocorrScore: _ppgAlgorithm?.currentBpmAutocorrScore ?? 0.0,
        ),
      ),
    );
  }

  // Y-axis scaling from raw detrended values. Data points are never rescaled.
  void _updateYAxisScale() {
    _samplesSinceLastScaleUpdate++;
    if (_samplesSinceLastScaleUpdate < 150) return;

    if (_smoothedData.isEmpty) return;

    // Use the last 150 samples for scaling (or all if less)
    final recentData = _smoothedData.length >= 150
        ? _smoothedData.sublist(_smoothedData.length - 150)
        : _smoothedData;
    final maxAbsY = recentData.map((spot) => spot.y.abs()).reduce(max);

    // Keep a margin so peaks do not touch chart bounds.
    final rawTarget = (maxAbsY * 1.15).clamp(0.05, 10.0);
    const step = 0.1;
    final quantized = (rawTarget / step).ceil() * step;

    // Hysteresis to avoid frequent oscillation.
    if (quantized > _yAxisHalfRange * 1.1 ||
        quantized < _yAxisHalfRange * 0.85) {
      _yAxisHalfRange = quantized;
    }

    _samplesSinceLastScaleUpdate = 0;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _accelerometerSubscription?.cancel();
    if (_isStreamingImages) {
      _cameraController.stopImageStream();
    }
    if (_hasInitializedCameraController) {
      _cameraController.dispose();
    }
    _elapsed.stop();
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _heartAnimationController.dispose();
    _progressController.dispose();
    _ppgAlgorithm?.dispose();
    _chartRevision.dispose();
    _bpmNotifier.dispose();
    _qualityNotifier.dispose();
    _remainingTimeNotifier.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // When route changes, stop streaming/animations to avoid background activity
    _stopAllActivity(disposeCamera: false);
    super.deactivate();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Also re-fires when the locale changes, so an idle screen follows a
    // language switch instead of keeping the previous language's labels.
    if (!_isRecording && !_isCountdownRunning) {
      appbar_text = L10n.of(context).homeReady;
      _buttonLabel = L10n.of(context).homeStartButton;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    try {
      if (!_hasInitializedCameraController) return;
      if (state == AppLifecycleState.inactive ||
          state == AppLifecycleState.paused) {
        if (_isStreamingImages) {
          _cameraController.stopImageStream();
        }
        // Svitilna sviti uz od prichodu na obrazovku, takze se v pozadi musi
        // zhasnout - jinak by telefon svitil uzivateli v kapse.
        _setTorch(false);
      } else if (state == AppLifecycleState.resumed) {
        if (_hasInitializedCameraController && !_isStreamingImages) {
          _startImageStream();
          _setTorch(true);
        }
      }
    } catch (e) {
      debugPrint('Lifecycle handling error: $e');
    }
    super.didChangeAppLifecycleState(state);
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double cameraSize =
        (screenWidth * 0.22).clamp(88.0, 130.0).toDouble();
    final double sideWidth = (screenWidth * 0.18).clamp(64.0, 100.0).toDouble();
    final double graphHeight =
        (screenHeight * 0.18).clamp(120.0, 180.0).toDouble();
    final double paddingSmall =
        (screenHeight * 0.009).clamp(6.0, 10.0).toDouble();
    final double paddingMedium =
        (screenHeight * 0.017).clamp(10.0, 18.0).toDouble();
    final double iconSizeMedium =
        (screenWidth * 0.08).clamp(26.0, 36.0).toDouble();
    final double fontSizeLarge =
        (screenWidth * 0.085).clamp(28.0, 40.0).toDouble();
    final double fontSizeMedium =
        (screenWidth * 0.038).clamp(13.0, 17.0).toDouble();
    final double fontSizeSmall =
        (screenWidth * 0.033).clamp(11.0, 15.0).toDouble();

    final currentCamera =
        _backCameras.isNotEmpty ? _backCameras[_currentBackCameraIndex] : null;
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Fire-and-forget: the route is already going away.
          unawaited(_stopAllActivity(disposeCamera: true));
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevent keyboard from resizing UI
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          centerTitle: true,
          toolbarHeight: 76,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.only(top: paddingSmall * 0.6),
                child: Text(
                  appbar_text,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: fontSizeMedium,
                  ),
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: paddingMedium * 2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // BPM display vlevo od kamery
                    if (_showBPM) ...[
                      Container(
                        width: sideWidth,
                        padding: EdgeInsets.only(right: paddingSmall),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ValueListenableBuilder<double>(
                              valueListenable: _bpmNotifier,
                              builder: (context, bpm, _) {
                                // Three digits at the full font size overflow
                                // this column and wrap onto a second line, so
                                // scale down instead of wrapping.
                                return FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    // No reading yet: say so instead of showing
                                    // a placeholder number.
                                    bpm > 0 ? bpm.round().toString() : L10n.of(context).homeNoReading,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: fontSizeLarge,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                );
                              },
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ScaleTransition(
                                    scale: _heartAnimationController.drive(
                                      Tween<double>(begin: 0.9, end: 1.3),
                                    ),
                                    child: Icon(
                                      Icons.favorite,
                                      color: Colors.red,
                                      size:
                                          iconSizeMedium * 0.6, // Smaller heart
                                    ),
                                  ),
                                  SizedBox(width: paddingSmall),
                                  Text(
                                    L10n.of(context).homeBpmUnit,
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(fontSize: fontSizeSmall),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Camera preview v kruhu. Only the border colour depends on
                    // signal quality, so the preview itself stays out of the
                    // rebuild path.
                    ValueListenableBuilder<SignalQuality>(
                      valueListenable: _qualityNotifier,
                      builder: (context, quality, child) => Container(
                        width: cameraSize,
                        height: cameraSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: currentCamera != null
                              ? Colors.black
                              : Colors.grey, // Background pro kruh
                          border: Border.all(
                            color: quality == SignalQuality.good
                                ? Colors.green
                                : Colors.red,
                            width: 4,
                          ),
                        ),
                        child: child,
                      ),
                      child: currentCamera != null
                          ? ClipOval(
                              child: SizedBox(
                                width: cameraSize,
                                height: cameraSize,
                                child: CameraBody(
                                  key: ValueKey(
                                      _currentBackCameraIndex), // Force rebuild on switch
                                  cameraDescription: currentCamera,
                                  onCameraReady: (controller) {
                                    setState(() {
                                      _cameraController = controller;
                                    });
                                    _startImageStream();
                                    _startGraphUpdates();
                                    // Bez svetla se merit neda, takze se
                                    // rozsviti hned po prichodu na obrazovku
                                    // mereni. Automatika kamery se tim stihne
                                    // ustalit jeste pred odpoctem.
                                    _setTorch(true);
                                  },
                                  onImageAvailable: (image) {
                                    // Nepoužíváme, protože stream je v _startImageStream
                                  },
                                ),
                              ),
                            )
                          : const Center(child: CircularProgressIndicator()),
                    ),
                    // Quality control vpravo od kamery
                    Container(
                      width: sideWidth,
                      padding: EdgeInsets.only(left: paddingSmall),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            L10n.of(context).homeQualityLabel,
                            style: TextStyle(
                              fontSize: fontSizeSmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: paddingSmall),
                          ValueListenableBuilder<SignalQuality>(
                            valueListenable: _qualityNotifier,
                            builder: (context, quality, _) => FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Icon(
                                    quality == SignalQuality.good
                                        ? Icons.check_circle
                                        : Icons.error,
                                    color: quality == SignalQuality.good
                                        ? Colors.green
                                        : Colors.red,
                                    size: iconSizeMedium * 0.5,
                                  ),
                                  SizedBox(width: paddingSmall * 0.5),
                                  Text(
                                    _qualityLabel(quality),
                                    maxLines: 1,
                                    softWrap: false,
                                    style: TextStyle(
                                      fontSize: fontSizeSmall,
                                      fontWeight: FontWeight.w500,
                                      color: quality == SignalQuality.good
                                          ? Colors.green
                                          : Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: paddingMedium * 2.2),
              Container(
                padding: EdgeInsets.only(top: paddingSmall),
                width: double.infinity,
                height: graphHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    return RepaintBoundary(
                      // Only this subtree repaints on new samples; the rest of
                      // the screen is rebuilt only on real state changes.
                      child: ValueListenableBuilder<int>(
                        valueListenable: _chartRevision,
                        builder: (context, _, __) {
                          final double minX = _currentTime - _windowTime;
                          final double maxX = _currentTime;
                          final double minY = -_yAxisHalfRange;
                          final double maxY = _yAxisHalfRange;
                          return Stack(
                            clipBehavior:
                                Clip.none, // Allow overflow (e.g., beyond left)
                            children: [
                              LineChart(
                                LineChartData(
                                  clipData: const FlClipData(
                                    // Allow beyond left, clip others
                                    left: false,
                                    right: true,
                                    top: true,
                                    bottom: true,
                                  ),
                                  gridData: const FlGridData(
                                    show: false, // Mřížka je vypnutá
                                  ),
                                  titlesData: const FlTitlesData(
                                    show: false, // Skryté pro čistý vzhled
                                  ),
                                  borderData: FlBorderData(
                                    show: true,
                                    border: Border.all(
                                        color: Colors.grey.withValues(alpha: 0.3)),
                                  ),
                                  minX: minX,
                                  maxX: maxX,
                                  minY: minY,
                                  maxY: maxY,
                                  lineBarsData: [
                                    LineChartBarData(
                                      spots: _smoothedData,
                                      isCurved: false, // Přímá čára pro signál
                                      color:
                                          const Color.fromARGB(255, 246, 41, 0),
                                      barWidth: 2.0,
                                      isStrokeCapRound: true,
                                      dotData: const FlDotData(show: false),
                                      belowBarData: BarAreaData(
                                        show: false,
                                      ),
                                    ),
                                    // Peak markers as a separate series (dots only)
                                    LineChartBarData(
                                      spots: _peakSpots,
                                      isCurved: false,
                                      color: Colors.transparent,
                                      barWidth: 0,
                                      dotData: FlDotData(
                                        show: true,
                                        getDotPainter:
                                            (spot, percent, barData, index) =>
                                                FlDotCirclePainter(
                                          radius: 3,
                                          color: Colors.blue,
                                          strokeWidth: 0,
                                        ),
                                      ),
                                      belowBarData: BarAreaData(show: false),
                                    ),
                                  ],
                                ),
                                duration: Duration
                                    .zero, // No animation to avoid "sucked" transform
                                // Removed curve since no duration
                              ),
                              // Vertikální čáry pro časové značky
                              ..._labels.map((label) {
                                final posX =
                                    ((label.x - minX) / (maxX - minX + 1e-6)) *
                                        chartWidth;
                                return Positioned(
                                  left: posX,
                                  top: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 1.0,
                                    color: Colors.grey.withValues(alpha: 0.5),
                                  ),
                                );
                              }),
                              // Texty pro časové značky (pod čarami)
                              ..._labels.map((label) {
                                final posX =
                                    ((label.x - minX) / (maxX - minX + 1e-6)) *
                                        chartWidth;
                                return Positioned(
                                  left: posX,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 4),
                                    child: Text(
                                      label.time,
                                      style: const TextStyle(
                                          fontSize: 10, color: Colors.black),
                                    ),
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: paddingMedium, vertical: 0),
                child: AnimatedBuilder(
                  animation: _progressController,
                  builder: (context, child) {
                    return LinearProgressIndicator(
                      value: _progressController.value,
                      backgroundColor: Colors.grey[300],
                      valueColor:
                          const AlwaysStoppedAnimation<Color>(Colors.red),
                    );
                  },
                ),
              ),
              // Countdown timer display
              if (_isRecording)
                Padding(
                  padding: EdgeInsets.only(top: paddingSmall),
                  child: Center(
                    child: ValueListenableBuilder<int>(
                      valueListenable: _remainingTimeNotifier,
                      builder: (context, remaining, _) => Text(
                        '$remaining s',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: fontSizeMedium,
                          fontWeight: FontWeight.w500,
                          color: Colors.black,
                        ),
                      ),
                    ),
                  ),
                ),
              SizedBox(height: paddingMedium * 1.2),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: paddingSmall),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: (screenWidth * 0.92).clamp(300.0, 420.0),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final controlsHeight =
                            (screenWidth * 0.45).clamp(140.0, 180.0).toDouble();
                        final sideOffset = constraints.maxWidth * 0.05;
                        final sideControlsTop = (controlsHeight * 0.45)
                            .clamp(72.0, 102.0)
                            .toDouble();
                        return SizedBox(
                          height: controlsHeight,
                          child: Stack(
                            alignment: Alignment.topCenter,
                            children: [
                              Align(
                                alignment: Alignment.topCenter,
                                child: SizedBox(
                                  width:
                                      (screenWidth * 0.34).clamp(120.0, 152.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.max,
                                    children: [
                                      Text(
                                        L10n.of(context).homeDurationLabel,
                                        style: TextStyle(
                                          fontSize: fontSizeSmall * 0.9,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      Flexible(
                                        fit: FlexFit.loose,
                                        child: IgnorePointer(
                                          ignoring: _isRecording,
                                          child: Opacity(
                                            opacity: _isRecording ? 0.5 : 1.0,
                                            child: NumberPicker(
                                              value: _recordingDuration,
                                              minValue: 10,
                                              maxValue: 300,
                                              step: 10,
                                              itemWidth: (screenWidth * 0.11)
                                                  .clamp(38.0, 54.0),
                                              onChanged: (value) {
                                                setState(() {
                                                  _recordingDuration = value;
                                                  _remainingTime = value;
                                                });
                                              },
                                              textStyle: TextStyle(
                                                fontSize: fontSizeSmall * 0.9,
                                                color: Colors.grey,
                                              ),
                                              selectedTextStyle: TextStyle(
                                                fontSize: fontSizeMedium * 0.92,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.black,
                                              ),
                                              decoration: BoxDecoration(
                                                border: Border.all(
                                                    color: Colors.grey,
                                                    width: 1),
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                left: sideOffset,
                                top: sideControlsTop,
                                child: SizedBox(
                                  width:
                                      (screenWidth * 0.22).clamp(82.0, 102.0),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.center,
                                    children: [
                                      IconButton(
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: (_backCameras.length < 2 ||
                                                _isSwitchingCamera)
                                            ? null
                                            : _switchBackCamera,
                                        icon: Icon(
                                          Icons.cameraswitch,
                                          color: Colors.grey,
                                          size: iconSizeMedium * 0.9,
                                        ),
                                        tooltip: L10n.of(context).homeSwitchCamera,
                                      ),
                                      Text(
                                        L10n.of(context).homeChangeCamera,
                                        style: TextStyle(
                                          fontSize: fontSizeSmall * 0.9,
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Positioned(
                                right: sideOffset,
                                top: sideControlsTop,
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.grey.withValues(alpha: 0.3),
                                        spreadRadius: 1,
                                        blurRadius: 3,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: IconButton(
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                    onPressed: _toggleFlashlight,
                                    icon: Icon(
                                      _isFlashOn
                                          ? CupertinoIcons.bolt_fill
                                          : CupertinoIcons.bolt_slash_fill,
                                      color: _isFlashOn
                                          ? const Color.fromARGB(255, 0, 0, 0)
                                          : Colors.grey,
                                      size: iconSizeMedium * 0.9,
                                    ),
                                    tooltip: _isFlashOn
                                        ? L10n.of(context).homeTorchOff
                                        : L10n.of(context).homeTorchOn,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              SizedBox(height: paddingMedium * 0.9),
              ElevatedButton(
                onPressed: _isCountdownRunning
                    ? null
                    : (_isRecording ? _stopRecording : _startCountdown),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black,
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05, vertical: paddingSmall),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return ScaleTransition(scale: animation, child: child);
                  },
                  child: Text(
                    _buttonLabel,
                    key: ValueKey<String>(_buttonLabel),
                    style: TextStyle(
                      fontSize: fontSizeSmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: paddingMedium), // Extra padding
            ],
          ),
        ),
        bottomNavigationBar: GNav(
          tabMargin: EdgeInsets.symmetric(horizontal: paddingSmall),
          gap: 0,
          activeColor: Colors.black,
          iconSize: iconSizeMedium * 0.8,
          backgroundColor: Colors.white,
          color: Colors.grey,
          selectedIndex: _selectedIndex,
          onTabChange: _onItemTapped,
          tabs: [
            GButton(
              icon: Symbols.family_home,
              text: L10n.of(context).navMenu,
            ),
            GButton(
              icon: Symbols.ecg_heart,
              text: L10n.of(context).navMeasure,
            ),
            GButton(
              icon: Symbols.help,
              text: L10n.of(context).navInfo,
            ),
          ],
        ),
      ),
    );
  }
}
