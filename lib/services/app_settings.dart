import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserMode { patient, doctor }

class AppSettingsData {
  final bool seniorMode;
  final bool highContrast;
  final double textScale; // 1.0 = default, 1.2/1.3 = larger
  final UserMode userMode;

  const AppSettingsData({
    this.seniorMode = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.userMode = UserMode.doctor,
  });

  AppSettingsData copyWith({
    bool? seniorMode,
    bool? highContrast,
    double? textScale,
    UserMode? userMode,
  }) =>
      AppSettingsData(
        seniorMode: seniorMode ?? this.seniorMode,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
        userMode: userMode ?? this.userMode,
      );
}

class AppSettings {
  static final ValueNotifier<AppSettingsData> notifier =
      ValueNotifier<AppSettingsData>(const AppSettingsData());

  static AppSettingsData get value => notifier.value;

  static const _kSeniorMode = 'settings_seniorMode';
  static const _kHighContrast = 'settings_highContrast';
  static const _kTextScale = 'settings_textScale';
  static const _kUserMode = 'settings_userMode'; // 0=patient, 1=doctor

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final senior = prefs.getBool(_kSeniorMode) ?? false;
    final contrast = prefs.getBool(_kHighContrast) ?? false;
    final scale = prefs.getDouble(_kTextScale) ?? 1.0;
    final modeIndex = prefs.getInt(_kUserMode) ?? 1;
    final mode = modeIndex == 0 ? UserMode.patient : UserMode.doctor;
    notifier.value = AppSettingsData(
      seniorMode: senior,
      highContrast: contrast,
      textScale: scale,
      userMode: mode,
    );
  }

  static void setSeniorMode(bool enabled) {
    notifier.value = notifier.value.copyWith(seniorMode: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kSeniorMode, enabled),
    );
  }

  static void setHighContrast(bool enabled) {
    notifier.value = notifier.value.copyWith(highContrast: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kHighContrast, enabled),
    );
  }

  static void setTextScale(double scale) {
    notifier.value = notifier.value.copyWith(textScale: scale);
    SharedPreferences.getInstance().then(
      (p) => p.setDouble(_kTextScale, scale),
    );
  }

  static void setUserMode(UserMode mode) {
    notifier.value = notifier.value.copyWith(userMode: mode);
    final index = mode == UserMode.patient ? 0 : 1;
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_kUserMode, index),
    );
  }
}
