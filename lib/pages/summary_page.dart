import 'package:flutter/foundation.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/home.dart';
import 'package:tepovka/ppg_algo.dart';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:health/health.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/elements/peak_detector.dart';
import 'package:tepovka/elements/hrv_calculator.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/services/measurement_quality.dart';
import 'package:tepovka/services/measurement_tags.dart';
import 'package:tepovka/elements/spectral_quality.dart';
import 'package:tepovka/widgets/bpm_scale.dart';
import 'package:tepovka/widgets/info_widgets.dart';
// Cloud sync disabled for local-only mode

enum PatientStatus { normal, rest }

class TimeLabel {
  double x;
  String time;
  TimeLabel(this.x, this.time);
}

class Summary extends StatefulWidget {
  final double averageBPM;
  final List<double> data;
  final List<int> bpmList;
  final List<double> frames;
  final int recordingDuration; // Přidáno: Délka měření
  /// Wall-clock start of the measurement itself, so the stored timestamp does
  /// not drift with however long the user spends on this summary screen.
  final DateTime startedAt;
  final double respiratoryRate; // Přidáno: Dechová frekvence
  final List<double> bpmHistory; // HR time series for Recovery metrics
  final List<RgbMeans> rawRgbSamples; // Raw RGB samples for export
  /// Wall-clock razítka jednotlivých snímků (ms). Prázdné u starších cest,
  /// pak se frekvence odvodí z počtu vzorků a délky měření.
  final List<int> frameTimestampsMs;

  /// Udaje vyplnene ve vyzkumnem rezimu pred merenim (ID probanda apod.).
  final Map<String, String> metadata;

  /// Nastavení kamery za měření a podíl přepálených pixelů (řádky hlavičky
  /// exportu). Drží se odděleně od [metadata], to jsou údaje o probandovi.
  final Map<String, String> cameraSettings;
  final double sdnn; // HRV: SDNN
  final double rmssd; // HRV: RMSSD
  final double pnn50; // HRV: pNN50
  final double sd1; // HRV: SD1
  final double sd2; // HRV: SD2
  final double spo2; // Estimated oxygen saturation
  final double bpmConfidence; // BPM confidence from FFT/autocorr
  final double bpmSnrScore; // SNR component of confidence
  final double bpmHarmonicScore; // Harmonic component of confidence
  final double bpmAutocorrScore; // Autocorrelation component of confidence
  const Summary({
    super.key,
    required this.averageBPM,
    required this.data,
    required this.bpmList,
    required this.frames,
    required this.recordingDuration,
    required this.startedAt,
    required this.respiratoryRate, // Přidáno: RR
    required this.bpmHistory,
    required this.rawRgbSamples,
    this.frameTimestampsMs = const [],
    this.metadata = const {},
    this.cameraSettings = const {},
    required this.sdnn,
    required this.rmssd,
    required this.pnn50,
    required this.sd1,
    required this.sd2,
    required this.spo2,
    required this.bpmConfidence,
    required this.bpmSnrScore,
    required this.bpmHarmonicScore,
    required this.bpmAutocorrScore,
  });
  @override
  State<Summary> createState() => _SummaryState();
}

class _SummaryState extends State<Summary> {
  final Health _health = Health();
  // ignore: unused_field
  final List<HealthDataPoint> _healthDataList = [];
  bool _isSaving = false;
  final TextEditingController _notesController = TextEditingController();

  /// Circumstances picked on this screen, saved with the record.
  final Set<MeasurementTag> _tags = {};
  List<FlSpot> _smoothedData = [];
  List<FlSpot> _peakSpots = [];
  final List<TimeLabel> _labels = [];
  final ScrollController _signalScrollController = ScrollController();
  double _calculatedAverageBPM = 0.0;

  /// Nominální frekvence z konfigurace kamery. Skutečná bývá nižší (~24 fps),
  /// proto se všude počítá s [_fs], ne s touto konstantou.
  static const double nominalSampleRate = 30.0;

  /// Změřená vzorkovací frekvence tohoto měření.
  double get _fs => _effectiveFs();

  double _effectiveFs() {
    final ts = widget.frameTimestampsMs;
    if (ts.length >= 10) {
      final span = ts.last - ts.first;
      if (span > 0) {
        final fs = (ts.length - 1) * 1000.0 / span;
        if (fs >= 5 && fs <= 120) return fs;
      }
    }
    if (widget.recordingDuration > 0 && widget.data.length >= 10) {
      final fs = widget.data.length / widget.recordingDuration;
      if (fs >= 5 && fs <= 120) return fs;
    }
    return nominalSampleRate;
  }

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
  double _slope60BpmPerMin = 0.0;
  double _tauSec = 0.0;
  final List<FlSpot> _recoverySpots = [];
  double _spo2 = 0.0;
  double _bpmConfidence = 0.0;
  double _bpmSnrScore = 0.0;
  double _bpmHarmonicScore = 0.0;
  double _bpmAutocorrScore = 0.0;
  double _bpmCiLower = 0.0;
  double _bpmCiUpper = 0.0;
  double _bpmMean = 0.0;
  double _bpmStdDev = 0.0;

