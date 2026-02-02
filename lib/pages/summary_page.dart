import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/about.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:health/health.dart';
import 'package:fftea/fftea.dart';
import 'dart:typed_data';

class TimeLabel {
  double x;
  String time;
  TimeLabel(this.x, this.time);
}

class Summmary extends StatefulWidget {
  final double averageBPM;
  final List<double> data;
  final List<int> bpm_list;
  final List<double> frames;
  final int recordingDuration; // Přidáno: Délka měření
  const Summmary({
    Key? key,
    required this.averageBPM,
    required this.data,
    required this.bpm_list,
    required this.frames,
    required this.recordingDuration,
  }) : super(key: key);
  @override
  State<Summmary> createState() => _SummmaryState();
}

class _SummmaryState extends State<Summmary> {
  int _selectedIndex = 0;
  final Health _health = Health();
  List<HealthDataPoint> _healthDataList = [];
  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();
  List<FlSpot> _smoothedData = [];
  List<FlSpot> _peakSpots = [];
  List<TimeLabel> _labels = [];
  double _calculatedAverageBPM = 0.0;
  static const double sampleRate = 30.0;
  static const double pixelsPerSecond =
      40.0; // Reduced for better fit, adjust as needed
  // HRV metrics
  double _sdnn = 0.0;
  double _rmssd = 0.0;
  double _pnn50 = 0.0;
  double _meanRR = 0.0;
  double _sd2 = 0.0;
  double _sd1 = 0.0;
  double _sd2sd1 = 0.0;
  double _lf = 0.0;
  double _hf = 0.0;
  double _lfhf = 0.0;
  double _stressIndex = 0.0;
  @override
  void initState() {
    print('bpm_list: ${widget.bpm_list}');
    //print('red_channel: ${widget.data}');
    print('Délka dat: ${widget.data.length}');
    super.initState();
    _authorizeHealth();
    _computeSmoothedPeaksAndLabels();
    _computeHRV();
  }

  void _computeSmoothedPeaksAndLabels() {
    // Trim data to exactly recording duration (remove initial if extra)
    int expectedLength = (widget.recordingDuration * sampleRate).toInt();
    List<double> trimmedData = widget.data;
    if (trimmedData.length > expectedLength) {
      trimmedData = trimmedData.sublist(trimmedData.length - expectedLength);
    }
    // Create spots with time x and inverted y
    List<FlSpot> spots = [];
    for (int i = 0; i < trimmedData.length; i++) {
      spots.add(FlSpot(i / sampleRate, -trimmedData[i]));
    }
    // Moving average smoothing
    int windowSize = 7;
    List<FlSpot> smoothed = [];
    for (int i = 0; i < spots.length; i++) {
      double sum = 0.0;
      int count = 0;
      for (int j = i - windowSize + 1; j <= i; j++) {
        if (j >= 0) {
          sum += spots[j].y;
          count++;
        }
      }
      double avg = count > 0 ? sum / count : spots[i].y;
      smoothed.add(FlSpot(spots[i].x, avg));
    }
    _smoothedData = smoothed;
    // Detect peaks on smoothed
    List<double> yValues = _smoothedData.map((s) => s.y).toList();
    List<int> peaks = _findPeaks(yValues, sampleRate: sampleRate);
    _peakSpots = peaks.map((i) => _smoothedData[i]).toList();
    // Calculate average BPM from peaks
    if (_peakSpots.length > 1) {
      double sumIntervals = 0.0;
      for (int i = 1; i < _peakSpots.length; i++) {
        sumIntervals += _peakSpots[i].x - _peakSpots[i - 1].x;
      }
      double averageInterval = sumIntervals / (_peakSpots.length - 1);
      _calculatedAverageBPM = 60.0 / averageInterval;
      // Clamp to reasonable range to match home page behavior
      if (_calculatedAverageBPM < 40 || _calculatedAverageBPM > 200)
        _calculatedAverageBPM = 70.0;
    } else {
      _calculatedAverageBPM = 0.0;
    }
    // Generate time labels every second
    double totalTime = trimmedData.length / sampleRate;
    for (int i = 0; i <= totalTime.floor(); i++) {
      int min = i ~/ 60;
      int sec = i % 60;
      String formatted = "$min:${sec.toString().padLeft(2, '0')}";
      _labels.add(TimeLabel(i.toDouble(), formatted));
    }
  }

