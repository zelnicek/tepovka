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
import 'package:flutter/cupertino.dart';

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
  List<FlSpot> _data2 = [];
  List<FlSpot> _smoothedData = [];
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
      _backCameras = allCameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList();
      if (_backCameras.isNotEmpty) {
        // Default to first back camera
        _currentBackCameraIndex = 0;
        setState(() {});
      }
    } catch (e) {
      print('Error loading back cameras: $e');
    }
  }

  Future<void> _switchBackCamera() async {
    if (_backCameras.length < 2) return; // No switch if only one back camera
    // Stop current stream if running
    if (_cameraController.value.isStreamingImages) {
      await _cameraController.stopImageStream();
    }
    // Cancel graph timer to prevent speeding up
    _graphUpdateTimer?.cancel();
    // Dispose old controller
    await _cameraController.dispose();
    // Turn off flash before switching
    if (_isFlashOn) {
      _isFlashOn = false;
    }
    // Update index
    _currentBackCameraIndex =
        (_currentBackCameraIndex + 1) % _backCameras.length;
    // Rebuild with new index; let CameraBody initialize
    setState(() {});
  }

  Future<void> _toggleFlashlight() async {
    if (_cameraController.value.isInitialized) {
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
    if (!_cameraController.value.isStreamingImages) {
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
    final double newValue = -rawValue * 1.0; // Bez zesílení - reálné hodnoty
    final double minX = max(0.0, _currentTime - _windowTime);
    final double maxX = _currentTime;
    // Append new data point with time as x
    final double newX = _currentTime;
    _data.add(FlSpot(newX, newValue));
    // Remove old data points (keep buffer for smooth left exit)
    _data.removeWhere((spot) => spot.x < minX - _bufferTime);
    _data2 = List<FlSpot>.from(_data);
    // Moving average smoothing
    int windowSize = 7; // Increased for less noise
    List<FlSpot> smoothed = [];
    for (int i = 0; i < _data.length; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        if (j >= 0) {
          sum += _data[j].y;
          count++;
        }
      }
      double avg = count > 0 ? sum / count : _data[i].y;
      smoothed.add(FlSpot(_data[i].x, avg));
    }
    _smoothedData = smoothed;
    // Detect peaks on the smoothed data
    List<double> yValues = _smoothedData.map((spot) => spot.y).toList();
    // IMPROVED: Use synchronized peak detection with adaptive threshold and minDistance.
    List<int> potential = _findPeaks(yValues, sampleRate: _sampleRate);
    double rightThresh = minX + (_currentTime - minX) * 0.7;
    double minDistTime = 60.0 / 200.0; // 0.3s min spacing for max HR 200
    for (int idx in potential) {
      FlSpot newPeak = _smoothedData[idx];
      if (newPeak.x > rightThresh &&
          !_peakSpots.any((ex) => (ex.x - newPeak.x).abs() < minDistTime)) {
        _peakSpots.add(newPeak);
      }
    }
    // Remove old peaks
    _peakSpots.removeWhere((spot) => spot.x < minX - _bufferTime);
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
      print('Updated live BPM: $_liveBPM'); // For debug
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
    // Aktualizuj kumulativní čas
    _currentTime += 1.0 / _sampleRate;
    if (_data.length >= 500 && !_isPlottingStarted) {
      _isPlottingStarted = true;
    }
    setState(() {}); // Aktualizuj UI
  }

  // IMPROVED: Robust live peak detection with local threshold, prominence, and refractory.
  List<int> _findPeaks(List<double> signal, {double sampleRate = 30.0}) {
    List<int> peaks = [];
    if (signal.length < 3) return peaks;

    final globalMean = signal.reduce((a, b) => a + b) / signal.length;
    final globalSumSq = signal
        .map((v) => (v - globalMean) * (v - globalMean))
        .reduce((a, b) => a + b);
    final globalStd = sqrt(globalSumSq / signal.length);

    final int minDistance =
        (sampleRate * 60 / 200).round().clamp(3, signal.length); // max HR 200
    final int localWindow = (sampleRate * 1.0).round().clamp(5, 120);

    int lastIndex = -minDistance;
    for (int i = 1; i < signal.length - 1; i++) {
      final isPeak = signal[i - 1] < signal[i] && signal[i] > signal[i + 1];
      if (!isPeak) continue;

      final start = (i - localWindow).clamp(0, signal.length - 1);
      final end = (i + localWindow).clamp(0, signal.length - 1);
      double localSum = 0.0;
      double localSumSq = 0.0;
      int count = 0;
      for (int j = start; j <= end; j++) {
        localSum += signal[j];
        localSumSq += signal[j] * signal[j];
        count++;
      }
      final localMean = localSum / count;
      final localVar = (localSumSq / count) - (localMean * localMean);
      final localStd = sqrt(localVar.abs());

      final threshold = localMean + 0.25 * localStd;
      final prominence = signal[i] - localMean;
      final aboveThreshold = signal[i] > threshold;
      final strongEnough = prominence > (0.35 * localStd).clamp(0.01, 999.0);
      final farEnough = (i - lastIndex) >= minDistance;

      if (!aboveThreshold || !strongEnough) continue;

      if (!farEnough) {
        if (peaks.isNotEmpty && signal[i] > signal[peaks.last]) {
          peaks[peaks.length - 1] = i;
          lastIndex = i;
        }
        continue;
      }

      peaks.add(i);
      lastIndex = i;
    }

    if (peaks.isEmpty && globalStd > 0) {
      final fallbackThreshold = globalMean + 0.15 * globalStd;
      lastIndex = -minDistance;
      for (int i = 1; i < signal.length - 1; i++) {
        final isPeak = signal[i - 1] < signal[i] && signal[i] > signal[i + 1];
        final aboveThreshold = signal[i] > fallbackThreshold;
        final farEnough = (i - lastIndex) >= minDistance;
        if (isPeak && aboveThreshold && farEnough) {
          peaks.add(i);
          lastIndex = i;
        }
      }
    }
    return peaks;
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
    // Turn off flashlight
    if (_cameraController.value.isInitialized) {
      await _cameraController.setFlashMode(FlashMode.off);
      setState(() {
        _isFlashOn = false;
      });
    }
    setState(() {
      _selectedIndex = index;
    });
    // Navigate to the selected page
    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const About()),
        );
        break;
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
    setState(() {
      _progressController.duration = Duration(seconds: _recordingDuration);
      _isRecording = true;
      appbar_text = 'PROBÍHÁ MĚŘENÍ...';
      _remainingTime = _recordingDuration;
      _buttonLabel = 'ZASTAVIT MĚŘENÍ';
      _liveBPM = 70.0; // Initial during recording
      _lastBpmUpdateTime = 0.0; // Reset update time
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
    setState(() {
      if (_data.length > 150) {
        _data.removeRange(0, 150);
      }
      if (_data2.length > 150) {
        _data2.removeRange(0, 150);
      }
    });
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
        // Fallback: estimate from average BPM (rough: RR ≈ HR/4 to HR/5)
        averageRR = (averageBPM / 4.5).clamp(6.0, 30.0);
        print('DEBUG: fallback1 averageRR = $averageRR (from BPM=$averageBPM)');
      }
    } else {
      // Fallback: estimate from average BPM
      averageRR = (averageBPM / 4.5).clamp(6.0, 30.0);
      print('DEBUG: fallback2 averageRR = $averageRR (from BPM=$averageBPM)');
    }
    print('DEBUG: Final RR = $averageRR');
    await _cameraController.setFlashMode(FlashMode.off);
    setState(() {
      _isFlashOn = false;
      _isRecording = false; // Ensure recording state is reset
      appbar_text = 'PŘIPRAVENO K MĚŘENÍ';
      _remainingTime = _recordingDuration;
      _signalQuality = 'Špatná'; // Reset kvality
    });
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => Summmary(
          averageBPM: averageBPM,
          data: _ppgAlgorithm?.dataToPlot() ?? [],
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
          bpmHistory: _ppgAlgorithm?.getBpmHistory() ?? const [],
        ),
      ),
    );
  }

  // Dynamické škálování Y osy – menší padding pro reálné hodnoty
  double _getDynamicMinY() {
    if (_data.isEmpty) return _ppgAlgorithm?.getMin() ?? -1.0;
    return _data.map((spot) => spot.y).reduce(min) - 1.0; // Malý padding
  }

  double _getDynamicMaxY() {
    if (_data.isEmpty) return _ppgAlgorithm?.getMax() ?? 1.0;
    return _data.map((spot) => spot.y).reduce(max) + 1.0; // Malý padding
  }

  @override
  void dispose() {
    if (_cameraController.value.isStreamingImages) {
      _cameraController.stopImageStream();
    }
    _cameraController.dispose();
    _graphUpdateTimer?.cancel();
    _navigationTimer?.cancel();
    _countdownTimer?.cancel();
    _cameraController.setFlashMode(FlashMode.off);
    _heartAnimationController.dispose();
    _progressController.dispose();
    super.dispose();
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
      bpm_list.add(_lastBPM.toInt());
    }
    if (currentBPM > 0) {
      double heartRateFactor = (currentBPM - 30) / (220 - 30);
      _heartAnimationController.duration =
          Duration(milliseconds: max(300, (600 / heartRateFactor).round()));
    }
    final minY = _getDynamicMinY();
    final maxY = _getDynamicMaxY();
    final double minX = max(0.0, _currentTime - _windowTime);
    final double maxX = _currentTime;
    final currentCamera =
        _backCameras.isNotEmpty ? _backCameras[_currentBackCameraIndex] : null;
    return Scaffold(
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black, // Background pro kruh
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
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey,
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
                                spots: _smoothedData,
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
              padding:
                  EdgeInsets.symmetric(horizontal: paddingMedium, vertical: 0),
              child: AnimatedBuilder(
                animation: _progressController,
                builder: (context, child) {
                  return LinearProgressIndicator(
                    value: _progressController.value,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
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
                          onPressed: _backCameras.length < 2
                              ? null
                              : _switchBackCamera,
                          icon: Icon(
                            Icons.cameraswitch,
                            color: Colors.grey,
                            size: iconSizeMedium,
                          ),
                          tooltip: 'Přepnout zadní kameru',
                        ),
                        Text(
                          'Změnit objektiv',
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
                            itemWidth: screenWidth * 0.15, // Dynamic item width
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
                              border: Border.all(color: Colors.grey, width: 1),
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
                transitionBuilder: (Widget child, Animation<double> animation) {
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
    );
  }
}
