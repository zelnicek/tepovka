import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// A white rounded card of settings rows, separated by hairlines that start
/// under the text, as in the iOS Settings app.
class SettingsCard extends StatelessWidget {
  const SettingsCard({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (int i = 0; i < children.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: r.spaceLg + SettingsRow.badgeSize(r) + r.spaceMd,
                color: const Color(0xFFE6E6E6),
              ),
            children[i],
          ],
        ],
      ),
    );
  }
}

/// One settings row: a tinted icon badge, title and optional subtitle, and
/// on the right a value, a control or a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.image,
    this.tint = kInfoSecondaryText,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = false,
    this.onTap,
    this.below,
  });

  final IconData? icon;

  /// Asset shown instead of [icon], e.g. the Apple Health logo.
  final String? image;
  final Color tint;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final VoidCallback? onTap;

  /// Full-width content under the row, such as a slider.
  final Widget? below;

  static double badgeSize(Responsive r) => r.iconXl * 0.85;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final double badge = badgeSize(r);
    return MergeSemantics(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
              horizontal: r.spaceLg, vertical: r.spaceSm + 3),
          child: Column(
            children: [
              Row(
                children: [
                  SizedBox(
                    width: badge,
                    height: badge,
                    child: image != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(badge * 0.24),
                            child: Image.asset(image!, fit: BoxFit.cover),
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: tint.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(badge * 0.28),
                            ),
                            child: Icon(icon, size: r.iconSm + 2, color: tint),
                          ),
                  ),
                  SizedBox(width: r.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: r.fontBodyLg,
                            color: titleColor ?? Colors.black,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          SizedBox(height: r.spaceXs / 2),
                          Text(
                            subtitle!,
                            style: TextStyle(
                                fontSize: r.fontSmall,
                                color: kInfoSecondaryText),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (value != null) ...[
                    SizedBox(width: r.spaceSm),
                    Text(
                      value!,
                      style: TextStyle(
                          fontSize: r.fontBody, color: kInfoSecondaryText),
                    ),
                  ],
                  if (trailing != null) ...[
                    SizedBox(width: r.spaceSm),
                    trailing!,
                  ],
                  if (chevron) ...[
                    SizedBox(width: r.spaceXs),
                    Icon(Icons.chevron_right,
                        color: Colors.black26, size: r.iconMd),
                  ],
                ],
              ),
              if (below != null)
                Padding(
                  padding:
                      EdgeInsets.only(left: badge + r.spaceMd, top: r.spaceSm),
                  child: below,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// iOS-style switch in the app's red.
class SettingsSwitch extends StatelessWidget {
  const SettingsSwitch(
      {super.key, required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => CupertinoSwitch(
        value: value,
        onChanged: onChanged,
        activeTrackColor: kInfoAccent,
      );
}

/// Two or more options in one row, the selected one in red.
class SettingsSegments<T> extends StatelessWidget {
  const SettingsSegments({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final (T value, String label) in options)
            Expanded(
              child: Semantics(
                button: true,
                selected: value == selected,
                inMutuallyExclusiveGroup: true,
                label: label,
                excludeSemantics: true,
                child: Material(
                  color: value == selected ? kInfoAccent : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => onSelected(value),
                    child: SizedBox(
                      height: r.iconXl * 0.95,
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: r.fontBody,
                            fontWeight: FontWeight.w600,
                            color: value == selected
                                ? Colors.white
                                : Colors.black87,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