  void _computeHRV() {
    if (_peakSpots.length < 2) return;
    List<double> rrIntervals = [];
    for (int i = 1; i < _peakSpots.length; i++) {
      double interval = (_peakSpots[i].x - _peakSpots[i - 1].x) * 1000; // in ms
      rrIntervals.add(interval);
    }
    if (rrIntervals.isEmpty) return;
    // Mean RR
    _meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
    // SDNN
    double sumSquares = 0.0;
    for (double rr in rrIntervals) {
      sumSquares += pow(rr - _meanRR, 2);
    }
    _sdnn = sqrt(sumSquares / rrIntervals.length);
    // RMSSD and pNN50 require at least 2 RR intervals
    if (rrIntervals.length < 2) {
      _rmssd = 0.0;
      _pnn50 = 0.0;
    } else {
      // RMSSD
      sumSquares = 0.0;
      for (int i = 1; i < rrIntervals.length; i++) {
        sumSquares += pow(rrIntervals[i] - rrIntervals[i - 1], 2);
      }
      _rmssd = sqrt(sumSquares / (rrIntervals.length - 1));
      // pNN50
      int nn50Count = 0;
      for (int i = 1; i < rrIntervals.length; i++) {
        if ((rrIntervals[i] - rrIntervals[i - 1]).abs() > 50) {
          nn50Count++;
        }
      }
      _pnn50 = (nn50Count / (rrIntervals.length - 1)) * 100;
    }
    // Poincare plot (SD1, SD2, SD2/SD1) - requires at least 2 RR
    if (rrIntervals.length < 2) {
      _sd1 = 0.0;
      _sd2 = 0.0;
      _sd2sd1 = 0.0;
    } else {
      List<double> rrDiff = [];
      for (int i = 1; i < rrIntervals.length; i++) {
        rrDiff.add(rrIntervals[i] - rrIntervals[i - 1]);
      }
      double sdDiff = sqrt(
          rrDiff.map((d) => pow(d, 2)).reduce((a, b) => a + b) / rrDiff.length);
      _sd1 = sdDiff / sqrt(2);
      _sd2 = sqrt(2 * pow(_sdnn, 2) - pow(_sd1, 2));
      _sd2sd1 = _sd2 / _sd1;
    }
    // Stress Index (Baevsky approximation)
    _stressIndex = _sdnn == 0 ? 0.0 : pow(_meanRR / (2 * _sdnn), 2).toDouble();
    // Frequency domain using FFT - requires more data, but proceed if possible
    if (rrIntervals.length < 3) {
      _lf = 0.0;
      _hf = 0.0;
      _lfhf = 0.0;
      return;
    }
    // Build beat times
    List<double> beatTimes = [0.0];
    for (double rr in rrIntervals) {
      beatTimes.add(beatTimes.last + rr / 1000.0);
    }
    // Times for interpolation: beatTimes.sublist(1), values: rrIntervals
    List<double> interpTimes = beatTimes.sublist(1);
    double totalDuration = beatTimes.last;
    // Resample to 4 Hz
    double targetFreq = 4.0;
    double dt = 1.0 / targetFreq;
    int numSamples = (totalDuration / dt).floor() + 1;
    List<double> newTimes = List.generate(numSamples, (i) => i * dt);
    List<double> resampledRR = _interpolate(interpTimes, rrIntervals, newTimes);
    // Detrend (subtract mean)
    resampledRR = resampledRR.map((v) => v - _meanRR).toList();
    // Apply Hanning window
    final hannWindow = Window.hanning(resampledRR.length);
    for (int i = 0; i < resampledRR.length; i++) {
      resampledRR[i] *= hannWindow[i];
    }
    // Pad to next power of 2
    int originalLength = resampledRR.length;
    int paddedLength = _nextPowerOf2(originalLength);
    Float64List paddedSignal = Float64List(paddedLength);
    paddedSignal.setRange(0, originalLength, Float64List.fromList(resampledRR));
    // Compute FFT
    final fft = FFT(paddedLength);
    final freq = fft.realFft(paddedSignal);
    // Compute powers (PSD)
    List<double> powers = freq.map((c) => c.x * c.x + c.y * c.y).toList();
    // Frequency resolution
    double freqResolution = targetFreq / paddedLength;
    // Integrate bands
    _lf = _integrateBand(powers, freqResolution, 0.04, 0.15);
    _hf = _integrateBand(powers, freqResolution, 0.15, 0.4);
    double total = _lf + _hf;
    if (total > 0) {
      _lf = (_lf / total) * 100;
      _hf = (_hf / total) * 100;
    }
    _lfhf = _hf == 0.0 ? 0.0 : _lf / _hf;
  }

