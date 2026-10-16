import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/achievements.dart';
import 'package:tepovka/services/haptics.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/widgets/settings_widgets.dart';

/// Totals, streaks and every badge, collected or with how far there is to go.
class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  HeartStats? _stats;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final records = await StorageService().readSummary();
      if (!mounted) return;
      setState(() => _stats =
          HeartStats.of(StatReading.fromStored(records), now: DateTime.now()));
    } catch (e) {
      debugPrint('Could not load the badges: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final HeartStats? s = _stats;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(t.badgesTitle,
            style:
                TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600)),
      ),
      body: s == null
          ? const Center(child: CircularProgressIndicator(color: kInfoAccent))
          : ListView(
              padding: EdgeInsets.fromLTRB(r.pagePadding.left, r.spaceSm,
                  r.pagePadding.right, r.spaceXl),
              children: [
                Row(
                  children: [
                    _stat(context, '${s.measurements}', t.badgesTotal),
                    SizedBox(width: r.spaceSm),
                    _stat(
                        context, t.daysCount(s.currentStreak), t.badgesCurrent),
                    SizedBox(width: r.spaceSm),
                    _stat(context, t.daysCount(s.bestStreak), t.badgesBest),
                  ],
                ),
                SizedBox(height: r.spaceLg),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: r.spaceSm + 2,
                  crossAxisSpacing: r.spaceSm + 2,
                  childAspectRatio: 1.08,
                  children: [
                    for (final HeartBadge b in HeartBadge.values)
                      _BadgeTile(badge: b, stats: s),
                  ],
                ),
              ],
            ),
    );
  }

  Widget _stat(BuildContext context, String value, String label) {
    final r = Responsive.of(context);
    return Expanded(
      child: InfoCard(
        padding:
            EdgeInsets.symmetric(horizontal: r.spaceSm, vertical: r.spaceMd),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: TextStyle(
                      fontSize: r.fontTitleLg, fontWeight: FontWeight.bold)),
            ),
            SizedBox(height: r.spaceXs / 2),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: r.fontCaption, color: kInfoSecondaryText)),
          ],
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge, required this.stats});

  final HeartBadge badge;
  final HeartStats stats;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final bool unlocked = badge.unlockedIn(stats);
    final int progress = badge.progressIn(stats).clamp(0, badge.goal);
    return InfoCard(
      padding: EdgeInsets.all(r.spaceMd),
      child: Column(
        children: [
          BadgeMedal(badge: badge, unlocked: unlocked, size: r.iconXl * 1.5),
          SizedBox(height: r.spaceSm),
          Text(badge.title(t),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: r.fontBody,
                  fontWeight: FontWeight.w600,
                  color: unlocked ? Colors.black : kInfoSecondaryText)),
          SizedBox(height: r.spaceXs / 2),
          Expanded(
            child: Text(badge.description(t),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: r.fontCaption, color: kInfoSecondaryText)),
          ),
          if (unlocked)
            Text(t.badgeUnlocked,
                style: TextStyle(
                    fontSize: r.fontCaption,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1E8E3E)))
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress / badge.goal,
                minHeight: 5,
                color: kInfoAccent,
                backgroundColor: const Color(0xFFEDEDED),
              ),
            ),
            SizedBox(height: r.spaceXs),
            Text(t.badgeProgress(progress, badge.goal),
                style: TextStyle(
                    fontSize: r.fontCaption, color: kInfoSecondaryText)),
          ],
        ],
      ),
    );
  }
}

/// A badge as a round medal: red with a white glyph once collected, grey
/// while still to come.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.badge,
    required this.unlocked,
    required this.size,
  });

  final HeartBadge badge;
  final bool unlocked;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: unlocked
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF6F61), kInfoAccent],
              )
            : null,
        color: unlocked ? null : const Color(0xFFEDEDED),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: kInfoAccent.withValues(alpha: 0.35),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: Icon(badge.icon,
          fill: 1,
          size: size * 0.5,
          color: unlocked ? Colors.white : const Color(0xFFB0B0B0)),
    );
  }
}

/// Celebrates [badges] just collected: the newest one large, the others as
/// small medals under it, with a way to the full list.
Future<void> showBadgeCelebration(
    BuildContext context, List<HeartBadge> badges) {
  if (badges.isEmpty) return Future.value();
  final L10n t = L10n.of(context);
  Haptics.medium();
  final HeartBadge main = badges.last;
  return showSettingsSheet<void>(
    context,
    builder: (sheetContext) {
      final r = Responsive.of(sheetContext);
      return SettingsSheet(
        title: t.badgeNew,
        children: [
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1),
              duration: const Duration(milliseconds: 700),
              curve: Curves.elasticOut,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child:
                  BadgeMedal(badge: main, unlocked: true, size: r.iconXl * 2.6),
            ),
          ),
          SizedBox(height: r.spaceLg),
          Text(main.title(t),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: r.fontHeadline, fontWeight: FontWeight.bold)),
          SizedBox(height: r.spaceXs),
          Text(main.description(t),
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: r.fontBody, color: kInfoSecondaryText)),
          if (badges.length > 1) ...[
            SizedBox(height: r.spaceMd),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: r.spaceSm,
              children: [
                for (final HeartBadge b in badges.sublist(0, badges.length - 1))
                  Tooltip(
                    message: b.title(t),
                    child: BadgeMedal(badge: b, unlocked: true, size: r.iconXl),
                  ),
              ],
            ),
          ],
          SizedBox(height: r.spaceXl),
          SettingsPrimaryButton(
            label: t.badgeGreat,
            onPressed: () => Navigator.pop(sheetContext),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: kInfoAccent),
            onPressed: () {
              Navigator.pop(sheetContext);
              Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AchievementsPage()));
            },
            child: Text(t.badgeAll),
          ),
        ],
      );
    },
  );
}
