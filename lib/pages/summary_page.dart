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
  final double respiratoryRate; // Přidáno: Dechová frekvence
  final List<double> bpmHistory; // HR time series for Recovery metrics
  final double sdnn; // HRV: SDNN
  final double rmssd; // HRV: RMSSD
  final double pnn50; // HRV: pNN50
  final double sd1; // HRV: SD1
  final double sd2; // HRV: SD2
  const Summmary({
    Key? key,
    required this.averageBPM,
    required this.data,
    required this.bpm_list,
    required this.frames,
    required this.recordingDuration,
    required this.respiratoryRate, // Přidáno: RR
    required this.bpmHistory,
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.sd1,
    required this.sd2,
  }) : super(key: key);
  @override
  State<Summmary> createState() => _SummmaryState();
}

class _SummmaryState extends State<Summmary> {
  int _selectedIndex = 0;
  final Health _health = Health();
  // ignore: unused_field
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
  double _respiratoryRate = 0.0; // Dechová frekvence
  // HR Recovery metrics
  double _hr0 = 0.0;
  double _hr60 = 0.0;
  double _hr120 = 0.0;
  double _hrr60 = 0.0;
  double _hrr120 = 0.0;
  double _slope60_bpmPerMin = 0.0;
  double _tauSec = 0.0;
  List<FlSpot> _recoverySpots = [];
  @override
  void initState() {
    print('bpm_list: ${widget.bpm_list}');
    //print('red_channel: ${widget.data}');
    print('Délka dat: ${widget.data.length}');
    super.initState();
    _authorizeHealth();
    _respiratoryRate = widget.respiratoryRate; // Uložení RR

    // Use HRV metrics from PPGAlgorithm (more accurate)
    _sdnn = widget.sdnn;
    _rmssd = widget.rmssd;
    _pnn50 = widget.pnn50;
    _sd1 = widget.sd1;
    _sd2 = widget.sd2;
    _sd2sd1 = _sd1 > 0 ? _sd2 / _sd1 : 0.0;

    _computeSmoothedPeaksAndLabels();
    _computeHRV(); // Compute remaining metrics (LF, HF, stress index)
    _computeHRRecovery();
    _buildRecoverySpots();
  }

  void _computeHRRecovery() {
    final hist = widget.bpmHistory.where((v) => v > 0).toList();
    final dur = widget.recordingDuration.toDouble();
    if (hist.length < 5 || dur <= 0) return;

    final n = hist.length;
    final secPerSample = dur / n;

    double avgIn(double tStart, double tEnd) {
      final startIdx = (tStart / secPerSample).floor().clamp(0, n - 1);
      final endIdx = (tEnd / secPerSample).ceil().clamp(0, n - 1);
      if (endIdx <= startIdx) return hist[startIdx].toDouble();
      final slice = hist.sublist(startIdx, endIdx + 1);
      final valid = slice.where((v) => v > 0).toList();
      if (valid.isEmpty) return 0.0;
      return valid.reduce((a, b) => a + b) / valid.length;
    }

    _hr0 = avgIn(0, 10);
    if (dur >= 60) {
      _hr60 = avgIn(50, 60);
      _hrr60 = (_hr0 - _hr60).clamp(0.0, 300.0);
      // Slope over first 60s
      final endT = 60.0;
      final endIdx = (endT / secPerSample).floor().clamp(1, n - 1);
      final xs = List<double>.generate(endIdx + 1, (i) => i * secPerSample);
      final ys = hist.sublist(0, endIdx + 1).map((v) => v.toDouble()).toList();
      final m = _linRegSlope(xs, ys); // bpm per second
      _slope60_bpmPerMin = m * 60.0;
    }
    if (dur >= 120) {
      _hr120 = avgIn(110, 120);
      _hrr120 = (_hr0 - _hr120).clamp(0.0, 300.0);
      // Tau estimate using log-linear with y_inf as mean of last 20s
      final yInf = avgIn((dur - 20).clamp(0, dur - 1), dur);
      if (yInf > 0 && _hr0 > yInf) {
        final xs = <double>[];
        final ys = <double>[];
        final maxT = 120.0;
        final maxIdx = (maxT / secPerSample).floor().clamp(1, n - 1);
        for (int i = 0; i <= maxIdx; i++) {
          final t = i * secPerSample;
          final y = hist[i].toDouble();
          final z = y - yInf;
          if (z > 1e-3) {
            xs.add(t);
            ys.add(log(z));
          }
        }
        if (xs.length >= 3) {
          final slope = _linRegSlope(xs, ys); // slope of ln(z) vs t
          if (slope < 0) {
            _tauSec = (-1.0 / slope);
          }
        }
      }
    }
  }