  List<double> _interpolate(
      List<double> times, List<double> values, List<double> newTimes) {
    List<double> result = [];
    int idx = 0;
    for (double t in newTimes) {
      if (t < times[0]) {
        result.add(values[0]);
        continue;
      }
      while (idx < times.length - 1 && t >= times[idx + 1]) {
        idx++;
      }
      if (idx >= times.length - 1) {
        result.add(values.last);
        continue;
      }
      double frac = (t - times[idx]) / (times[idx + 1] - times[idx]);
      double val = values[idx] + frac * (values[idx + 1] - values[idx]);
      result.add(val);
    }
    return result;
  }

  int _nextPowerOf2(int n) {
    if (n <= 0) return 1;
    return pow(2, (log(n) / log(2)).ceil()).toInt();
  }

  double _integrateBand(List<double> psd, double res, double low, double high) {
    double sum = 0.0;
    int start = (low / res).ceil();
    int end = (high / res).floor();
    for (int i = start; i <= end; i++) {
      if (i < psd.length) {
        sum += psd[i];
      }
    }
    return sum;
  }

  Color _getStressColor(double index) {
    if (index < 50) return Colors.green;
    if (index < 100) return Colors.orange;
    return Colors.red;
  }

  List<int> _findPeaks(List<double> signal, {double sampleRate = 30.0}) {
    List<int> peaks = [];
    if (signal.length < 3) return peaks;

    // Compute adaptive threshold: mean + 0.5 * std to avoid tiny fluctuations.
    double mean = signal.reduce((a, b) => a + b) / signal.length;
    double sumSqDiff =
        signal.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b);
    double std = sqrt(sumSqDiff / signal.length);
    double adaptiveThreshold = mean + 0.3 * std;

    // Min distance in samples (for max HR 200 BPM).
    double minDistance = sampleRate / (200 / 60); // ~0.3s interval.

