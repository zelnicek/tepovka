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
import 'package:tepovka/services/reminder_service.dart';
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
    ReminderService.openMeasureRequests.addListener(_openMeasureFromReminder);
    if (ReminderService.takeLaunchRequest()) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _openMeasureFromReminder());
    }
  }

  @override
  void dispose() {
    ReminderService.openMeasureRequests
        .removeListener(_openMeasureFromReminder);
    super.dispose();
  }

  bool _openingMeasureFromReminder = false;

  /// A tapped reminder opens the measurement straight away. This screen is
  /// the root route, so whatever was open on top of it is closed first.
  Future<void> _openMeasureFromReminder() async {
    if (!mounted || _openingMeasureFromReminder) return;
    _openingMeasureFromReminder = true;
    Navigator.of(context).popUntil((route) => route.isFirst);
    await _open(const Home());
    _openingMeasureFromReminder = false;
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

  Future<void> _onItemTapped(int index) async {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        await _open(const Home());
        break;
      case 2:
        await _open(const About());
        break;
    }
    // Back on this screen: the bar must point at it again, not at the tab
    // that was tapped to leave.
    if (mounted) setState(() => _selectedIndex = 0);
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

    // assets/Text_loading.png is 1029 × 419 px.
    final double wordmarkWidth = (r.width * 0.27).clamp(96.0, 130.0);

    // No app bar: the header scrolls with the page, so it can grow with the
    // text size instead of being clipped by a fixed toolbar height.
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: r.pagePadding.copyWith(top: r.spaceSm, bottom: 0),
                sliver: SliverList.list(
                  children: [
                    _header(context),
                    SizedBox(height: r.spaceLg),
                    _measureCard(context),
                    InfoSectionLabel(t.homeLastMeasurement),
                    _records.isEmpty
                        ? _emptyCard(context)
                        : _lastMeasurementCard(context),
                    InfoSectionLabel(t.homeSectionMore),
                    _menuCard(context),
                  ],
                ),
              ),
              // Only the footer fills the leftover space, so the wordmark sits
              // at the bottom when there is room and simply follows the
              // content when there is not (senior mode, small phones).
              SliverFillRemaining(
                hasScrollBody: false,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(height: r.spaceLg),
                    // A quiet signature rather than a second headline.
                    Semantics(
                      label: 'Tepovka, powered by VUT',
                      image: true,
                      excludeSemantics: true,
                      // Explicit height: the fill sliver measures its child's
                      // intrinsic height, and an image with only a width
                      // reports the height it would have at full screen
                      // width, which made the page scroll for no reason.
                      child: SizedBox(
                        width: wordmarkWidth,
                        height: wordmarkWidth * 419 / 1029,
                        child: Opacity(
                          opacity: 0.5,
                          child: Image.asset(
                            'assets/Text_loading.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: r.spaceSm),
                  ],
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
      ),
    );
  }

  /// App icon with the name written out and today's date, settings on the
  /// right.
  Widget _header(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final double iconSize = r.iconXl * 1.6;
    return Padding(
      padding: EdgeInsets.only(top: r.spaceXs),
      child: Row(
        children: [
          ExcludeSemantics(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(iconSize * 0.24),
              child: Image.asset(
                'assets/tepovka_icon.png',
                height: iconSize,
                width: iconSize,
              ),
            ),
          ),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Tepovka',
                    style: TextStyle(
                      fontSize: r.fontHeadline * 1.2,
                      fontWeight: FontWeight.bold,
                      height: 1.1,
                    ),
                  ),
                ),
                SizedBox(height: r.spaceXs / 2),
                Text(
                  _today(context),
                  style: TextStyle(
                      fontSize: r.fontBody, color: kInfoSecondaryText),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: t.a11yOpenSettings,
            icon: Icon(Symbols.settings, size: r.iconLg),
            onPressed: () => _open(const SettingsPage()),
          ),
        ],
      ),
    );
  }

  /// "Thursday, October 15" in the app language, first letter capitalised
  /// (Czech writes weekdays in lower case).
  String _today(BuildContext context) {
    final String locale = Localizations.localeOf(context).toString();
    final DateTime now = DateTime.now();
    String text;
    try {
      text = DateFormat.MMMMEEEEd(locale).format(now);
    } catch (_) {
      text = '${now.day}. ${now.month}. ${now.year}';
    }
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
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
          padding: EdgeInsets.all(r.spaceLg),
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
    final double barArea = r.iconXl;
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

  /// The secondary destinations as one list card: a row each, with a line
  /// saying what is behind it.
  Widget _menuCard(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final rows = <Widget>[
      _menuRow(context, Icons.history, const Color(0xFF1A73E8),
          t.homeTileHistory, t.homeTileHistoryHint, const RecordsPage()),
      _menuRow(context, Icons.help_outline, const Color(0xFF1E8E3E),
          t.homeTileHowItWorks, t.homeTileHowItWorksHint, const About()),
      _menuRow(context, Icons.info_outline, kInfoSecondaryText, t.homeTileAbout,
          t.homeTileAboutHint, const InfoApp()),
    ];
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < rows.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                // Starts under the text, as in iOS lists.
                indent: r.spaceLg + r.iconXl * 1.1 + r.spaceMd,
                color: const Color(0xFFE6E6E6),
              ),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _menuRow(BuildContext context, IconData icon, Color color,
      String title, String hint, Widget page) {
    final r = Responsive.of(context);
    final double badge = r.iconXl * 1.1;
    return Semantics(
      button: true,
      label: '$title, $hint',
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _open(page),
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.spaceLg, vertical: r.spaceSm + 2),
          child: Row(
            children: [
              Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(badge * 0.28),
                ),
                child: Icon(icon, size: r.iconMd, color: color),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                          fontSize: r.fontBodyLg, fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: r.spaceXs / 2),
                    Text(
                      hint,
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black26, size: r.iconMd),
            ],
          ),
        ),
      ),
    );
  }
}
