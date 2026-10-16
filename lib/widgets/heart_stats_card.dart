import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/achievements.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// The home screen's "your heart" card: the measuring streak, and how many
/// times the heart has beaten today, counting up live at the resting rate.
/// Tapping it opens the badges.
class HeartStatsCard extends StatelessWidget {
  const HeartStatsCard({super.key, required this.stats, required this.onTap});

  final HeartStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final String hint = stats.measuredToday
        ? t.streakBest(stats.bestStreak)
        : stats.currentStreak > 0
            ? t.streakKeep
            : t.streakStart;
    final int? resting = stats.restingBpm;
    return InfoCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: r.iconXl,
                height: r.iconXl,
                decoration: BoxDecoration(
                  color: stats.currentStreak > 0
                      ? kInfoAccentTint
                      : const Color(0xFFF0F0F0),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Symbols.local_fire_department,
                  fill: 1,
                  size: r.iconMd,
                  color: stats.currentStreak > 0
                      ? kInfoAccent
                      : kInfoSecondaryText,
                ),
              ),
              SizedBox(width: r.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.streakDays(stats.currentStreak),
                        style: TextStyle(
                            fontSize: r.fontBodyLg,
                            fontWeight: FontWeight.w600)),
                    Text(hint,
                        style: TextStyle(
                            fontSize: r.fontSmall, color: kInfoSecondaryText)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.black26, size: r.iconMd),
            ],
          ),
          if (resting != null) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: r.spaceMd),
              child: const Divider(height: 1, color: Color(0xFFE6E6E6)),
            ),
            _BeatCounter(stats: stats, bpm: resting),
          ],
        ],
      ),
    );
  }
}

/// Today's heartbeats, counting up once per beat at [bpm], with the heart
/// giving a small throb each time.
class _BeatCounter extends StatefulWidget {
  const _BeatCounter({required this.stats, required this.bpm});

  final HeartStats stats;
  final int bpm;

  @override
  State<_BeatCounter> createState() => _BeatCounterState();
}

class _BeatCounterState extends State<_BeatCounter>
    with SingleTickerProviderStateMixin {
  late final AnimationController _throb = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 140),
  );
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void didUpdateWidget(_BeatCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bpm != widget.bpm) _start();
  }

  void _start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      Duration(milliseconds: (60000 / widget.bpm).round()),
      (_) {
        if (!mounted) return;
        // The number is always worked out from the clock, so it cannot drift.
        setState(() {});
        if (!MediaQuery.disableAnimationsOf(context)) {
          _throb.forward(from: 0).then((_) {
            if (mounted) _throb.reverse();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _throb.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final DateTime now = DateTime.now();
    final NumberFormat number =
        NumberFormat.decimalPattern(Localizations.localeOf(context).toString());
    final int today = widget.stats.beatsToday(now) ?? 0;
    final int? total = widget.stats.beatsSinceFirst(now);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: Tween<double>(begin: 1, end: 1.22).animate(
                  CurvedAnimation(parent: _throb, curve: Curves.easeOut)),
              child: Icon(Icons.favorite, color: kInfoAccent, size: r.iconLg),
            ),
            SizedBox(width: r.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.beatsTodayLabel,
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText)),
                  Text.rich(TextSpan(children: [
                    TextSpan(
                      text: number.format(today),
                      style: TextStyle(
                        fontSize: r.fontTitleLg,
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    TextSpan(
                      text: ' ${t.beatsUnit(today)}',
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText),
                    ),
                  ])),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: r.spaceSm),
        Text(
          [
            if (total != null) t.beatsSinceFirst(number.format(total)),
            t.beatsEstimate(widget.bpm),
          ].join(' · '),
          style: TextStyle(fontSize: r.fontCaption, color: Colors.black45),
        ),
      ],
    );
  }
}