    double lastIndex = -double.infinity;
    for (int i = 1; i < signal.length - 1; i++) {
      bool isPeak = signal[i - 1] < signal[i] && signal[i] > signal[i + 1];
      bool aboveThreshold = signal[i] > adaptiveThreshold;
      bool farEnough = (i - lastIndex) >= minDistance;

      if (isPeak && aboveThreshold && farEnough) {
        peaks.add(i);
        lastIndex = i.toDouble();
      }
    }
    return peaks;
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _authorizeHealth() async {
    final types = [
      HealthDataType.HEART_RATE,
    ];
    final permissionGranted = await _health.requestAuthorization(
      [HealthDataType.HEART_RATE],
      permissions: [HealthDataAccess.READ_WRITE],
    );
    if (!permissionGranted) {
      print('Oprávnění k zápisu do Apple Health nebylo uděleno.');
      return;
    }
    bool requested = await _health.requestAuthorization(types);
    if (!requested) {
      print('Uživatel odmítl přístup k HealthKit');
    } else {
      print('HealthKit autorizace proběhla úspěšně');
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
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

  Future<void> _saveMeasurement() async {
    if (_isSaving) {
      print('Ukládání již probíhá.');
      return;
    }
    _isSaving = true;
    try {
      print('Začátek ukládání měření');
      final directory = await getApplicationDocumentsDirectory();
      final summaryFile = File('${directory.path}/measurement_summary.json');
      final now = DateTime.now();
      final formattedDate =
          '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
      final formattedTime =
          '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';
      final averageBpm = widget.averageBPM.toInt();
      final dataForPlot = widget.data;
      final notesContent = _notesController.text;
      final bpmList = widget.bpm_list;
      final frames = widget.frames.skip(2).toList();
      final record = {
        'date': formattedDate,
        'time': formattedTime,
        'averageBPM': averageBpm,
        'dataForPlot': dataForPlot,
        'notes': notesContent,
        'bpmList': bpmList,
        'frames': frames,
        'duration': widget.recordingDuration,
        'hrv': {
          'sdnn': _sdnn,
          'rmssd': _rmssd,
          'pnn50': _pnn50,
          'meanRR': _meanRR,
          'sd1': _sd1,
          'sd2': _sd2,
          'sd2sd1': _sd2sd1,
          'lf': _lf,
          'hf': _hf,
          'lfhf': _lfhf,
          'stressIndex': _stressIndex,
        }
      };
      List<dynamic> existingRecords = [];
      if (await summaryFile.exists()) {
        final content = await summaryFile.readAsString();
        existingRecords = json.decode(content);
      }
      existingRecords.add(record);
      await summaryFile.writeAsString(json.encode(existingRecords),
          mode: FileMode.write);
      print('Ukládání úspěšně dokončeno');
    } catch (e) {
      print('Chyba při ukládání: $e');
    } finally {
      _isSaving = false;
    }
  }

  Future<void> _saveToAppleHealth(double bpm) async {
    final now = DateTime.now();
    final start = now.subtract(Duration(seconds: widget.recordingDuration));
    final bpmValue = bpm.toInt();
    bool success = await _health.writeHealthData(
      value: bpmValue.toDouble(),
      type: HealthDataType.HEART_RATE,
      startTime: start,
      endTime: now,
    );
    if (success) {
      print('Tepová frekvence byla úspěšně uložena do Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(
                'Úspěšně uloženo do Apple Health',
                style:
                    TextStyle(color: const Color.fromARGB(255, 192, 192, 192)),
              ),
              SizedBox(
                width: 50,
              ),
              Image.asset(
                'assets/Icon - Apple Health.png',
                width: 24,
                height: 24,
              ),
            ],
          ),
          backgroundColor: const Color.fromARGB(255, 54, 54, 54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      print('Nepodařilo se uložit do Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chyba při ukládání do Apple Health'),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  double _getDynamicMinY() {
    if (_smoothedData.isEmpty) return -1.0;
    return _smoothedData.map((spot) => spot.y).reduce(min) - 1.0;
  }

  double _getDynamicMaxY() {
    if (_smoothedData.isEmpty) return 1.0;
    return _smoothedData.map((spot) => spot.y).reduce(max) + 1.0;
  }

  @override
  Widget build(BuildContext context) {
    double totalTime = _smoothedData.length / sampleRate;
    double chartWidth = totalTime * pixelsPerSecond;
    final minY = _getDynamicMinY();
    final maxY = _getDynamicMaxY();
    final double minX = 0.0;
    final double maxX = totalTime;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          centerTitle: true,
          title: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'VÝSLEDEK',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        ),
        body: SingleChildScrollView(
            child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 20),
              child: Column(
                children: [
                  const Text(
                    'Průměrná tepová frekvence:',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 20,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '${_calculatedAverageBPM.toInt()} bpm',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 40,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
              child: Container(
                height: 40,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.red.withOpacity(1),
                              Colors.orange.withOpacity(1),
                              Colors.green.withOpacity(1),
                              Colors.orange.withOpacity(1),
                              Colors.red.withOpacity(1),
                            ],
                            stops: const [
                              0.0,
                              0.11,
                              0.20,
                              0.55,
                              0.75,
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Positioned(
                      left: ((_calculatedAverageBPM.clamp(30, 220) - 30) /
                              (220 - 30)) *
                          (MediaQuery.of(context).size.width - 40),
                      child: Container(
                        width: 10,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Center(
                      child: Text(
                        '${_calculatedAverageBPM.toInt()} bpm',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const Positioned(
                      left: 10,
                      top: 10,
                      child: Text(
                        '30',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const Positioned(
                      right: 10,
                      top: 10,
                      child: Text(
                        '220',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _notesController,
                style: const TextStyle(
                  color: Colors.black,
                ),
                cursorColor: Colors.grey,
                decoration: InputDecoration(
                  labelText: 'Poznámka',
                  labelStyle: const TextStyle(
                    color: Color.fromARGB(255, 110, 109, 109),
                  ),
                  hintText: 'Zadejte své poznámky k měření...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color: Colors.grey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                    borderSide: const BorderSide(
                      color: Color.fromARGB(255, 110, 109, 109),
                      width: 1.5,
                    ),
                  ),
                  fillColor: Colors.white,
                ),
                maxLines: null,
              ),
            ),
            SizedBox(
              height: 200,
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      // Increased padding to accommodate label overhang
                      child: RepaintBoundary(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            LineChart(
                              LineChartData(
                                clipData: const FlClipData(
                                  left: false,
                                  right: true, // Allow overflow on right
                                  top: true,
                                  bottom: true,
                                ),
                                gridData: const FlGridData(show: false),
                                titlesData: const FlTitlesData(show: false),
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
                                    isCurved: false,
                                    color:
                                        const Color.fromARGB(255, 246, 41, 0),
                                    barWidth: 2.0,
                                    isStrokeCapRound: true,
                                    dotData: const FlDotData(show: false),
                                    belowBarData: BarAreaData(
                                      show: false,
                                    ),
                                  ),
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
                              duration: Duration.zero,
                            ),
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
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // HRV Analysis Section
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'HRV Analýza',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                childAspectRatio: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                children: [
                  _buildHRVCard('SDNN', '${_sdnn.toStringAsFixed(2)} ms'),
                  _buildHRVCard('RMSSD', '${_rmssd.toStringAsFixed(2)} ms'),
                  _buildHRVCard('pNN50', '${_pnn50.toStringAsFixed(2)} %'),
                  _buildHRVCard('Mean RR', '${_meanRR.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD1', '${_sd1.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD2', '${_sd2.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD2/SD1', '${_sd2sd1.toStringAsFixed(2)}'),
                  _buildHRVCard('LF', '${_lf.toStringAsFixed(2)} %'),
                  _buildHRVCard('HF', '${_hf.toStringAsFixed(2)} %'),
                  _buildHRVCard('LF/HF', '${_lfhf.toStringAsFixed(2)}'),
                  _buildHRVCard(
                    'Stress Index',
                    '${_stressIndex.toStringAsFixed(2)}',
                    valueColor: _getStressColor(_stressIndex),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(
                    Symbols.heart_broken,
                    size: 30,
                  ),
                  color: const Color.fromARGB(255, 222, 16, 1),
                  onPressed: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IntroPage()),
                    );
                  },
                ),
                InkWell(
                  onTap: () async {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const IntroPage()),
                    );
                  },
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 100),
                    scale: _isSaving ? 1.0 : 1.1,
                    child: const Text(
                      'Zrušit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: const Color.fromARGB(255, 222, 16, 1),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 50,
                ),
                IconButton(
                  icon: const Icon(
                    Symbols.heart_plus,
                    size: 45,
                  ),
                  color: Colors.blue,
                  onPressed: _isSaving
                      ? null
                      : () async {
                          await _saveMeasurement();
                          await _saveToAppleHealth(widget.averageBPM);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const IntroPage()),
                          );
                        },
                ),
                InkWell(
                  onTap: _isSaving
                      ? null
                      : () async {
                          await _saveMeasurement();
                          await _saveToAppleHealth(widget.averageBPM);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const IntroPage()),
                          );
                        },
                  child: AnimatedScale(
                    duration: const Duration(milliseconds: 100),
                    scale: _isSaving ? 1.0 : 1.1,
                    child: const Text(
                      'Uložit',
                      style: TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ),
                ),
              ],
            )
          ],
        )),
        bottomNavigationBar: GNav(
          tabMargin: const EdgeInsets.symmetric(horizontal: 10),
          gap: 0,
          activeColor: Colors.black,
          iconSize: 24,
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

  Widget _buildHRVCard(String title, String value, {Color? valueColor}) {
    return Card(
      elevation: 2,
      color: Colors.white, // White background
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(
          color: Color.fromARGB(120, 158, 158, 158), // Slick black border
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black, // Ensure text is black for contrast
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                color:
                    valueColor ?? Colors.black, // Use provided color or default
              ),
            ),
          ],
        ),
      ),
    );
  }
}