  double _linRegSlope(List<double> x, List<double> y) {
    final n = x.length;
    if (n == 0 || y.length != n) return 0.0;
    final meanX = x.reduce((a, b) => a + b) / n;
    final meanY = y.reduce((a, b) => a + b) / n;
    double num = 0.0, den = 0.0;
    for (int i = 0; i < n; i++) {
      final dx = x[i] - meanX;
      num += dx * (y[i] - meanY);
      den += dx * dx;
    }
    if (den == 0.0) return 0.0;
    return num / den;
  }

  void _buildRecoverySpots() {
    final hist = widget.bpmHistory.where((v) => v > 0).toList();
    final dur = widget.recordingDuration.toDouble();
    _recoverySpots.clear();
    if (hist.length < 2 || dur <= 0) return;
    final n = hist.length;
    final secPerSample = dur / n;
    for (int i = 0; i < n; i++) {
      _recoverySpots.add(FlSpot(i * secPerSample, hist[i].toDouble()));
    }
  }

  Widget _buildHrrChart() {
    if (_recoverySpots.length < 2) {
      return const SizedBox.shrink();
    }
    final minX = 0.0;
    final maxX = widget.recordingDuration.toDouble();
    double minY = _recoverySpots.map((s) => s.y).reduce(min);
    double maxY = _recoverySpots.map((s) => s.y).reduce(max);
    final padding = ((maxY - minY).abs() * 0.1).clamp(2.0, 15.0);
    minY = (minY - padding).clamp(30.0, 300.0);
    maxY = (maxY + padding).clamp(30.0, 300.0);

    List<LineChartBarData> markerLines = [];
    void addVLine(double x, Color color) {
      if (x <= maxX) {
        markerLines.add(LineChartBarData(
          spots: [FlSpot(x, minY), FlSpot(x, maxY)],
          isCurved: false,
          color: color.withOpacity(0.35),
          barWidth: 1.5,
          dotData: const FlDotData(show: false),
        ));
      }
    }

    addVLine(60, Colors.blueGrey);
    addVLine(120, Colors.blueGrey);

    return SizedBox(
      height: 160,
      child: Card(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color.fromARGB(120, 158, 158, 158)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
          child: LineChart(
            LineChartData(
              gridData: const FlGridData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (value, meta) {
                      String label = '';
                      if (value == 0) label = '0s';
                      if ((value - 60).abs() < 0.01 && maxX >= 60)
                        label = '60s';
                      if ((value - 120).abs() < 0.01 && maxX >= 120)
                        label = '120s';
                      if ((value - maxX).abs() < 0.01)
                        label = '${maxX.toInt()}s';
                      return Text(label, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              minX: minX,
              maxX: maxX,
              minY: minY,
              maxY: maxY,
              lineBarsData: [
                LineChartBarData(
                  spots: _recoverySpots,
                  isCurved: true,
                  color: const Color.fromARGB(255, 0, 0, 0),
                  barWidth: 2.0,
                  dotData: const FlDotData(show: false),
                ),
                ...markerLines,
              ],
            ),
          ),
        ),
      ),
    );
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

    // Mean RR (for LF/HF calculation and stress index)
    _meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;

    // Stress Index (Baevsky approximation) - using SDNN from PPGAlgorithm
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
    if (times.isEmpty || values.isEmpty || newTimes.isEmpty) return result;
    int idx = 0;
    for (double t in newTimes) {
      if (t <= times.first) {
        result.add(values.first);
        continue;
      }
      while (idx < times.length - 1 && t > times[idx + 1]) {
        idx++;
      }
      if (idx >= times.length - 1) {
        result.add(values.last);
        continue;
      }
      final t0 = times[idx];
      final t1 = times[idx + 1];
      final v0 = values[idx];
      final v1 = values[idx + 1];
      final frac = (t - t0) / (t1 - t0);
      result.add(v0 + frac * (v1 - v0));
    }
    return result;
  }

  int _nextPowerOf2(int n) {
    if (n <= 0) return 1;
    return pow(2, (log(n) / log(2)).ceil()).toInt();
  }

  double _integrateBand(
      List<double> psd, double freqResolution, double startHz, double endHz) {
    if (psd.isEmpty || freqResolution <= 0) return 0.0;
    int startIdx = (startHz / freqResolution).floor().clamp(0, psd.length - 1);
    int endIdx =
        (endHz / freqResolution).ceil().clamp(startIdx, psd.length - 1);
    double sum = 0.0;
    for (int i = startIdx; i <= endIdx; i++) {
      sum += psd[i];
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

    // Robust detection: local threshold + prominence + refractory
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
      // Derived series for full record
      final smoothedWaveform = _smoothedData
          .map((s) => {
                't': s.x,
                'y': s.y,
              })
          .toList();
      final peakTimesSec = _peakSpots.map((s) => s.x).toList();
      final rrIntervalsMs = <double>[];
      for (int i = 1; i < _peakSpots.length; i++) {
        rrIntervalsMs.add((_peakSpots[i].x - _peakSpots[i - 1].x) * 1000.0);
      }
      final record = {
        'date': formattedDate,
        'time': formattedTime,
        'averageBPM': averageBpm,
        'dataForPlot': dataForPlot,
        'notes': notesContent,
        'bpmList': bpmList,
        'bpmHistory': widget.bpmHistory,
        'frames': frames,
        'waveformSmoothed': smoothedWaveform,
        'peakTimesSec': peakTimesSec,
        'rrIntervalsMs': rrIntervalsMs,
        'duration': widget.recordingDuration,
        'respiratoryRate': _respiratoryRate, // Přidáno: RR
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
        },
        'hrr': {
          'hr0': _hr0,
          'hr60': _hr60,
          'hr120': _hr120,
          'hrr60': _hrr60,
          'hrr120': _hrr120,
          'slope60_bpmPerMin': _slope60_bpmPerMin,
          'tauSec': _tauSec,
        },
        'recoveryChart': {
          'durationSec': widget.recordingDuration,
          'points': _recoverySpots
              .map((s) => {
                    't': s.x,
                    'bpm': s.y,
                  })
              .toList(),
        },
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
    // Section toggle: 0=Signal, 1=HRV, 2=HRR
    _summarySectionIndex = _summarySectionIndex.clamp(0, 2);
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
            const SizedBox(height: 12),
            // Section toggle buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  _buildSectionChip('Signál', 0),
                  const SizedBox(width: 8),
                  _buildSectionChip('HRV', 1),
                  const SizedBox(width: 8),
                  _buildSectionChip('Zotavení', 2),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Conditional sections
            if (_summarySectionIndex == 0)
              _buildSignalSection(chartWidth, minX, maxX, minY, maxY)
            else if (_summarySectionIndex == 1)
              _buildHrvSection()
            else
              _buildHrrSection(),
            const SizedBox(height: 16),
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

  // Section toggle state
  int _summarySectionIndex = 0;

  Widget _buildSectionChip(String label, int index) {
    final bool selected = _summarySectionIndex == index;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        setState(() => _summarySectionIndex = index);
      },
      selectedColor: Colors.blue.shade100,
      backgroundColor: Colors.white,
      labelStyle: TextStyle(
        color: selected ? Colors.blue.shade900 : Colors.black,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildSignalSection(
      double chartWidth, double minX, double maxX, double minY, double maxY) {
    return SizedBox(
      height: 170,
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: chartWidth,
              child: RepaintBoundary(
                child: Stack(
                  clipBehavior: Clip.none,
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
                        borderData: FlBorderData(
                          show: true,
                          border:
                              Border.all(color: Colors.grey.withOpacity(0.3)),
                        ),
                        minX: minX,
                        maxX: maxX,
                        minY: minY,
                        maxY: maxY,
                        lineBarsData: [
                          LineChartBarData(
                            spots: _smoothedData,
                            isCurved: false,
                            color: const Color.fromARGB(255, 246, 41, 0),
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
                              getDotPainter: (spot, percent, barData, index) =>
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
                      final posX = ((label.x - minX) / (maxX - minX + 1e-6)) *
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
                      final posX = ((label.x - minX) / (maxX - minX + 1e-6)) *
                          chartWidth;
                      return Positioned(
                        left: posX,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            label.time,
                            style: const TextStyle(
                                fontSize: 9, color: Colors.black),
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
    );
  }

  Widget _buildHrvSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
              _buildHRVCard('Dechová frekvence',
                  '${_respiratoryRate.toStringAsFixed(1)} dechů/min'),
              _buildHRVCard('SDNN', '${_sdnn.toStringAsFixed(2)} ms'),
              _buildHRVCard('RMSSD', '${_rmssd.toStringAsFixed(2)} ms'),
              _buildHRVCard('pNN50', '${_pnn50.toStringAsFixed(2)} %'),
              _buildHRVCard('Průměrný RR', '${_meanRR.toStringAsFixed(2)} ms'),
              _buildHRVCard('SD1', '${_sd1.toStringAsFixed(2)} ms'),
              _buildHRVCard('SD2', '${_sd2.toStringAsFixed(2)} ms'),
              _buildHRVCard('SD2/SD1', '${_sd2sd1.toStringAsFixed(2)}'),
              _buildHRVCard('LF', '${_lf.toStringAsFixed(2)} %'),
              _buildHRVCard('HF', '${_hf.toStringAsFixed(2)} %'),
              _buildHRVCard('LF/HF', '${_lfhf.toStringAsFixed(2)}'),
              _buildHRVCard(
                'Index stresu',
                '${_stressIndex.toStringAsFixed(2)}',
                valueColor: _getStressColor(_stressIndex),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHrrSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Zotavení srdeční frekvence',
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Měří pokles tepové frekvence po zátěži. Vyšší pokles za 60–120 s obvykle značí lepší kardiovaskulární kondici a rychlejší zotavení.',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildHrrChart(),
        ),
        const SizedBox(height: 8),
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
              _buildHRVCard('HR (0–10 s)',
                  _hr0 > 0 ? '${_hr0.toStringAsFixed(1)} bpm' : '—'),
              _buildHRVCard('HR v 60. s',
                  _hr60 > 0 ? '${_hr60.toStringAsFixed(1)} bpm' : '—'),
              _buildHRVCard('Pokles 0–60 s',
                  _hrr60 > 0 ? '${_hrr60.toStringAsFixed(1)} bpm' : '—'),
              _buildHRVCard('Sklon (0–60 s)',
                  '${_slope60_bpmPerMin.toStringAsFixed(1)} bpm/min'),
              _buildHRVCard('HR v 120. s',
                  _hr120 > 0 ? '${_hr120.toStringAsFixed(1)} bpm' : '—'),
              _buildHRVCard('Pokles 0–120 s',
                  _hrr120 > 0 ? '${_hrr120.toStringAsFixed(1)} bpm' : '—'),
              _buildHRVCard('Tau (odhad)',
                  _tauSec > 0 ? '${_tauSec.toStringAsFixed(1)} s' : '—'),
            ],
          ),
        ),
      ],
    );
  }

  void _showMetricInfo(String title, String value) {
    final desc = _getMetricInfoText(title);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      backgroundColor: Colors.white,
      isDismissible: true,
      enableDrag: true,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                desc,
                style: const TextStyle(fontSize: 15),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Zavřít'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getMetricInfoText(String title) {
    switch (title) {
      // Czech labels used in UI
      case 'Dechová frekvence':
        return 'Dechová frekvence (dechů/min). Odvozeno ze změn amplitudy PPG, typicky 6–20 dechů/min v klidu.';
      case 'Průměrný RR':
        return 'Průměrná délka NN (RR) intervalu v milisekundách. Nepřímo souvisí s klidovou TF (delší RR = nižší BPM).';
      case 'Index stresu':
        return 'Baevského index – orientační míra stresové zátěže. Vyšší hodnoty mohou ukazovat na vyšší napětí, interpretuj s ohledem na podmínky měření.';
      // HR Recovery metrics (current titles)
      case 'HR₀':
        return 'Průměrná tepová frekvence v prvních 10 sekundách po ukončení zátěže. Slouží jako výchozí úroveň pro posouzení poklesu (HRR).';
      case 'HR@60s':
        return 'Tepová frekvence kolem 60. sekundy zotavení (průměr z 50–60 s). Používá se k výpočtu HRR60.';
      case 'HRR60':
        return 'Pokles TF za 60 s: rozdíl mezi HR₀ (0–10 s) a HR@60s (50–60 s). Vyšší hodnota obvykle značí lepší kondici a rychlejší zotavení.';
      case 'Slope(0–60s)':
        return 'Lineární sklon poklesu TF v prvních 60 s, vyjádřený v bpm/min. Více záporný sklon (rychlejší pokles) typicky znamená lepší zotavení.';
      case 'HR@120s':
        return 'Tepová frekvence kolem 120. sekundy zotavení (průměr z 110–120 s). Vhodné pro delší protokoly (HRR120).';
      case 'HRR120':
        return 'Pokles TF za 120 s: rozdíl mezi HR₀ a HR@120s (110–120 s). Vyšší hodnota obvykle značí lepší kardiovaskulární kondici.';
      case 'Tau':
        return 'Odhad časové konstanty (τ) exponenciálního poklesu TF směrem k bazální hodnotě. Nižší τ znamená rychlejší zotavení.';

      // HR Recovery metrics (alternative Czech titles)
      case 'HR (0–10 s)':
        return 'Průměrná tepová frekvence v prvních 10 sekundách zotavení. Slouží jako výchozí hodnota pro porovnání poklesu.';
      case 'HR v 60. s':
        return 'Tepová frekvence kolem 60. sekundy po ukončení zátěže. Porovnává se s počáteční HR pro HRR60.';
      case 'Pokles 0–60 s':
        return 'Heart Rate Recovery za 60 s: rozdíl HR mezi 0–10 s a 50–60 s. Vyšší = rychlejší zotavení.';
      case 'Sklon (0–60 s)':
        return 'Lineární sklon poklesu HR v prvních 60 s, vyjádřený v bpm/min. Více záporný = rychlejší pokles.';
      case 'HR v 120. s':
        return 'Tepová frekvence kolem 120. sekundy. Vhodné pro delší zotavení a výpočet HRR120.';
      case 'Pokles 0–120 s':
        return 'Heart Rate Recovery za 120 s: rozdíl HR mezi 0–10 s a 110–120 s. Vyšší = lepší kondice.';
      case 'Tau (odhad)':
        return 'Odhad časové konstanty exponenciálního poklesu HR k bazální hodnotě (nižší znamená rychlejší zotavení).';
      case 'RMSSD':
        return 'Root Mean Square of Successive Differences – citlivé na krátkodobou, parasympatickou aktivitu. Vyšší hodnoty obvykle znamenají lepší regeneraci a nižší stres.';
      case 'SDNN':
        return 'Standardní odchylka NN intervalů – celková variabilita srdeční frekvence za celé měření. Odráží kombinaci krátkodobých i dlouhodobých vlivů.';
      case 'pNN50':
        return 'Podíl po sobě jdoucích NN intervalů, které se liší o více než 50 ms. Vyšší procento obvykle ukazuje na silnější parasympatickou aktivitu.';
      case 'Mean RR':
        return 'Průměrná délka NN (RR) intervalu v milisekundách. Nepřímo souvisí s klidovou tepovou frekvencí (delší RR = nižší BPM).';
      case 'SD1':
        return 'SD1 (Poincaré) – krátkodobá HRV (beat‑to‑beat variabilita). Blízce souvisí s RMSSD a parasympatikem.';
      case 'SD2':
        return 'SD2 (Poincaré) – dlouhodobá HRV. Zachycuje pomalejší kolísání a trend variability.';
      case 'SD2/SD1':
        return 'Poměr dlouhodobé/krátkodobé variability. Vyšší poměr může ukazovat na převahu dlouhodobých oscilací nebo zvýšený stres.';
      case 'LF':
        return 'Low Frequency složka (0.04–0.15 Hz) – směs sympatické i parasympatické aktivity. Uvádíme jako procento z (LF+HF).';
      case 'HF':
        return 'High Frequency složka (0.15–0.40 Hz) – převážně parasympatická aktivita (dýchací sinusová arytmie). Uvádíme jako procento z (LF+HF).';
      case 'LF/HF':
        return 'Poměr LF/HF – orientační ukazatel rovnováhy sympatikus/parasympatikus. Interpretace musí brát v úvahu kontext a délku záznamu.';
      case 'RR':
        return 'Dechová frekvence (breaths per minute). Odvozeno ze změn amplitudy PPG, typicky 6–20 dechů/min v klidu.';
      case 'Stress Index':
        return 'Baevského index – orientační míra stresové zátěže. Vyšší hodnoty mohou ukazovat na vyšší napětí. Vnímej s ohledem na podmínky měření.';
      default:
        return 'Metrika HRV. Hodnoť v kontextu délky záznamu, artefaktů a podmínek měření.';
    }
  }

  Widget _buildHRVCard(String title, String value, {Color? valueColor}) {
    final iconKey = GlobalKey();
    final hint = _getMetricInfoText(title);
    return InkWell(
      onTap: () => _showAnchoredMetricInfo(title, value, iconKey),
      borderRadius: BorderRadius.circular(10),
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(
            color: Color.fromARGB(120, 158, 158, 158),
            width: 1,
          ),
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Tooltip(
                    message: hint,
                    waitDuration: const Duration(milliseconds: 500),
                    showDuration: const Duration(seconds: 4),
                    preferBelow: false,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 16,
                        color: valueColor ?? Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 4,
              top: 4,
              child: Tooltip(
                message: 'Tip: klepni pro vysvětlení',
                waitDuration: const Duration(milliseconds: 300),
                child: InkResponse(
                  key: iconKey,
                  radius: 16,
                  onTap: () => _showAnchoredMetricInfo(title, value, iconKey),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.black.withOpacity(0.45),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAnchoredMetricInfo(
      String title, String value, GlobalKey anchorKey) async {
    final ctx = anchorKey.currentContext;
    if (ctx == null) {
      _showMetricInfo(title, value);
      return;
    }
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      _showMetricInfo(title, value);
      return;
    }
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;
    final rect = RelativeRect.fromLTRB(
      offset.dx,
      offset.dy + size.height,
      offset.dx + size.width,
      offset.dy,
    );
    final desc = _getMetricInfoText(title);
    await showMenu(
      context: context,
      position: rect,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      items: [
        PopupMenuItem(
          enabled: false,
          padding: const EdgeInsets.all(0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        value,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(desc),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
