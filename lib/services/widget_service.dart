import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/app_locale.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/services/reminder_service.dart';
import 'package:tepovka/services/storage_service.dart';

/// Keeps the home-screen widget in step with the history, and opens the
/// measurement when the widget is tapped. The native side is WidgetChannel
/// in ios/Runner/AppDelegate.swift; the widget itself is ios/TepovkaWidget.
class WidgetService {
  WidgetService._();

  static const MethodChannel _channel = MethodChannel('tepovka/widget');

  /// How many of the latest readings the widget draws as bars.
  static const int recentCount = 7;

  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      // Tapped while the app was running: same path as a reminder tap.
      if (call.method == 'openMeasure') {
        ReminderService.openMeasureRequests.value++;
      }
    });
    // Saving or deleting a record bumps the revision; a language change
    // shows up as a settings change.
    StorageService.revision.addListener(_refresh);
    AppSettings.notifier.addListener(_refresh);
    await _refresh();
  }

  /// Whether the app was started by tapping the widget. Asked once by the
  /// home screen when it first appears; true only the first time.
  static Future<bool> takeLaunchRequest() async {
    try {
      return await _channel.invokeMethod<bool>('takeLaunchAction') ?? false;
    } on MissingPluginException {
      return false; // Android, tests
    } catch (e) {
      debugPrint('Widget launch check failed: $e');
      return false;
    }
  }

  static Future<void> _refresh() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final List<Map<String, dynamic>> records =
          await StorageService().readSummary();
      final locale = appLocale(AppSettings.value);
      await _channel.invokeMethod<void>(
        'update',
        jsonEncode(payload(records, lookupL10n(locale), locale.languageCode)),
      );
    } on MissingPluginException {
      // No widget channel on this platform.
    } catch (e) {
      debugPrint('Widget update failed: $e');
    }
  }

  /// What the widget shows, from the stored records in any order: the
  /// latest reading with a heart rate, the ones before it and the labels in
  /// the app's language (which may differ from the phone's). Readings of
  /// 0 bpm are left out, as on the home screen's trend.
  @visibleForTesting
  static Map<String, Object?> payload(
    List<Map<String, dynamic>> records,
    L10n t,
    String locale,
  ) {
    DateTime? instantOf(Map<String, dynamic> r) =>
        DateTime.tryParse('${r['startedAt'] ?? ''}') ??
        DateTime.tryParse('${r['date']} ${r['time']}');
    int bpmOf(Map<String, dynamic> r) =>
        r['averageBPM'] is num ? (r['averageBPM'] as num).round() : 0;

    final List<(DateTime, Map<String, dynamic>)> readings = [
      for (final Map<String, dynamic> r in records)
        if (bpmOf(r) > 0 && instantOf(r) != null) (instantOf(r)!, r),
    ]..sort((a, b) => a.$1.compareTo(b.$1));
    final (DateTime, Map<String, dynamic>)? last =
        readings.isEmpty ? null : readings.last;
    final Object? quality = last?.$2['signalQuality'];
    return {
      'bpm': last == null ? null : bpmOf(last.$2),
      'atMs': last?.$1.millisecondsSinceEpoch.toDouble(),
      'quality': quality is Map ? quality['level'] : null,
      'recent': [
        for (final (_, Map<String, dynamic> r)
            in readings.skip(max(0, readings.length - recentCount)))
          bpmOf(r),
      ],
      'locale': locale,
      'labels': {
        'title': t.homeLastMeasurement,
        'empty': t.homeNoMeasurementsTitle,
        'measure': t.homeMeasureTitle,
        'unit': t.homeBpmUnit,
        'today': t.recordsToday,
      },
    };
  }
}
