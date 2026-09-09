import 'dart:io';
import 'package:tepovka/l10n/app_localizations.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/info_app.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tepovka/elements/create_pdf.dart'; // Import the PDF creation function
import 'package:tepovka/elements/unified_peak_detector.dart';
import 'package:tepovka/elements/signal_quality_index.dart';
import 'package:tepovka/services/app_settings.dart';
import 'dart:convert';
import 'package:tepovka/elements/responsive.dart';
import 'dart:math';
import 'package:fftea/fftea.dart';
import 'dart:typed_data';

/// Nominální snímkovací frekvence kamery. Skutečná bývá nižší (~24 fps) —
/// měření proti Faros 180 EKG a oxymetru v srpnu 2026 dalo poměr 1.232
/// (95% CI 1.222–1.243), takže s pevnými 30 Hz je časová osa o ~25 %
/// zrychlená a všechno odvozené z intervalů (BPM, HRV) posunuté.
const double kNominalSampleRate = 30.0;

class Record {
  final String date;
  final String time;

  /// ISO-8601 instants for the measurement itself and for when it was stored.
  /// Empty on records written before these fields existed.
  final String startedAt;
  final String endedAt;
  final String savedAt;
  final int averageBPM;
  final String notesContent;
  final List<double> dataForPlot;
  final List<int> bpmList;
  final List<double> frames;
  final int duration;

  /// Změřená vzorkovací frekvence měření v Hz. 0 u starších záznamů,
  /// pak ji odvodí [_RecordsPageState.sampleRateOf] z délky a počtu vzorků.
  final double sampleRateHz;

  /// Wall-clock razítka snímků (ms), zarovnaná na [dataForPlot].
  /// Prázdné u záznamů uložených dřív, než se razítka začala ukládat.
  final List<int> frameTimestampsMs;

  /// Údaje vyplněné ve výzkumném režimu před měřením (ID probanda, protokol…).
  final Map<String, String> metadata;
  final Map<String, dynamic> hrv; // HRV metrics
  final double respiratoryRate; // RR breaths/min
  final List<double> bpmHistory; // BPM time series for recovery
  final List<Map<String, dynamic>> rawRgbSamples; // Raw RGB per-frame export
  final Map<String, dynamic> hrr; // HR Recovery metrics
  final Map<String, dynamic> recoveryChart; // Recovery chart points

  Record({
    required this.date,
    required this.time,
    this.startedAt = '',
    this.endedAt = '',
    this.savedAt = '',
    required this.averageBPM,
    required this.notesContent,
    required this.dataForPlot,
    required this.bpmList,
    required this.frames,
    required this.duration,
    this.sampleRateHz = 0.0,
    this.frameTimestampsMs = const [],
    this.metadata = const {},
    required this.hrv,
    required this.respiratoryRate,
    required this.bpmHistory,
    required this.rawRgbSamples,
    required this.hrr,
    required this.recoveryChart,
  });

  /// Vzorkovací frekvence tohoto záznamu: nejdřív ze skutečných razítek
  /// snímků, pak z uložené změřené hodnoty, pak z počtu vzorků na délku
  /// měření. Teprve když nic z toho nedává smysl, vrátí nominálních 30 Hz.
  double get effectiveSampleRate {
    if (frameTimestampsMs.length >= 10) {
      final span = frameTimestampsMs.last - frameTimestampsMs.first;
      if (span > 0) {
        final fs = (frameTimestampsMs.length - 1) * 1000.0 / span;
        if (fs >= 5 && fs <= 120) return fs;
      }
    }
    if (sampleRateHz >= 5 && sampleRateHz <= 120) return sampleRateHz;
    if (frames.isNotEmpty) {
      final measured = frames.last; // getFrames() přidává průměr na konec
      if (measured >= 5 && measured <= 120) return measured;
    }
    if (duration > 0 && dataForPlot.length >= 10) {
      final fs = dataForPlot.length / duration;
      if (fs >= 5 && fs <= 120) return fs;
    }
    return kNominalSampleRate;
  }

