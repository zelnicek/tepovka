import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// One colour per settings card, so every row of a topic carries the same
/// badge and a glance finds the section. Controls (switches, segments,
/// sliders, buttons) stay in the app's red everywhere.
abstract final class SettingsTint {
  static const Color measurement = kInfoAccent;
  static const Color display = Color(0xFF1A73E8);
  static const Color sound = Color(0xFFE8710A);
  static const Color data = Color(0xFF1E8E3E);
  static const Color research = Color(0xFF7B3FE4);
  static const Color profile = Color(0xFF00838F);
  static const Color support = kInfoSecondaryText;
}

/// A white rounded card of settings rows, separated by hairlines that start
/// under the text, as in the iOS Settings app. [tint] colours the badges of
/// all rows inside.
class SettingsCard extends StatelessWidget {
  const SettingsCard({
    super.key,
    this.tint = SettingsTint.support,
    this.outlined = false,
    required this.children,
  });

  final Color tint;

  /// A hairline around the card, for when it sits on white (in a sheet).
  final bool outlined;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return _CardTint(
      tint: tint,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: outlined
              ? const BorderSide(color: Color(0xFFE6E6E6))
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (int i = 0; i < children.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: r.spaceLg + SettingsBadge.size(r) + r.spaceMd,
                  color: const Color(0xFFE6E6E6),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _CardTint extends InheritedWidget {
  const _CardTint({required this.tint, required super.child});

  final Color tint;

  static Color of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_CardTint>()?.tint ??
      SettingsTint.support;

  @override
  bool updateShouldNotify(_CardTint oldWidget) => tint != oldWidget.tint;
}

/// The rounded square in front of a row: a glyph on a light wash of [tint],
/// or an app icon such as Apple Health's, full size with a hairline so its
/// white face does not melt into the card.
class SettingsBadge extends StatelessWidget {
  const SettingsBadge(
      {super.key, this.icon, this.image, this.tint = SettingsTint.support});

  final IconData? icon;
  final String? image;
  final Color tint;

  static double size(Responsive r) => r.iconXl * 0.85;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final double badge = size(r);
    final BorderRadius radius = BorderRadius.circular(badge * 0.28);
    if (image != null) {
      return Container(
        width: badge,
        height: badge,
        foregroundDecoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: const Color(0xFFE6E6E6)),
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Image.asset(image!, fit: BoxFit.cover),
        ),
      );
    }
    return Container(
      width: badge,
      height: badge,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        borderRadius: radius,
      ),
      child: Icon(icon, size: r.iconSm + 2, color: tint),
    );
  }
}

/// One settings row: a badge, title and optional subtitle, and on the right
/// a value, a control or a chevron.
///
/// The same rules hold on every settings screen: a chevron means the row
/// opens something (a page, a sheet, a picker); a switch toggles in place;
/// [destructive] rows act at once and are red.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    this.icon,
    this.image,
    this.tint,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.chevron = false,
    this.destructive = false,
    this.onTap,
    this.below,
  });

  final IconData? icon;

  /// Asset shown instead of [icon], e.g. the Apple Health logo.
  final String? image;

  /// Badge colour; the card's colour when null.
  final Color? tint;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool chevron;
  final bool destructive;
  final VoidCallback? onTap;

  /// Full-width content under the row, such as a slider.
  final Widget? below;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final Color badgeTint =
        destructive ? kInfoAccent : (tint ?? _CardTint.of(context));
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
                  SettingsBadge(icon: icon, image: image, tint: badgeTint),
                  SizedBox(width: r.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: r.fontBodyLg,
                            color: destructive ? kInfoAccent : Colors.black,
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
                  padding: EdgeInsets.only(
                      left: SettingsBadge.size(r) + r.spaceMd, top: r.spaceSm),
                  child: below,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A text field laid out like a [SettingsRow], for forms inside a card.
class SettingsField extends StatelessWidget {
  const SettingsField({
    super.key,
    required this.icon,
    required this.controller,
    required this.label,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.textInputAction,
  });

  final IconData icon;
  final TextEditingController controller;
  final String label;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscureText;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: r.spaceLg, vertical: r.spaceXs),
      child: Row(
        children: [
          SettingsBadge(icon: icon, tint: _CardTint.of(context)),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              obscureText: obscureText,
              textInputAction: textInputAction,
              style: TextStyle(fontSize: r.fontBodyLg),
              decoration: InputDecoration(
                border: InputBorder.none,
                labelText: label,
                labelStyle: TextStyle(color: kInfoSecondaryText),
                floatingLabelStyle: TextStyle(color: kInfoSecondaryText),
                hintText: hint,
                hintStyle:
                    TextStyle(fontSize: r.fontBody, color: Colors.black38),
              ),
            ),
          ),
        ],
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

