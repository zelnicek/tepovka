import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/widgets/settings_widgets.dart';
import 'package:tepovka/services/local_logger.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// Measurement counters and the local log. Only needed when something goes
/// wrong, so it lives one level below Settings instead of at its bottom.
class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});

  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);

  int _measurementsCount = 0;
  String _lastMeasurement = '-';

  @override
  void initState() {
    super.initState();
    _loadLocalStats();
  }

  Future<void> _loadLocalStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _measurementsCount = prefs.getInt('measurements_count') ?? 0;
        _lastMeasurement = prefs.getString('last_measurement_time') ?? '-';
      });
    } catch (e) {
      debugPrint('Failed to load local stats: $e');
    }
  }

  /// The stored ISO timestamp as a date and time in the app language.
  String _formatLastMeasurement(BuildContext context) {
    final DateTime? when = DateTime.tryParse(_lastMeasurement);
    if (when == null) return _lastMeasurement;
    final String locale = Localizations.localeOf(context).toString();
    try {
      return '${DateFormat.yMMMd(locale).format(when)} '
          '${DateFormat.jm(locale).format(when)}';
    } catch (_) {
      return _lastMeasurement;
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _openLog() async {
    try {
      final path = await LocalLogger.getLogFilePath();
      if (path != null && await File(path).exists()) {
        await OpenFilex.open(path);
      } else {
        if (!mounted) return;
        _snack(L10n.of(context).settingsLogNotFound);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(L10n.of(context).settingsLogOpenError('$e'));
    }
  }

  Future<void> _shareLog() async {
    try {
      final path = await LocalLogger.getLogFilePath();
      if (path != null && await File(path).exists()) {
        await SharePlus.instance
            .share(ShareParams(files: [XFile(path)], text: 'Tepovka logs'));
      } else {
        if (!mounted) return;
        _snack(L10n.of(context).settingsLogNotFound);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(L10n.of(context).settingsLogShareError('$e'));
    }
  }

  Future<void> _clearLog() async {
    try {
      final path = await LocalLogger.getLogFilePath();
      if (path != null && await File(path).exists()) {
        await File(path).delete();
        await LocalLogger.init(); // recreate
        if (!mounted) return;
        _snack(L10n.of(context).settingsLogCleared);
      } else {
        if (!mounted) return;
        _snack(L10n.of(context).settingsLogNotFound);
      }
    } catch (e) {
      if (!mounted) return;
      _snack(L10n.of(context).settingsLogDeleteError('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          t.settingsDiagnostics,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            r.pagePadding.left, 0, r.pagePadding.right, r.spaceXl),
        children: [
          InfoSectionLabel(t.settingsLogSection),
          SettingsCard(children: [
            SettingsRow(
              icon: Icons.insights,
              tint: kInfoSecondaryText,
              title: t.settingsLocalCount,
              value: '$_measurementsCount',
            ),
            SettingsRow(
              icon: Icons.access_time,
              tint: kInfoSecondaryText,
              title: t.settingsLastMeasurement,
              value: _formatLastMeasurement(context),
            ),
          ]),
          SizedBox(height: r.spaceLg),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.open_in_new,
              tint: kInfoSecondaryText,
              title: t.settingsOpenLog,
              chevron: true,
              onTap: _openLog,
            ),
            SettingsRow(
              icon: Symbols.share,
              tint: kInfoSecondaryText,
              title: t.settingsShareLog,
              chevron: true,
              onTap: _shareLog,
            ),
            SettingsRow(
              icon: Symbols.delete,
              tint: kInfoAccent,
              title: t.settingsClearLog,
              titleColor: kInfoAccent,
              onTap: _clearLog,
            ),
          ]),
        ],
      ),
    );
  }
}
