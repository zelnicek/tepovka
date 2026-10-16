import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/achievements.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// The last year as a grid of days, a column per week from Monday to
/// Sunday, each day shaded by its resting heart rate: pale for the lowest
/// days, deep red for the highest. Opens on today; scrolls back through the
/// year. Tapping a day says what it was.
class YearHeatmap extends StatefulWidget {
  const YearHeatmap({super.key, required this.days, required this.now});

  final Map<DateTime, ({int? bpm, int count})> days;
  final DateTime now;

  static const int weeks = 53;

  @override
  State<YearHeatmap> createState() => _YearHeatmapState();
}

class _YearHeatmapState extends State<YearHeatmap> {
  static const double _cell = 12;
  static const double _gap = 3;
  static const double _step = _cell + _gap;

  static const Color _empty = Color(0xFFEEEEEE);

  /// Measured, but only after exercise, coffee or stress.
  static const Color _notResting = Color(0xFFC9C9C9);
  static const List<Color> _shades = [
    Color(0xFFF9D7D4),
    Color(0xFFF2A49E),
    Color(0xFFEA6B63),
    kInfoAccent,
  ];

  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final String locale = Localizations.localeOf(context).toString();
    final DateTime today = dayOf(widget.now);
    final DateTime thisMonday =
        DateTime(today.year, today.month, today.day - (today.weekday - 1));
    final DateTime firstMonday = DateTime(thisMonday.year, thisMonday.month,
        thisMonday.day - 7 * (YearHeatmap.weeks - 1));
    DateTime dayAt(int week, int weekday) => DateTime(firstMonday.year,
        firstMonday.month, firstMonday.day + week * 7 + weekday);

    final List<int> values = [
      for (final MapEntry<DateTime, ({int? bpm, int count})> e
          in widget.days.entries)
        if (e.value.bpm != null && !e.key.isBefore(firstMonday)) e.value.bpm!
    ];
    final int lo = values.isEmpty ? 0 : values.reduce((a, b) => a < b ? a : b);
    final int hi = values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b);
    Color colorOf(DateTime day) {
      final ({int? bpm, int count})? d = widget.days[day];
      if (d == null) return _empty;
      if (d.bpm == null) return _notResting;
      if (hi == lo) return _shades[1];
      final double share = (d.bpm! - lo) / (hi - lo);
      return _shades[
          (share * _shades.length).floor().clamp(0, _shades.length - 1)];
    }

    String dayText(DateTime day) {
      String date;
      try {
        date = DateFormat.MMMMEEEEd(locale).format(day);
      } catch (_) {
        date = '${day.day}. ${day.month}.';
      }
      // Czech writes weekdays in lower case; this one starts the sentence.
      if (date.isNotEmpty) date = date[0].toUpperCase() + date.substring(1);
      final ({int? bpm, int count})? d = widget.days[day];
      if (d == null) return t.recordsYearDayEmpty(date);
      if (d.bpm == null) return t.recordsYearDayNoRest(date);
      return t.recordsYearDay(date, d.bpm!, d.count);
    }

    String weekdayLabel(int weekday) {
      try {
        return DateFormat.E(locale).format(dayAt(0, weekday));
      } catch (_) {
        return '';
      }
    }

    String monthLabel(DateTime day) {
      try {
        return DateFormat.MMM(locale).format(day);
      } catch (_) {
        return '${day.month}.';
      }
    }

    final TextStyle small =
        TextStyle(fontSize: r.fontCaption, color: kInfoSecondaryText);
    const double monthRow = 16;

    return InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.recordsYearTitle,
              style: TextStyle(
                  fontSize: r.fontBodyLg, fontWeight: FontWeight.w600)),
          SizedBox(height: r.spaceMd),
          ExcludeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monday, Wednesday and Friday, as GitHub labels them.
                Padding(
                  padding: const EdgeInsets.only(top: monthRow),
                  child: Column(
                    children: [
                      for (int d = 0; d < 7; d++)
                        SizedBox(
                          height: _step,
                          child: d.isEven && d < 6
                              ? Text(weekdayLabel(d),
                                  style:
                                      small.copyWith(fontSize: 9, height: 1.3))
                              : null,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    // Starts at the right end, on this week.
                    reverse: true,
                    child: SizedBox(
                      width: YearHeatmap.weeks * _step,
                      height: monthRow + 7 * _step,
                      child: Stack(
                        children: [
                          for (int w = 0; w < YearHeatmap.weeks; w++)
                            if (w == 0 ||
                                dayAt(w, 0).month != dayAt(w - 1, 0).month)
                              Positioned(
                                left: w * _step,
                                top: 0,
                                child: Text(monthLabel(dayAt(w, 0)),
                                    style: small.copyWith(fontSize: 9)),
                              ),
                          for (int w = 0; w < YearHeatmap.weeks; w++)
                            for (int d = 0; d < 7; d++)
                              if (!dayAt(w, d).isAfter(today))
                                Positioned(
                                  left: w * _step,
                                  top: monthRow + d * _step,
                                  child: GestureDetector(
                                    onTap: () =>
                                        setState(() => _selected = dayAt(w, d)),
                                    child: Container(
                                      width: _cell,
                                      height: _cell,
                                      decoration: BoxDecoration(
                                        color: colorOf(dayAt(w, d)),
                                        borderRadius: BorderRadius.circular(3),
                                        border: dayAt(w, d) == _selected
                                            ? Border.all(
                                                color: Colors.black, width: 1.5)
                                            : dayAt(w, d) == today
                                                ? Border.all(
                                                    color: Colors.black38)
                                                : null,
                                      ),
                                    ),
                                  ),
                                ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: r.spaceMd),
          Row(
            children: [
              Expanded(
                child: Text(
                  _selected == null ? t.recordsYearHint : dayText(_selected!),
                  style: TextStyle(
                      fontSize: r.fontSmall,
                      color: _selected == null
                          ? kInfoSecondaryText
                          : Colors.black87),
                ),
              ),
              SizedBox(width: r.spaceSm),
              ExcludeSemantics(
                child: Row(
                  children: [
                    Text(t.recordsYearLow, style: small),
                    const SizedBox(width: 4),
                    for (final Color c in _shades)
                      Container(
                        width: 10,
                        height: 10,
                        margin: const EdgeInsets.symmetric(horizontal: 1.5),
                        decoration: BoxDecoration(
                            color: c, borderRadius: BorderRadius.circular(2)),
                      ),
                    const SizedBox(width: 4),
                    Text(t.recordsYearHigh, style: small),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: r.spaceSm),
          Text(t.recordsYearCaption,
              style: TextStyle(fontSize: r.fontCaption, color: Colors.black45)),
        ],
      ),
    );
  }
}
