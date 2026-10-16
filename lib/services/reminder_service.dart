import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/achievements.dart';
import 'package:tepovka/services/app_locale.dart';
import 'package:tepovka/services/storage_service.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:timezone/data/latest_10y.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Daily measurement reminder, as local notifications only.
///
/// Instead of one repeating notification, the coming [_days] days are planned
/// as separate notifications. That is what allows skipping a day once a
/// measurement has been taken; a repeating trigger fires regardless. The plan
/// is redrawn at every start, after every measurement and whenever the
/// setting changes, so it keeps reaching a month ahead while the app is used.
///
/// Times are scheduled in the device's own time zone. Handing iOS the same
/// instant in UTC does not work: its calendar trigger reads the hour and minute
/// as local time and ignores the zone, so a 22:15 reminder was set for 20:15.
class ReminderService {
  ReminderService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static Future<void>? _ready;

  /// Reminder ids are [_firstId] to [_firstId] + [_days] - 1.
  static const int _firstId = 7100;
  static const int _days = 30;

  /// Bumped when a reminder is tapped while the app is running, so the home
  /// screen can open the measurement.
  static final ValueNotifier<int> openMeasureRequests = ValueNotifier<int>(0);

  static bool _launchedFromReminder = false;

  /// Whether the app was started by tapping a reminder. Answers true once.
  static bool takeLaunchRequest() {
    final bool launched = _launchedFromReminder;
    _launchedFromReminder = false;
    return launched;
  }

  /// Serialises rescheduling: a start-up and a finished measurement can ask at
  /// the same moment, and interleaved cancel/schedule calls would mix plans.
  static Future<void> _queue = Future<void>.value();

  static Future<void> init() => _ready ??= _initialize();

  static Future<void> _initialize() async {
    tz_data.initializeTimeZones();
    // A saved measurement changes the streak the next reminder talks about.
    StorageService.revision.addListener(() => unawaited(reschedule()));
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          // Permission is asked when the reminder is switched on, with the
          // reason on screen, not as a surprise at start-up.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestSoundPermission: false,
            requestBadgePermission: false,
          ),
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
        onDidReceiveNotificationResponse: (_) => openMeasureRequests.value++,
      );
      final NotificationAppLaunchDetails? launch =
          await _plugin.getNotificationAppLaunchDetails();
      _launchedFromReminder = launch?.didNotificationLaunchApp ?? false;
    } catch (e) {
      debugPrint('Reminder setup failed: $e');
    }
  }

  /// Asks the system for permission to notify. False when refused now or
  /// earlier; iOS then only lets the user change it in Settings.
  static Future<bool> requestPermission() async {
    await init();
    try {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        return await ios.requestPermissions(alert: true, sound: true) ?? false;
      }
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        return await android.requestNotificationsPermission() ?? false;
      }
    } catch (e) {
      debugPrint('Reminder permission request failed: $e');
    }
    return false;
  }

  /// Opens the app's notification settings, the only place to undo a refusal.
  static Future<void> openSystemSettings() async {
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  /// Redraws the plan from the current settings.
  static Future<void> reschedule() =>
      _queue = _queue.then((_) => _reschedule()).catchError((Object e) {
        debugPrint('Reminder scheduling failed: $e');
      });

  /// Points the time-zone library at the device's zone. Re-read on every
  /// reschedule, so a trip across zones is picked up at the next start.
  static Future<void> _useDeviceTimeZone() async {
    try {
      final TimezoneInfo zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (e) {
      debugPrint('Could not read the device time zone: $e');
    }
  }

  static Future<void> _reschedule() async {
    await init();
    await _useDeviceTimeZone();
    for (int i = 0; i < _days; i++) {
      await _plugin.cancel(id: _firstId + i);
    }

    final AppSettingsData settings = AppSettings.value;
    if (!settings.reminderEnabled) return;

    final L10n t = lookupL10n(appLocale(settings));
    final DateTime? last = await _lastMeasurement();
    final List<DateTime> plan = planFor(
      now: DateTime.now(),
      minutes: settings.reminderMinutes,
      lastMeasurement: last,
    );

    // The next reminder mentions the streak when there is one to keep: today
    // after a measurement yesterday, or tomorrow after one today.
    final HeartStats stats = HeartStats.of(
      StatReading.fromStored(await StorageService().readSummary()),
      now: DateTime.now(),
    );
    final DateTime today = dayOf(DateTime.now());
    final DateTime streakDay = stats.measuredToday
        ? DateTime(today.year, today.month, today.day + 1)
        : today;
    bool keepsStreak(DateTime at) =>
        stats.currentStreak >= 2 && dayOf(at) == streakDay;

    final NotificationDetails details = NotificationDetails(
      // No banner while the app is open: the user is already in it.
      iOS: const DarwinNotificationDetails(
        presentAlert: false,
        presentBanner: false,
        presentList: false,
        presentSound: false,
      ),
      android: AndroidNotificationDetails(
        'measurement_reminder',
        t.settingsReminder,
      ),
    );

    for (int i = 0; i < plan.length; i++) {
      await _plugin.zonedSchedule(
        id: _firstId + i,
        title: t.reminderTitle,
        body: i == 0 && keepsStreak(plan[i])
            ? t.reminderStreakBody(stats.currentStreak)
            : t.reminderBody,
        scheduledDate: tz.TZDateTime(tz.local, plan[i].year, plan[i].month,
            plan[i].day, plan[i].hour, plan[i].minute),
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: 'measure',
      );
    }
  }

  /// When to remind: [minutes] after midnight on each of the next [days]
  /// days, leaving out times already past and today when a measurement was
  /// taken today.
  @visibleForTesting
  static List<DateTime> planFor({
    required DateTime now,
    required int minutes,
    DateTime? lastMeasurement,
    int days = _days,
  }) {
    final bool measuredToday = lastMeasurement != null &&
        lastMeasurement.year == now.year &&
        lastMeasurement.month == now.month &&
        lastMeasurement.day == now.day;
    return [
      for (int i = 0; i < days; i++)
        // DateTime rolls day overflow into the next month and applies the
        // daylight-saving offset of that particular day.
        DateTime(now.year, now.month, now.day + i, minutes ~/ 60, minutes % 60),
    ]
        .where((at) => at.isAfter(now))
        .where((at) => !(measuredToday &&
            at.day == now.day &&
            at.month == now.month &&
            at.year == now.year))
        .toList();
  }

  /// Written by the measure screen when a measurement finishes.
  static Future<DateTime?> _lastMeasurement() async {
    final prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString('last_measurement_time');
    return raw == null ? null : DateTime.tryParse(raw);
  }
}
