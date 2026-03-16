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
import 'package:tepovka/elements/signal_quality_checker.dart'; // Import samostatné třídy pro kvalitu
import 'package:tepovka/elements/peak_detector.dart';
import 'package:flutter/cupertino.dart';
import 'package:tepovka/services/tts_service.dart';

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

class _HomeState extends State<Home> with TickerProviderStateMixin {
  late CameraController _cameraController; // Definice proměnné pro kameru
  PPGAlgorithm? _ppgAlgorithm;
  Timer? _graphUpdateTimer;
  Timer? _navigationTimer;
  Timer? _countdownTimer; // Timer for countdown display
  List<FlSpot> _data = [];
  List<FlSpot> _smoothedData = [];
  List<FlSpot> _fullRecordData =
      []; // Full record for Summary, never window-pruned
  List<TimeLabel> _labels = [];
  List<FlSpot> _peakSpots = []; // FlSpot instances for detected peaks
  bool _isPlottingStarted = false;
  int _selectedIndex = 1;
  double _lastBPM = 0;
  late AnimationController _progressController;
  bool _isRecording = false; // Tracks whether recording is active
  bool _showBPM = true; // Determines whether BPM is displayed
  bool _isFlashOn = false; // Tracks flashlight state
  String appbar_text = 'PŘIPRAVENO K MĚŘENÍ';
  List<int> bpm_list = [];
  int _recordingDuration = 30; // Default recording duration in seconds
  int _remainingTime = 30; // Remaining time for countdown display
  double _currentTime = 0.0; // Kumulativní čas pro legendu
  int _lastLabelSecond = 0;
  String _signalQuality = 'Špatná'; // Proměnná pro kvalitu signálu
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
  String _buttonLabel = 'ZAHÁJIT MĚŘENÍ';
  double _liveBPM = 70.0; // New: Live BPM from UI peaks
  double _lastBpmUpdateTime = 0.0; // New: Time of last BPM update
  double _yAxisHalfRange =
      1.5; // Symmetric Y axis around 0 for stable oscilloscope view
  int _samplesSinceLastScaleUpdate = 0;
  double _emaState = 0.0; // Persistent EMA state across timer ticks
  bool _isTeardown = false;
  bool _isSwitchingCamera = false;

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
    // Inicializace samostatné třídy pro kvalitu
    _signalQualityChecker = SignalQualityChecker();
    // Initialize back cameras list
    _initializeBackCameras();
    // Initialize camera and algorithm
    _ppgAlgorithm = PPGAlgorithm();
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

      print(
          'Camera debug: total=${allCameras.length}, back=${backCameras.length}, switchable=${_backCameras.length}');
      for (final cam in allCameras) {
        print(
            'Camera debug: name=${cam.name}, dir=${cam.lensDirection}, sensorOrientation=${cam.sensorOrientation}');
      }