  // Convert Record to JSON format
  Map<String, dynamic> toJson() {
    return {
      'date': date,
      'time': time,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'savedAt': savedAt,
      'averageBPM': averageBPM,
      'notes': notesContent,
      'dataForPlot': dataForPlot,
      'bpmList': bpmList,
      'frames': frames,
      'duration': duration,
      'sampleRateHz': sampleRateHz,
      'frameTimestampsMs': frameTimestampsMs,
      'metadata': metadata,
      'hrv': hrv,
      'respiratoryRate': respiratoryRate,
      'bpmHistory': bpmHistory,
      'rawRgbSamples': rawRgbSamples,
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
      startedAt: json['startedAt'] ?? '',
      endedAt: json['endedAt'] ?? '',
      savedAt: json['savedAt'] ?? '',
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
      sampleRateHz: (json['sampleRateHz'] ?? 0.0).toDouble(),
      frameTimestampsMs: json['frameTimestampsMs'] != null
          ? List<int>.from(
              json['frameTimestampsMs'].map((v) => (v as num).toInt()))
          : const <int>[],
      metadata: json['metadata'] != null
          ? Map<String, String>.from((json['metadata'] as Map)
              .map((k, v) => MapEntry(k.toString(), v.toString())))
          : const <String, String>{},
      hrv: json['hrv'] ?? {}, // Default to empty map if null
      respiratoryRate: (json['respiratoryRate'] ?? 0.0).toDouble(),
      bpmHistory: json['bpmHistory'] != null
          ? List<double>.from(
              json['bpmHistory'].map((v) => (v as num).toDouble()))
          : <double>[],
      rawRgbSamples: json['rawRgbSamples'] != null
          ? List<Map<String, dynamic>>.from(json['rawRgbSamples']
              .map((sample) => Map<String, dynamic>.from(sample as Map)))
          : <Map<String, dynamic>>[],
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
  static const double pixelsPerSecond = 20.0; // Used for chart width
  List<Record> _records = [];
  final ScrollController _chartScrollController = ScrollController();
  int _selectedIndex = -1;
  final StorageService _storage = StorageService();
  // UX filters state
  List<Record> _visible = [];
  String _searchQuery = '';
  int _minBpm = 40;
  int _maxBpm = 200;
  DateTime? _startDate;
  DateTime? _endDate;
  String _qualityFilter = 'all'; // all|good|medium|poor
  String _sortMode = 'date_desc'; // date_desc|date_asc|bpm_desc|bpm_asc
  bool _selectionMode = false;
  final Set<String> _selectedKeys = <String>{}; // key: "date_time"

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final List<Map<String, dynamic>> jsonList = await _storage.readSummary();
      if (jsonList.isNotEmpty) {
        final List<Record> loadedRecords =
            jsonList.map((json) => Record.fromJson(json)).toList();

        // Recalculate averageBPM for each record to match details view
        List<Record> updatedRecords = [];
        for (var rec in loadedRecords) {
          double calc = _calculateAverageBPM(rec);
          updatedRecords.add(Record(
            date: rec.date,
            time: rec.time,
            // Bez těchto tří polí ztrácel seznam přesný okamžik měření a export
            // pak spadl na méně přesné date+time.
            startedAt: rec.startedAt,
            endedAt: rec.endedAt,
            savedAt: rec.savedAt,
            averageBPM: calc.toInt(),
            notesContent: rec.notesContent,
            dataForPlot: rec.dataForPlot,
            bpmList: rec.bpmList,
            frames: rec.frames,
            duration: rec.duration,
            sampleRateHz: rec.sampleRateHz,
            frameTimestampsMs: rec.frameTimestampsMs,
            metadata: rec.metadata,
            hrv: rec.hrv,
            respiratoryRate: rec.respiratoryRate,
            bpmHistory: rec.bpmHistory,
            rawRgbSamples: rec.rawRgbSamples,
            hrr: rec.hrr,
            recoveryChart: rec.recoveryChart,
          ));
        }

        setState(() {
          _records = updatedRecords;
        });
        _applyFilters();

        // Save updated records
        await _saveRecords();
      } else {
      }
    } catch (e) {
      debugPrint('Chyba při načítání záznamů: $e');
    }
  }

  DateTime _parseRecordDateTime(Record r) {
    try {
      final partsDate = r.date.split('-');
      final partsTime = r.time.split(':');
      return DateTime(
        int.parse(partsDate[0]),
        int.parse(partsDate[1]),
        int.parse(partsDate[2]),
        int.parse(partsTime[0]),
        int.parse(partsTime[1]),
        int.parse(partsTime[2]),
      );
    } catch (_) {
      return DateTime(1970);
    }
  }

  String _qualityFor(Record r) {
    final sdnn = (r.hrv['sdnn'] ?? 0.0).toDouble();
    final rmssd = (r.hrv['rmssd'] ?? 0.0).toDouble();
    final stress = (r.hrv['stressIndex'] ?? 999.0).toDouble();
    final frameAvg = r.frames.isNotEmpty ? r.frames.last : 0.0;
    int score = 0;
    if (sdnn >= 40) score++;
    if (rmssd >= 25) score++;
    if (stress <= 100) score++;
    if (frameAvg >= 25) score++;
    if (r.duration >= 25) score++;
    if (score >= 4) return 'good';
    if (score >= 2) return 'medium';
    return 'poor';
  }