  double get _effectiveAverageBpm =>
      _calculatedAverageBPM > 0 ? _calculatedAverageBPM : widget.averageBPM;

  int _responsiveGridColumns(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    // Ensure at least two columns on small phones (e.g. iPhone SE ~320dp)
    if (width < 320) return 1; // extremely narrow (unlikely)
    if (width < 700) return 2; // phones and small tablets -> 2 columns
    return 3; // larger tablets -> 3 columns
  }

  @override
  void initState() {
    //debugPrint('red_channel: ${widget.data}');
    super.initState();
    _respiratoryRate =
        (widget.respiratoryRate > 0 && widget.respiratoryRate <= 30)
            ? widget.respiratoryRate
            : 0.0; // 0.0 = nevalidní / nezobrazovat

    // Use HRV metrics from PPGAlgorithm (more accurate)
    _sdnn = widget.sdnn;
    _rmssd = widget.rmssd;
    _pnn50 = widget.pnn50;
    _sd1 = widget.sd1;
    _sd2 = widget.sd2;
    _spo2 = (widget.spo2 >= 70.0 && widget.spo2 <= 100.0) ? widget.spo2 : 0.0;
    _bpmConfidence = widget.bpmConfidence.clamp(0.0, 1.0);
    _bpmSnrScore = widget.bpmSnrScore.clamp(0.0, 1.0);
    _bpmHarmonicScore = widget.bpmHarmonicScore.clamp(0.0, 1.0);
    _bpmAutocorrScore = widget.bpmAutocorrScore.clamp(0.0, 1.0);
    _computeBpmConfidenceInterval();
    _sd2sd1 = _sd1 > 0 ? _sd2 / _sd1 : 0.0;

    _computeSmoothedPeaksAndLabels();
    _computeHRV(); // Compute remaining metrics (LF, HF, stress index)
    _computeHRRecovery();
    _buildRecoverySpots();
    _quality = _gradeSignal();
  }

  /// Signal quality of this recording, graded off the UI thread; a long
  /// recording takes dozens of FFTs.
  late final Future<SpectralQuality?> _quality;
  SpectralQuality? _qualityResult;
  bool _qualityDone = false;

  Future<SpectralQuality?> _gradeSignal() async {
    final double fs = _fs;
    final int expected = (widget.recordingDuration * fs).toInt();
    // The same samples the export and the history detail use.
    final List<double> data = widget.data.length > expected
        ? widget.data.sublist(widget.data.length - expected)
        : List<double>.from(widget.data);
    final SpectralQuality? result = await compute(_gradeRecording, (data, fs));
    if (mounted) {
      setState(() {
        _qualityResult = result;
        _qualityDone = true;
      });
    }
    return result;
  }

  void _computeBpmConfidenceInterval() {
    final values = widget.bpmHistory.where((v) => v > 0).toList();
    if (values.length < 2) return;
    _bpmMean = values.reduce((a, b) => a + b) / values.length;
    double sumSq = 0.0;
    for (final value in values) {
      final diff = value - _bpmMean;
      sumSq += diff * diff;
    }
    _bpmStdDev = sqrt(sumSq / (values.length - 1));
    final standardError = _bpmStdDev / sqrt(values.length.toDouble());
    final margin = 1.96 * standardError;
    _bpmCiLower = max(0.0, _bpmMean - margin);
    _bpmCiUpper = _bpmMean + margin;
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
      _slope60BpmPerMin = m * 60.0;
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
          color: color.withValues(alpha: 0.35),
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
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 16, 8),
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
                      if ((value - 60).abs() < 0.01 && maxX >= 60) {
                        label = '60s';
                      }
                      if ((value - 120).abs() < 0.01 && maxX >= 120) {
                        label = '120s';
                      }
                      if ((value - maxX).abs() < 0.01) {
                        label = '${maxX.toInt()}s';
                      }
                      return Text(label, style: const TextStyle(fontSize: 10));
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
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
    int expectedLength = (widget.recordingDuration * _fs).toInt();
    List<double> trimmedData = widget.data;
    if (trimmedData.length > expectedLength) {
      trimmedData = trimmedData.sublist(trimmedData.length - expectedLength);
    }
    // Create spots with time x; signal is already oriented in Home.
    List<FlSpot> spots = [];
    for (int i = 0; i < trimmedData.length; i++) {
      spots.add(FlSpot(i / _fs, trimmedData[i]));
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
    List<int> peaks = PeakDetector.findPeaks(yValues, sampleRate: _fs);
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
      if (_calculatedAverageBPM < 40 || _calculatedAverageBPM > 200) {
        _calculatedAverageBPM = 70.0;
      }
    } else {
      _calculatedAverageBPM = 0.0;
    }
    // Generate time labels every second
    double totalTime = trimmedData.length / _fs;
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
    final hrv = HrvCalculator.compute(rrIntervals);

