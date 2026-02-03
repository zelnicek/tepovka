import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/info_app.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tepovka/elements/create_pdf.dart'; // Import the PDF creation function
import 'dart:math';
import 'package:fftea/fftea.dart';
import 'dart:typed_data';

class Record {
  final String date;
  final String time;
  final int averageBPM;
  final String notesContent;
  final List<double> dataForPlot;
  final List<int> bpmList;
  final List<double> frames;
  final int duration;
  final Map<String, dynamic> hrv; // HRV metrics
  final double respiratoryRate; // RR breaths/min
  final List<double> bpmHistory; // BPM time series for recovery
  final Map<String, dynamic> hrr; // HR Recovery metrics
  final Map<String, dynamic> recoveryChart; // Recovery chart points

  Record({
    required this.date,
    required this.time,
    required this.averageBPM,
    required this.notesContent,
    required this.dataForPlot,
    required this.bpmList,
    required this.frames,
    required this.duration,
    required this.hrv,
    required this.respiratoryRate,
    required this.bpmHistory,
    required this.hrr,
    required this.recoveryChart,
  });

  // Convert Record to JSON format
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'time': time,
      'averageBPM': averageBPM,
      'notes': notesContent,
      'dataForPlot': dataForPlot,
      'bpmList': bpmList,
      'frames': frames,
      'duration': duration,
      'hrv': hrv,
      'respiratoryRate': respiratoryRate,
      'bpmHistory': bpmHistory,
      'hrr': hrr,
      'recoveryChart': recoveryChart,
    };
  }

  @override
  String toString() {
    return 'Record(date: $date, time: $time, averageBPM: $averageBPM, notesContent: $notesContent, dataForPlot: $dataForPlot, bpmList: $bpmList, frames: $frames, duration: $duration, hrv: $hrv)';
  }

  // Convert JSON back to Record object
  factory Record.fromJson(Map<String, dynamic> json) {
    return Record(
      date: json['date'] ?? '', // Default to empty string if null
      time: json['time'] ?? '', // Default to empty string if null
      averageBPM: json['averageBPM'] ?? 0, // Default to 0 if null
      notesContent: json['notes'] ?? '', // Default to empty string if null
      dataForPlot: json['dataForPlot'] != null
          ? List<double>.from(json['dataForPlot'])
          : [],
      bpmList: json['bpmList'] != null ? List<int>.from(json['bpmList']) : [],
      frames: json['frames'] != null
          ? List<double>.from(json['frames'])
          : [], // Default to empty list if null
      duration: json['duration'] ?? 30, // Default to 30 if null
      hrv: json['hrv'] ?? {}, // Default to empty map if null
      respiratoryRate: (json['respiratoryRate'] ?? 0.0).toDouble(),
      bpmHistory: json['bpmHistory'] != null
          ? List<double>.from(
              json['bpmHistory'].map((v) => (v as num).toDouble()))
          : <double>[],
      hrr: json['hrr'] ?? {},
      recoveryChart: json['recoveryChart'] ?? {},
    );
  }
}

class RecordsPage extends StatefulWidget {
  const RecordsPage({super.key});

  @override
  State<RecordsPage> createState() => _RecordsPageState();
}

class _RecordsPageState extends State<RecordsPage> {
  static const double sampleRate = 30.0; // Define sample rate (Hz)
  static const double pixelsPerSecond = 20.0; // Used for chart width
  List<Record> _records = [];
  int _selectedIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final summaryFile = File('${directory.path}/measurement_summary.json');

      if (await summaryFile.exists()) {
        final contents = await summaryFile.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);

        List<Record> loadedRecords =
            jsonList.map((json) => Record.fromJson(json)).toList();

        // Recalculate averageBPM for each record to match details view
        List<Record> updatedRecords = [];
        for (var rec in loadedRecords) {
          double calc = _calculateAverageBPM(rec);
          updatedRecords.add(Record(
            date: rec.date,
            time: rec.time,
            averageBPM: calc.toInt(),
            notesContent: rec.notesContent,
            dataForPlot: rec.dataForPlot,
            bpmList: rec.bpmList,
            frames: rec.frames,
            duration: rec.duration,
            hrv: rec.hrv,
            respiratoryRate: rec.respiratoryRate,
            bpmHistory: rec.bpmHistory,
            hrr: rec.hrr,
            recoveryChart: rec.recoveryChart,
          ));
        }

