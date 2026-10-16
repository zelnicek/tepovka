import 'dart:io';
import 'package:tepovka/l10n/app_localizations.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/home.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
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
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/pages/about.dart';
import 'package:intl/intl.dart';
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

  /// Nastavení kamery za měření a přepálení kanálů, viz `buildCameraReport`.
  final Map<String, String> cameraSettings;
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
    this.cameraSettings = const {},
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
      'cameraSettings': cameraSettings,
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
      cameraSettings: json['cameraSettings'] != null
          ? Map<String, String>.from((json['cameraSettings'] as Map)
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

  /// Bumped after returning from a page opened from the bottom bar.
  int _navResets = 0;
  final StorageService _storage = StorageService();
  // UX filters state
  List<Record> _visible = [];
  String _searchQuery = '';

  /// The heart-rate filter's full range; at these ends it filters nothing.
  /// The default used to be 40–200, which silently hid readings outside it.
  static const int _bpmFloor = 30;
  static const int _bpmCeiling = 220;
  int _minBpm = _bpmFloor;
  int _maxBpm = _bpmCeiling;
  bool _searchOpen = false;
  final TextEditingController _searchController = TextEditingController();
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

        // The stored heart rate is the one the summary showed after the
        // measurement, so it is kept. It used to be recomputed from the saved
        // waveform on every visit and written back, which silently replaced
        // the measured value and turned records without a waveform into
        // 0 bpm. Recomputing now only fills in a missing value, in memory.
        List<Record> updatedRecords = [];
        for (var rec in loadedRecords) {
          final int bpm = rec.averageBPM > 0
              ? rec.averageBPM
              : _calculateAverageBPM(rec).toInt();
          updatedRecords.add(Record(
            date: rec.date,
            time: rec.time,
            // Bez těchto tří polí ztrácel seznam přesný okamžik měření a export
            // pak spadl na méně přesné date+time.
            startedAt: rec.startedAt,
            endedAt: rec.endedAt,
            savedAt: rec.savedAt,
            averageBPM: bpm,
            notesContent: rec.notesContent,
            dataForPlot: rec.dataForPlot,
            bpmList: rec.bpmList,
            frames: rec.frames,
            duration: rec.duration,
            sampleRateHz: rec.sampleRateHz,
            frameTimestampsMs: rec.frameTimestampsMs,
            metadata: rec.metadata,
            cameraSettings: rec.cameraSettings,
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
        // Deliberately no save here: viewing the history must not rewrite it.
      } else {}
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

  /// When the measurement was taken; older records carry only date and time.
  DateTime _instantOf(Record r) =>
      _parseRecordStart(r) ?? _parseRecordDateTime(r);

  /// Signal quality from the confidence the analysis reported for the
  /// measurement: 'good', 'medium' or 'poor', or null for records saved before
  /// it was stored. The list used to grade records by HRV thresholds instead,
  /// so every record without HRV showed up as "poor".
  static String? _signalQualityOf(Record r) {
    final Object? confidence = r.hrv['confidence'];
    if (confidence is! Map) return null;
    final Object? value = confidence['bpmConfidence'];
    if (value is! num) return null;
    if (value >= 0.6) return 'good';
    if (value >= 0.3) return 'medium';
    return 'poor';
  }

  void _applyFilters() {
    List<Record> out = List<Record>.from(_records);
    // Search, including the dates as the list now shows them.
    if (_searchQuery.isNotEmpty) {
      final String q = _searchQuery.toLowerCase();
      out = out.where((r) {
        final DateTime when = _instantOf(r);
        String shown = '';
        try {
          shown = '${DateFormat.yMMMMEEEEd(_locale).format(when)} '
              '${DateFormat.yMd(_locale).format(when)} ${_formatTime(when)}';
        } catch (_) {}
        return r.notesContent.toLowerCase().contains(q) ||
            r.date.contains(q) ||
            r.time.contains(q) ||
            shown.toLowerCase().contains(q) ||
            r.averageBPM.toString().contains(q);
      }).toList();
    }
    // BPM range; the full range filters nothing.
    if (_minBpm > _bpmFloor || _maxBpm < _bpmCeiling) {
      out = out
          .where((r) => r.averageBPM >= _minBpm && r.averageBPM <= _maxBpm)
          .toList();
    }
    // Date range
    if (_startDate != null || _endDate != null) {
      out = out.where((r) {
        final dt = _instantOf(r);
        final after = _startDate == null || !dt.isBefore(_startDate!);
        final before = _endDate == null || !dt.isAfter(_endDate!);
        return after && before;
      }).toList();
    }
    // Quality
    if (_qualityFilter != 'all') {
      out = out.where((r) => _signalQualityOf(r) == _qualityFilter).toList();
    }
    // Sort
    out.sort((a, b) {
      switch (_sortMode) {
        case 'date_asc':
          return _instantOf(a).compareTo(_instantOf(b));
        case 'bpm_desc':
          return b.averageBPM.compareTo(a.averageBPM);
        case 'bpm_asc':
          return a.averageBPM.compareTo(b.averageBPM);
        case 'date_desc':
        default:
          return _instantOf(b).compareTo(_instantOf(a));
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
    if (!await _confirmDelete(
        body: L10n.of(context)
            .recordsConfirmDeleteSelectedBody(_selectedKeys.length))) {
      return;
    }
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

  /// Asks before deleting. Returns whether to go ahead.
  Future<bool> _confirmDelete({String? body}) async {
    final L10n t = L10n.of(context);
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(t.recordsConfirmDeleteTitle),
        content: Text(body ?? t.recordsConfirmDeleteBody),
        actions: [
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.black87),
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(t.commonCancel),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kInfoAccent),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t.commonDelete),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  Future<void> _deleteRecord(Record record) async {
    try {
      setState(() => _records.remove(record));
      // The swiped row has to leave the list in the same frame, or Flutter
      // complains that a dismissed item is still in the tree.
      _applyFilters();
      await _saveRecords();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 1),
          content: Text(L10n.of(context).recordsDeleted),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Chyba při mazání záznamu: $e');
    }
  }

  Future<void> _onItemTapped(int index) async {
    switch (index) {
      case 0:
        // The home screen is the root route and is still underneath; pushing
        // a new one stacked another copy on top every time.
        Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      case 1:
        await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const Home()));
        break;
      case 2:
        await Navigator.push(
            context, MaterialPageRoute(builder: (context) => const About()));
        break;
    }
    // Back here: a measurement may have been added, and the bar must not stay
    // on the tab that was used to leave.
    if (!mounted) return;
    setState(() => _navResets++);
    _loadRecords();
  }

  bool get _filtersActive =>
      _qualityFilter != 'all' ||
      _startDate != null ||
      _endDate != null ||
      _minBpm > _bpmFloor ||
      _maxBpm < _bpmCeiling ||
      _sortMode != 'date_desc';

  void _clearFilters() {
    setState(() {
      _qualityFilter = 'all';
      _startDate = null;
      _endDate = null;
      _minBpm = _bpmFloor;
      _maxBpm = _bpmCeiling;
      _sortMode = 'date_desc';
    });
    _applyFilters();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _searchController.clear();
        _searchQuery = '';
      }
    });
    _applyFilters();
  }

  String get _locale => Localizations.localeOf(context).toString();

  String _formatTime(DateTime when) {
    try {
      return DateFormat.jm(_locale).format(when);
    } catch (_) {
      return '${when.hour}:${when.minute.toString().padLeft(2, '0')}';
    }
  }

  String _formatShortDate(DateTime when) {
    try {
      return DateFormat.yMMMd(_locale).format(when);
    } catch (_) {
      return '${when.day}. ${when.month}. ${when.year}';
    }
  }

  /// "Today", "Yesterday", or the weekday and date, with the year only when
  /// it is not this one.
  String _dayLabel(DateTime day) {
    final L10n t = L10n.of(context);
    final DateTime now = DateTime.now();
    final int daysAgo =
        DateTime(now.year, now.month, now.day).difference(day).inDays;
    if (daysAgo == 0) return t.recordsToday;
    if (daysAgo == 1) return t.recordsYesterday;
    String text;
    try {
      text = (day.year == now.year
              ? DateFormat.MMMMEEEEd(_locale)
              : DateFormat.yMMMMEEEEd(_locale))
          .format(day);
    } catch (_) {
      text = '${day.day}. ${day.month}. ${day.year}';
    }
    // Czech writes weekdays in lower case; as a heading it starts upper case.
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }

  /// Quality, date range, heart-rate range and sort order in one sheet, so
  /// the list itself starts at the top of the screen. Changes apply live.
  Future<void> _openFilterSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final r = Responsive.of(context);
          final L10n t = L10n.of(context);

          void update(VoidCallback change) {
            setState(change);
            setSheetState(() {});
            _applyFilters();
          }

          Widget heading(String text) => Padding(
                padding: EdgeInsets.only(top: r.spaceLg, bottom: r.spaceSm),
                child: Text(
                  text,
                  style: TextStyle(
                      fontSize: r.fontSmall,
                      fontWeight: FontWeight.w600,
                      color: kInfoSecondaryText),
                ),
              );

          Widget choice(String label, bool selected, VoidCallback select) =>
              ChoiceChip(
                label: Text(label),
                selected: selected,
                showCheckmark: false,
                selectedColor: kInfoAccentTint,
                backgroundColor: Colors.white,
                side: BorderSide(
                    color: selected ? kInfoAccent : const Color(0xFFDDDDDD)),
                labelStyle: TextStyle(
                  fontSize: r.fontBody,
                  color: selected ? const Color(0xFFB3261E) : Colors.black87,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                onSelected: (_) => update(select),
              );

          final bool hasDates = _startDate != null || _endDate != null;
          return SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(r.spaceXl, 0, r.spaceXl, r.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.recordsFilters,
                    style: TextStyle(
                        fontSize: r.fontTitle, fontWeight: FontWeight.w600),
                  ),
                  heading(t.recordsSignalQuality),
                  Wrap(
                    spacing: r.spaceSm,
                    runSpacing: r.spaceSm,
                    children: [
                      choice(t.recordsFilterAll, _qualityFilter == 'all',
                          () => _qualityFilter = 'all'),
                      choice(t.qualityGood, _qualityFilter == 'good',
                          () => _qualityFilter = 'good'),
                      choice(t.qualityMedium, _qualityFilter == 'medium',
                          () => _qualityFilter = 'medium'),
                      choice(t.qualityBad, _qualityFilter == 'poor',
                          () => _qualityFilter = 'poor'),
                    ],
                  ),
                  heading(t.recordsDateRange),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black87,
                            side: const BorderSide(color: Color(0xFFDDDDDD)),
                            alignment: Alignment.centerLeft,
                            padding: EdgeInsets.symmetric(
                                horizontal: r.spaceMd, vertical: r.spaceSm + 2),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          icon:
                              const Icon(Icons.date_range, color: kInfoAccent),
                          label: Text(
                            hasDates
                                ? '${_startDate != null ? _formatShortDate(_startDate!) : '…'} – ${_endDate != null ? _formatShortDate(_endDate!) : '…'}'
                                : t.recordsAnyDate,
                          ),
                          onPressed: () async {
                            final DateTimeRange? picked =
                                await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2024),
                              lastDate:
                                  DateTime.now().add(const Duration(days: 1)),
                            );
                            if (picked == null) return;
                            update(() {
                              _startDate = picked.start;
                              // Through the end of the last day, not its
                              // first second.
                              _endDate = DateTime(picked.end.year,
                                  picked.end.month, picked.end.day, 23, 59, 59);
                            });
                          },
                        ),
                      ),
                      if (hasDates)
                        IconButton(
                          tooltip: t.recordsAnyDate,
                          icon: const Icon(Icons.close),
                          onPressed: () => update(() {
                            _startDate = null;
                            _endDate = null;
                          }),
                        ),
                    ],
                  ),
                  heading(t.recordsBpmRange('$_minBpm', '$_maxBpm')),
                  SliderTheme(
                    data: SliderThemeData(
                      activeTrackColor: kInfoAccent,
                      inactiveTrackColor: kInfoAccentTint,
                      thumbColor: kInfoAccent,
                      overlayColor: kInfoAccent.withValues(alpha: 0.12),
                      valueIndicatorColor: kInfoAccent,
                    ),
                    child: RangeSlider(
                      values:
                          RangeValues(_minBpm.toDouble(), _maxBpm.toDouble()),
                      min: _bpmFloor.toDouble(),
                      max: _bpmCeiling.toDouble(),
                      divisions: _bpmCeiling - _bpmFloor,
                      labels: RangeLabels('$_minBpm', '$_maxBpm'),
                      onChanged: (v) => update(() {
                        _minBpm = v.start.round();
                        _maxBpm = v.end.round();
                      }),
                    ),
                  ),
                  heading(t.recordsSort),
                  Wrap(
                    spacing: r.spaceSm,
                    runSpacing: r.spaceSm,
                    children: [
                      choice(t.recordsSortDateNewest, _sortMode == 'date_desc',
                          () => _sortMode = 'date_desc'),
                      choice(t.recordsSortDateOldest, _sortMode == 'date_asc',
                          () => _sortMode = 'date_asc'),
                      choice(t.recordsSortBpmHighest, _sortMode == 'bpm_desc',
                          () => _sortMode = 'bpm_desc'),
                      choice(t.recordsSortBpmLowest, _sortMode == 'bpm_asc',
                          () => _sortMode = 'bpm_asc'),
                    ],
                  ),
                  SizedBox(height: r.spaceXl),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.black87,
                            minimumSize: Size.fromHeight(r.iconXl * 1.3),
                          ),
                          onPressed: _filtersActive
                              ? () {
                                  _clearFilters();
                                  setSheetState(() {});
                                }
                              : null,
                          child: Text(t.recordsClearFilters),
                        ),
                      ),
                      SizedBox(width: r.spaceMd),
                      Expanded(
                        child: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: kInfoAccent,
                            minimumSize: Size.fromHeight(r.iconXl * 1.3),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                          ),
                          onPressed: () => Navigator.pop(sheetContext),
                          child: Text(
                            t.commonDone,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Average, range and the latest readings as bars. HRV trends fold out
  /// below, and only when the records actually carry HRV, instead of four
  /// tiles of zeros.
  Widget _buildSummaryCard() {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final List<Record> sorted = List<Record>.from(_visible)
      ..sort((a, b) => _instantOf(a).compareTo(_instantOf(b)));
    final List<int> bpms = [
      for (final Record rec in sorted)
        if (rec.averageBPM > 0) rec.averageBPM
    ];
    if (bpms.isEmpty) return const SizedBox.shrink();
    final int avg = (bpms.reduce((a, b) => a + b) / bpms.length).round();
    final int lo = bpms.reduce(min);
    final int hi = bpms.reduce(max);
    final List<int> recent = bpms.sublist(max(0, bpms.length - 14));

    List<FlSpot> seriesFor(String key) {
      final List<FlSpot> spots = [];
      for (final Record rec in sorted) {
        final num? value = rec.hrv[key] is num ? rec.hrv[key] as num : null;
        if (value == null || value <= 0 || !value.isFinite) continue;
        spots.add(FlSpot(spots.length.toDouble(), value.toDouble()));
      }
      return spots;
    }

    Widget? hrvTile(
        String title, String unit, List<FlSpot> spots, Color color) {
      if (spots.length < 2) return null;
      final List<double> ys = spots.map((s) => s.y).toList();
      return _buildTrendTile(
        r: r,
        title: title,
        unit: unit,
        spots: spots,
        color: color,
        avg: ys.reduce((a, b) => a + b) / ys.length,
        lo: ys.reduce(min),
        hi: ys.reduce(max),
      );
    }

    final List<Widget> hrvTiles = [
      hrvTile('SDNN', 'ms', seriesFor('sdnn'), const Color(0xFF1A73E8)),
      hrvTile('RMSSD', 'ms', seriesFor('rmssd'), Colors.teal),
      hrvTile(t.metricsStressIndex, '', seriesFor('stressIndex'),
          Colors.deepOrange),
    ].whereType<Widget>().toList();

    final double barArea = r.iconXl;
    return InfoCard(
      padding: EdgeInsets.fromLTRB(
          r.spaceLg, r.spaceLg, r.spaceLg, hrvTiles.isEmpty ? r.spaceLg : 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.recordsAverageLabel,
                        style: TextStyle(
                            fontSize: r.fontSmall, color: kInfoSecondaryText)),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: '$avg',
                        style: TextStyle(
                            fontSize: r.fontDisplay,
                            fontWeight: FontWeight.bold,
                            height: 1.1),
                      ),
                      TextSpan(
                        text: ' ${t.homeBpmUnit}',
                        style: TextStyle(
                            fontSize: r.fontBody, color: kInfoSecondaryText),
                      ),
                    ])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(t.recordsRangeLabel,
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText)),
                  Text(
                    lo == hi
                        ? '$lo ${t.homeBpmUnit}'
                        : '$lo–$hi ${t.homeBpmUnit}',
                    style: TextStyle(
                        fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          if (recent.length >= 2) ...[
            SizedBox(height: r.spaceMd),
            ExcludeSemantics(
              child: SizedBox(
                height: barArea,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < recent.length; i++) ...[
                      if (i > 0) SizedBox(width: r.spaceXs),
                      Expanded(
                        child: Container(
                          height: hi == lo
                              ? barArea * 0.6
                              : barArea *
                                  (0.3 + 0.7 * (recent[i] - lo) / (hi - lo)),
                          decoration: BoxDecoration(
                            color: i == recent.length - 1
                                ? kInfoAccent
                                : const Color(0xFFF6C9C6),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          SizedBox(height: r.spaceSm),
          Text(
            t.recordsMeasurementsCount(bpms.length),
            style: TextStyle(fontSize: r.fontCaption, color: Colors.black45),
          ),
          if (hrvTiles.isNotEmpty)
            Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.only(bottom: r.spaceLg),
                iconColor: kInfoAccent,
                collapsedIconColor: kInfoSecondaryText,
                title: Text(
                  t.recordsHrvTrends,
                  style: TextStyle(
                      fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                ),
                children: [
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: r.gridColumns,
                    childAspectRatio: r.gridColumns == 1 ? 2.6 : 1.35,
                    crossAxisSpacing: r.spaceSm + 2,
                    mainAxisSpacing: r.spaceSm + 2,
                    children: hrvTiles,
                  ),
                ],
              ),
            ),
        ],
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
                            color: color.withValues(alpha: 0.12),
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

  /// Records under a heading per day when sorted by date; as one flat card,
  /// with the date in each row, when sorted by heart rate.
  List<Widget> _buildRecordGroups(BuildContext context) {
    final r = Responsive.of(context);
    if (!_sortMode.startsWith('date')) {
      return [
        SizedBox(height: r.spaceLg),
        _recordGroupCard(context, _visible, showDate: true),
      ];
    }
    final List<Widget> groups = [];
    DateTime? day;
    List<Record> bucket = [];
    void flush() {
      if (bucket.isEmpty) return;
      groups
        ..add(InfoSectionLabel(_dayLabel(day!)))
        ..add(_recordGroupCard(context, bucket, showDate: false));
      bucket = [];
    }

    for (final Record rec in _visible) {
      final DateTime when = _instantOf(rec);
      final DateTime thatDay = DateTime(when.year, when.month, when.day);
      if (thatDay != day) {
        flush();
        day = thatDay;
      }
      bucket.add(rec);
    }
    flush();
    return groups;
  }

  Widget _recordGroupCard(BuildContext context, List<Record> records,
      {required bool showDate}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < records.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, indent: 16, color: Color(0xFFE6E6E6)),
            _recordRow(context, records[i], showDate: showDate),
          ],
        ],
      ),
    );
  }

  /// One measurement: time (and date when not grouped), length and note on
  /// the left, heart rate and a signal-quality dot on the right. Swipe left
  /// to delete, long-press to start selecting.
  Widget _recordRow(BuildContext context, Record record,
      {required bool showDate}) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final String key = '${record.date}_${record.time}';
    final bool selected = _selectedKeys.contains(key);
    final DateTime when = _instantOf(record);
    final String time = _formatTime(when);
    final String title = showDate ? '${_formatShortDate(when)} · $time' : time;
    final String note =
        record.notesContent.trim().replaceAll(RegExp(r'\s+'), ' ');
    final String subtitle = [
      t.homeSecondsSuffix(record.duration),
      if (note.isNotEmpty) note,
    ].join(' · ');

    final Widget row = InkWell(
      onTap: () =>
          _selectionMode ? _toggleSelection(key) : _showRecordDetail(record),
      onLongPress: _selectionMode
          ? null
          : () {
              HapticFeedback.selectionClick();
              setState(() {
                _selectionMode = true;
                _selectedKeys
                  ..clear()
                  ..add(key);
              });
            },
      child: Padding(
        padding: EdgeInsets.fromLTRB(_selectionMode ? r.spaceXs : r.spaceLg,
            r.spaceSm + 2, r.spaceMd, r.spaceSm + 2),
        child: Row(
          children: [
            if (_selectionMode)
              Checkbox(
                value: selected,
                activeColor: kInfoAccent,
                onChanged: (_) => _toggleSelection(key),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: r.spaceXs / 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: r.fontSmall, color: kInfoSecondaryText),
                  ),
                ],
              ),
            ),
            SizedBox(width: r.spaceSm),
            Text.rich(TextSpan(children: [
              TextSpan(
                text: record.averageBPM > 0
                    ? '${record.averageBPM}'
                    : t.homeNoReading,
                style: TextStyle(
                    fontSize: r.fontTitle,
                    fontWeight: FontWeight.bold,
                    color: Colors.black),
              ),
              TextSpan(
                text: ' ${t.homeBpmUnit}',
                style:
                    TextStyle(fontSize: r.fontSmall, color: kInfoSecondaryText),
              ),
            ])),
            SizedBox(width: r.spaceSm),
            _qualityDot(_signalQualityOf(record)),
            if (!_selectionMode) ...[
              SizedBox(width: r.spaceXs),
              Icon(Icons.chevron_right, color: Colors.black26, size: r.iconMd),
            ],
          ],
        ),
      ),
    );

    if (_selectionMode) return row;
    return Dismissible(
      key: ValueKey(key),
      direction: DismissDirection.endToStart,
      background: Container(
        color: kInfoAccent,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: r.spaceXl),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // Cancelling springs the row back instead of reloading the whole page.
      confirmDismiss: (_) => _confirmDelete(),
      onDismissed: (_) => _deleteRecord(record),
      child: row,
    );
  }

  /// Green, amber or red by the signal quality measured at the time; no
  /// dot for records saved before that was stored.
  Widget _qualityDot(String? quality) {
    const double size = 8;
    if (quality == null) return const SizedBox(width: size);
    final L10n t = L10n.of(context);
    final (Color color, String label) = switch (quality) {
      'good' => (const Color(0xFF1E8E3E), t.qualityGood),
      'medium' => (const Color(0xFFE8A317), t.qualityMedium),
      _ => (kInfoAccent, t.qualityBad),
    };
    return Semantics(
      label: t.a11ySignalQuality(label),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }

  Widget _searchField(BuildContext context) {
    final r = Responsive.of(context);
    return TextField(
      controller: _searchController,
      autofocus: true,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: L10n.of(context).recordsSearchHint,
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.white,
        contentPadding: EdgeInsets.symmetric(vertical: r.spaceMd),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
      onChanged: (v) {
        _searchQuery = v.trim();
        _applyFilters();
      },
    );
  }

  Widget _noMatch(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceXxl),
      child: Column(
        children: [
          Icon(Icons.filter_alt_off_outlined,
              size: r.iconXl, color: Colors.black26),
          SizedBox(height: r.spaceSm),
          Text(
            t.recordsNoMatch,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: r.fontBody, color: kInfoSecondaryText),
          ),
          if (_filtersActive)
            TextButton(
              style: TextButton.styleFrom(foregroundColor: kInfoAccent),
              onPressed: _clearFilters,
              child: Text(t.recordsClearFilters),
            ),
        ],
      ),
    );
  }

  /// Scrollable even when empty, so pull-to-refresh still works.
  Widget _emptyState(BuildContext context) {
    final r = Responsive.of(context);
    return ListView(
      padding: EdgeInsets.symmetric(horizontal: r.spaceXl),
      children: [
        SizedBox(height: r.height * 0.22),
        Icon(Symbols.ecg_heart, size: r.iconXl * 1.5, color: Colors.black26),
        SizedBox(height: r.spaceMd),
        Text(
          L10n.of(context).recordsEmpty,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: r.fontBodyLg, color: kInfoSecondaryText),
        ),
      ],
    );
  }

  Widget _selectionBar(BuildContext context) {
    final r = Responsive.of(context);
    final int count = _selectedKeys.length;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            r.pagePadding.left, r.spaceSm, r.pagePadding.right, r.spaceSm),
        child: SizedBox(
          height: r.iconXl * 1.4,
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: kInfoAccent,
              disabledBackgroundColor: const Color(0xFFE0E0E0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: count == 0 ? null : _deleteSelected,
            icon: const Icon(Icons.delete_outline),
            label: Text(
              L10n.of(context).recordsDeleteSelected(count),
              style: TextStyle(
                  fontSize: r.fontBodyLg, fontWeight: FontWeight.bold),
            ),
          ),
        ),
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
      record.cameraSettings.forEach((k, v) => meta(k, v.replaceAll(',', ' ')));

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
        // Čísla zpět jako čísla, ať je analýza nemusí převádět.
        'camera': {
          for (final e in record.cameraSettings.entries)
            e.key: _numberOrText(e.value),
        },
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
      record.cameraSettings.forEach((key, value) => sb.writeln('$key: $value'));
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

  static Object _numberOrText(String value) {
    final n = num.tryParse(value);
    return n != null && n.isFinite ? n : value;
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
      // Use saved HRV. JSON gives back an int for a whole number written
      // without a decimal point, and assigning that to a double throws, which
      // left the detail silently unopened.
      double saved(String key) {
        final Object? value = record.hrv[key];
        return value is num ? value.toDouble() : 0.0;
      }

      sdnn = saved('sdnn');
      rmssd = saved('rmssd');
      pnn50 = saved('pnn50');
      meanRR = saved('meanRR');
      sd1 = saved('sd1');
      sd2 = saved('sd2');
      sd2sd1 = saved('sd2sd1');
      lf = saved('lf');
      hf = saved('hf');
      lfhf = saved('lfhf');
      stressIndex = saved('stressIndex');
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

    Future<void> exportPdf(BuildContext context) async {
      // Resolve the PDF's text before the first await, so no BuildContext is
      // touched across an async gap.
      final pdfLabels = PdfLabels.of(L10n.of(context));
      final chartImageBytes = await _captureChart(chartKey);
      final hrvMetrics = {
        'SDNN': '${sdnn.toStringAsFixed(2)} ms',
        'RMSSD': '${rmssd.toStringAsFixed(2)} ms',
        'pNN50': '${pnn50.toStringAsFixed(2)} %',
        'Mean RR': '${meanRR.toStringAsFixed(2)} ms',
        'SD1': '${sd1.toStringAsFixed(2)} ms',
        'SD2': '${sd2.toStringAsFixed(2)} ms',
        'SD2/SD1': sd2sd1.toStringAsFixed(2),
        'LF': '${lf.toStringAsFixed(2)} %',
        'HF': '${hf.toStringAsFixed(2)} %',
        'LF/HF': lfhf.toStringAsFixed(2),
        'Stress Index': stressIndex.toStringAsFixed(2),
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
    }

    Future<void> exportTxt() async {
      final txtPath = await _createExport(record);
      if (txtPath != null) {
        await OpenFilex.open(txtPath);
      }
    }

    // A full page rather than a dialog: the detail is long, and the dialog
    // squeezed it between a title and three buttons.
    Navigator.of(context).push(MaterialPageRoute(builder: (context) {
      final r = Responsive.of(context);
      final L10n t = L10n.of(context);
      final DateTime when = _instantOf(record);
      final String? quality = _signalQualityOf(record);
      final String? qualityLabel = switch (quality) {
        'good' => t.qualityGood,
        'medium' => t.qualityMedium,
        'poor' => t.qualityBad,
        _ => null,
      };

      Widget section(String title, List<Widget> children) => InfoCard(
            padding: EdgeInsets.zero,
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                childrenPadding:
                    EdgeInsets.fromLTRB(r.spaceMd, 0, r.spaceMd, r.spaceMd),
                iconColor: kInfoAccent,
                collapsedIconColor: kInfoSecondaryText,
                title: Text(
                  title,
                  style: TextStyle(
                      fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                ),
                children: children,
              ),
            ),
          );

      Widget metricGrid(List<Widget> cards) => GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: cards,
          );

      return Scaffold(
        backgroundColor: _canvas,
        appBar: AppBar(
          backgroundColor: _canvas,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          centerTitle: true,
          title: Text(
            '${_formatShortDate(when)} · ${_formatTime(when)}',
            style:
                TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
          ),
          actions: [
            IconButton(
              tooltip: t.recordsDownloadPdf,
              icon: const Icon(FontAwesomeIcons.filePdf,
                  size: 20, color: kInfoAccent),
              onPressed: () => exportPdf(context),
            ),
            IconButton(
              tooltip: t.recordsExportTxt,
              icon: const Icon(FontAwesomeIcons.fileLines, size: 20),
              onPressed: exportTxt,
            ),
          ],
        ),
        // Not a ListView: that would stop building the chart once it scrolls
        // out of view, and the PDF export captures it from the screen.
        body: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
              r.pagePadding.left, r.spaceSm, r.pagePadding.right, r.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InfoCard(
                child: Column(
                  children: [
                    Text(
                      t.summaryAverageHeartRate
                          .replaceAll(RegExp(r':\s*$'), ''),
                      style: TextStyle(
                          fontSize: r.fontBody, color: kInfoSecondaryText),
                    ),
                    Text.rich(TextSpan(children: [
                      TextSpan(
                        text: '${calculatedAverageBPM.toInt()}',
                        style: TextStyle(
                            fontSize: r.fontDisplayXl,
                            fontWeight: FontWeight.bold),
                      ),
                      TextSpan(
                        text: ' ${t.homeBpmUnit}',
                        style: TextStyle(
                            fontSize: r.fontBodyLg, color: kInfoSecondaryText),
                      ),
                    ])),
                    Text(
                      [
                        t.homeSecondsSuffix(record.duration),
                        if (qualityLabel != null)
                          t.a11ySignalQuality(qualityLabel),
                      ].join(' · '),
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText),
                    ),
                    SizedBox(height: r.spaceLg),
                    _bpmScale(context, calculatedAverageBPM),
                  ],
                ),
              ),
              if (record.notesContent.trim().isNotEmpty) ...[
                SizedBox(height: r.spaceMd),
                InfoCard(
                  child: Text(
                    record.notesContent,
                    style: TextStyle(fontSize: r.fontBody, height: 1.4),
                  ),
                ),
              ],
              SizedBox(height: r.spaceMd),
              InfoCard(
                padding: EdgeInsets.fromLTRB(
                    r.spaceMd, r.spaceMd, r.spaceMd, r.spaceSm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.measurePulseWave,
                      style: TextStyle(
                          fontSize: r.fontCaption, color: kInfoSecondaryText),
                    ),
                    SizedBox(height: r.spaceXs),
                    if (smoothedData.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: r.spaceXl),
                        child: Center(
                          child: Text(
                            t.recordsNoWaveform,
                            style: TextStyle(
                                fontSize: r.fontBody,
                                color: kInfoSecondaryText),
                          ),
                        ),
                      )
                    else
                      SizedBox(
                        height: 150,
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
                                          right: true,
                                          top: true,
                                          bottom: true,
                                        ),
                                        gridData: const FlGridData(show: false),
                                        titlesData:
                                            const FlTitlesData(show: false),
                                        borderData: FlBorderData(show: false),
                                        minX: minX,
                                        maxX: maxX,
                                        minY: minY,
                                        maxY: maxY,
                                        lineBarsData: [
                                          LineChartBarData(
                                            spots: smoothedData,
                                            isCurved: false,
                                            color: kInfoAccent,
                                            barWidth: 2.0,
                                            isStrokeCapRound: true,
                                            dotData:
                                                const FlDotData(show: false),
                                            belowBarData:
                                                BarAreaData(show: false),
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
                                                color: const Color(0xFF1A73E8),
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
                                          color: Colors.black
                                              .withValues(alpha: 0.08),
                                        ),
                                      );
                                    }),
                                    ...labels.map((label) {
                                      final posX = ((label.x - minX) /
                                              (maxX - minX + 1e-6)) *
                                          chartWidth;
                                      return Positioned(
                                        left: posX,
                                        bottom: 0,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 4),
                                          child: Text(
                                            label.time,
                                            style: const TextStyle(
                                                fontSize: 10,
                                                color: Colors.black45),
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
              ),
              SizedBox(height: r.spaceMd),
              section(t.metricsHrvAnalysis, [
                metricGrid([
                  _buildHRVCard(
                      t.metricsRespiratoryRate,
                      t.metricsBreathsPerMinute(
                          record.respiratoryRate.toStringAsFixed(1))),
                  _buildHRVCard('SDNN', '${sdnn.toStringAsFixed(2)} ms'),
                  _buildHRVCard('RMSSD', '${rmssd.toStringAsFixed(2)} ms'),
                  _buildHRVCard('pNN50', '${pnn50.toStringAsFixed(2)} %'),
                  _buildHRVCard(
                      t.metricsAverageRr, '${meanRR.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD1', '${sd1.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD2', '${sd2.toStringAsFixed(2)} ms'),
                  _buildHRVCard('SD2/SD1', sd2sd1.toStringAsFixed(2)),
                  _buildHRVCard('LF', '${lf.toStringAsFixed(2)} %'),
                  _buildHRVCard('HF', '${hf.toStringAsFixed(2)} %'),
                  _buildHRVCard('LF/HF', lfhf.toStringAsFixed(2)),
                  _buildHRVCard(
                    t.metricsStressIndex,
                    stressIndex.toStringAsFixed(2),
                    valueColor: _getStressColor(stressIndex),
                  ),
                ]),
              ]),
              SizedBox(height: r.spaceMd),
              section(t.metricsHeartRateRecovery, [
                Text(
                  t.metricsRecoveryIntro,
                  style:
                      TextStyle(fontSize: r.fontSmall, color: Colors.black54),
                ),
                SizedBox(height: r.spaceSm),
                _buildRecordRecoveryChart(record),
                SizedBox(height: r.spaceSm),
                metricGrid([
                  _buildHRVCard(
                      t.metricHr0,
                      (record.hrr['hr0'] ?? 0.0) > 0
                          ? '${(record.hrr['hr0'] ?? 0.0).toStringAsFixed(1)} bpm'
                          : '—'),
                  _buildHRVCard(
                      t.metricHr60,
                      (record.hrr['hr60'] ?? 0.0) > 0
                          ? '${(record.hrr['hr60'] ?? 0.0).toStringAsFixed(1)} bpm'
                          : '—'),
                  _buildHRVCard(
                      t.metricHrr60,
                      (record.hrr['hrr60'] ?? 0.0) > 0
                          ? '${(record.hrr['hrr60'] ?? 0.0).toStringAsFixed(1)} bpm'
                          : '—'),
                  _buildHRVCard(t.metricSlope60,
                      '${(record.hrr['slope60_bpmPerMin'] ?? 0.0).toStringAsFixed(1)} bpm/min'),
                  _buildHRVCard(
                      t.metricHr120,
                      (record.hrr['hr120'] ?? 0.0) > 0
                          ? '${(record.hrr['hr120'] ?? 0.0).toStringAsFixed(1)} bpm'
                          : '—'),
                  _buildHRVCard(
                      t.metricHrr120,
                      (record.hrr['hrr120'] ?? 0.0) > 0
                          ? '${(record.hrr['hrr120'] ?? 0.0).toStringAsFixed(1)} bpm'
                          : '—'),
                  _buildHRVCard(
                      t.metricTau,
                      (record.hrr['tauSec'] ?? 0.0) > 0
                          ? '${(record.hrr['tauSec'] ?? 0.0).toStringAsFixed(1)} s'
                          : '—'),
                ]),
              ]),
            ],
          ),
        ),
      );
    }));
  }

  /// Where the reading falls between 30 and 220 bpm. The marker is placed
  /// from the bar's real width; it used to use the screen width, which put it
  /// in the wrong spot inside the old dialog.
  Widget _bpmScale(BuildContext context, double bpm) {
    final r = Responsive.of(context);
    const double lo = 30;
    const double hi = 220;
    final double fraction = ((bpm.clamp(lo, hi) - lo) / (hi - lo)).toDouble();
    TextStyle labelStyle() =>
        TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText);
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, constraints) {
        final double width = constraints.maxWidth;
        const double marker = 6;
        final double x =
            (fraction * width).clamp(marker / 2, width - marker / 2);
        return Column(
          children: [
            SizedBox(
              height: 12,
              width: width,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.red,
                            Colors.orange,
                            Colors.green,
                            Colors.orange,
                            Colors.red,
                          ],
                          stops: [0.0, 0.11, 0.20, 0.55, 0.75],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x - marker / 2,
                    top: -4,
                    bottom: -4,
                    child: Container(
                      width: marker,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black87, width: 1.5),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: r.spaceXs + 2),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${lo.toInt()}', style: labelStyle()),
                Text('${hi.toInt()}', style: labelStyle()),
              ],
            ),
          ],
        );
      }),
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

  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final TextStyle titleStyle =
        TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600);
    if (_selectionMode) {
      return AppBar(
        backgroundColor: _canvas,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          icon: const Icon(Icons.close),
          onPressed: () => setState(() {
            _selectionMode = false;
            _selectedKeys.clear();
          }),
        ),
        title: Text(t.recordsSelectedCount(_selectedKeys.length),
            style: titleStyle),
      );
    }
    return AppBar(
      backgroundColor: _canvas,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      title: Text(t.recordsTitle, style: titleStyle),
      actions: [
        IconButton(
          tooltip: t.recordsSearch,
          icon: Icon(_searchOpen ? Icons.search_off : Icons.search),
          onPressed: _toggleSearch,
        ),
        IconButton(
          tooltip: t.recordsFilters,
          onPressed: _openFilterSheet,
          icon: Badge(
            isLabelVisible: _filtersActive,
            backgroundColor: kInfoAccent,
            smallSize: 8,
            child: const Icon(Icons.tune),
          ),
        ),
        PopupMenuButton<String>(
          tooltip: t.recordsMore,
          color: Colors.white,
          icon: const Icon(Icons.more_vert),
          onSelected: (_) => setState(() {
            _selectionMode = true;
            _selectedKeys.clear();
          }),
          itemBuilder: (context) => [
            PopupMenuItem(
                value: 'select', child: Text(t.recordsSelectMultiple)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Scaffold(
      backgroundColor: _canvas,
      appBar: _buildAppBar(context),
      body: RefreshIndicator.adaptive(
        onRefresh: _loadRecords,
        color: kInfoAccent,
        backgroundColor: Colors.white,
        child: _records.isEmpty
            ? _emptyState(context)
            : ListView(
                padding: EdgeInsets.fromLTRB(r.pagePadding.left, r.spaceSm,
                    r.pagePadding.right, r.spaceXl),
                children: [
                  if (_searchOpen) ...[
                    _searchField(context),
                    SizedBox(height: r.spaceMd),
                  ],
                  _buildSummaryCard(),
                  if (_visible.isEmpty)
                    _noMatch(context)
                  else
                    ..._buildRecordGroups(context),
                ],
              ),
      ),
      bottomNavigationBar: _selectionMode
          ? _selectionBar(context)
          : GNav(
              // A new key after returning resets the bar, which otherwise
              // keeps showing the tab that was used to leave.
              key: ValueKey(_navResets),
              tabMargin: EdgeInsets.symmetric(horizontal: r.spaceSm),
              gap: 0,
              activeColor: Colors.black,
              iconSize: r.iconMd,
              backgroundColor: Colors.white,
              color: Colors.grey,
              selectedIndex: -1,
              onTabChange: _onItemTapped,
              tabs: [
                GButton(icon: Symbols.family_home, text: t.navMenu),
                GButton(icon: Symbols.ecg_heart, text: t.navMeasure),
                GButton(icon: Symbols.help, text: t.navInfo),
              ],
            ),
    );
  }

  @override
  void dispose() {
    _chartScrollController.dispose();
    _searchController.dispose();
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