      if (_backCameras.isNotEmpty) {
        // Prefer rear camera as default if present.
        final firstBackIndex = _backCameras
            .indexWhere((c) => c.lensDirection == CameraLensDirection.back);
        _currentBackCameraIndex = firstBackIndex >= 0 ? firstBackIndex : 0;
        setState(() {});
      }
    } catch (e) {
      print('Error loading back cameras: $e');
    }
  }

  Future<void> _switchBackCamera() async {
    if (_backCameras.length < 2 || _isSwitchingCamera) return;
    _isSwitchingCamera = true;
    try {
      if (_isStreamingImages) {
        await _cameraController.stopImageStream();
      }
      _graphUpdateTimer?.cancel();
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
      print('Error switching camera: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Nepodařilo se přepnout kameru. Zkuste to znovu.'),
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
        if (_ppgAlgorithm != null) {
          _ppgAlgorithm!.processImage(image);
          // Neaktualizujeme UI zde, timer se postará o live efekt
        }
      });
    }
  }

  void _updateLiveData() {
    if (_ppgAlgorithm == null) return;
    final ppgPlot = _ppgAlgorithm!.getPpgPlot();
    if (ppgPlot.isEmpty) return;
    final double rawValue = ppgPlot.last;
    final double newValue =
        -rawValue * 1.0; // Inverze: surový signál se invertuje pro zobrazení
    // Keep a fixed oscilloscope-like window from the very first frame.
    // This prevents horizontal stretching while the signal history grows.
    final double minX = _currentTime - _windowTime;
    // Append new data point with time as x
    final double newX = _currentTime;
    _data.add(FlSpot(newX, newValue));
    // Remove old data points (keep buffer for smooth left exit)
    _data.removeWhere((spot) => spot.x < minX - _bufferTime);

    // IMPROVED FILTERING PIPELINE:
    // 1. Median filter (spike removal) → 2. Baseline removal → 3. Light EMA smoothing
    // This preserves waveform morphology while removing noise and drift.

    List<double> yValues = _data.map((spot) => spot.y).toList();

    // Step 1: Median filter for spike/outlier removal (window=5)
    List<double> medianFiltered = List<double>.from(yValues);
    const int medianWindowSize = 5;
    for (int i = 0; i < yValues.length; i++) {
      List<double> window = [];
      for (int j = i - medianWindowSize ~/ 2;
          j <= i + medianWindowSize ~/ 2;
          j++) {
        if (j >= 0 && j < yValues.length) {
          window.add(yValues[j]);
        }
      }
      window.sort();
      medianFiltered[i] = window[window.length ~/ 2];
    }

    // Step 2: Causal baseline removal using backward-only moving average
    // Only uses past samples so already-plotted values don't change
    const int baselineWindow = 60; // ~2 seconds at 30 FPS
    List<double> detrended = List<double>.filled(medianFiltered.length, 0.0);
    for (int i = 0; i < medianFiltered.length; i++) {
      double sum = 0.0;
      int count = 0;
      final int start = max(0, i - baselineWindow + 1);
      for (int j = start; j <= i; j++) {
        sum += medianFiltered[j];
        count++;
      }
      detrended[i] = medianFiltered[i] - (count > 0 ? sum / count : 0.0);
    }

    // Step 3: Causal EMA - apply only to the new sample and keep history unchanged.
    const double emaAlpha = 0.4;
    final double latestDetrended = detrended.last;
    _emaState = _emaState * (1 - emaAlpha) + latestDetrended * emaAlpha;

    // Append only the newest smoothed point to avoid historical Y deformation.
    _smoothedData.add(FlSpot(_data.last.x, _emaState));
    if (_isRecording) {
      _fullRecordData.add(FlSpot(_data.last.x, _emaState));
    }

    // Keep the same visible/pruned time window as _data.
    _smoothedData.removeWhere(
        (spot) => spot.x < _currentTime - _windowTime - _bufferTime);
    _updateYAxisScale();

    // Peak detection on detrended+smoothed signal
    List<double> smoothedYValues = _smoothedData.map((spot) => spot.y).toList();
    List<int> allPeaks =
        PeakDetector.findPeaks(smoothedYValues, sampleRate: _sampleRate);

    double rightThresh = minX + (_currentTime - minX) * 0.7;
    double minDistTime = 60.0 / 150.0; // 0.4s min spacing for max HR 150

    // Filter peaks by prominence and time position
    final double mean = smoothedYValues.isEmpty
        ? 0
        : smoothedYValues.reduce((a, b) => a + b) / smoothedYValues.length;
    final double std = smoothedYValues.isEmpty
        ? 1
        : sqrt(smoothedYValues
                .map((v) => (v - mean) * (v - mean))
                .reduce((a, b) => a + b) /
            smoothedYValues.length);
    final double prominenceThreshold =
        0.5 * std; // Slightly lower for detrended signal

    for (int idx in allPeaks) {
      FlSpot newPeak = _smoothedData[idx];
      double peakProminence = smoothedYValues[idx] - mean;

      if (peakProminence > prominenceThreshold &&
          newPeak.x > rightThresh &&
          !_peakSpots.any((ex) => (ex.x - newPeak.x).abs() < minDistTime)) {
        _peakSpots.add(newPeak);
      }
    }

    // Remove old peaks
    _peakSpots.removeWhere((spot) => spot.x < minX - _bufferTime);

    // Sort peaks by time
    _peakSpots.sort((a, b) => a.x.compareTo(b.x));

    // New: Calculate live BPM from recent peaks if 5 seconds have passed
    if (_currentTime - _lastBpmUpdateTime >= 5.0 && _peakSpots.length >= 3) {
      // Need at least 2 intervals
      List<double> intervals = [];
      for (int i = 1; i < _peakSpots.length; i++) {
        intervals.add(_peakSpots[i].x - _peakSpots[i - 1].x);
      }
      double avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      _liveBPM = 60.0 / avgInterval;
      // Clamp to reasonable range
      if (_liveBPM < 40 || _liveBPM > 200) _liveBPM = 70.0;
      _lastBpmUpdateTime = _currentTime; // Update last time
      print(
          'DEBUG: ${_peakSpots.length} peaks detected, intervals: ${intervals.map((i) => i.toStringAsFixed(2)).toList()}, avgInterval: ${avgInterval.toStringAsFixed(3)}s, BPM: ${_liveBPM.toStringAsFixed(1)}'); // For debug
    }
    // Posuň časové značky – no shift needed, remove old
    _labels.removeWhere((label) => label.x < minX);
    // Přidej novou značku každou sekundu
    final currentSecond = _currentTime.floor();
    if (currentSecond > _lastLabelSecond) {
      final now = DateTime.now();
      final formattedTime =
          "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";
      _labels.add(TimeLabel(_currentTime, formattedTime));
      _lastLabelSecond = currentSecond;
    }
    // Aktualizuj kvalitu signálu pomocí samostatné třídy
    final rgbMeans = _ppgAlgorithm?.getLastRgbMeans();
    _signalQuality =
        _signalQualityChecker.calculateQuality(_data, rgbMeans: rgbMeans);
    // Announce quality changes in senior mode (Czech TTS)
    TtsService.instance.announceQuality(_signalQuality);
    // Aktualizuj kumulativní čas
    _currentTime += 1.0 / _sampleRate;
    if (_data.length >= 500 && !_isPlottingStarted) {
      _isPlottingStarted = true;
    }
    setState(() {}); // Aktualizuj UI
  }

  void _stopRecording() {
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _progressController.reset();
    _signalQualityChecker.reset(); // Reset historie kvality při stopu
    setState(() {
      _isRecording = false;
      _isCountdownRunning = false;
      appbar_text = 'PŘIPRAVENO K MĚŘENÍ';
      _remainingTime = _recordingDuration;
      _signalQuality = 'Špatná'; // Reset kvality
      _buttonLabel = 'ZAHÁJIT MĚŘENÍ';
      _liveBPM = 70.0; // Reset live BPM
      _lastBpmUpdateTime = 0.0; // Reset update time
      _yAxisHalfRange = 1.5;
      _samplesSinceLastScaleUpdate = 0;
      _emaState = 0.0;
      _fullRecordData = [];
    });
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
      _graphUpdateTimer?.cancel();
      _navigationTimer?.cancel();
      _countdownTimer?.cancel();
      _progressController.stop();
      _heartAnimationController.stop();
      if (_hasInitializedCameraController) {
        await _cameraController.setFlashMode(FlashMode.off);
        _isFlashOn = false;
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

  void _startGraphUpdateTimer() {
    // Ensure previous timer is cancelled
    _graphUpdateTimer?.cancel();
    setState(() {
      _isPlottingStarted = true;
    });
    // Timer pro live aktualizace každých ~33ms pro plynulý osciloskopový efekt (blízko 30fps)
    _graphUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 33), (timer) {
      _updateLiveData();
    });
  }

  void _initializeTimers() {
    _navigationTimer = Timer(Duration(seconds: _recordingDuration), () {
      _navigateToSummaryPage();
    });
    // Countdown timer for display
    setState(() {
      _remainingTime = _recordingDuration;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_remainingTime > 0) {
          _remainingTime--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  void _startRecording() async {
    if (_isRecording) return; // Prevent multiple recordings
    // Reset kvality na začátku měření pro čistý start
    _signalQualityChecker.reset();
    // Reset PPG algorithm for new measurement
    _ppgAlgorithm?.reset();
    // Validate recording duration
    if (_recordingDuration < 10 || _recordingDuration > 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Zadejte dobu trvání mezi 10 a 300 sekundami'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    if (_recordingDuration < 60) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Pro HRV analýzu doporučujeme délku měření alespoň 60 sekund.'),
          duration: Duration(seconds: 3),
        ),
      );
    }

    if (_hasInitializedCameraController && !_isFlashOn) {
      try {
        await _cameraController.setFlashMode(FlashMode.torch);
        if (mounted) {
          setState(() {
            _isFlashOn = true;
          });
        }
      } catch (e) {
        debugPrint('Auto torch enable failed: $e');
      }
    }

    setState(() {
      _progressController.duration = Duration(seconds: _recordingDuration);
      _isRecording = true;
      appbar_text = 'PROBÍHÁ MĚŘENÍ...';
      _remainingTime = _recordingDuration;
      _buttonLabel = 'ZASTAVIT MĚŘENÍ';
      _liveBPM = 70.0; // Initial during recording
      _lastBpmUpdateTime = 0.0; // Reset update time
      _yAxisHalfRange = 1.5;
      _samplesSinceLastScaleUpdate = 0;
      _emaState = 0.0;
      _fullRecordData = [];
    });
    _initializeTimers();
    _progressController.forward();
  }

  void _startCountdown() {
    setState(() {
      _isCountdownRunning = true;
      appbar_text = 'PŘIPRAVTE SE...';
      _buttonLabel = '3';
    });
    // Voice announcement for seniors
    TtsService.instance.announceCountdown();
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
    List<double> frames_list = _ppgAlgorithm?.getFrames() ?? [];
    List<double> respiratoryRates = _ppgAlgorithm?.getRespiratoryRates() ?? [];

    print(
        'DEBUG: respiratoryRates = $respiratoryRates, isEmpty=${respiratoryRates.isEmpty}, length=${respiratoryRates.length}');

    double averageRR = 0.0;
    if (respiratoryRates.isNotEmpty) {
      // Filter out zero values and calculate average of valid measurements
      final validRates = respiratoryRates.where((r) => r > 0).toList();
      print(
          'DEBUG: validRates = $validRates (from ${respiratoryRates.length} total)');
      if (validRates.isNotEmpty) {
        averageRR = validRates.reduce((a, b) => a + b) / validRates.length;
        print('DEBUG: calculated averageRR = $averageRR');
      } else {
        averageRR = 0.0; // validRates empty -> unknown RR
      }
    } else {
      averageRR = 0.0; // no RR available
    }
    print('DEBUG: Final RR = $averageRR');
    if (_hasInitializedCameraController) {
      await _cameraController.setFlashMode(FlashMode.off);
    }
    setState(() {
      _isFlashOn = false;
      _isRecording = false; // Ensure recording state is reset
      appbar_text = 'PŘIPRAVENO K MĚŘENÍ';
      _remainingTime = _recordingDuration;
      _signalQuality = 'Špatná'; // Reset kvality
    });
    // Haptics for UX: signal completion
    HapticFeedback.lightImpact();
    // Voice announcement for seniors (do not block navigation)
    // Fire-and-forget to avoid getting stuck on awaitSpeakCompletion
    // ignore: unawaited_futures
    TtsService.instance.announceMeasurementEnd();
    print(
        'DEBUG fullRecordData length: ${_fullRecordData.length}, recordingDuration: $_recordingDuration');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Summary(
          averageBPM: averageBPM,
          data: _fullRecordData.map((s) => s.y).toList(),
          bpm_list: bpm_list,
          frames: frames_list,
          recordingDuration:
              _recordingDuration, // Přidáno: Předání délky měření
          respiratoryRate: averageRR, // Přidáno: Předání RR
          sdnn: _ppgAlgorithm?.getSdnn() ?? 0.0,
          rmssd: _ppgAlgorithm?.getRmssd() ?? 0.0,
          pnn50: _ppgAlgorithm?.getPnn50() ?? 0.0,
          sd1: _ppgAlgorithm?.getSd1() ?? 0.0,
          sd2: _ppgAlgorithm?.getSd2() ?? 0.0,
          spo2: _ppgAlgorithm?.getSummarySpO2() ?? 0.0,
          bpmHistory: _ppgAlgorithm?.getBpmHistory() ?? const [],
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
    if (_isStreamingImages) {
      _cameraController.stopImageStream();
    }
    if (_hasInitializedCameraController) {
      _cameraController.dispose();
    }
    _graphUpdateTimer?.cancel();
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _heartAnimationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    // When route changes, stop streaming/animations to avoid background activity
    _stopAllActivity(disposeCamera: false);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double cameraSize =
        screenWidth * 0.25; // 25% of screen width for camera
    final double sideWidth = screenWidth * 0.2; // 20% for BPM and quality
    final double graphHeight =
        screenHeight * 0.25; // 25% of screen height for graph
    final double paddingSmall = screenHeight * 0.01; // Small dynamic padding
    final double paddingMedium = screenHeight * 0.02; // Medium dynamic padding
    final double iconSizeMedium = screenWidth * 0.08; // Medium icon size
    final double fontSizeLarge = screenWidth * 0.09; // Large font (e.g., BPM)
    final double fontSizeMedium = screenWidth * 0.04; // Medium font
    final double fontSizeSmall = screenWidth * 0.035; // Small font

    double currentBPM = _liveBPM; // Always use live BPM from peaks
    if (currentBPM != _lastBPM) {
      HapticFeedback.heavyImpact();
      _lastBPM = currentBPM;
    }
    if (currentBPM > 0) {
      double heartRateFactor = (currentBPM - 30) / (220 - 30);
      _heartAnimationController.duration =
          Duration(milliseconds: max(300, (600 / heartRateFactor).round()));
    }
    final minY = -_yAxisHalfRange;
    final maxY = _yAxisHalfRange;
    final double minX = _currentTime - _windowTime;
    final double maxX = _currentTime;

    final List<FlSpot> scaledSmoothedData = _smoothedData;
    final List<FlSpot> scaledPeakSpots = _peakSpots;
    final currentCamera =
        _backCameras.isNotEmpty ? _backCameras[_currentBackCameraIndex] : null;
    return WillPopScope(
      onWillPop: () async {
        await _stopAllActivity(disposeCamera: true);
        return true;
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false, // Prevent keyboard from resizing UI
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          centerTitle: true,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                appbar_text,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: fontSizeMedium,
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
                            Text(
                              currentBPM.round().toString(),
                              style: TextStyle(
                                fontSize: fontSizeLarge, // Dynamic large font
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                ScaleTransition(
                                  scale: _heartAnimationController.drive(
                                    Tween<double>(begin: 0.9, end: 1.3),
                                  ),
                                  child: Icon(
                                    Icons.favorite,
                                    color: Colors.red,
                                    size: iconSizeMedium * 0.6, // Smaller heart
                                  ),
                                ),
                                SizedBox(width: paddingSmall),
                                Text(
                                  'bpm',
                                  style: TextStyle(fontSize: fontSizeSmall),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    // Camera preview v kruhu
                    if (currentCamera != null)
                      Container(
                        width: cameraSize,
                        height: cameraSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black, // Background pro kruh
                          border: Border.all(
                            color: _signalQuality == 'Dobrá'
                                ? Colors.green
                                : Colors.red,
                            width: 4,
                          ),
                        ),
                        child: ClipOval(
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
                                _startGraphUpdateTimer();
                              },
                              onImageAvailable: (image) {
                                // Nepoužíváme, protože stream je v _startImageStream
                              },
                            ),
                          ),
                        ),
                      )
                    else
                      Container(
                        width: cameraSize,
                        height: cameraSize,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey,
                          border: Border.all(
                            color: _signalQuality == 'Dobrá'
                                ? Colors.green
                                : Colors.red,
                            width: 4,
                          ),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                    // Quality control vpravo od kamery
                    Container(
                      width: sideWidth,
                      padding: EdgeInsets.only(left: paddingSmall),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Kvalita',
                            style: TextStyle(
                              fontSize: fontSizeSmall,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          SizedBox(height: paddingSmall),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _signalQuality == 'Dobrá'
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: _signalQuality == 'Dobrá'
                                    ? Colors.green
                                    : Colors.red,
                                size: iconSizeMedium * 0.5,
                              ),
                              SizedBox(width: paddingSmall * 0.5),
                              Flexible(
                                child: Text(
                                  _signalQuality,
                                  style: TextStyle(
                                    fontSize: fontSizeSmall,
                                    fontWeight: FontWeight.w500,
                                    color: _signalQuality == 'Dobrá'
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: paddingMedium),
              Container(
                padding: EdgeInsets.only(top: paddingSmall),
                width: double.infinity,
                height: graphHeight,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final chartWidth = constraints.maxWidth;
                    return RepaintBoundary(
                      // Added this for performance optimization
                      child: Stack(
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
                                    color: Colors.grey.withOpacity(0.3)),
                              ),
                              minX: minX,
                              maxX: maxX,
                              minY: minY,
                              maxY: maxY,
                              lineBarsData: [
                                LineChartBarData(
                                  spots: scaledSmoothedData,
                                  isCurved: false, // Přímá čára pro signál
                                  color: const Color.fromARGB(255, 246, 41, 0),
                                  barWidth: 2.0,
                                  isStrokeCapRound: true,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: BarAreaData(
                                    show: false,
                                  ),
                                ),
                                // Peak markers as a separate series (dots only)
                                LineChartBarData(
                                  spots: scaledPeakSpots,
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
                                color: Colors.grey.withOpacity(0.5),
                              ),
                            );
                          }).toList(),
                          // Texty pro časové značky (pod čarami)
                          ..._labels.map((label) {
                            final posX =
                                ((label.x - minX) / (maxX - minX + 1e-6)) *
                                    chartWidth;
                            return Positioned(
                              left: posX,
                              bottom: 0,
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  label.time,
                                  style: const TextStyle(
                                      fontSize: 10, color: Colors.black),
                                ),
                              ),
                            );
                          }).toList(),
                        ],
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
                  child: Text(
                    '$_remainingTime s',
                    style: TextStyle(
                      fontSize: fontSizeMedium,
                      fontWeight: FontWeight.w500,
                      color: Colors.black,
                    ),
                  ),
                ),
              SizedBox(height: paddingMedium),
              // NumberPicker uprostřed a torch na pravo s paddingem
              Padding(
                padding: EdgeInsets.symmetric(horizontal: iconSizeMedium),
                child: Row(
                  children: [
                    // Camera switch button zleva
                    SizedBox(
                      width: sideWidth,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          IconButton(
                            onPressed:
                                (_backCameras.length < 2 || _isSwitchingCamera)
                                    ? null
                                    : _switchBackCamera,
                            icon: Icon(
                              Icons.cameraswitch,
                              color: Colors.grey,
                              size: iconSizeMedium,
                            ),
                            tooltip: 'Přepnout kameru',
                          ),
                          Text(
                            'Změnit kameru',
                            style: TextStyle(
                              fontSize: fontSizeSmall,
                              color: Colors.grey,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    // Time picker vycentrovaný uprostřed
                    Column(
                      children: [
                        Text(
                          'Doba měření (sekundy)',
                          style: TextStyle(
                            fontSize: fontSizeSmall,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        Opacity(
                          opacity: _isRecording ? 0.5 : 1.0,
                          child: IgnorePointer(
                            ignoring: _isRecording,
                            child: NumberPicker(
                              value: _recordingDuration,
                              minValue: 10,
                              maxValue: 300,
                              step: 10, // Increment by 10 seconds
                              itemWidth:
                                  screenWidth * 0.15, // Dynamic item width
                              onChanged: (value) {
                                setState(() {
                                  _recordingDuration = value;
                                  _remainingTime = value; // Sync remaining time
                                });
                              },
                              textStyle: TextStyle(
                                fontSize: fontSizeSmall,
                                color: Colors.grey,
                              ),
                              selectedTextStyle: TextStyle(
                                fontSize: fontSizeMedium,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              decoration: BoxDecoration(
                                border:
                                    Border.all(color: Colors.grey, width: 1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    // Torch button napravo
                    SizedBox(
                      width: sideWidth,
                      child: Center(
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.grey.withOpacity(0.3),
                                spreadRadius: 1,
                                blurRadius: 3,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: IconButton(
                            onPressed: _toggleFlashlight,
                            icon: Icon(
                              _isFlashOn
                                  ? CupertinoIcons.bolt_fill
                                  : CupertinoIcons.bolt_slash_fill,
                              color: _isFlashOn
                                  ? const Color.fromARGB(255, 0, 0, 0)
                                  : Colors.grey,
                              size: iconSizeMedium,
                            ),
                            tooltip:
                                _isFlashOn ? 'Vypnout blesk' : 'Zapnout blesk',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: paddingMedium),
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
          tabs: const [
            GButton(
              icon: Symbols.family_home,
              text: 'MENU',
            ),
            GButton(
              icon: Symbols.ecg_heart,
              text: 'MĚŘENÍ',
            ),
            GButton(
              icon: Symbols.help,
              text: 'INFO',
            ),
          ],
        ),
      ),
    );
  }
}