        setState(() {
          _records = updatedRecords;
        });

        // Save updated records
        await _saveRecords();
      } else {
        print('Soubor nenalezen!');
      }
    } catch (e) {
      print('Chyba při načítání záznamů: $e');
    }
  }

  Future<void> _saveRecords() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final summaryFile = File('${directory.path}/measurement_summary.json');

      final jsonList = _records.map((record) => record.toJson()).toList();
      await summaryFile.writeAsString(jsonEncode(jsonList));

      print('Záznamy uloženy!');
    } catch (e) {
      print('Chyba při ukládání záznamů: $e');
    }
  }

  Future<void> _deleteRecord(int index) async {
    try {
      setState(() {
        _records.removeAt(index);
      });
      await _saveRecords(); // Save after deletion
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          duration: Duration(seconds: 1),
          content: Text('Záznam smazán'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      print('Chyba při mazání záznamu: $e');
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
          MaterialPageRoute(builder: (context) => const InfoApp()),
        );
        break;
    }
  }

  void _refreshPage() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (context) => RecordsPage()), // Název vaší aktuální stránky
    );
  }

  Future<void> _showDeleteConfirmation(int index) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          title: const Text('Potvrdit smazání'),
          content: const Text('Opravdu chcete tento záznam smazat?'),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 255, 5, 5),
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Zavře dialog
                _refreshPage(); // Obnoví stránku
              },
              child: const Text('Zrušit'),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: const Color.fromARGB(255, 0, 0, 0),
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecord(index);
              },
              child: const Text('Smazat'),
            ),
          ],
        );
      },
    );
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

  Color _getStressColor(double index) {
    if (index < 50) return Colors.green;
    if (index < 100) return Colors.orange;
    return Colors.red;
  }

  Future<String?> _createTxt(Record record) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file =
          File('${directory.path}/record_${record.date}_${record.time}.txt');
      StringBuffer sb = StringBuffer();
      sb.writeln('Date: ${record.date}');
      sb.writeln('Time: ${record.time}');
      sb.writeln('Average BPM: ${record.averageBPM}');
      sb.writeln('Notes: ${record.notesContent}');
      sb.writeln('Duration: ${record.duration}');
      sb.writeln('');
      sb.writeln('Time (s),Signal Value');

      // Compute trimmed data
      int expectedLength = (record.duration * sampleRate).toInt();
      List<double> trimmedData = record.dataForPlot;
      if (trimmedData.length > expectedLength) {
        trimmedData = trimmedData.sublist(trimmedData.length - expectedLength);
      }

      // Write signal data
      for (int i = 0; i < trimmedData.length; i++) {
        double time = i / sampleRate;
        sb.writeln('${time.toStringAsFixed(3)},${trimmedData[i]}');
      }

      // Compute peaks
      List<FlSpot> spots = [];
      for (int i = 0; i < trimmedData.length; i++) {
        spots.add(FlSpot(i / sampleRate, -trimmedData[i]));
      }
      // Moving average smoothing
      int windowSize = 7;
      List<FlSpot> smoothedData = [];
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
        smoothedData.add(FlSpot(spots[i].x, avg));
      }
      // Detect peaks
      List<double> yValues = smoothedData.map((s) => s.y).toList();
      List<int> peaks = _findPeaks(yValues);

      // Write peak indices
      sb.writeln('');
      sb.writeln('Peak Indices:');
      for (int p in peaks) {
        sb.writeln(p.toString());
      }

      await file.writeAsString(sb.toString());
      return file.path;
    } catch (e) {
      print('Error creating TXT: $e');
      return null;
    }
  }

  double _calculateAverageBPM(Record record) {
    // Trim data to exactly recording duration (remove initial if extra)
    int expectedLength = (record.duration * sampleRate).toInt();
    List<double> trimmedData = record.dataForPlot;
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
    List<FlSpot> smoothedData = [];
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
      smoothedData.add(FlSpot(spots[i].x, avg));
    }
    // Detect peaks on smoothed
    List<double> yValues = smoothedData.map((s) => s.y).toList();
    List<int> peaks = _findPeaks(yValues);
    List<FlSpot> peakSpots = peaks.map((i) => smoothedData[i]).toList();
    // Calculate average BPM from peaks
    double calculatedAverageBPM = 0.0;
    if (peakSpots.length > 1) {
      double sumIntervals = 0.0;
      for (int i = 1; i < peakSpots.length; i++) {
        sumIntervals += peakSpots[i].x - peakSpots[i - 1].x;
      }
      double averageInterval = sumIntervals / (peakSpots.length - 1);
      calculatedAverageBPM = 60.0 / averageInterval;
    }
    return calculatedAverageBPM;
  }

  void _showRecordDetail(Record record) {
    // Recompute smoothed data, peaks, labels, and HRV
    List<FlSpot> smoothedData = [];
    List<FlSpot> peakSpots = [];
    List<TimeLabel> labels = [];
    double calculatedAverageBPM = 0.0;
    double sdnn = 0.0;
    double rmssd = 0.0;
    double pnn50 = 0.0;
    double meanRR = 0.0;
    double sd2 = 0.0;
    double sd1 = 0.0;
    double sd2sd1 = 0.0;
    double lf = 0.0;
    double hf = 0.0;
    double lfhf = 0.0;
    double stressIndex = 0.0;

    // Trim data to exactly recording duration (remove initial if extra)
    int expectedLength = (record.duration * sampleRate).toInt();
    List<double> trimmedData = record.dataForPlot;
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
      smoothedData.add(FlSpot(spots[i].x, avg));
    }
    // Detect peaks on smoothed
    List<double> yValues = smoothedData.map((s) => s.y).toList();
    List<int> peaks = _findPeaks(yValues);
    peakSpots = peaks.map((i) => smoothedData[i]).toList();
    // Calculate average BPM from peaks
    if (peakSpots.length > 1) {
      double sumIntervals = 0.0;
      for (int i = 1; i < peakSpots.length; i++) {
        sumIntervals += peakSpots[i].x - peakSpots[i - 1].x;
      }
      double averageInterval = sumIntervals / (peakSpots.length - 1);
      calculatedAverageBPM = 60.0 / averageInterval;
    } else {
      calculatedAverageBPM = 0.0;
    }
    // Generate time labels every 5 seconds to avoid overlap
    double totalTime = trimmedData.length / sampleRate;
    for (int i = 0; i <= totalTime.floor(); i += 5) {
      int min = i ~/ 60;
      int sec = i % 60;
      String formatted = "$min:${sec.toString().padLeft(2, '0')}";
      labels.add(TimeLabel(i.toDouble(), formatted));
    }

    // Compute HRV if not present or recompute
    if (record.hrv.isEmpty) {
      if (peakSpots.length < 2) {
        // No HRV if insufficient peaks
      } else {
        List<double> rrIntervals = [];
        for (int i = 1; i < peakSpots.length; i++) {
          double interval =
              (peakSpots[i].x - peakSpots[i - 1].x) * 1000; // in ms
          rrIntervals.add(interval);
        }
        if (rrIntervals.isNotEmpty) {
          // Mean RR
          meanRR = rrIntervals.reduce((a, b) => a + b) / rrIntervals.length;
          // SDNN
          double sumSquares = 0.0;
          for (double rr in rrIntervals) {
            sumSquares += pow(rr - meanRR, 2);
          }
          sdnn = sqrt(sumSquares / rrIntervals.length);
          // RMSSD
          sumSquares = 0.0;
          for (int i = 1; i < rrIntervals.length; i++) {
            sumSquares += pow(rrIntervals[i] - rrIntervals[i - 1], 2);
          }
          rmssd = sqrt(sumSquares / (rrIntervals.length - 1));
          // pNN50
          int nn50Count = 0;
          for (int i = 1; i < rrIntervals.length; i++) {
            if ((rrIntervals[i] - rrIntervals[i - 1]).abs() > 50) {
              nn50Count++;
            }
          }
          pnn50 = (nn50Count / (rrIntervals.length - 1)) * 100;
          // Poincare plot (SD1, SD2, SD2/SD1)
          List<double> rrDiff = [];
          for (int i = 1; i < rrIntervals.length; i++) {
            rrDiff.add(rrIntervals[i] - rrIntervals[i - 1]);
          }
          double sdDiff = sqrt(
              rrDiff.map((d) => pow(d, 2)).reduce((a, b) => a + b) /
                  rrDiff.length);
          sd1 = sdDiff / sqrt(2);
          sd2 = sqrt(2 * pow(sdnn, 2) - pow(sd1, 2));
          sd2sd1 = sd2 / sd1;
          // Stress Index (Baevsky approximation)
          stressIndex =
              sdnn == 0 ? 0.0 : (pow(meanRR / (2 * sdnn), 2) as double);
          // Frequency domain using FFT
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
          List<double> resampledRR =
              _interpolate(interpTimes, rrIntervals, newTimes);
          // Detrend (subtract mean)
          resampledRR = resampledRR.map((v) => v - meanRR).toList();
          // Apply Hanning window
          final hannWindow = Window.hanning(resampledRR.length);
          for (int i = 0; i < resampledRR.length; i++) {
            resampledRR[i] *= hannWindow[i];
          }
          // Pad to next power of 2
          int originalLength = resampledRR.length;
          int paddedLength = _nextPowerOf2(originalLength);
          Float64List paddedSignal = Float64List(paddedLength);
          paddedSignal.setRange(
              0, originalLength, Float64List.fromList(resampledRR));
          // Compute FFT
          final fft = FFT(paddedLength);
          final freq = fft.realFft(paddedSignal);
          // Compute powers (PSD)
          List<double> powers = freq.map((c) => c.x * c.x + c.y * c.y).toList();
          // Frequency resolution
          double freqResolution = targetFreq / paddedLength;
          // Integrate bands
          lf = _integrateBand(powers, freqResolution, 0.04, 0.15);
          hf = _integrateBand(powers, freqResolution, 0.15, 0.4);
          double total = lf + hf;
          if (total > 0) {
            lf = (lf / total) * 100;
            hf = (hf / total) * 100;
          }
          lfhf = hf == 0.0 ? 0.0 : lf / hf;
        }
      }
    } else {
      // Use saved HRV
      sdnn = record.hrv['sdnn'] ?? 0.0;
      rmssd = record.hrv['rmssd'] ?? 0.0;
      pnn50 = record.hrv['pnn50'] ?? 0.0;
      meanRR = record.hrv['meanRR'] ?? 0.0;
      sd1 = record.hrv['sd1'] ?? 0.0;
      sd2 = record.hrv['sd2'] ?? 0.0;
      sd2sd1 = record.hrv['sd2sd1'] ?? 0.0;
      lf = record.hrv['lf'] ?? 0.0;
      hf = record.hrv['hf'] ?? 0.0;
      lfhf = record.hrv['lfhf'] ?? 0.0;
      stressIndex = record.hrv['stressIndex'] ?? 0.0;
    }

    // Removed duplicate totalTime declaration
    double chartWidth = totalTime * pixelsPerSecond;
    double minY = smoothedData.isEmpty
        ? -1.0
        : smoothedData.map((spot) => spot.y).reduce(min) - 1.0;
    double maxY = smoothedData.isEmpty
        ? 1.0
        : smoothedData.map((spot) => spot.y).reduce(max) + 1.0;
    double minX = 0.0;
    double maxX = totalTime;

    GlobalKey chartKey = GlobalKey();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          insetPadding:
              const EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0),
          backgroundColor: const Color.fromARGB(255, 242, 242, 242),
          contentPadding: const EdgeInsets.all(0),
          title: Text(
            '${record.date} ve ${record.time}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                          '${calculatedAverageBPM.toInt()} bpm',
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
                    padding: const EdgeInsets.symmetric(
                        vertical: 20, horizontal: 20),
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
                            left: ((calculatedAverageBPM.clamp(30, 220) - 30) /
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
                              '${calculatedAverageBPM.toInt()} bpm',
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
                    child: Text(
                      record.notesContent,
                      style: const TextStyle(
                        color: Colors.black,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  SizedBox(
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
                              key: chartKey,
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
                                      titlesData:
                                          const FlTitlesData(show: false),
                                      borderData: FlBorderData(
                                        show: true,
                                        border: Border.all(
                                            color:
                                                Colors.grey.withOpacity(0.3)),
                                      ),
                                      minX: minX,
                                      maxX: maxX,
                                      minY: minY,
                                      maxY: maxY,
                                      lineBarsData: [
                                        LineChartBarData(
                                          spots: smoothedData,
                                          isCurved: false,
                                          color: const Color.fromARGB(
                                              255, 246, 41, 0),
                                          barWidth: 2.0,
                                          isStrokeCapRound: true,
                                          dotData: const FlDotData(show: false),
                                          belowBarData: BarAreaData(
                                            show: false,
                                          ),
                                        ),
                                        LineChartBarData(
                                          spots: peakSpots,
                                          isCurved: false,
                                          color: Colors.transparent,
                                          barWidth: 0,
                                          dotData: FlDotData(
                                            show: true,
                                            getDotPainter: (spot, percent,
                                                    barData, index) =>
                                                FlDotCirclePainter(
                                              radius: 3,
                                              color: Colors.blue,
                                              strokeWidth: 0,
                                            ),
                                          ),
                                          belowBarData:
                                              BarAreaData(show: false),
                                        ),
                                      ],
                                    ),
                                    duration: Duration.zero,
                                  ),
                                  ...labels.map((label) {
                                    final posX = ((label.x - minX) /
                                            (maxX - minX + 1e-6)) *
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
                                  ...labels.map((label) {
                                    final posX = ((label.x - minX) /
                                            (maxX - minX + 1e-6)) *
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
                                              fontSize: 10,
                                              color: Colors.black),
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
                  const SizedBox(height: 16),
                  // Collapsible HRV section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                            color: Color.fromARGB(120, 158, 158, 158)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        initiallyExpanded: false,
                        title: const Text(
                          'HRV Analýza',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          const SizedBox(height: 8),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _buildHRVCard('Dechová frekvence',
                                  '${record.respiratoryRate.toStringAsFixed(1)} dechů/min'),
                              _buildHRVCard(
                                  'SDNN', '${sdnn.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'RMSSD', '${rmssd.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'pNN50', '${pnn50.toStringAsFixed(2)} %'),
                              _buildHRVCard('Průměrný RR',
                                  '${meanRR.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'SD1', '${sd1.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'SD2', '${sd2.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'SD2/SD1', '${sd2sd1.toStringAsFixed(2)}'),
                              _buildHRVCard('LF', '${lf.toStringAsFixed(2)} %'),
                              _buildHRVCard('HF', '${hf.toStringAsFixed(2)} %'),
                              _buildHRVCard(
                                  'LF/HF', '${lfhf.toStringAsFixed(2)}'),
                              _buildHRVCard(
                                'Index stresu',
                                '${stressIndex.toStringAsFixed(2)}',
                                valueColor: _getStressColor(stressIndex),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Collapsible HRR section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Card(
                      color: Colors.white,
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: const BorderSide(
                            color: Color.fromARGB(120, 158, 158, 158)),
                      ),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 12),
                        initiallyExpanded: true,
                        title: const Text(
                          'Zotavení srdeční frekvence',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          const SizedBox(height: 6),
                          const Text(
                            'Měří pokles tepové frekvence po zátěži. Vyšší pokles za 60–120 s obvykle značí lepší kardiovaskulární kondici a rychlejší zotavení.',
                            style:
                                TextStyle(fontSize: 13, color: Colors.black54),
                          ),
                          const SizedBox(height: 6),
                          _buildRecordRecoveryChart(record),
                          const SizedBox(height: 6),
                          GridView.count(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            crossAxisCount: 2,
                            childAspectRatio: 2,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _buildHRVCard(
                                  'HR (0–10 s)',
                                  (record.hrr['hr0'] ?? 0.0) > 0
                                      ? '${(record.hrr['hr0'] ?? 0.0).toStringAsFixed(1)} bpm'
                                      : '—'),
                              _buildHRVCard(
                                  'HR v 60. s',
                                  (record.hrr['hr60'] ?? 0.0) > 0
                                      ? '${(record.hrr['hr60'] ?? 0.0).toStringAsFixed(1)} bpm'
                                      : '—'),
                              _buildHRVCard(
                                  'Pokles 0–60 s',
                                  (record.hrr['hrr60'] ?? 0.0) > 0
                                      ? '${(record.hrr['hrr60'] ?? 0.0).toStringAsFixed(1)} bpm'
                                      : '—'),
                              _buildHRVCard('Sklon (0–60 s)',
                                  '${(record.hrr['slope60_bpmPerMin'] ?? 0.0).toStringAsFixed(1)} bpm/min'),
                              _buildHRVCard(
                                  'HR v 120. s',
                                  (record.hrr['hr120'] ?? 0.0) > 0
                                      ? '${(record.hrr['hr120'] ?? 0.0).toStringAsFixed(1)} bpm'
                                      : '—'),
                              _buildHRVCard(
                                  'Pokles 0–120 s',
                                  (record.hrr['hrr120'] ?? 0.0) > 0
                                      ? '${(record.hrr['hrr120'] ?? 0.0).toStringAsFixed(1)} bpm'
                                      : '—'),
                              _buildHRVCard(
                                  'Tau (odhad)',
                                  (record.hrr['tauSec'] ?? 0.0) > 0
                                      ? '${(record.hrr['tauSec'] ?? 0.0).toStringAsFixed(1)} s'
                                      : '—'),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Tlačítko pro PDF
                    TextButton(
                      onPressed: () async {
                        final chartImageBytes = await _captureChart(chartKey);
                        final hrvMetrics = {
                          'SDNN': '${sdnn.toStringAsFixed(2)} ms',
                          'RMSSD': '${rmssd.toStringAsFixed(2)} ms',
                          'pNN50': '${pnn50.toStringAsFixed(2)} %',
                          'Mean RR': '${meanRR.toStringAsFixed(2)} ms',
                          'SD1': '${sd1.toStringAsFixed(2)} ms',
                          'SD2': '${sd2.toStringAsFixed(2)} ms',
                          'SD2/SD1': '${sd2sd1.toStringAsFixed(2)}',
                          'LF': '${lf.toStringAsFixed(2)} %',
                          'HF': '${hf.toStringAsFixed(2)} %',
                          'LF/HF': '${lfhf.toStringAsFixed(2)}',
                          'Stress Index': '${stressIndex.toStringAsFixed(2)}',
                        };
                        final pdfPath = await createPdf(
                          averageBPM: calculatedAverageBPM.toInt(),
                          notes: record.notesContent,
                          duration: record.duration,
                          hrvMetrics: hrvMetrics,
                          chartImageBytes: chartImageBytes,
                          formattedDate: record.date,
                          formattedTime: record.time,
                        );
                        if (pdfPath != null) {
                          await OpenFilex.open(pdfPath);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue, // Barva textu a ikony
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Aby text a ikona byly u sebe
                        children: [
                          Icon(
                            FontAwesomeIcons.filePdf, // Ikona pro PDF
                            size: 18, // Velikost ikony
                            color: Colors.red, // Barva ikony
                          ),
                          const SizedBox(
                              width: 5), // Malý prostor mezi ikonou a textem
                          const Text(
                            'Stáhnout PDF',
                            style:
                                TextStyle(color: Colors.black), // Barva textu
                          ),
                        ],
                      ),
                    ),

                    // Tlačítko pro TXT
                    TextButton(
                      onPressed: () async {
                        final txtPath = await _createTxt(record);
                        if (txtPath != null) {
                          await OpenFilex.open(txtPath);
                        }
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue, // Barva textu a ikony
                      ),
                      child: Row(
                        mainAxisSize:
                            MainAxisSize.min, // Aby text a ikona byly u sebe
                        children: [
                          Icon(
                            FontAwesomeIcons.fileLines, // Ikona pro TXT
                            size: 18, // Velikost ikony
                            color: Colors.black, // Barva ikony
                          ),
                          const SizedBox(
                              width: 5), // Malý prostor mezi ikonou a textem
                          const Text(
                            'Export TXT',
                            style:
                                TextStyle(color: Colors.black), // Barva textu
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Zavřít'),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<Uint8List?> _captureChart(GlobalKey key) async {
    try {
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return null;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      print('Error capturing chart: $e');
      return null;
    }
  }

  List<int> _findPeaks(List<double> signal) {
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

  Widget _buildRecordRecoveryChart(Record record) {
    // Build recovery spots from saved points or bpmHistory
    final List<FlSpot> spots = [];
    double durationSec = record.duration.toDouble();
    if (record.recoveryChart.isNotEmpty &&
        (record.recoveryChart['points'] is List)) {
      final pts = (record.recoveryChart['points'] as List);
      for (final p in pts) {
        final t = (p['t'] as num?)?.toDouble() ?? 0.0;
        final bpm = (p['bpm'] as num?)?.toDouble() ?? 0.0;
        if (bpm > 0) spots.add(FlSpot(t, bpm));
      }
      final d = record.recoveryChart['durationSec'];
      if (d is num) durationSec = d.toDouble();
    } else if (record.bpmHistory.isNotEmpty && durationSec > 0) {
      final n = record.bpmHistory.length;
      final secPerSample = durationSec / n;
      for (int i = 0; i < n; i++) {
        final bpm = record.bpmHistory[i].toDouble();
        if (bpm > 0) spots.add(FlSpot(i * secPerSample, bpm));
      }
    }

    if (spots.length < 2) {
      return const SizedBox.shrink();
    }

    final minX = 0.0;
    final maxX = durationSec;
    double minY = spots.map((s) => s.y).reduce(min);
    double maxY = spots.map((s) => s.y).reduce(max);
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
                  spots: spots,
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

  String _getMetricInfoText(String title) {
    switch (title) {
      // Czech HRR labels
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

      // HRV labels
      case 'Dechová frekvence':
        return 'Dechová frekvence (dechů/min). Odvozeno ze změn amplitudy PPG, typicky 6–20 dechů/min v klidu.';
      case 'Průměrný RR':
        return 'Průměrná délka NN (RR) intervalu v milisekundách. Nepřímo souvisí s klidovou TF (delší RR = nižší BPM).';
      case 'Index stresu':
        return 'Baevského index – orientační míra stresové zátěže. Vyšší hodnoty mohou ukazovat na vyšší napětí, interpretuj s ohledem na podmínky měření.';
      case 'SDNN':
        return 'Standardní odchylka NN intervalů – celková variabilita srdeční frekvence za celé měření.';
      case 'RMSSD':
        return 'Root Mean Square of Successive Differences – citlivé na krátkodobou, parasympatickou aktivitu.';
      case 'pNN50':
        return 'Podíl po sobě jdoucích NN intervalů, které se liší o více než 50 ms. Vyšší procento obvykle ukazuje na silnější parasympatickou aktivitu.';
      case 'SD1':
        return 'SD1 (Poincaré) – krátkodobá HRV (beat‑to‑beat variabilita).';
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
      default:
        return 'Metrika – vykládej v kontextu délky záznamu, artefaktů a podmínek měření.';
    }
  }

  void _showAnchoredMetricInfo(
      String title, String value, GlobalKey anchorKey) async {
    final ctx = anchorKey.currentContext;
    if (ctx == null) {
      return;
    }
    final renderBox = ctx.findRenderObject() as RenderBox?;
    if (renderBox == null) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        elevation: 0,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'HISTORIE MĚŘENÍ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: RefreshIndicator.adaptive(
          onRefresh: () async {
            // Simulace načítání
            await Future.delayed(const Duration(milliseconds: 10));
          },
          displacement: 50.0, // Vzdálenost indikátoru
          edgeOffset: 0.0, // Okraj indikátoru
          color: Colors.grey, // Barva rotujícího srdíčka
          backgroundColor: Colors.white, // Bílé pozadí
          strokeWidth: 3.0, // Tloušťka indikátoru
          child: _records.isEmpty
              ? const Center(child: Text('Nebyly nalezeny žádné záznamy.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(10),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: _records.length,
                  itemBuilder: (context, index) {
                    int actualIndex = _records.length -
                        1 -
                        index; // reverse order without header
                    var record = _records[actualIndex];
                    return Column(
                      children: [
                        Dismissible(
                          key: ValueKey('${record.date}_${record.time}'),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.withOpacity(0.7),
                            padding: const EdgeInsets.only(right: 20),
                            child: const Align(
                              alignment: Alignment.centerRight,
                              child: Icon(
                                Icons.delete,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          onDismissed: (direction) {
                            _showDeleteConfirmation(actualIndex);
                          },
                          child: GestureDetector(
                            onTap: () => _showRecordDetail(record),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 5,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.history,
                                    color: Colors.black.withOpacity(0.7),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      '${record.date} ve ${record.time}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  SizedBox(
                                    width: 65,
                                    child: Text(
                                      'tep:${record.averageBPM}',
                                      textAlign: TextAlign.left,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      _showRecordDetail(record);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Divider(),
                      ],
                    );
                  },
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
    );
  }
}

class TimeLabel {
  final double x;
  final String time;

  TimeLabel(this.x, this.time);
}
