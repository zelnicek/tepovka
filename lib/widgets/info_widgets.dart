import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// Building blocks shared by the "How it works" and "About" pages, so the two
/// stay visually consistent: white rounded cards on the app's grey canvas,
/// with red kept for actions and the heart.
const Color kInfoAccent = Color(0xFFE53935);
const Color kInfoAccentTint = Color(0xFFFDECEA);
const Color kInfoSecondaryText = Color(0xFF6E6D6D);

/// Asks before an action that cannot be undone, the action in red. Every
/// such action in the app goes through here, so they all ask the same way.
/// Returns whether to go ahead.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String body,
  required String confirmLabel,
}) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: Colors.white,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          style: TextButton.styleFrom(foregroundColor: Colors.black87),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: Text(L10n.of(dialogContext).commonCancel),
        ),
        TextButton(
          style: TextButton.styleFrom(foregroundColor: kInfoAccent),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// White rounded card. Tappable when [onTap] is set.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.child,
    this.onTap,
    this.color = Colors.white,
    this.padding,
  });

  final Widget child;
  final VoidCallback? onTap;
  final Color color;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final BorderRadius radius = BorderRadius.circular(16);
    return Material(
      color: color,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: padding ?? EdgeInsets.all(r.spaceLg),
          child: child,
        ),
      ),
    );
  }
}

/// Small grey label that introduces a group of cards.
class InfoSectionLabel extends StatelessWidget {
  const InfoSectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(r.spaceXs, r.spaceXl, r.spaceXs, r.spaceSm),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: TextStyle(
            fontSize: r.fontBody,
            fontWeight: FontWeight.w600,
            color: kInfoSecondaryText,
          ),
        ),
      ),
    );
  }
}

/// A card of collapsible sections: titles stay visible, the long text opens
/// on demand. Keeps every word of the original page reachable without making
/// readers who only need the basics scroll past it.
class InfoDetailsCard extends StatelessWidget {
  const InfoDetailsCard({super.key, required this.items});

  /// (title, body) pairs, shown in order.
  final List<(String, String)> items;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return InfoCard(
      padding: EdgeInsets.symmetric(vertical: r.spaceXs),
      child: Theme(
        // ExpansionTile draws its own dividers when open; inside a card they
        // read as stray lines.
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: Column(
          children: [
            for (int i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: r.spaceLg,
                  endIndent: r.spaceLg,
                  color: const Color(0xFFE6E6E6),
                ),
              ExpansionTile(
                tilePadding: EdgeInsets.symmetric(horizontal: r.spaceLg),
                childrenPadding:
                    EdgeInsets.fromLTRB(r.spaceLg, 0, r.spaceLg, r.spaceLg),
                expandedAlignment: Alignment.centerLeft,
                iconColor: kInfoAccent,
                collapsedIconColor: kInfoSecondaryText,
                title: Text(
                  items[i].$1,
                  style: TextStyle(
                    fontSize: r.fontBodyLg,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                children: [
                  Text(
                    items[i].$2,
                    style: TextStyle(
                      fontSize: r.fontBody,
                      height: 1.45,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
