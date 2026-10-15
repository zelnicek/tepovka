import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/home.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/pages/about.dart';
import 'package:tepovka/pages/info_app.dart';
import 'package:tepovka/pages/measure_guide.dart';
import 'package:tepovka/pages/records.dart';
import 'package:tepovka/pages/settings.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// Home screen.
///
/// Measuring is why the app gets opened, so it is the one dominant action.
/// Below it the last measurement and a short trend come straight from local
/// storage, so a result is visible without opening the history.
class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  int _selectedIndex = 0;

  /// Stored measurements, oldest first. Empty until loaded.
  List<Record> _records = const [];

  /// Bars shown in the trend strip.
  static const int _trendLength = 7;

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    try {
      final List<Map<String, dynamic>> raw =
          await StorageService().readSummary();
      final List<Record> records = raw.map(Record.fromJson).toList()
        ..sort((a, b) => _instantOf(a).compareTo(_instantOf(b)));
      if (!mounted) return;
      setState(() => _records = records);
    } catch (e) {
      // The home screen still works without the card; history shows the
      // details if storage is readable there.
      debugPrint('Could not load records for the home screen: $e');
    }
  }

  /// When the measurement was taken. Older records carry only date and time.
  static DateTime _instantOf(Record r) {
    final DateTime? started =
        r.startedAt.isNotEmpty ? DateTime.tryParse(r.startedAt) : null;
    return started ??
        DateTime.tryParse('${r.date} ${r.time}') ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  /// Opens [page] and refreshes the card on return, since a measurement or a
  /// deletion may have changed what is stored.
  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    if (mounted) _loadRecords();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0:
        _open(const IntroPage());
        break;
      case 1:
        _open(const Home());
        break;
      case 2:
        _open(const About());
        break;
    }
  }

  String _formatWhen(BuildContext context, DateTime when) {
    final L10n t = L10n.of(context);
    final String locale = Localizations.localeOf(context).toString();
    String time;
    String day;
    try {
      time = DateFormat.jm(locale).format(when);
      day = DateFormat.MMMd(locale).format(when);
    } catch (_) {
      time = '${when.hour}:${when.minute.toString().padLeft(2, '0')}';
      day = '${when.day}. ${when.month}.';
    }
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    final DateTime thatDay = DateTime(when.year, when.month, when.day);
    final int daysAgo = today.difference(thatDay).inDays;
    if (daysAgo == 0) return t.homeToday(time);
    if (daysAgo == 1) return t.homeYesterday(time);
    return '$day $time';
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleSpacing: r.spaceLg,
        toolbarHeight: r.iconXl * 1.8,
        // The app icon up top; the wordmark sits at the foot of the page.
        title: Semantics(
          label: 'Tepovka',
          image: true,
          excludeSemantics: true,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r.spaceMd),
            child: Image.asset(
              'assets/tepovka_icon.png',
              height: r.iconXl * 1.25,
              width: r.iconXl * 1.25,
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: t.a11yOpenSettings,
            icon: Icon(Symbols.settings, size: r.iconMd),
            onPressed: () => _open(const SettingsPage()),
          ),
          SizedBox(width: r.spaceSm),
        ],
      ),
      body: SafeArea(
        // Fills the screen so the wordmark can sit at the bottom when there is
        // room, and simply scrolls with everything else when there is not
        // (senior mode, small phones).
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: r.pagePadding,
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _measureCard(context),
                    InfoSectionLabel(t.homeLastMeasurement),
                    _records.isEmpty
                        ? _emptyCard(context)
                        : _lastMeasurementCard(context),
                    SizedBox(height: r.spaceMd),
                    Row(
                      children: [
                        _tile(context, Icons.history, const Color(0xFF1A73E8),
                            t.homeTileHistory, const RecordsPage()),
                        SizedBox(width: r.spaceSm),
                        _tile(
                            context,
                            Icons.help_outline,
                            const Color(0xFF1E8E3E),
                            t.homeTileHowItWorks,
                            const About()),
                        SizedBox(width: r.spaceSm),
                        _tile(context, Icons.info_outline, kInfoSecondaryText,
                            t.homeTileAbout, const InfoApp()),
                      ],
                    ),
                    SizedBox(height: r.spaceXl),
                    const Spacer(),
                    Center(
                      child: Semantics(
                        label: 'Tepovka, powered by VUT',
                        image: true,
                        excludeSemantics: true,
                        child: Image.asset(
                          'assets/Text_loading.png',
                          width: (r.width * 0.42).clamp(140.0, 200.0),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    SizedBox(height: r.spaceMd),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: GNav(
        tabMargin: EdgeInsets.symmetric(horizontal: r.spaceSm),
        gap: r.spaceSm,
        activeColor: Colors.black,
        iconSize: r.iconMd,
        haptic: true,
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
    );
  }

  Widget _measureCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Material(
      color: kInfoAccent,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          _open(const Home());
        },
        child: Padding(
          padding: EdgeInsets.all(r.spaceLg + r.spaceXs),
          child: Row(
            children: [
              Container(
                width: r.iconXl * 1.5,
                height: r.iconXl * 1.5,
                decoration: const BoxDecoration(
                    color: Colors.white, shape: BoxShape.circle),
                child: Icon(Icons.favorite, color: kInfoAccent, size: r.iconLg),
              ),
              SizedBox(width: r.spaceMd + r.spaceXs),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.homeMeasureTitle,
                      style: TextStyle(
                          fontSize: r.fontHeadline,
                          fontWeight: FontWeight.bold,
                          color: Colors.white),
                    ),
                    SizedBox(height: r.spaceXs / 2),
                    Text(
                      t.homeMeasureSubtitle,
                      style: TextStyle(
                          fontSize: r.fontBody, color: const Color(0xFFFFE3E1)),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.white, size: r.iconLg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lastMeasurementCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final Record last = _records.last;
    final List<Record> recent = _records
        .sublist(max(0, _records.length - _trendLength))
        .where((rec) => rec.averageBPM > 0)
        .toList();

    return InfoCard(
      onTap: () => _open(const RecordsPage()),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label:
                '${t.a11yHeartRateValue('${last.averageBPM}')}, ${_formatWhen(context, _instantOf(last))}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '${last.averageBPM}',
                      style: TextStyle(
                          fontSize: r.fontDisplayXl,
                          fontWeight: FontWeight.bold,
                          height: 1.0),
                    ),
                    SizedBox(width: r.spaceXs),
                    Text(t.homeBpmUnit,
                        style: TextStyle(
                            fontSize: r.fontBodyLg, color: kInfoSecondaryText)),
                  ],
                ),
                SizedBox(height: r.spaceXs),
                Text(
                  '${_formatWhen(context, _instantOf(last))} · ${last.duration} s',
                  style: TextStyle(
                      fontSize: r.fontSmall, color: kInfoSecondaryText),
                ),
              ],
            ),
          ),
          if (recent.length >= 2) ...[
            SizedBox(height: r.spaceMd),
            _trend(context, recent),
            SizedBox(height: r.spaceSm),
            Text(
              t.homeTrendCaption(
                recent.length,
                (recent.map((e) => e.averageBPM).reduce((a, b) => a + b) /
                        recent.length)
                    .round()
                    .toString(),
              ),
              style: TextStyle(fontSize: r.fontCaption, color: Colors.black45),
            ),
          ],
        ],
      ),
    );
  }

  /// Bars scaled between the lowest and highest value shown, so a change of a
  /// few bpm is still visible. The newest bar is red.
  Widget _trend(BuildContext context, List<Record> recent) {
    final r = Responsive.of(context);
    final List<int> bpms = recent.map((e) => e.averageBPM).toList();
    final int lo = bpms.reduce(min);
    final int hi = bpms.reduce(max);
    final double barArea = r.iconXl * 1.25;
    return ExcludeSemantics(
      child: SizedBox(
        height: barArea,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (int i = 0; i < bpms.length; i++) ...[
              if (i > 0) SizedBox(width: r.spaceXs + 2),
              Expanded(
                child: Container(
                  height: hi == lo
                      ? barArea * 0.6
                      : barArea * (0.3 + 0.7 * (bpms[i] - lo) / (hi - lo)),
                  decoration: BoxDecoration(
                    color: i == bpms.length - 1
                        ? kInfoAccent
                        : const Color(0xFFF6C9C6),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _emptyCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return InfoCard(
      onTap: () => MeasureGuide.open(context),
      padding: EdgeInsets.symmetric(horizontal: r.spaceLg, vertical: r.spaceXl),
      child: Column(
        children: [
          Icon(Symbols.ecg_heart, size: r.iconXl, color: Colors.black26),
          SizedBox(height: r.spaceSm),
          Text(
            t.homeNoMeasurementsTitle,
            style:
                TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: r.spaceXs),
          Text(
            t.homeNoMeasurementsBody,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: r.fontBody, height: 1.4, color: kInfoSecondaryText),
          ),
          SizedBox(height: r.spaceMd),
          Text(
            t.homeOpenGuide,
            style: TextStyle(
                fontSize: r.fontBody,
                fontWeight: FontWeight.w600,
                color: kInfoAccent),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, IconData icon, Color color, String label,
      Widget page) {
    final r = Responsive.of(context);
    return Expanded(
      child: InfoCard(
        onTap: () => _open(page),
        padding:
            EdgeInsets.symmetric(vertical: r.spaceMd, horizontal: r.spaceXs),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Column(
            children: [
              Icon(icon, size: r.iconLg, color: color),
              SizedBox(height: r.spaceXs),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(fontSize: r.fontSmall, height: 1.25),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
