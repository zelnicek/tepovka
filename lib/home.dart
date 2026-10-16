import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tepovka/services/haptics.dart';
import 'package:tepovka/elements/camera_body.dart';
import 'package:tepovka/ppg_algo.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
import 'package:tepovka/pages/summary_page.dart';
import 'dart:math';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/about.dart';
import 'package:numberpicker/numberpicker.dart';
import 'package:tepovka/elements/research_metadata_dialog.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/services/camera_lock.dart';
import 'package:tepovka/pages/measure_guide.dart';
import 'package:tepovka/elements/signal_quality_checker.dart'; // Import samostatné třídy pro kvalitu
import 'package:tepovka/elements/peak_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/services/tts_service.dart';
import 'package:tepovka/services/reminder_service.dart';
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
  bool _isFlashOn = false; // Tracks flashlight state
  String appBarText = '';
  List<int> bpmList = [];
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

  /// Nastavení kamery hned po zamčení a po případném ubrání expozice kvůli
  /// přepálené červené (bez ubírání jsou totožná). Na iOS; jinde null.
  CameraSettings? _cameraAtLock;
  CameraSettings? _cameraLocked;
  int _exposureReductionSteps = 0;

  /// Proč se stahování expozice zastavilo (jen ve výzkumném režimu); jde do
  /// exportu, aby se dalo poznat, jestli zbylé přepálení šlo vůbec odstranit.
  String? _exposureStopReason;

  /// Zvyšuje se při každém zrušení měření. Příprava kamery běží souběžně
  /// s odpočtem a podle změny pozná, že už na kameru nesmí sahat — jinak by
  /// po zrušení zamkla vyvážení bílé, které by přežilo do dalšího měření.
  int _captureGeneration = 0;

  /// Je otevřený návod, jak měřit. Svítilna mezitím zůstává zhasnutá.
  bool _guideOpen = false;

  /// Kolikrát nejvýš se ubere 1 EV, a jak dlouho se po každém kroku sbírají
  /// snímky pro rozhodnutí o dalším. Čtyři kroky = šestnáctkrát méně světla,
  /// víc už by zelený kanál zapadl do šumu.
  static const int _maxExposureReductionSteps = 4;
  static const Duration _clipProbeWindow = Duration(milliseconds: 300);

  String get _cameraId => _cameraController.description.name;

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

  /// Starts at "no finger": before the first frame there is nothing to judge,
  /// and showing "weak signal" in red on arrival read like an error.
  final ValueNotifier<SignalQuality> _qualityNotifier =
      ValueNotifier<SignalQuality>(SignalQuality.noFinger);

  /// Whether a frame has been judged since the last reset. The first verdict
  /// is always announced, even when it matches the neutral starting value.
  bool _qualityKnown = false;

  /// Lengths offered as one tap; anything else goes through "Other".
  static const List<int> _durationPresets = [20, 30, 60, 120];
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
    // Kdo sem přichází poprvé, uvidí nejdřív návod, jak měřit.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowGuide());
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
    if (_qualityNotifier.value != _signalQuality || !_qualityKnown) {
      _qualityKnown = true;
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
      Haptics.selection();
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
      appBarText = L10n.of(context).homeReady;
      _remainingTime = _recordingDuration;
      _signalQuality = SignalQuality.bad; // Reset kvality
      _buttonLabel = L10n.of(context).homeStartButton;
      _yAxisHalfRange = 1.5;
      _samplesSinceLastScaleUpdate = 0;
    });
    _qualityKnown = false;
    _qualityNotifier.value = SignalQuality.noFinger;
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
        // The home screen is the root route and is still underneath. Pushing
        // a new one stacked another copy on top every time.
        Navigator.of(context).popUntil((route) => route.isFirst);
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
    _captureGeneration++;
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

  /// Zapne nebo zhasne svitilnu a udrzi [_isFlashOn] v souladu se skutecnosti.
  Future<void> _setTorch(bool on) async {
    if (!_hasInitializedCameraController || _isTeardown) return;
    // Nad obrazovkou je návod: svítit uživateli do ruky, zatímco čte, nemá
    // smysl a telefon se zbytečně zahřívá. Rozsvítí se po zavření návodu.
    if (on && _guideOpen) return;
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

  /// Freezes focus, exposure and — on iOS — white balance, so the camera's
  /// automatics can neither track the pulse nor rebalance the colour channels.
  /// Failures are non-fatal: not every device exposes these controls.
  Future<void> _maybeShowGuide() async {
    if (!mounted || !await MeasureGuide.shouldShowOnFirstVisit()) return;
    if (!mounted) return;
    await _openGuide();
  }

  /// Otevře návod, jak měřit; svítilnu zatím zhasne a pak ji zase rozsvítí.
  Future<void> _openGuide() async {
    if (_guideOpen || _isRecording || _isCountdownRunning) return;
    _guideOpen = true;
    await _setTorch(false);
    if (!mounted) {
      _guideOpen = false;
      return;
    }
    await MeasureGuide.open(context);
    _guideOpen = false;
    if (mounted) await _setTorch(true);
  }

  Future<void> _lockCaptureSettings() async {
    _cameraAtLock = null;
    _cameraLocked = null;
    _exposureReductionSteps = 0;
    _exposureStopReason = null;
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
    // Plugin camera vyvážení bílé zamknout neumí, takže by celé měření
    // přepočítávalo poměr kanálů. Nativní zámek ho přidá, expozici a ostření
    // zmrazí na přesných hodnotách a vrátí je pro export.
    _cameraAtLock = await CameraLock.lock(_cameraId);
    _cameraLocked = _cameraAtLock;
  }

  /// Ubírá expozici po 1 EV, dokud červený kanál naráží na strop rozsahu.
  ///
  /// Automatika expozice měří hlavně zelenou, která je přes prst s bleskem
  /// tmavá, a vytáhne expozici tak vysoko, že červená přepálí. Pro tep je to
  /// jedno, ale přepálená červená nemá pulzní složku, kterou potřebuje odhad
  /// saturace. Vrací true, pokud se expozice změnila.
  Future<bool> _keepRedBelowClipping(int generation) async {
    final algorithm = _ppgAlgorithm;
    final locked = _cameraLocked;
    if (algorithm == null || locked == null) return false;
    CameraSettings camera = locked;
    CameraSettings? beforeLastStep;
    var changed = false;
    for (var step = 0;; step++) {
      algorithm.takeClipWindow();
      await Future.delayed(_clipProbeWindow);
      if (!mounted ||
          generation != _captureGeneration ||
          !_hasInitializedCameraController) {
        break;
      }
      final window = algorithm.takeClipWindow();
      final decision = decideExposureStep(
        frames: window.frames,
        redClipFraction: window.redFraction,
        greenMean: algorithm.getLastRgbMeans().green,
        stepsTaken: _exposureReductionSteps,
        maxSteps: _maxExposureReductionSteps,
      );
      _exposureStopReason = decision.reason;

      if (decision.action == ExposureAction.revert) {
        // Poslední krok stáhl zelenou do tmy: vrátit ho. Červená pak zůstane
        // přepálená, ale tep ze zelené je důležitější a přepálení je vidět.
        final previous = beforeLastStep;
        final duration = previous?.exposureDurationS;
        final iso = previous?.iso;
        if (duration != null && iso != null) {
          final restored = await CameraLock.setExposure(
              _cameraId, ExposureTarget(durationS: duration, iso: iso));
          if (restored != null) {
            camera = restored;
            _exposureReductionSteps--;
          }
        }
        break;
      }
      if (decision.action != ExposureAction.reduce) break;

      final target = reducedExposure(camera);
      if (target == null) {
        _exposureStopReason = 'min_exposure';
        break;
      }
      final applied = await CameraLock.setExposure(_cameraId, target);
      if (generation != _captureGeneration) {
        // Měření se mezitím zrušilo a kamera je odemčená; nastavená expozice
        // by na ní jinak zůstala viset.
        await CameraLock.unlock(_cameraId);
        return false;
      }
      if (applied == null) {
        _exposureStopReason = 'unavailable';
        break;
      }
      if (!changed && mounted) {
        setState(() {
          appBarText = L10n.of(context).homeAdjustingCamera;
        });
      }
      beforeLastStep = camera;
      camera = applied;
      _exposureReductionSteps++;
      changed = true;
    }
    _cameraLocked = camera;
    return changed;
  }

  /// Restores auto focus, exposure and white balance once a measurement ends.
  Future<void> _unlockCaptureSettings() async {
    if (!_hasInitializedCameraController) return;
    await CameraLock.unlock(_cameraId);
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
    final generation = _captureGeneration;
    _signalQualityChecker.reset();
    _ppgAlgorithm?.reset();

    // Pojistka pro pripad, ze stream neni v chodu - jinak by zaznam bezel
    // naprazdno a vysledkem by byl prazdny soubor.
    if (_hasInitializedCameraController && !_isStreamingImages) {
      _startImageStream();
    }

    // Zámek z přerušeného měření by jinak přežil a vyvážení bílé by se
    // nedorovnalo na právě přiložený prst.
    if (_hasInitializedCameraController) {
      await CameraLock.unlock(_cameraId);
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

    // Zrušeno během ustalování: zamykat už nic, kamera je zpátky v automatice.
    if (generation != _captureGeneration) return;

    // Lock focus, exposure and white balance now that the torch is on and the
    // finger is in place. Auto-exposure otherwise keeps chasing the
    // pulse-driven brightness change and cancels out the very modulation we
    // are trying to measure. Locking at camera init instead would freeze the
    // settings of the empty scene.
    await _lockCaptureSettings();
    // Ve výzkumném režimu se navíc hlídá přepálení červeného kanálu. Krok
    // expozice je pro filtry skok jasu, takže se analýza po něm spustí znovu
    // a zobrazovací pipeline dostane celé okno nulové linie na srovnání.
    if (AppSettings.value.researchMode &&
        await _keepRedBelowClipping(generation)) {
      _signalQualityChecker.reset();
      _ppgAlgorithm?.reset();
      await Future.delayed(
          Duration(milliseconds: (_baselineWindowSeconds * 1000).round()));
    }
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

    // The HRV length advice used to pop up here on every short measurement;
    // it now sits under the duration selector, where the choice is made.

    // Příprava normálně doběhla během odpočtu; když se sem přijde jinudy,
    // dožene se tady.
    await (_preparation ??= _prepareCapture());
    _preparation = null;
    if (!mounted || _isRecording) return;

    _measurementStartedAt = DateTime.now();
    setState(() {
      _progressController.duration = Duration(seconds: _recordingDuration);
      _isRecording = true;
      appBarText = L10n.of(context).homeMeasuring;
      _remainingTime = _recordingDuration;
      _buttonLabel = L10n.of(context).homeStopButton;
    });
    _startRecordBuffer();
    _ppgAlgorithm?.resetRecordingClipping();
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
      appBarText = L10n.of(context).homeGetReady;
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
    bpmList.add(averageBPM.toInt());
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
    // Přepálení se zkopíruje hned: po odemčení se expozice znovu rozjede
    // a další snímky už k záznamu nepatří.
    final clipping = _ppgAlgorithm?.recordingClipping.copy();
    // Nastavení kamery se odečte ještě zamčené, aby šlo porovnat se stavem
    // na začátku; teprve pak se kamera vrátí do automatiky.
    CameraSettings? cameraAtEnd;
    if (_hasInitializedCameraController) {
      cameraAtEnd = await CameraLock.snapshot(_cameraId);
      await _unlockCaptureSettings();
    }
    final cameraReport = buildCameraReport(
      initial: _cameraAtLock,
      locked: _cameraLocked,
      atEnd: cameraAtEnd,
      exposureReductionSteps: _exposureReductionSteps,
      clipping: clipping,
      exposureStopReason: _exposureStopReason,
    );
    if (_hasInitializedCameraController) {
      await _cameraController.setFlashMode(FlashMode.off);
    }
    // The torch call is a platform round-trip; the user may have navigated away
    // in the meantime, and everything below touches context.
    if (!mounted) return;
    setState(() {
      _isFlashOn = false;
      _isRecording = false; // Ensure recording state is reset
      appBarText = L10n.of(context).homeReady;
      _remainingTime = _recordingDuration;
      _signalQuality = SignalQuality.bad; // Reset kvality
    });
    // Ve výzkumném režimu se na problém s kamerou upozorní hned, aby šlo
    // měření zopakovat, dokud je proband na místě.
    if (AppSettings.value.researchMode) {
      final l10n = L10n.of(context);
      final warning = cameraReport.settingsHeld == false
          ? l10n.homeCameraSettingsChanged
          : (cameraReport.redClipped ? l10n.homeRedChannelClipped : null);
      if (warning != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(warning),
          duration: const Duration(seconds: 6),
        ));
      }
    }
    // Haptics for UX: signal completion
    Haptics.light();
    // Voice announcement for seniors (do not block navigation)
    // Fire-and-forget to avoid getting stuck on awaitSpeakCompletion
    // ignore: unawaited_futures
    TtsService.instance
        .announceMeasurementEnd(L10n.of(context).ttsMeasurementEnd);
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
          // Measured today: today's reminder is no longer needed.
          await ReminderService.reschedule();
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
          bpmList: bpmList,
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
          cameraSettings: cameraReport.lines,
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
      appBarText = L10n.of(context).homeReady;
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

  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final bool busy = _isRecording || _isCountdownRunning;
    final double cameraSize = (r.width * 0.32).clamp(110.0, 140.0).toDouble();
    final double ringSize = cameraSize + r.spaceLg;
    final double graphHeight = (r.height * 0.12).clamp(84.0, 120.0).toDouble();

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
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _canvas,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            t.measureTitle,
            style:
                TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: t.homeHelp,
              // Během odpočtu a měření by návod měření přerušil.
              onPressed: busy ? null : _openGuide,
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              r.pagePadding.left, r.spaceXs, r.pagePadding.right, r.spaceLg),
          child: Column(
            children: [
              _statusPill(context),
              SizedBox(height: r.spaceLg),
              _cameraRing(context, currentCamera, cameraSize, ringSize),
              SizedBox(height: r.spaceMd),
              _bpmReadout(context),
              SizedBox(height: r.spaceSm),
              _signalChip(context),
              SizedBox(height: r.spaceSm),
              _hintLine(context),
              SizedBox(height: r.spaceMd),
              _chartCard(context, graphHeight),
              SizedBox(height: r.spaceLg),
              _durationSelector(context, enabled: !busy),
              SizedBox(height: r.spaceLg),
              _controlsRow(context),
            ],
          ),
        ),
        // Hidden while measuring: leaving mid-measurement should take a
        // deliberate Stop, not a stray tap on the bar.
        bottomNavigationBar: busy
            ? null
            : GNav(
                tabMargin: EdgeInsets.symmetric(horizontal: r.spaceSm),
                gap: 0,
                activeColor: Colors.black,
                iconSize: r.iconMd,
                backgroundColor: Colors.white,
                color: Colors.grey,
                selectedIndex: _selectedIndex,
                onTabChange: _onItemTapped,
                tabs: [
                  GButton(icon: Symbols.family_home, text: t.navMenu),
                  GButton(icon: Symbols.ecg_heart, text: t.navMeasure),
                  GButton(icon: Symbols.help, text: t.navInfo),
                ],
              ),
      ),
    );
  }

  /// What the screen is doing right now, with the time left while measuring.
  Widget _statusPill(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final Color background;
    final Color foreground;
    if (_isRecording) {
      background = kInfoAccentTint;
      foreground = const Color(0xFFB3261E);
    } else if (_isCountdownRunning) {
      background = const Color(0xFFFFF4E0);
      foreground = const Color(0xFF8A5300);
    } else {
      background = Colors.white;
      foreground = Colors.black87;
    }
    Widget label(String text) => Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
              fontSize: r.fontBody,
              fontWeight: FontWeight.w600,
              color: foreground),
        );
    return Container(
      padding:
          EdgeInsets.symmetric(horizontal: r.spaceMd, vertical: r.spaceXs + 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      // Only the label repaints each second, not the screen.
      child: _isRecording
          ? ValueListenableBuilder<int>(
              valueListenable: _remainingTimeNotifier,
              builder: (context, remaining, _) =>
                  label(t.measureRunning(remaining)),
            )
          : label(appBarText),
    );
  }

  /// Camera preview in a circle, with the measurement's progress drawn
  /// around it. While idle the ring turns green once the signal is good,
  /// which is the cue to start.
  Widget _cameraRing(BuildContext context, CameraDescription? camera,
      double cameraSize, double ringSize) {
    return SizedBox(
      width: ringSize,
      height: ringSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          RepaintBoundary(
            child: ValueListenableBuilder<SignalQuality>(
              valueListenable: _qualityNotifier,
              builder: (context, quality, _) => AnimatedBuilder(
                animation: _progressController,
                builder: (context, _) => CustomPaint(
                  size: Size.square(ringSize),
                  painter: _RingPainter(
                    progress: _isRecording ? _progressController.value : 0.0,
                    track: _isRecording
                        ? const Color(0xFFF6C9C6)
                        : (quality == SignalQuality.good
                            ? const Color(0xFFA5D6A7)
                            : const Color(0xFFDDDDDD)),
                    color: kInfoAccent,
                    width: 6,
                  ),
                ),
              ),
            ),
          ),
          Container(
            width: cameraSize,
            height: cameraSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: camera != null ? Colors.black : Colors.grey.shade400,
            ),
            child: camera != null
                ? ClipOval(
                    child: SizedBox(
                      width: cameraSize,
                      height: cameraSize,
                      child: CameraBody(
                        key: ValueKey(
                            _currentBackCameraIndex), // Force rebuild on switch
                        cameraDescription: camera,
                        onCameraReady: (controller) {
                          setState(() {
                            _cameraController = controller;
                          });
                          // Zámek vyvážení bílé drží na zařízení i po zavření
                          // kamery; nová obrazovka musí začínat v automatice.
                          unawaited(
                              CameraLock.unlock(controller.description.name));
                          _startImageStream();
                          _startGraphUpdates();
                          // Bez svetla se merit neda, takze se rozsviti hned
                          // po prichodu na obrazovku mereni. Automatika kamery
                          // se tim stihne ustalit jeste pred odpoctem.
                          _setTorch(true);
                        },
                        onImageAvailable: (image) {
                          // Nepoužíváme, protože stream je v _startImageStream
                        },
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  /// Live heart rate, or a dash until there is a reading.
  Widget _bpmReadout(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return ValueListenableBuilder<double>(
      valueListenable: _bpmNotifier,
      builder: (context, bpm, _) => Semantics(
        liveRegion: true,
        label: bpm > 0
            ? t.a11yHeartRateValue('${bpm.round()}')
            : t.a11yHeartRateUnknown,
        excludeSemantics: true,
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: bpm > 0 ? '${bpm.round()}' : t.homeNoReading,
              style: TextStyle(
                  fontSize: r.fontDisplayXl,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  color: Colors.black),
            ),
            TextSpan(
              text: ' ${t.homeBpmUnit} ',
              style:
                  TextStyle(fontSize: r.fontBodyLg, color: kInfoSecondaryText),
            ),
            WidgetSpan(
              alignment: PlaceholderAlignment.middle,
              child: ScaleTransition(
                scale: _heartAnimationController.drive(
                  Tween<double>(begin: 0.9, end: 1.3),
                ),
                child: Icon(Icons.favorite, color: kInfoAccent, size: r.iconSm),
              ),
            ),
          ]),
          maxLines: 1,
        ),
      ),
    );
  }

  /// Signal quality as a small coloured label. Grey until a finger is on the
  /// camera, amber for a weak signal, green when it is good.
  Widget _signalChip(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return ValueListenableBuilder<SignalQuality>(
      valueListenable: _qualityNotifier,
      builder: (context, quality, _) {
        final (String label, Color background, Color foreground, Color dot) =
            switch (quality) {
          SignalQuality.good => (
              t.measureSignalGood,
              const Color(0xFFE6F4EA),
              const Color(0xFF1E6B34),
              const Color(0xFF1E8E3E),
            ),
          SignalQuality.bad => (
              t.measureSignalWeak,
              const Color(0xFFFFF4E0),
              const Color(0xFF8A5300),
              const Color(0xFFE8A317),
            ),
          SignalQuality.poorContact => (
              t.qualityPoorContact,
              const Color(0xFFFFF4E0),
              const Color(0xFF8A5300),
              const Color(0xFFE8A317),
            ),
          SignalQuality.noFinger => (
              t.measureSignalNoFinger,
              const Color(0xFFE8E8E8),
              const Color(0xFF555555),
              const Color(0xFF9E9E9E),
            ),
        };
        return Semantics(
          liveRegion: true,
          label: t.a11ySignalQuality(_qualityLabel(quality)),
          excludeSemantics: true,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: r.spaceMd, vertical: r.spaceXs),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
                ),
                SizedBox(width: r.spaceXs + 2),
                Text(
                  label,
                  style: TextStyle(
                      fontSize: r.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: foreground),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Konkrétní pokyn podle kvality signálu: štítek nad ním říká, co je
  /// špatně, tahle věta co s tím. Výška je pevná na dva řádky, aby graf
  /// neposkakoval, když se pokyn změní.
  Widget _hintLine(BuildContext context) {
    final r = Responsive.of(context);
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(r.fontSmall) * 1.35 * 2,
      child: Center(
        child: ValueListenableBuilder<SignalQuality>(
          valueListenable: _qualityNotifier,
          builder: (context, quality, _) => Text(
            measureHint(L10n.of(context), quality),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: r.fontSmall,
              height: 1.35,
              color: quality == SignalQuality.good
                  ? const Color(0xFF1E6B34)
                  : kInfoSecondaryText,
            ),
          ),
        ),
      ),
    );
  }

  /// Live pulse wave in a white card.
  Widget _chartCard(BuildContext context, double graphHeight) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(r.spaceMd, r.spaceSm, r.spaceMd, r.spaceSm),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.measurePulseWave,
            style:
                TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText),
          ),
          SizedBox(height: r.spaceXs),
          SizedBox(
            height: graphHeight,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                return Semantics(
                  label: t.a11yLiveChart,
                  excludeSemantics: true,
                  child: RepaintBoundary(
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
                          clipBehavior: Clip.hardEdge,
                          children: [
                            LineChart(
                              LineChartData(
                                clipData: const FlClipData(
                                  left: false,
                                  right: true,
                                  top: true,
                                  bottom: true,
                                ),
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
                                borderData: FlBorderData(show: false),
                                minX: minX,
                                maxX: maxX,
                                minY: minY,
                                maxY: maxY,
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: _smoothedData,
                                    isCurved: false,
                                    color: kInfoAccent,
                                    barWidth: 2.0,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(show: false),
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
                                        color: const Color(0xFF1A73E8),
                                        strokeWidth: 0,
                                      ),
                                    ),
                                    belowBarData: BarAreaData(show: false),
                                  ),
                                ],
                              ),
                              duration: Duration
                                  .zero, // No animation to avoid "sucked" transform
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
                                  color: Colors.black.withValues(alpha: 0.06),
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
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 3),
                                  child: Text(
                                    label.time,
                                    style: const TextStyle(
                                        fontSize: 9, color: Colors.black38),
                                  ),
                                ),
                              );
                            }),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _setDuration(int seconds) {
    if (seconds == _recordingDuration) return;
    Haptics.selection();
    setState(() {
      _recordingDuration = seconds;
      _remainingTime = seconds;
    });
  }

  /// Any length from 10 to 300 s, for when the presets do not fit.
  Future<void> _pickCustomDuration() async {
    final L10n t = L10n.of(context);
    int value = _recordingDuration;
    final int? picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final r = Responsive.of(context);
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(r.spaceXl, 0, r.spaceXl, r.spaceLg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    t.homeDurationLabel,
                    style: TextStyle(
                        fontSize: r.fontTitle, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: r.spaceMd),
                  NumberPicker(
                    value: value,
                    minValue: 10,
                    maxValue: 300,
                    step: 10,
                    axis: Axis.horizontal,
                    itemWidth: r.iconXl * 2,
                    haptics: Haptics.enabled,
                    textMapper: (text) => t.homeSecondsSuffix(int.parse(text)),
                    onChanged: (v) => setSheetState(() => value = v),
                    textStyle: TextStyle(
                        fontSize: r.fontBody, color: kInfoSecondaryText),
                    selectedTextStyle: TextStyle(
                        fontSize: r.fontTitleLg,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),
                    // NumberPicker paints this over the selected value, so a
                    // filled box would hide it; outline only.
                    decoration: BoxDecoration(
                      border: Border.all(color: kInfoAccent, width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  SizedBox(height: r.spaceLg),
                  SizedBox(
                    width: double.infinity,
                    height: r.iconXl * 1.4,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: kInfoAccent,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => Navigator.pop(sheetContext, value),
                      child: Text(
                        t.commonDone,
                        style: TextStyle(
                            fontSize: r.fontBodyLg,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked != null && mounted) _setDuration(picked);
  }

  /// Measurement length as a row of options instead of a scroll wheel, with
  /// the HRV advice right where the choice is made. Stays in place (dimmed)
  /// while measuring so the screen does not jump.
  Widget _durationSelector(BuildContext context, {required bool enabled}) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final bool custom = !_durationPresets.contains(_recordingDuration);

    Widget option(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spaceXs / 2),
          child: Semantics(
            button: true,
            selected: selected,
            inMutuallyExclusiveGroup: true,
            label: label,
            excludeSemantics: true,
            child: Material(
              color: selected ? kInfoAccent : Colors.white,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: SizedBox(
                  height: r.iconXl * 1.15,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: r.spaceXs),
                        child: Text(
                          label,
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: r.fontBody,
                            fontWeight: FontWeight.w600,
                            color: selected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return IgnorePointer(
      ignoring: !enabled,
      child: AnimatedOpacity(
        opacity: enabled ? 1.0 : 0.4,
        duration: const Duration(milliseconds: 200),
        child: Column(
          children: [
            Text(
              t.homeDurationLabel,
              style: TextStyle(
                  fontSize: r.fontSmall,
                  fontWeight: FontWeight.w600,
                  color: kInfoSecondaryText),
            ),
            SizedBox(height: r.spaceSm),
            Row(
              children: [
                for (final int seconds in _durationPresets)
                  option(
                      t.homeSecondsSuffix(seconds),
                      _recordingDuration == seconds,
                      () => _setDuration(seconds)),
                option(
                  custom
                      ? t.homeSecondsSuffix(_recordingDuration)
                      : t.measureDurationOther,
                  custom,
                  _pickCustomDuration,
                ),
              ],
            ),
            SizedBox(height: r.spaceXs + 2),
            Text(
              _recordingDuration >= 60
                  ? t.measureDurationHrvOk
                  : t.measureDurationHrvShort,
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText),
            ),
          ],
        ),
      ),
    );
  }

  /// Camera switch and torch either side of the main button.
  Widget _controlsRow(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    // Switching cameras mid-measurement would tear down the very stream being
    // recorded, so it waits until the measurement is over.
    final bool canSwitch = _backCameras.length >= 2 &&
        !_isSwitchingCamera &&
        !_isRecording &&
        !_isCountdownRunning;
    return Row(
      children: [
        _roundButton(
          context,
          icon: Icons.cameraswitch_outlined,
          tooltip: t.homeSwitchCamera,
          color: kInfoSecondaryText,
          onPressed: canSwitch ? _switchBackCamera : null,
        ),
        SizedBox(width: r.spaceMd),
        Expanded(child: _primaryButton(context)),
        SizedBox(width: r.spaceMd),
        _roundButton(
          context,
          icon: _isFlashOn
              ? CupertinoIcons.bolt_fill
              : CupertinoIcons.bolt_slash_fill,
          tooltip: _isFlashOn ? t.homeTorchOff : t.homeTorchOn,
          color: _isFlashOn ? const Color(0xFFE8A317) : kInfoSecondaryText,
          onPressed: _toggleFlashlight,
        ),
      ],
    );
  }

  Widget _roundButton(
    BuildContext context, {
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback? onPressed,
  }) {
    final r = Responsive.of(context);
    final double size = r.iconXl * 1.4;
    return Semantics(
      button: true,
      enabled: onPressed != null,
      label: tooltip,
      excludeSemantics: true,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              width: size,
              height: size,
              child: Icon(
                icon,
                size: r.iconMd,
                color:
                    onPressed == null ? color.withValues(alpha: 0.35) : color,
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Red "Start" like the home screen's measure card; the countdown runs on
  /// it, and while measuring it turns into an outlined "Stop".
  Widget _primaryButton(BuildContext context) {
    final r = Responsive.of(context);
    final bool outlined = _isRecording;
    final VoidCallback? onTap = _isCountdownRunning
        ? null
        : (_isRecording ? _stopRecording : _startCountdown);
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: _buttonLabel,
      excludeSemantics: true,
      child: Material(
        color: outlined ? Colors.white : kInfoAccent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: outlined
              ? const BorderSide(color: kInfoAccent, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  Haptics.medium();
                  onTap();
                },
          child: SizedBox(
            height: r.iconXl * 1.4,
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: Text(
                  _buttonLabel,
                  key: ValueKey<String>(_buttonLabel),
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: r.fontBodyLg,
                    fontWeight: FontWeight.bold,
                    color: outlined ? kInfoAccent : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Track plus a progress arc starting at twelve o'clock.
class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.width,
  });

  final double progress;
  final Color track;
  final Color color;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = (Offset.zero & size).deflate(width / 2);
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = track;
    canvas.drawArc(rect, 0, 2 * pi, false, paint);
    if (progress > 0) {
      paint
        ..color = color
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
          rect, -pi / 2, 2 * pi * progress.clamp(0.0, 1.0), false, paint);
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.width != width;
}
