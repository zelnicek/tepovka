import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/home.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/heart_rate_recovery.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// The recovery test step by step: exercise, then measure two minutes
/// straight away. Below, the earlier tests and how the drop in the first
/// minute has changed.
class RecoveryTestPage extends StatefulWidget {
  const RecoveryTestPage({super.key});

  @override
  State<RecoveryTestPage> createState() => _RecoveryTestPageState();
}

/// One saved test: when, and how far the heart rate fell.
class _Test {
  const _Test(this.at, this.drop60, this.drop120);
  final DateTime at;
  final double drop60;
  final double drop120;
}

class _RecoveryTestPageState extends State<RecoveryTestPage> {
  List<_Test> _tests = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final List<Map<String, dynamic>> records;
    try {
      records = await StorageService().readSummary();
    } catch (e) {
      debugPrint('Recovery tests could not be read: $e');
      return;
    }
    double asDouble(Object? v) => v is num ? v.toDouble() : 0;
    final List<_Test> tests = [];
    for (final Map<String, dynamic> r in records) {
      if (r['protocol'] != kRecoveryProtocol) continue;
      final DateTime? at = DateTime.tryParse('${r['startedAt'] ?? ''}') ??
          DateTime.tryParse('${r['date']} ${r['time']}');
      final Object? hrr = r['hrr'];
      if (at == null || hrr is! Map) continue;
      tests.add(_Test(at, asDouble(hrr['hrr60']), asDouble(hrr['hrr120'])));
    }
    tests.sort((a, b) => b.at.compareTo(a.at));
    if (mounted) setState(() => _tests = tests);
  }

  Future<void> _start() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => const Home(recoveryTest: true)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(t.recoveryTestTitle,
            style:
                TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600)),
      ),
      body: ListView(
        padding: r.pagePadding.copyWith(top: r.spaceSm, bottom: r.spaceXl),
        children: [
          Text(t.recoveryIntro,
              style: TextStyle(fontSize: r.fontBody, color: Colors.black87)),
          SizedBox(height: r.spaceMd),
          InfoCard(
            child: Column(
              children: [
                for (final (int i, String step) in [
                  t.recoveryStep1,
                  t.recoveryStep2,
                  t.recoveryStep3,
                ].indexed) ...[
                  if (i > 0) SizedBox(height: r.spaceMd),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: r.iconSm * 0.65,
                        backgroundColor: kInfoAccentTint,
                        child: Text('${i + 1}',
                            style: TextStyle(
                                fontSize: r.fontSmall,
                                fontWeight: FontWeight.bold,
                                color: kInfoAccent)),
                      ),
                      SizedBox(width: r.spaceMd),
                      Expanded(
                        child:
                            Text(step, style: TextStyle(fontSize: r.fontBody)),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          SizedBox(height: r.spaceMd),
          Container(
            padding: EdgeInsets.all(r.spaceMd),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: r.iconSm, color: const Color(0xFF8A5300)),
                SizedBox(width: r.spaceSm),
                Expanded(
                  child: Text(t.recoverySafety,
                      style: TextStyle(
                          fontSize: r.fontSmall,
                          color: const Color(0xFF8A5300))),
                ),
              ],
            ),
          ),
          SizedBox(height: r.spaceLg),
          SizedBox(
            height: r.iconXl * 1.4,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: kInfoAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _start,
              child: Text(t.recoveryStart,
                  style: TextStyle(
                      fontSize: r.fontBodyLg,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
            ),
          ),
          InfoSectionLabel(t.recoveryMyTests),
          if (_tests.isEmpty)
            InfoCard(
              child: Text(t.recoveryNoTests,
                  style: TextStyle(
                      fontSize: r.fontSmall, color: kInfoSecondaryText)),
            )
          else ...[
            if (_tests.length >= 2) ...[
              _trend(context),
              SizedBox(height: r.spaceMd),
            ],
            InfoCard(
              padding: EdgeInsets.symmetric(
                  horizontal: r.spaceLg, vertical: r.spaceSm),
              child: Column(
                children: [
                  for (final (int i, _Test test) in _tests.indexed) ...[
                    if (i > 0) const Divider(height: 1),
                    _row(context, test),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, _Test test) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final String locale = Localizations.localeOf(context).toString();
    String date;
    try {
      date = DateFormat.yMMMd(locale).add_Hm().format(test.at);
    } catch (_) {
      date = '${test.at.day}. ${test.at.month}. ${test.at.year}';
    }
    String drop(double v) => v > 0 ? '−${v.round()}' : '—';
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceSm),
      child: Row(
        children: [
          Expanded(child: Text(date, style: TextStyle(fontSize: r.fontBody))),
          Text('${drop(test.drop60)} ${t.recoveryAfter1Min}',
              style: TextStyle(
                  fontSize: r.fontSmall, fontWeight: FontWeight.w600)),
          SizedBox(width: r.spaceMd),
          Text('${drop(test.drop120)} ${t.recoveryAfter2Min}',
              style:
                  TextStyle(fontSize: r.fontSmall, color: kInfoSecondaryText)),
        ],
      ),
    );
  }

  /// The drop in the first minute over the tests, oldest on the left.
  Widget _trend(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final List<_Test> oldestFirst = _tests.reversed.toList();
    final List<FlSpot> spots = [
      for (final (int i, _Test test) in oldestFirst.indexed)
        if (test.drop60 > 0) FlSpot(i.toDouble(), test.drop60)
    ];
    if (spots.length < 2) return const SizedBox.shrink();
    // A round top, so the labels fall on tens and do not crowd.
    final double top =
        (spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) / 10).ceil() *
            10.0;
    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.recoveryTrendTitle,
              style:
                  TextStyle(fontSize: r.fontBody, fontWeight: FontWeight.w600)),
          SizedBox(height: r.spaceMd),
          SizedBox(
            height: 120,
            child: LineChart(LineChartData(
              minX: 0,
              maxX: (oldestFirst.length - 1).toDouble(),
              minY: 0,
              maxY: top,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 32,
                    interval: 10,
                    getTitlesWidget: (v, meta) => Text('${v.round()}',
                        style: TextStyle(
                            fontSize: r.fontCaption,
                            color: kInfoSecondaryText)),
                  ),
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  color: kInfoAccent,
                  barWidth: 2.5,
                  dotData: const FlDotData(show: true),
                ),
              ],
            )),
          ),
        ],
      ),
    );
  }
}