    _meanRR = hrv.meanRrMs;
    _sdnn = hrv.sdnn;
    _rmssd = hrv.rmssd;
    _pnn50 = hrv.pnn50;
    _sd1 = hrv.sd1;
    _sd2 = hrv.sd2;
    _sd2sd1 = hrv.sd1Sd2Ratio > 0 ? hrv.sd2 / hrv.sd1 : 0.0;
    _stressIndex = hrv.baevskySi;
    _lf = hrv.lfNorm;
    _hf = hrv.hfNorm;
    _lfhf = hrv.lfHfRatio;

    // Fallback RR estimate from RR-interval modulation when algo RR is unavailable.
    if (_respiratoryRate == 0.0 && rrIntervals.length >= 10) {
      const double windowSec = 6.0;
      final int windowSamples =
          (windowSec * 1000 / _meanRR).round().clamp(3, rrIntervals.length);

      final List<double> variances = [];
      for (int i = 0; i <= rrIntervals.length - windowSamples; i++) {
        final window = rrIntervals.sublist(i, i + windowSamples);
        final mean = window.reduce((a, b) => a + b) / window.length;
        final variance =
            window.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
                window.length;
        variances.add(variance);
      }

      if (variances.isNotEmpty) {
        int breathCount = 0;
        for (int i = 1; i < variances.length - 1; i++) {
          if (variances[i] > variances[i - 1] &&
              variances[i] > variances[i + 1]) {
            breathCount++;
          }
        }

        final totalTimeSec = rrIntervals.reduce((a, b) => a + b) / 1000.0;
        if (totalTimeSec > 0 && breathCount > 0) {
          final estimated = (breathCount / totalTimeSec) * 60.0;
          if (estimated >= 6 && estimated <= 30) {
            _respiratoryRate = estimated;
          }
        }
      }
    }
  }

  Color _getStressColor(double index) {
    if (index < 50) return Colors.green;
    if (index < 100) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    _notesController.dispose();
    _signalScrollController.dispose();
    super.dispose();
  }

  /// Asks for Health access once, for heart rate and, when this measurement
  /// has one worth writing, heart rate variability.
  Future<void> _authorizeHealth({required bool withHrv}) async {
    final bool granted = await _health.requestAuthorization(
      [
        HealthDataType.HEART_RATE,
        if (withHrv) HealthDataType.HEART_RATE_VARIABILITY_SDNN,
      ],
      permissions: [
        HealthDataAccess.READ_WRITE,
        if (withHrv) HealthDataAccess.WRITE,
      ],
    );
    if (!granted) {
      debugPrint('Oprávnění k zápisu do Apple Health nebylo uděleno.');
    }
  }

  /// SDNN worth writing to Health as heart rate variability, or null. Only
  /// from a minute or more with a good signal: Apple's own HRV readings are
  /// one-minute recordings, and a shorter or noisier camera recording would
  /// put a number in the user's health record it cannot stand behind.
  /// iOS only; Health Connect has no SDNN type.
  Future<double?> _sdnnForHealth() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return null;
    if (widget.recordingDuration < 60) return null;
    final SpectralQuality? quality = await _quality;
    if (quality?.level != MeasurementQuality.good) return null;
    if (!_sdnn.isFinite || _sdnn <= 0 || _sdnn > 300) return null;
    return _sdnn;
  }

  Future<void> _saveMeasurement() async {
    if (_isSaving) {
      return;
    }
    _isSaving = true;
    try {
      final storage = StorageService();
      // Stamp the record with when the measurement was taken, not when the
      // user got around to tapping save.
      final started = widget.startedAt;
      final ended = started.add(Duration(seconds: widget.recordingDuration));
      final formattedDate =
          '${started.year}-${started.month.toString().padLeft(2, '0')}-${started.day.toString().padLeft(2, '0')}';
      final formattedTime =
          '${started.hour.toString().padLeft(2, '0')}:${started.minute.toString().padLeft(2, '0')}:${started.second.toString().padLeft(2, '0')}';
      final averageBpm = _effectiveAverageBpm.toInt();
      final dataForPlot = widget.data;
      final notesContent = _notesController.text;
      final bpmList = widget.bpmList;
      final frames = widget.frames.skip(2).toList();
      // Derived series for full record
      final smoothedWaveform = _smoothedData
          .map((s) => {
                't': s.x,
                'y': s.y,
              })
          .toList();
      final rawRgbSamples = widget.rawRgbSamples
          .map((sample) => {
                'red': sample.red,
                'green': sample.green,
                'blue': sample.blue,
              })
          .toList();
      final peakTimesSec = _peakSpots.map((s) => s.x).toList();
      // Razítka zarovnaná na uložený signál (data se ořezávají odzadu).
      final allStamps = widget.frameTimestampsMs;
      final frameTimestampsMs = allStamps.length >= dataForPlot.length
          ? allStamps.sublist(allStamps.length - dataForPlot.length)
          : allStamps;
      final rrIntervalsMs = <double>[];
      for (int i = 1; i < _peakSpots.length; i++) {
        rrIntervalsMs.add((_peakSpots[i].x - _peakSpots[i - 1].x) * 1000.0);
      }
      final SpectralQuality? quality = await _quality;
      final record = {
        'date': formattedDate,
        'time': formattedTime,
        // Unambiguous machine-readable instants for export/analysis.
        'startedAt': started.toIso8601String(),
        'endedAt': ended.toIso8601String(),
        'savedAt': DateTime.now().toIso8601String(),
        'averageBPM': averageBpm,
        'dataForPlot': dataForPlot,
        'notes': notesContent,
        'tags': [
          for (final MeasurementTag tag in MeasurementTag.values)
            if (_tags.contains(tag)) tag.name,
        ],
        'bpmList': bpmList,
        'bpmHistory': widget.bpmHistory,
        'rawRgbSamples': rawRgbSamples,
        'frames': frames,
        'sampleRateHz': _fs,
        'metadata': widget.metadata,
        'cameraSettings': widget.cameraSettings,
        'frameTimestampsMs': frameTimestampsMs,
        'waveformSmoothed': smoothedWaveform,
        'peakTimesSec': peakTimesSec,
        'rrIntervalsMs': rrIntervalsMs,
        'duration': widget.recordingDuration,
        'respiratoryRate': _respiratoryRate, // Přidáno: RR
        'spo2': _spo2,
        'confidence': {
          'bpmConfidence': _bpmConfidence,
          'snrScore': _bpmSnrScore,
          'harmonicScore': _bpmHarmonicScore,
          'autocorrScore': _bpmAutocorrScore,
          'meanBpm': _bpmMean,
          'stdDevBpm': _bpmStdDev,
          'ciLowerBpm': _bpmCiLower,
          'ciUpperBpm': _bpmCiUpper,
        },
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
          'confidence': {
            'bpmConfidence': _bpmConfidence,
            'snrScore': _bpmSnrScore,
            'harmonicScore': _bpmHarmonicScore,
            'autocorrScore': _bpmAutocorrScore,
            'meanBpm': _bpmMean,
            'stdDevBpm': _bpmStdDev,
            'ciLowerBpm': _bpmCiLower,
            'ciUpperBpm': _bpmCiUpper,
          },
        },
        'hrr': {
          'hr0': _hr0,
          'hr60': _hr60,
          'hr120': _hr120,
          'hrr60': _hrr60,
          'hrr120': _hrr120,
          'slope60_bpmPerMin': _slope60BpmPerMin,
          'tauSec': _tauSec,
        },
        if (quality != null) 'signalQuality': quality.toJson(),
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
      await storage.appendRecord(record);
      await storage.appendRecordTxt(record);
      // Cloud sync disabled in local-only mode.
      _saveSucceeded = true;
    } catch (e) {
      // A failed save used to be swallowed here while the caller navigated
      // away as if it had worked, losing the measurement without a word.
      debugPrint('Failed to save measurement: $e');
      _saveSucceeded = false;
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(L10n.of(context).summarySaveFailed),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      _isSaving = false;
    }
  }

  /// Whether the last [_saveMeasurement] call actually persisted the record.
  /// The save buttons leave the screen only when it did.
  bool _saveSucceeded = false;

  Future<void> _saveToAppleHealth(double bpm, {double? sdnn}) async {
    // Guard against invalid BPM values (Health Connect requires >= 1)
    if (bpm.isNaN || !bpm.isFinite || bpm <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).summaryInvalidHeartRate),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    // Use the real measurement interval. Deriving it backwards from "now"
    // shifted the whole window forward by however long the summary was open.
    final start = widget.startedAt;
    final end = start.add(Duration(seconds: widget.recordingDuration));
    final bpmValue = bpm.round().clamp(1, 300); // clamp to a sensible range
    bool success = await _health.writeHealthData(
      value: bpmValue.toDouble(),
      type: HealthDataType.HEART_RATE,
      startTime: start,
      endTime: end,
    );
    bool hrvSaved = false;
    if (success && sdnn != null) {
      try {
        hrvSaved = await _health.writeHealthData(
          value: sdnn,
          type: HealthDataType.HEART_RATE_VARIABILITY_SDNN,
          startTime: start,
          endTime: end,
        );
      } catch (e) {
        debugPrint('HRV write to Apple Health failed: $e');
      }
    }
    if (!mounted) return;
    if (success) {
      debugPrint('Heart rate written to Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Expanded(
                child: Text(
                  hrvSaved
                      ? L10n.of(context).summarySavedToHealthWithHrv
                      : L10n.of(context).summarySavedToHealth,
                  style: TextStyle(
                    color: const Color.fromARGB(255, 192, 192, 192),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(
                width: 12,
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
      debugPrint('Failed to write to Apple Health');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(L10n.of(context).summaryHealthSaveError),
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 1),
        ),
      );
    }
  }

  /// Pomocná funkce na výpočet percentilu – používá se pro robustní škálování bez vlivů outlierů
  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = ((percentile / 100.0) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
  }

  double _getDynamicMinY() {
    if (_smoothedData.isEmpty) return -1.0;
    final yValues = _smoothedData.map((spot) => spot.y).toList();
    // Použij 2. percentil místo absolutního minima – ignoruje outliers na konci
    final minValue = _calculatePercentile(yValues, 2.0);
    return minValue - 1.0;
  }

  double _getDynamicMaxY() {
    if (_smoothedData.isEmpty) return 1.0;
    final yValues = _smoothedData.map((spot) => spot.y).toList();
    // Použij 98. percentil místo absolutního maxima – ignoruje outliers na konci
    final maxValue = _calculatePercentile(yValues, 98.0);
    return maxValue + 1.0;
  }

  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  /// True while saving, to disable the buttons and show progress.
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.value;
    final r = Responsive.of(context);
    double totalTime = _smoothedData.length / _fs;
    double chartWidth = totalTime * pixelsPerSecond;
    final minY = _getDynamicMinY();
    final maxY = _getDynamicMaxY();
    final double minX = 0.0;
    final double maxX = totalTime;
    // Section toggle: 0=Signal, 1=HRV, 2=HRR
    _summarySectionIndex = _summarySectionIndex.clamp(0, 2);
    final bool patient = settings.userMode == UserMode.patient;
    // Leaving is only through Save or Discard. A swipe back used to drop the
    // measurement without a word.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _discard();
      },
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: _canvas,
          appBar: AppBar(
            automaticallyImplyLeading: false,
            backgroundColor: _canvas,
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            centerTitle: true,
            title: Text(
              L10n.of(context).summaryTitle,
              style:
                  TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
            ),
          ),
          body: SingleChildScrollView(
            // The keyboard covers Save; scrolling puts it away.
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(
                r.pagePadding.left, r.spaceSm, r.pagePadding.right, r.spaceXl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _resultCard(context),
                SizedBox(height: r.spaceMd),
                // Tags and the note in both modes: they matter as much to a
                // patient keeping a diary as to a doctor.
                if (patient) ...[
                  _patientCard(context),
                  SizedBox(height: r.spaceMd),
                  _contextCard(context),
                ] else ...[
                  _contextCard(context),
                  SizedBox(height: r.spaceLg),
                  _sectionSelector(context),
                  SizedBox(height: r.spaceMd),
                  if (_summarySectionIndex == 0)
                    _buildSignalSection(chartWidth, minX, maxX, minY, maxY)
                  else if (_summarySectionIndex == 1)
                    _buildHrvSection(context)
                  else
                    _buildHrrSection(context),
                ],
              ],
            ),
          ),
          // Save and Discard take the place of the bottom bar: leaving through
          // the bar lost the measurement.
          bottomNavigationBar: _actionBar(context),
        ),
      ),
    );
  }

  /// Average heart rate, length and signal quality, with a nudge to measure
  /// again when the signal was weak.
  Widget _resultCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    // Too little signal to grade and no heart rate: that is a poor recording,
    // not an unknown one.
    final MeasurementQuality? quality = _qualityResult?.level ??
        (_qualityDone && _effectiveAverageBpm <= 0
            ? MeasurementQuality.poor
            : null);
    final int bpm = _effectiveAverageBpm.round();
    return InfoCard(
      child: Column(
        children: [
          Text(
            t.summaryAverageHeartRate.replaceAll(RegExp(r':\s*$'), ''),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: r.fontBody, color: kInfoSecondaryText),
          ),
          Text.rich(
            TextSpan(children: [
              TextSpan(
                text: bpm > 0 ? '$bpm' : t.homeNoReading,
                style: TextStyle(
                    fontSize: r.fontDisplayXl * 1.15,
                    fontWeight: FontWeight.bold),
              ),
              TextSpan(
                text: ' ${t.homeBpmUnit}',
                style: TextStyle(
                    fontSize: r.fontBodyLg, color: kInfoSecondaryText),
              ),
            ]),
          ),
          Text(
            [
              t.homeSecondsSuffix(widget.recordingDuration),
              if (quality != null) t.a11ySignalQuality(quality.label(t)),
              if (_respiratoryRate > 0)
                t.metricsBreathsPerMinute(_respiratoryRate.toStringAsFixed(0)),
            ].join(' · '),
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: r.fontSmall, color: kInfoSecondaryText),
          ),
          SizedBox(height: r.spaceLg),
          BpmScale(bpm: _effectiveAverageBpm),
          if (quality == MeasurementQuality.poor) ...[
            SizedBox(height: r.spaceMd),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                  r.spaceMd, r.spaceSm + 2, r.spaceXs, r.spaceXs),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4E0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          size: r.iconSm, color: const Color(0xFF8A5300)),
                      SizedBox(width: r.spaceSm),
                      Expanded(
                        child: Text(
                          t.summaryWeakSignal,
                          style: TextStyle(
                              fontSize: r.fontSmall,
                              color: const Color(0xFF8A5300)),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8A5300)),
                      onPressed: _busy ? null : _measureAgain,
                      child: Text(
                        t.summaryMeasureAgain,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Patient mode: a plain verdict instead of the metrics.
  Widget _patientCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final bool normal = _patientStatus() == PatientStatus.normal;
    final Color foreground =
        normal ? const Color(0xFF1E6B34) : const Color(0xFF8A5300);
    return InfoCard(
      color: normal ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4E0),
      child: Row(
        children: [
          Icon(normal ? Icons.check_circle : Icons.pause_circle_filled,
              color: foreground, size: r.iconLg),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  normal ? t.summaryInNorm : t.summaryRest,
                  style: TextStyle(
                      fontSize: r.fontTitle,
                      fontWeight: FontWeight.bold,
                      color: foreground),
                ),
                SizedBox(height: r.spaceXs / 2),
                Text(
                  normal ? t.summaryContinueActivity : t.summaryShortRest,
                  style: TextStyle(fontSize: r.fontBody, color: foreground),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Tags for the usual circumstances, one tap each, and a free note for
  /// anything else.
  Widget _contextCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return InfoCard(
      padding: EdgeInsets.fromLTRB(r.spaceLg, r.spaceMd, r.spaceLg, r.spaceXs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.summaryContextTitle,
            style: TextStyle(fontSize: r.fontBody, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: r.spaceSm),
          Wrap(
            spacing: r.spaceSm,
            runSpacing: r.spaceSm,
            children: [
              for (final MeasurementTag tag in MeasurementTag.values)
                InfoChoiceChip(
                  label: tag.label(t),
                  icon: tag.icon,
                  selected: _tags.contains(tag),
                  onSelected: (on) => setState(() {
                    if (on) {
                      _tags.add(tag);
                    } else {
                      _tags.remove(tag);
                    }
                  }),
                ),
            ],
          ),
          SizedBox(height: r.spaceSm),
          const Divider(height: 1, color: Color(0xFFE6E6E6)),
          TextField(
            controller: _notesController,
            onTapOutside: (_) => FocusScope.of(context).unfocus(),
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            cursorColor: kInfoAccent,
            style: TextStyle(fontSize: r.fontBody, color: Colors.black),
            decoration: InputDecoration(
              labelText: t.commonNote,
              hintText: t.summaryNotesHint,
              border: InputBorder.none,
              labelStyle: const TextStyle(color: kInfoSecondaryText),
              floatingLabelStyle: const TextStyle(color: kInfoSecondaryText),
            ),
          ),
        ],
      ),
    );
  }

  /// Signal, HRV and recovery as one row of options, like the measurement
  /// length on the measure screen.
  Widget _sectionSelector(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final List<String> labels = [
      t.summaryTabSignal,
      'HRV',
      t.summaryTabRecovery,
    ];
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: r.spaceXs / 2),
              child: Semantics(
                button: true,
                selected: _summarySectionIndex == i,
                inMutuallyExclusiveGroup: true,
                label: labels[i],
                excludeSemantics: true,
                child: Material(
                  color: _summarySectionIndex == i ? kInfoAccent : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => setState(() => _summarySectionIndex = i),
                    child: SizedBox(
                      height: r.iconXl * 1.15,
                      child: Center(
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: r.fontBody,
                            fontWeight: FontWeight.w600,
                            color: _summarySectionIndex == i
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _actionBar(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            r.pagePadding.left, r.spaceSm, r.pagePadding.right, r.spaceSm),
        child: Row(
          children: [
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: kInfoAccent,
                minimumSize: Size(r.iconXl * 2.4, r.iconXl * 1.4),
              ),
              onPressed: _busy ? null : _discard,
              child: Text(
                t.summaryDiscard,
                style: TextStyle(
                    fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
              ),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: SizedBox(
                height: r.iconXl * 1.4,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: kInfoAccent,
                    disabledBackgroundColor: kInfoAccent.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                  ),
                  onPressed: _busy ? null : _saveAndLeave,
                  child: _busy
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: Colors.white),
                        )
                      // Apple Health transparency (Guideline 2.5.1): saving
                      // also writes the heart rate to Health, so its icon
                      // sits on the button.
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              t.commonSave,
                              style: TextStyle(
                                  fontSize: r.fontBodyLg,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            SizedBox(width: r.spaceSm),
                            Image.asset(
                              'assets/Icon - Apple Health.png',
                              width: 22,
                              height: 22,
                              semanticLabel: 'Apple Health',
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Saves the record, then the heart rate (and HRV when it qualifies) to
  /// Apple Health, then returns to the home screen. Health access is asked
  /// here, when saving to it is what the user chose, rather than the moment
  /// the summary opened.
  Future<void> _saveAndLeave() async {
    if (_busy) return;
    setState(() => _busy = true);
    await _saveMeasurement();
    if (!_saveSucceeded) {
      if (mounted) setState(() => _busy = false);
      return;
    }
    try {
      final double? sdnn = await _sdnnForHealth();
      await _authorizeHealth(withHrv: sdnn != null);
      await _saveToAppleHealth(_effectiveAverageBpm, sdnn: sdnn);
    } catch (e) {
      // The record is saved; Health is a bonus and must not block leaving.
      debugPrint('Apple Health write failed: $e');
    }
    if (!mounted) return;
    _leave();
  }

  Future<void> _discard() async {
    final L10n t = L10n.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(t.summaryDiscardTitle),
        content: Text(t.summaryDiscardBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.summaryKeep),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kInfoAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.summaryDiscard),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) _leave();
  }

  /// Back to the home screen, which is the root route. Pushing a new home
  /// screen here stacked a second copy on top of the first.
  void _leave() => Navigator.of(context).popUntil((route) => route.isFirst);

  /// Replaces this summary with a fresh measurement; nothing is saved.
  void _measureAgain() {
    Navigator.of(context)
        .pushReplacement(MaterialPageRoute(builder: (_) => const Home()));
  }

  PatientStatus _patientStatus() {
    final bpm = _effectiveAverageBpm;
    final rr = _respiratoryRate;
    // Jednoduché pravidlo: klidová zona
    final isBpmOk = bpm >= 55 && bpm <= 95;
    final isRrOk = rr == 0.0 || (rr >= 8 && rr <= 20);
    return (isBpmOk && isRrOk) ? PatientStatus.normal : PatientStatus.rest;
  }

  // Section toggle state
  int _summarySectionIndex = 0;

  /// The recorded pulse wave, scrollable over the whole measurement.
  Widget _buildSignalSection(
      double chartWidth, double minX, double maxX, double minY, double maxY) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return InfoCard(
      padding: EdgeInsets.fromLTRB(r.spaceMd, r.spaceMd, r.spaceMd, r.spaceSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            t.measurePulseWave,
            style:
                TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText),
          ),
          SizedBox(height: r.spaceXs),
          if (_smoothedData.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.spaceXl),
              child: Center(
                child: Text(
                  t.recordsNoWaveform,
                  style: TextStyle(
                      fontSize: r.fontBody, color: kInfoSecondaryText),
                ),
              ),
            )
          else
            SizedBox(
              height: 150,
              child: Scrollbar(
                controller: _signalScrollController,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _signalScrollController,
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
                                color: Colors.black.withValues(alpha: 0.08),
                              ),
                            );
                          }),
                          ..._labels.map((label) {
                            final posX =
                                ((label.x - minX) / (maxX - minX + 1e-6)) *
                                    chartWidth;
                            return Positioned(
                              left: posX,
                              bottom: 0,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: Text(
                                  label.time,
                                  style: const TextStyle(
                                      fontSize: 9, color: Colors.black45),
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// A short tinted note for a caveat about the numbers around it.
  Widget _note(BuildContext context, String text) {
    final r = Responsive.of(context);
    return Container(
      padding: EdgeInsets.all(r.spaceMd),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E0),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline,
              size: r.iconSm, color: const Color(0xFF8A5300)),
          SizedBox(width: r.spaceSm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                  fontSize: r.fontSmall, color: const Color(0xFF8A5300)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricGrid(BuildContext context, List<Widget> cards) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: _responsiveGridColumns(context),
      childAspectRatio: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: cards,
    );
  }

  Widget _buildHrvSection(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _metricGrid(context, [
          _buildHRVCard('SDNN', '${_sdnn.toStringAsFixed(2)} ms'),
          _buildHRVCard('RMSSD', '${_rmssd.toStringAsFixed(2)} ms'),
          _buildHRVCard('pNN50', '${_pnn50.toStringAsFixed(2)} %'),
          _buildHRVCard(t.metricsAverageRr, '${_meanRR.toStringAsFixed(2)} ms'),
          _buildHRVCard('SD1', '${_sd1.toStringAsFixed(2)} ms'),
          _buildHRVCard('SD2', '${_sd2.toStringAsFixed(2)} ms'),
          _buildHRVCard('SD2/SD1', _sd2sd1.toStringAsFixed(2)),
          if (_frequencyHrvShown) ...[
            _buildHRVCard('LF', '${_lf.toStringAsFixed(2)} %'),
            _buildHRVCard('HF', '${_hf.toStringAsFixed(2)} %'),
            _buildHRVCard('LF/HF', _lfhf.toStringAsFixed(2)),
          ],
          _buildHRVCard(
            t.metricsStressIndex,
            _stressIndex.toStringAsFixed(2),
            valueColor: _getStressColor(_stressIndex),
          ),
        ]),
        if (!_frequencyHrvShown) ...[
          SizedBox(height: r.spaceMd),
          _note(context, t.metricsFrequencyNeedsLonger),
        ],
      ],
    );
  }

  /// LF and HF need two minutes (HRV standards ask for five); from a
  /// shorter recording the calculator returns zeros, which read as values.
  bool get _frequencyHrvShown =>
      widget.recordingDuration >= HrvCalculator.minFrequencySeconds;

  Widget _buildHrrSection(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: r.spaceXs),
          child: Text(
            t.metricsRecoveryIntro,
            style: TextStyle(fontSize: r.fontSmall, color: kInfoSecondaryText),
          ),
        ),
        SizedBox(height: r.spaceMd),
        _buildHrrChart(),
        SizedBox(height: r.spaceMd),
        _metricGrid(context, [
          _buildHRVCard(
              t.metricHr0, _hr0 > 0 ? '${_hr0.toStringAsFixed(1)} bpm' : '—'),
          _buildHRVCard(t.metricHr60,
              _hr60 > 0 ? '${_hr60.toStringAsFixed(1)} bpm' : '—'),
          _buildHRVCard(t.metricHrr60,
              _hrr60 > 0 ? '${_hrr60.toStringAsFixed(1)} bpm' : '—'),
          _buildHRVCard(t.metricSlope60,
              '${_slope60BpmPerMin.toStringAsFixed(1)} bpm/min'),
          _buildHRVCard(t.metricHr120,
              _hr120 > 0 ? '${_hr120.toStringAsFixed(1)} bpm' : '—'),
          _buildHRVCard(t.metricHrr120,
              _hrr120 > 0 ? '${_hrr120.toStringAsFixed(1)} bpm' : '—'),
          _buildHRVCard(t.metricTau,
              _tauSec > 0 ? '${_tauSec.toStringAsFixed(1)} s' : '—'),
        ]),
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
                  child: Text(L10n.of(context).commonClose),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _getMetricInfoText(String title) {
    final L10n t = L10n.of(context);
    // Titles that are translated cannot be switch cases (a case label must be
    // a compile-time constant), and matching them here keeps the lookup
    // working in whatever language the caller rendered the title in.
    if (title == t.metricsRespiratoryRate) return t.tipRespiratoryRate;
    if (title == t.metricsAverageRr) return t.tipMeanRr;
    if (title == t.metricsHeartRate) return t.tipGenericHrv;
    if (title == t.metricsStressIndex) return t.tipBaevsky;
    if (title == t.metricHr0) return t.tipHr0;
    if (title == t.metricHr60) return t.tipHr60;
    if (title == t.metricHrr60) return t.tipHrr60;
    if (title == t.metricSlope60) return t.tipHrSlope;
    if (title == t.metricHr120) return t.tipHr120;
    if (title == t.metricHrr120) return t.tipHrr120;
    if (title == t.metricTau) return t.tipHrTau;

    switch (title) {
      // Technical abbreviations render identically in both languages.
      case 'RMSSD':
        return t.tipRmssd;
      case 'SDNN':
        return t.tipSdnn;
      case 'pNN50':
        return t.tipPnn50;
      case 'Mean RR':
      case 'RR':
        return t.tipMeanRr;
      case 'SD1':
        return t.tipSd1;
      case 'SD2':
        return t.tipSd2;
      case 'SD2/SD1':
        return t.tipSd2Sd1Ratio;
      case 'LF':
        return t.tipLf;
      case 'HF':
        return t.tipHf;
      case 'LF/HF':
        return t.tipLfHfRatio;
      case 'Stress Index':
        return t.tipBaevsky;
      case 'HR\u2080':
      case 'HR (0\u201310 s)':
        return t.tipHr0;
      case 'HR@60s':
      case 'HR v 60. s':
        return t.tipHr60;
      case 'HRR60':
      case 'Pokles 0\u201360 s':
        return t.tipHrr60;
      case 'Slope(0\u201360s)':
      case 'Sklon (0\u201360 s)':
        return t.tipHrSlope;
      case 'HR@120s':
      case 'HR v 120. s':
        return t.tipHr120;
      case 'HRR120':
      case 'Pokles 0\u2013120 s':
        return t.tipHrr120;
      case 'Tau':
      case 'Tau (odhad)':
        return t.tipHrTau;
      default:
        return t.tipGenericHrv;
    }
  }

  Widget _buildHRVCard(String title, String value, {Color? valueColor}) {
    final iconKey = GlobalKey();
    final hint = _getMetricInfoText(title);
    return InkWell(
      onTap: () => _showAnchoredMetricInfo(title, value, iconKey),
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
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
                message: L10n.of(context).commonTapForExplanation,
                waitDuration: const Duration(milliseconds: 300),
                child: InkResponse(
                  key: iconKey,
                  radius: 16,
                  onTap: () => _showAnchoredMetricInfo(title, value, iconKey),
                  child: Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Colors.black.withValues(alpha: 0.45),
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
    final maxPopupWidth =
        (MediaQuery.sizeOf(context).width - 32).clamp(180.0, 260.0).toDouble();
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
            constraints: BoxConstraints(maxWidth: maxPopupWidth),
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

/// Runs in a background isolate.
SpectralQuality? _gradeRecording((List<double>, double) job) =>
    assessRecording(job.$1, job.$2);