  void _applyFilters() {
    List<Record> out = List<Record>.from(_records);
    // Search
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      out = out.where((r) {
        return r.notesContent.toLowerCase().contains(q) ||
            r.date.contains(q) ||
            r.time.contains(q) ||
            r.averageBPM.toString().contains(q);
      }).toList();
    }
    // BPM range
    out = out
        .where((r) => r.averageBPM >= _minBpm && r.averageBPM <= _maxBpm)
        .toList();
    // Date range
    if (_startDate != null || _endDate != null) {
      out = out.where((r) {
        final dt = _parseRecordDateTime(r);
        final after = _startDate == null || !dt.isBefore(_startDate!);
        final before = _endDate == null || !dt.isAfter(_endDate!);
        return after && before;
      }).toList();
    }
    // Quality
    if (_qualityFilter != 'all') {
      out = out.where((r) => _qualityFor(r) == _qualityFilter).toList();
    }
    // Sort
    out.sort((a, b) {
      switch (_sortMode) {
        case 'date_asc':
          return _parseRecordDateTime(a).compareTo(_parseRecordDateTime(b));
        case 'bpm_desc':
          return b.averageBPM.compareTo(a.averageBPM);
        case 'bpm_asc':
          return a.averageBPM.compareTo(b.averageBPM);
        case 'date_desc':
        default:
          return _parseRecordDateTime(b).compareTo(_parseRecordDateTime(a));
      }
    });
    setState(() {
      _visible = out;
    });
  }

  void _toggleSelection(String key) {
    setState(() {
      if (_selectedKeys.contains(key)) {
        _selectedKeys.remove(key);
      } else {
        _selectedKeys.add(key);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final toDelete = _records
        .where((r) => _selectedKeys.contains('${r.date}_${r.time}'))
        .toList();
    setState(() {
      _records
          .removeWhere((r) => _selectedKeys.contains('${r.date}_${r.time}'));
      _selectedKeys.clear();
      _selectionMode = false;
    });
    await _saveRecords();
    if (!mounted) return;
    _applyFilters();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 1),
        content: Text(L10n.of(context).recordsDeletedCount(toDelete.length)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _saveRecords() async {
    try {
      final List<Map<String, dynamic>> jsonList =
          _records.map((record) => record.toJson()).toList();
      await _storage.writeSummary(jsonList);

    } catch (e) {
      debugPrint('Chyba při ukládání záznamů: $e');
    }
  }

  Future<void> _deleteRecord(int index) async {
    try {
      setState(() {
        _records.removeAt(index);
      });
      await _saveRecords(); // Save after deletion
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: Duration(seconds: 1),
          content: Text(L10n.of(context).recordsDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Chyba při mazání záznamu: $e');
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
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Text(L10n.of(context).recordsConfirmDeleteTitle),
          content: Text(L10n.of(context).recordsConfirmDeleteBody),
          actions: <Widget>[
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () {
                Navigator.of(context).pop(); // Zavře dialog
                _refreshPage(); // Obnoví stránku
              },
              child: Text(L10n.of(context).commonCancel),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteRecord(index);
              },
              child: Text(L10n.of(context).commonDelete),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search
        TextField(
          decoration: InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: L10n.of(context).recordsSearchHint,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            _searchQuery = v.trim();
            _applyFilters();
          },
        ),
        const SizedBox(height: 8),
        // Quality chips
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            ChoiceChip(
              label: Text(L10n.of(context).recordsFilterAll),
              selected: _qualityFilter == 'all',
              onSelected: (_) {
                setState(() => _qualityFilter = 'all');
                _applyFilters();
              },
            ),
            ChoiceChip(
              label: Text(L10n.of(context).qualityGood),
              selected: _qualityFilter == 'good',
              onSelected: (_) {
                setState(() => _qualityFilter = 'good');
                _applyFilters();
              },
            ),
            ChoiceChip(
              label: Text(L10n.of(context).qualityMedium),
              selected: _qualityFilter == 'medium',
              onSelected: (_) {
                setState(() => _qualityFilter = 'medium');
                _applyFilters();
              },
            ),
            ChoiceChip(
              label: Text(L10n.of(context).qualityBad),
              selected: _qualityFilter == 'poor',
              onSelected: (_) {
                setState(() => _qualityFilter = 'poor');
                _applyFilters();
              },
            ),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.lightBlue,
                side: const BorderSide(color: Colors.lightBlue),
              ),
              icon: const Icon(Icons.date_range),
              label: Text(_startDate == null && _endDate == null
                  ? 'Datum'
                  : '${_startDate?.toIso8601String().substring(0, 10) ?? '...'} — ${_endDate?.toIso8601String().substring(0, 10) ?? '...'}'),
              onPressed: () async {
                final picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(2024),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked.start;
                    _endDate = picked.end;
                  });
                  _applyFilters();
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        // BPM range
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.of(context).recordsBpmRange('$_minBpm', '$_maxBpm')),
            SliderTheme(
              data: SliderThemeData(
                activeTrackColor: Colors.lightBlue,
                inactiveTrackColor: Colors.lightBlue.withOpacity(0.25),
                thumbColor: Colors.lightBlue,
                overlayColor: Colors.lightBlue.withOpacity(0.12),
              ),
              child: RangeSlider(
                values: RangeValues(_minBpm.toDouble(), _maxBpm.toDouble()),
                min: 30,
                max: 220,
                divisions: 190,
                labels: RangeLabels('$_minBpm', '$_maxBpm'),
                onChanged: (v) {
                  setState(() {
                    _minBpm = v.start.round();
                    _maxBpm = v.end.round();
                  });
                  _applyFilters();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTrendsSection() {
    if (_visible.length < 2) {
      return const SizedBox.shrink();
    }

    final sorted = List<Record>.from(_visible)
      ..sort(
          (a, b) => _parseRecordDateTime(a).compareTo(_parseRecordDateTime(b)));

    List<FlSpot> seriesFor(double Function(Record r) extractor) {
      final spots = <FlSpot>[];
      for (int i = 0; i < sorted.length; i++) {
        final value = extractor(sorted[i]);
        if (value.isNaN || value.isInfinite) continue;
        spots.add(FlSpot(i.toDouble(), value));
      }
      return spots;
    }

    final bpmSpots = seriesFor((r) => r.averageBPM.toDouble());
    final sdnnSpots = seriesFor((r) => (r.hrv['sdnn'] ?? 0.0).toDouble());
    final rmssdSpots = seriesFor((r) => (r.hrv['rmssd'] ?? 0.0).toDouble());
    final stressSpots =
        seriesFor((r) => (r.hrv['stressIndex'] ?? 0.0).toDouble());

    double mean(Iterable<double> values) =>
        values.isEmpty ? 0.0 : values.reduce((a, b) => a + b) / values.length;
    double minV(Iterable<double> values) =>
        values.isEmpty ? 0.0 : values.reduce(min);
    double maxV(Iterable<double> values) =>
        values.isEmpty ? 0.0 : values.reduce(max);

    final List<double> bpmValues =
        sorted.map<double>((r) => r.averageBPM.toDouble()).toList();
    final List<double> sdnnValues = sorted
        .map<double>((r) => (r.hrv['sdnn'] ?? 0.0).toDouble())
        .where((value) => value > 0)
        .toList();
    final List<double> rmssdValues = sorted
        .map<double>((r) => (r.hrv['rmssd'] ?? 0.0).toDouble())
        .where((value) => value > 0)
        .toList();

    double trendDelta(List<double> values) {
      if (values.length < 4) return 0.0;
      final headEnd = (values.length * 0.3).ceil();
      final tailStart = values.length - headEnd;
      final head = values.sublist(0, headEnd);
      final tail = values.sublist(tailStart);
      return mean(tail) - mean(head);
    }

    final bpmTrend = trendDelta(bpmValues);

    int good = 0;
    int medium = 0;
    int poor = 0;
    for (final record in sorted) {
      switch (_qualityFor(record)) {
        case 'good':
          good++;
          break;
        case 'medium':
          medium++;
          break;
        default:
          poor++;
      }
    }

    final total = sorted.length;

    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceSm),
      child: Card(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color.fromARGB(120, 158, 158, 158)),
        ),
        child: ExpansionTile(
          initiallyExpanded: true,
          tilePadding: EdgeInsets.symmetric(horizontal: r.spaceMd + 2),
          title: Row(
            children: [
              Icon(Icons.insights, color: Colors.blue, size: r.iconMd),
              SizedBox(width: r.spaceSm),
              Text(
                L10n.of(context).recordsLongTermTrends,
                style: TextStyle(
                    fontSize: r.fontBodyLg, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          subtitle: Text(
            L10n.of(context)
                    .recordsTrendSummary(
                        total, mean(bpmValues).toStringAsFixed(0)) +
                (bpmTrend.abs() < 0.5
                    ? ''
                    : '  •  ${bpmTrend > 0 ? '↑' : '↓'} ${bpmTrend.abs().toStringAsFixed(1)} bpm'),
            style: TextStyle(fontSize: r.fontSmall, color: Colors.black54),
          ),
          childrenPadding:
              EdgeInsets.fromLTRB(r.spaceMd, 0, r.spaceMd, r.spaceMd),
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: r.gridColumns,
              childAspectRatio: r.gridColumns == 1 ? 2.6 : 1.35,
              crossAxisSpacing: r.spaceSm + 2,
              mainAxisSpacing: r.spaceSm + 2,
              children: [
                _buildTrendTile(
                  r: r,
                  title: L10n.of(context).metricsHeartRate,
                  unit: L10n.of(context).homeBpmUnit,
                  spots: bpmSpots,
                  color: const Color.fromARGB(255, 246, 41, 0),
                  avg: mean(bpmValues),
                  lo: minV(bpmValues),
                  hi: maxV(bpmValues),
                ),
                _buildTrendTile(
                  r: r,
                  title: 'SDNN',
                  unit: 'ms',
                  spots: sdnnSpots,
                  color: Colors.blue,
                  avg: mean(sdnnValues),
                  lo: sdnnValues.isEmpty ? 0 : minV(sdnnValues),
                  hi: sdnnValues.isEmpty ? 0 : maxV(sdnnValues),
                ),
                _buildTrendTile(
                  r: r,
                  title: 'RMSSD',
                  unit: 'ms',
                  spots: rmssdSpots,
                  color: Colors.teal,
                  avg: mean(rmssdValues),
                  lo: rmssdValues.isEmpty ? 0 : minV(rmssdValues),
                  hi: rmssdValues.isEmpty ? 0 : maxV(rmssdValues),
                ),
                _buildTrendTile(
                  r: r,
                  title: L10n.of(context).metricsStressIndex,
                  unit: '',
                  spots: stressSpots,
                  color: Colors.deepOrange,
                  avg: mean(stressSpots.map((spot) => spot.y)),
                  lo: stressSpots.isEmpty
                      ? 0
                      : minV(stressSpots.map((spot) => spot.y)),
                  hi: stressSpots.isEmpty
                      ? 0
                      : maxV(stressSpots.map((spot) => spot.y)),
                ),
              ],
            ),
            SizedBox(height: r.spaceMd),
            Row(
              children: [
                Expanded(
                  flex: good,
                  child: _qualityBar(r, Colors.green, L10n.of(context).qualityGood, good),
                ),
                if (medium > 0)
                  Expanded(
                    flex: medium,
                    child: _qualityBar(r, Colors.orange, L10n.of(context).qualityMedium, medium),
                  ),
                if (poor > 0)
                  Expanded(
                    flex: poor,
                    child: _qualityBar(r, Colors.red, L10n.of(context).qualityBad, poor),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendTile({
    required Responsive r,
    required String title,
    required String unit,
    required List<FlSpot> spots,
    required Color color,
    required double avg,
    required double lo,
    required double hi,
  }) {
    final hasData = spots.length >= 2;
    return Container(
      padding: EdgeInsets.all(r.spaceSm + 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color.fromARGB(120, 158, 158, 158)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: r.fontSmall,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: r.spaceXs / 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                hasData ? avg.toStringAsFixed(1) : '—',
                style: TextStyle(
                  fontSize: r.fontTitle,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (unit.isNotEmpty)
                Padding(
                  padding: EdgeInsets.only(left: r.spaceXs / 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                        fontSize: r.fontCaption, color: Colors.black54),
                  ),
                ),
            ],
          ),
          Expanded(
            child: hasData
                ? LineChart(
                    LineChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      borderData: FlBorderData(show: false),
                      lineTouchData: const LineTouchData(enabled: false),
                      minY: lo - ((hi - lo).abs() * 0.1 + 1),
                      maxY: hi + ((hi - lo).abs() * 0.1 + 1),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.25,
                          color: color,
                          barWidth: 2,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: color.withOpacity(0.12),
                          ),
                        ),
                      ],
                    ),
                    duration: Duration.zero,
                  )
                : Center(
                    child: Text(
                      '—',
                      style: TextStyle(
                          color: Colors.black38, fontSize: r.fontSmall),
                    ),
                  ),
          ),
          if (hasData)
            Text(
              'min ${lo.toStringAsFixed(0)} • max ${hi.toStringAsFixed(0)}',
              style:
                  TextStyle(fontSize: r.fontCaption - 1, color: Colors.black45),
            ),
        ],
      ),
    );
  }

  Widget _qualityBar(Responsive r, Color color, String label, int count) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: r.spaceXs / 2),
      padding: EdgeInsets.symmetric(vertical: r.spaceXs + 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
              fontSize: r.fontBody,
            ),
          ),
          Text(
            label,
            style: TextStyle(
                fontSize: r.fontCaption - 1, color: color.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityChip(Record record) {
    final q = _qualityFor(record);
    Color color;
    String label;
    switch (q) {
      case 'good':
        color = Colors.green;
        label = L10n.of(context).qualityGood.toLowerCase();
        break;
      case 'medium':
        color = Colors.orange;
        label = L10n.of(context).qualityMedium.toLowerCase();
        break;
      default:
        color = Colors.red;
        label = L10n.of(context).qualityBad.toLowerCase();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
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
                      Flexible(
                        child: Text(
                          title,
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: 2,
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
                    child: SizedBox(
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          style: TextStyle(
                            fontSize: 16,
                            color: valueColor ?? Colors.black,
                          ),
                        ),
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

  /// Resolves a record's start instant, falling back to the legacy
  /// date + time strings for records saved before startedAt existed.
  static DateTime? _parseRecordStart(Record record) {
    if (record.startedAt.isNotEmpty) {
      final DateTime? parsed = DateTime.tryParse(record.startedAt);
      if (parsed != null) return parsed;
    }
    if (record.date.isNotEmpty && record.time.isNotEmpty) {
      return DateTime.tryParse('${record.date} ${record.time}');
    }
    return null;
  }

  /// Vsechno, co export potrebuje, spocitane jednou pro vsechny formaty.
  _ExportBundle _prepareExport(Record record) {
    final double fs = record.effectiveSampleRate;
    final int expectedLength = (record.duration * fs).toInt();
    List<double> data = record.dataForPlot;
    if (data.length > expectedLength) {
      data = data.sublist(data.length - expectedLength);
    }

    List<int> stamps = record.frameTimestampsMs;
    if (stamps.length > data.length) {
      stamps = stamps.sublist(stamps.length - data.length);
    }
    final bool hasStamps = stamps.length == data.length;

    List<Map<String, dynamic>> raws = record.rawRgbSamples;
    if (raws.length > data.length) {
      raws = raws.sublist(raws.length - data.length);
    }
    final bool hasRaw = raws.length == data.length;

    final sqa = SignalQualityIndex(fs: fs).evaluate(data);
    // Signal ma pulzy nahoru (overeno na merenich 2026: sikmost derivace
    // +0,84 u 97 % zaznamu), detektor tedy hleda maxima primo v nem.
    // Krome vrcholu se hledaji i paty pulzu. Nastup pulzu ma strmejsi hranu
    // a nemate ho dikroticky zakmit, takze intervaly z pat vychazeji
    // spolehliveji - na merenich 2026 z nich detektor nasel 99,9 % tepu
    // proti 98,9 % z vrcholu. Vrcholy se proto zobrazuji, casuje se z pat.
    final detector = UnifiedPpgPeakDetector(fs: fs);
    final peaks = detector.detect(data, zeroPhase: true);
    final feet = detector.detect(data.map((v) => -v).toList(), zeroPhase: true);

    final int? t0Ms = hasStamps ? stamps.first : null;
    final times = List<double>.generate(
      data.length,
      (i) => hasStamps ? (stamps[i] - t0Ms!) / 1000.0 : i / fs,
    );
    double timeOf(PpgPeak peak) {
      if (!hasStamps) return peak.timeSec;
      final int i0 = peak.fractionalIndex.floor().clamp(0, stamps.length - 1);
      final int i1 = (i0 + 1).clamp(0, stamps.length - 1);
      final double frac = peak.fractionalIndex - i0;
      return ((stamps[i0] + (stamps[i1] - stamps[i0]) * frac) - t0Ms!) / 1000.0;
    }

    final peakTimes = peaks.map(timeOf).toList();
    final footTimes = feet.map(timeOf).toList();

    return _ExportBundle(
      fs: fs,
      data: data,
      times: times,
      raws: hasRaw ? raws : const [],
      peakIndices: peaks.map((p) => p.fractionalIndex.round()).toList(),
      peakTimes: peakTimes,
      footIndices: feet.map((p) => p.fractionalIndex.round()).toList(),
      footTimes: footTimes,
      bpmFromFeet: detector.bpmFromPeaks(feet),
      hasRaw: hasRaw,
      hasStamps: hasStamps,
      startInstant: _parseRecordStart(record),
      quality: sqa,
      sampleRateSource: hasStamps
          ? 'frame timestamps'
          : (record.sampleRateHz > 0
              ? 'measured'
              : 'derived from sample count'),
    );
  }

  /// Ulozi zaznam ve formatu zvolenem v nastaveni. Vraci cestu k souboru.
  Future<String?> _createExport(Record record) async {
    switch (AppSettings.value.exportFormat) {
      case ExportFormat.csv:
        return _createCsv(record);
      case ExportFormat.json:
        return _createJson(record);
      case ExportFormat.txt:
        return _createTxt(record);
    }
  }

  Future<String?> _createCsv(Record record) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file =
          File('${directory.path}/record_${record.date}_${record.time}.csv');
      final b = _prepareExport(record);
      final sb = StringBuffer();

      // Metadata jako komentarova hlavicka - pandas i Excel ji umi preskocit.
      void meta(String key, Object? value) =>
          sb.writeln('# $key,${value ?? ''}');
      meta('date', record.date);
      meta('time', record.time);
      meta('started_at', record.startedAt);
      meta('duration_s', record.duration);
      meta('average_bpm', record.averageBPM);
      meta('bpm_from_feet', b.bpmFromFeet.toStringAsFixed(1));
      meta('timing_landmark', 'pulse foot');
      meta('sample_rate_hz', b.fs.toStringAsFixed(3));
      meta('sample_rate_source', b.sampleRateSource);
      meta(
          'signal_quality',
          '${b.quality.level.name} '
              '(${b.quality.score.toStringAsFixed(0)}/100)');
      meta('notes', record.notesContent.replaceAll(',', ' '));
      record.metadata.forEach((k, v) => meta(k, v.replaceAll(',', ' ')));

      sb.writeln(b.raws.isEmpty
          ? 'time_s,timestamp,signal,peak,foot'
          : 'time_s,timestamp,signal,peak,foot,raw_green,raw_red,raw_blue');
      final peakSet = b.peakIndices.toSet();
      final footSet = b.footIndices.toSet();
      for (int i = 0; i < b.data.length; i++) {
        sb.writeln('${b.times[i].toStringAsFixed(3)},${b.stampAt(i)},'
            '${b.data[i]},${peakSet.contains(i) ? 1 : 0},'
            '${footSet.contains(i) ? 1 : 0}${b.raw(i)}');
      }
      await file.writeAsString(sb.toString());
      return file.path;
    } catch (e) {
      debugPrint('Error creating CSV: $e');
      return null;
    }
  }

  Future<String?> _createJson(Record record) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file =
          File('${directory.path}/record_${record.date}_${record.time}.json');
      final b = _prepareExport(record);
      final payload = {
        'schema': 'tepovka.record/1',
        'date': record.date,
        'time': record.time,
        'startedAt': record.startedAt,
        'endedAt': record.endedAt,
        'savedAt': record.savedAt,
        'durationS': record.duration,
        'averageBpm': record.averageBPM,
        'notes': record.notesContent,
        'metadata': record.metadata,
        'sampleRateHz': b.fs,
        'sampleRateSource': b.sampleRateSource,
        'signalPipeline':
            'median(5) -> baseline removal -> EMA(alpha=0.4), inverted',
        'quality': {
          'level': b.quality.level.name,
          'score': b.quality.score,
          'snrDb': b.quality.snrDb,
          'periodicity': b.quality.periodicity,
          'reason': b.quality.reason,
        },
        'hrv': record.hrv,
        'respiratoryRate': record.respiratoryRate,
        'timeS': b.times,
        'signal': b.data,
        'peakIndices': b.peakIndices,
        'peakTimesS': b.peakTimes,
        'footIndices': b.footIndices,
        'footTimesS': b.footTimes,
        'bpmFromFeet': b.bpmFromFeet,
        'timingLandmark': 'foot',
        if (b.raws.isNotEmpty) ...{
          'rawGreen': b.raws.map((r) => r['green']).toList(),
          'rawRed': b.raws.map((r) => r['red']).toList(),
          'rawBlue': b.raws.map((r) => r['blue']).toList(),
        },
      };
      await file
          .writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
      return file.path;
    } catch (e) {
      debugPrint('Error creating JSON: $e');
      return null;
    }
  }

  Future<String?> _createTxt(Record record) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file =
          File('${directory.path}/record_${record.date}_${record.time}.txt');
      final b = _prepareExport(record);

      final sb = StringBuffer();
      sb.writeln('Date: ${record.date}');
      sb.writeln('Time: ${record.time}');
      sb.writeln('Measurement start: '
          '${record.startedAt.isNotEmpty ? record.startedAt : '${record.date} ${record.time}'}');
      if (record.endedAt.isNotEmpty) {
        sb.writeln('Measurement end: ${record.endedAt}');
      }
      if (record.savedAt.isNotEmpty) {
        sb.writeln('Saved at: ${record.savedAt}');
      }
      sb.writeln('Average BPM: ${record.averageBPM}');
      sb.writeln('BPM from pulse feet: ${b.bpmFromFeet.toStringAsFixed(1)}');
      sb.writeln('Notes: ${record.notesContent}');
      sb.writeln('Duration: ${record.duration}');
      record.metadata.forEach((key, value) => sb.writeln('$key: $value'));
      sb.writeln('Sample rate (Hz): ${b.fs.toStringAsFixed(3)}');
      sb.writeln('Sample rate source: ${b.sampleRateSource}');
      sb.writeln('Signal quality: ${b.quality.level.name} '
          '(${b.quality.score.toStringAsFixed(0)}/100, '
          'SNR ${b.quality.snrDb.toStringAsFixed(1)} dB)');
      sb.writeln('Raw channels: '
          '${b.hasRaw ? 'green,red,blue (ROI mean, unfiltered)' : 'not available'}');
      sb.writeln('Signal Value pipeline: '
          'median(5) -> baseline removal -> EMA(alpha=0.4), inverted');
      sb.writeln('Timing landmark: pulse foot');
      sb.writeln('');
      sb.writeln(b.hasRaw
          ? 'Time (s),Timestamp,Signal Value,Raw Green,Raw Red,Raw Blue'
          : 'Time (s),Timestamp,Signal Value');

      for (int i = 0; i < b.data.length; i++) {
        sb.writeln('${b.times[i].toStringAsFixed(3)},${b.stampAt(i)},'
            '${b.data[i]}${b.raw(i)}');
      }

      void section(String title, List<Object> values) {
        sb.writeln('');
        sb.writeln(title);
        for (final v in values) {
          sb.writeln(v.toString());
        }
      }

      section('Peak Indices:', b.peakIndices);
      section('Peak Times (s):',
          b.peakTimes.map((t) => t.toStringAsFixed(4)).toList());
      section('Foot Indices:', b.footIndices);
      section('Foot Times (s):',
          b.footTimes.map((t) => t.toStringAsFixed(4)).toList());

      await file.writeAsString(sb.toString());
      return file.path;
    } catch (e) {
      debugPrint('Error creating TXT: $e');
      return null;
    }
  }

  double _calculateAverageBPM(Record record) {
    // Trim data to exactly recording duration (remove initial if extra)
    final double fs = record.effectiveSampleRate;
    int expectedLength = (record.duration * fs).toInt();
    List<double> trimmedData = record.dataForPlot;
    if (trimmedData.length > expectedLength) {
      trimmedData = trimmedData.sublist(trimmedData.length - expectedLength);
    }
    // Create spots with time x in the stored signal polarity.
    List<FlSpot> spots = [];
    for (int i = 0; i < trimmedData.length; i++) {
      spots.add(FlSpot(i / fs, trimmedData[i]));
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
    // Tep se pocita z pat pulzu (presnejsi casovani), ne z vrcholu - stejne
    // jako v exportu, aby list, detail i soubor hlasily shodne BPM.
    final feet = UnifiedPpgPeakDetector(fs: fs)
        .detect(smoothedData.map((s) => -s.y).toList(), zeroPhase: true);
    List<FlSpot> peakSpots = feet
        .map((foot) => smoothedData[
            (foot.timeSec * fs).round().clamp(0, smoothedData.length - 1)])
        .toList();
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

  /// Pomocná funkce na výpočet percentilu – pro robustní škálování bez vlivů outlierů
  double _calculatePercentile(List<double> values, double percentile) {
    if (values.isEmpty) return 0.0;
    final sorted = List<double>.from(values)..sort();
    final index = ((percentile / 100.0) * (sorted.length - 1)).round();
    return sorted[index.clamp(0, sorted.length - 1)];
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
    final double fs = record.effectiveSampleRate;
    int expectedLength = (record.duration * fs).toInt();
    List<double> trimmedData = record.dataForPlot;
    if (trimmedData.length > expectedLength) {
      trimmedData = trimmedData.sublist(trimmedData.length - expectedLength);
    }
    // Ulozeny signal uz je otoceny v Home (pulzy miri nahoru), takze se
    // vykresluje tak, jak je - jinak by detail ukazoval krivku vzhuru nohama
    // oproti osciloskopu behem mereni a vrcholy by padaly do udoli.
    List<FlSpot> spots = [];
    for (int i = 0; i < trimmedData.length; i++) {
      spots.add(FlSpot(i / fs, trimmedData[i]));
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
    // Detect peaks on the same smoothed waveform that is actually plotted.
    final detector = UnifiedPpgPeakDetector(fs: fs);
    final plottedSignal = smoothedData.map((spot) => spot.y).toList();
    final detectedPeaks = detector.detect(plottedSignal, zeroPhase: true);
    peakSpots = detectedPeaks.map((peak) {
      final int nearestIndex =
          (peak.timeSec * fs).round().clamp(0, smoothedData.length - 1);
      final visibleSpot = smoothedData[nearestIndex];
      return FlSpot(visibleSpot.x, visibleSpot.y);
    }).toList();
    // Keep the detail BPM identical to the list view.
    calculatedAverageBPM = record.averageBPM.toDouble();
    // Generate time labels every 5 seconds to avoid overlap
    double totalTime = trimmedData.length / fs;
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

    // Použji percentilové škálování místo min-max – odolné vůči výchylkám na konci
    double minY = -1.0;
    double maxY = 1.0;
    if (smoothedData.isNotEmpty) {
      final yValues = smoothedData.map((spot) => spot.y).toList();
      minY = _calculatePercentile(yValues, 2.0) - 1.0;
      maxY = _calculatePercentile(yValues, 98.0) + 1.0;
    }

    double minX = 0.0;
    double maxX = totalTime;

    GlobalKey chartKey = GlobalKey();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final r = Responsive.of(context);
        return AlertDialog(
          insetPadding: r.dialogInsetPadding,
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
                        Text(
                          L10n.of(context).summaryAverageHeartRate,
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
                        controller: _chartScrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _chartScrollController,
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
                        title: Text(
                          L10n.of(context).metricsHrvAnalysis,
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
                            childAspectRatio: 1.55,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            children: [
                              _buildHRVCard(L10n.of(context).metricsRespiratoryRate,
                                  L10n.of(context).metricsBreathsPerMinute(record.respiratoryRate.toStringAsFixed(1))),
                              _buildHRVCard(
                                  'SDNN', '${sdnn.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'RMSSD', '${rmssd.toStringAsFixed(2)} ms'),
                              _buildHRVCard(
                                  'pNN50', '${pnn50.toStringAsFixed(2)} %'),
                              _buildHRVCard(L10n.of(context).metricsAverageRr,
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
                                L10n.of(context).metricsStressIndex,
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
                        title: Text(
                          L10n.of(context).metricsHeartRateRecovery,
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        childrenPadding:
                            const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            L10n.of(context).metricsRecoveryIntro,
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
                            childAspectRatio: 1.55,
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
          // Tři tlačítka ve Wrapu se na užších displejích lámala tak, že
          // „Zavřít" zůstalo samo na druhém řádku. Teď je rozvržení záměrné:
          // dva exporty vedle sebe, zavření pod nimi.
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          actions: <Widget>[
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          // Resolve the PDF's text before the first await, so
                          // no BuildContext is touched across an async gap.
                          final pdfLabels = PdfLabels.of(L10n.of(context));
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
                            labels: pdfLabels,
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
                          foregroundColor: Colors.blue,
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            Icon(
                              FontAwesomeIcons.filePdf,
                              size: 18,
                              color: Colors.red,
                            ),
                            Text(
                              L10n.of(context).recordsDownloadPdf,
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        onPressed: () async {
                          final txtPath = await _createExport(record);
                          if (txtPath != null) {
                            await OpenFilex.open(txtPath);
                          }
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.blue,
                        ),
                        child: Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 5,
                          children: [
                            Icon(
                              FontAwesomeIcons.fileLines,
                              size: 18,
                              color: Colors.black,
                            ),
                            Text(
                              L10n.of(context).recordsExportTxt,
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: const Color.fromARGB(255, 0, 0, 0),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(L10n.of(context).commonClose),
                  ),
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
      debugPrint('Error capturing chart: $e');
      return null;
    }
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
    // Aplikuj percentilové škálování pro robustnost vůči outlierům
    final yValues = spots.map((s) => s.y).toList();
    minY = _calculatePercentile(yValues, 2.0);
    maxY = _calculatePercentile(yValues, 98.0);
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
    final L10n t = L10n.of(context);
    // Titles that are translated cannot be switch cases (a case label must be
    // a compile-time constant), and matching them here keeps the lookup
    // working in whatever language the caller rendered the title in.
    if (title == t.metricsRespiratoryRate) return t.tipRespiratoryRate;
    if (title == t.metricsAverageRr) return t.tipMeanRr;
    if (title == t.metricsHeartRate) return t.tipGenericHrv;
    if (title == t.metricsStressIndex) return t.tipBaevsky;

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
    final mq = MediaQuery.of(context);
    final left = offset.dx;
    final top = offset.dy + size.height;
    final right = mq.size.width - (offset.dx + size.width);
    final bottom = mq.size.height - offset.dy;
    final rect = RelativeRect.fromLTRB(left, top, right, bottom);
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
            constraints: BoxConstraints(
                maxWidth: (MediaQuery.of(context).size.width - 48)
                    .clamp(140.0, 560.0)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Flexible(
                        child: Text(
                          value,
                          textAlign: TextAlign.end,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.black54),
                        ),
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
    final r = Responsive.of(context);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              L10n.of(context).recordsTitle,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: r.fontTitleLg,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: L10n.of(context).recordsSelectMultiple,
            icon: Icon(_selectionMode
                ? Icons.check_box
                : Icons.check_box_outline_blank),
            onPressed: () {
              setState(() {
                _selectionMode = !_selectionMode;
                _selectedKeys.clear();
              });
            },
          ),
          PopupMenuButton<String>(
            tooltip: L10n.of(context).recordsSort,
            onSelected: (value) {
              setState(() {
                _sortMode = value;
              });
              _applyFilters();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                  value: 'date_desc', child: Text(L10n.of(context).recordsSortDateNewest)),
              PopupMenuItem(value: 'date_asc', child: Text(L10n.of(context).recordsSortDateOldest)),
              PopupMenuItem(value: 'bpm_desc', child: Text(L10n.of(context).recordsSortBpmHighest)),
              PopupMenuItem(value: 'bpm_asc', child: Text(L10n.of(context).recordsSortBpmLowest)),
            ],
            icon: const Icon(Icons.sort),
          ),
        ],
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
              ? Center(child: Text(L10n.of(context).recordsEmpty))
              : ListView(
                  padding: const EdgeInsets.all(10),
                  children: [
                    _buildFilterBar(context),
                    const SizedBox(height: 8),
                    _buildTrendsSection(),
                    if (_visible.isNotEmpty) const SizedBox(height: 8),
                    ...List.generate(_visible.length, (index) {
                      final record = _visible[index];
                      final recordKey = '${record.date}_${record.time}';
                      final selected = _selectedKeys.contains(recordKey);
                      return Column(
                        children: [
                          Dismissible(
                            key: ValueKey(recordKey),
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
                              final idx = _records.indexOf(record);
                              _showDeleteConfirmation(idx);
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
                                    if (_selectionMode)
                                      Checkbox(
                                        value: selected,
                                        onChanged: (_) =>
                                            _toggleSelection(recordKey),
                                      ),
                                    Icon(
                                      Icons.history,
                                      color: Colors.black.withOpacity(0.7),
                                    ),
                                    const SizedBox(width: 10),
                                    // Datum a čas pod sebou. Na jednom řádku se
                                    // dlouhé datum lámalo do tří řádků a celý
                                    // řádek se rozjel.
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            record.date,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.blue,
                                            ),
                                          ),
                                          Text(
                                            record.time,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.black
                                                  .withOpacity(0.55),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      '${record.averageBPM} bpm',
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black,
                                      ),
                                    ),
                                    _buildQualityChip(record),
                                    const Icon(
                                      Icons.arrow_forward_ios,
                                      color: Colors.black45,
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const Divider(),
                        ],
                      );
                    }),
                    if (_selectionMode && _selectedKeys.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Center(
                          child: ElevatedButton.icon(
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete_forever),
                            label: Text(
                              L10n.of(context).recordsDeleteSelected(_selectedKeys.length),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                )),
      bottomNavigationBar: GNav(
        tabMargin: EdgeInsets.symmetric(horizontal: r.spaceSm),
        gap: 0,
        activeColor: Colors.black,
        iconSize: r.iconMd,
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
    );
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    super.dispose();
  }
}

class TimeLabel {
  final double x;
  final String time;

  TimeLabel(this.x, this.time);
}

/// Predpocitana data pro export ve vsech formatech.
class _ExportBundle {
  const _ExportBundle({
    required this.fs,
    required this.data,
    required this.times,
    required this.raws,
    required this.peakIndices,
    required this.peakTimes,
    required this.footIndices,
    required this.footTimes,
    required this.bpmFromFeet,
    required this.hasRaw,
    required this.hasStamps,
    required this.startInstant,
    required this.quality,
    required this.sampleRateSource,
  });

  final double fs;
  final List<double> data;
  final List<double> times;
  final List<Map<String, dynamic>> raws;
  final List<int> peakIndices;
  final List<double> peakTimes;
  final List<int> footIndices;
  final List<double> footTimes;

  /// Tep spocitany z intervalu mezi patami pulzu.
  final double bpmFromFeet;
  final bool hasRaw;
  final bool hasStamps;
  final DateTime? startInstant;

  String raw(int i) =>
      hasRaw ? ',${raws[i]['green']},${raws[i]['red']},${raws[i]['blue']}' : '';

  String stampAt(int i) =>
      startInstant
          ?.add(Duration(microseconds: (times[i] * 1e6).round()))
          .toIso8601String() ??
      '';
  final SqaResult quality;
  final String sampleRateSource;
}