/// Red slider between two glyphs. Its track starts where the row text does
/// and ends where the row values do, like the segments above it.
class SettingsSlider extends StatelessWidget {
  const SettingsSlider({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.divisions,
    this.label,
    required this.onChanged,
    this.start,
    this.end,
  });

  final double value;
  final double min;
  final double max;
  final int? divisions;
  final String? label;
  final ValueChanged<double> onChanged;
  final Widget? start;
  final Widget? end;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Row(
      children: [
        if (start != null) start!,
        Expanded(
          child: SliderTheme(
            data: SliderThemeData(
              // The default pads by the 24 pt touch halo on each side, which
              // pushed the track in from everything else in the card.
              padding: EdgeInsets.symmetric(
                  horizontal: r.spaceMd, vertical: r.spaceSm),
              trackHeight: 4,
              activeTrackColor: kInfoAccent,
              inactiveTrackColor: const Color(0xFFE6E6E6),
              thumbColor: kInfoAccent,
              activeTickMarkColor: Colors.white70,
              inactiveTickMarkColor: Colors.black26,
              overlayColor: kInfoAccent.withValues(alpha: 0.12),
              valueIndicatorColor: kInfoAccent,
            ),
            child: Slider(
              min: min,
              max: max,
              divisions: divisions,
              label: label,
              value: value,
              onChanged: onChanged,
            ),
          ),
        ),
        if (end != null) end!,
      ],
    );
  }
}

/// Full-width red button that ends a sheet or a form.
class SettingsPrimaryButton extends StatelessWidget {
  const SettingsPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return SizedBox(
      width: double.infinity,
      height: r.iconXl * 1.4,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: kInfoAccent,
          disabledBackgroundColor: kInfoAccent.withValues(alpha: 0.4),
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: busy ? null : onPressed,
        child: busy
            ? SizedBox(
                width: r.iconMd,
                height: r.iconMd,
                child: const CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: r.iconMd),
                    SizedBox(width: r.spaceSm),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: r.fontBodyLg, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// The body every settings sheet shares: a title (with an optional leading
/// image), then [children]. Lifts itself above the keyboard.
class SettingsSheet extends StatelessWidget {
  const SettingsSheet({
    super.key,
    required this.title,
    this.leading,
    required this.children,
  });

  final String title;
  final Widget? leading;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(r.spaceXl, 0, r.spaceXl,
            r.spaceLg + MediaQuery.viewInsetsOf(context).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: r.spaceMd),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        fontSize: r.fontTitle, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: r.spaceMd),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Opens [builder] as a white sheet with a drag handle, the look of every
/// picker in the app.
Future<T?> showSettingsSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.white,
    showDragHandle: true,
    // Lets a sheet with a text field rise above the keyboard.
    isScrollControlled: true,
    builder: builder,
  );
}

/// A sheet listing [options]; returns the tapped one, or null when dismissed.
Future<T?> showSettingsChoice<T>(
  BuildContext context, {
  required String title,
  required List<(T, String)> options,
  required T selected,
}) {
  return showSettingsSheet<T>(
    context,
    builder: (context) {
      final r = Responsive.of(context);
      return SettingsSheet(
        title: title,
        children: [
          for (int i = 0; i < options.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: Color(0xFFE6E6E6)),
            Semantics(
              selected: options[i].$1 == selected,
              inMutuallyExclusiveGroup: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => Navigator.pop(context, options[i].$1),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: r.iconXl * 1.35),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          options[i].$2,
                          style: TextStyle(
                            fontSize: r.fontBodyLg,
                            fontWeight: options[i].$1 == selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      if (options[i].$1 == selected)
                        Icon(Icons.check_rounded,
                            color: kInfoAccent, size: r.iconMd),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      );
    },
  );
}

/// A time-of-day wheel in a sheet, with a Done button.
Future<TimeOfDay?> showSettingsTimePicker(
  BuildContext context, {
  required String title,
  required String doneLabel,
  required TimeOfDay initial,
}) {
  TimeOfDay value = initial;
  return showSettingsSheet<TimeOfDay>(
    context,
    builder: (context) {
      final r = Responsive.of(context);
      return SettingsSheet(
        title: title,
        children: [
          SizedBox(
            height: r.iconXl * 5,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: MediaQuery.alwaysUse24HourFormatOf(context),
              initialDateTime:
                  DateTime(2000, 1, 1, initial.hour, initial.minute),
              onDateTimeChanged: (d) => value = TimeOfDay.fromDateTime(d),
            ),
          ),
          SizedBox(height: r.spaceLg),
          SettingsPrimaryButton(
            label: doneLabel,
            onPressed: () => Navigator.pop(context, value),
          ),
        ],
      );
    },
  );
}
