import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserMode { patient, doctor }

class AppSettingsData {
  final bool seniorMode;
  final bool highContrast;
  final double textScale; // 1.0 = default, 1.2/1.3 = larger
  final UserMode userMode;
  final bool haptics; // NEW: Haptická odezva
  final bool saveRecords; // NEW: Ukládání záznamů
  final bool seniorModeOnboardingShown; // NEW: Onboarding flag

  const AppSettingsData({
    this.seniorMode = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.userMode = UserMode.doctor,
    this.haptics = true,
    this.saveRecords = true,
    this.seniorModeOnboardingShown = false,
  });

  AppSettingsData copyWith({
    bool? seniorMode,
    bool? highContrast,
    double? textScale,
    UserMode? userMode,
    bool? haptics,
    bool? saveRecords,
    bool? seniorModeOnboardingShown,
  }) =>
      AppSettingsData(
        seniorMode: seniorMode ?? this.seniorMode,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
        userMode: userMode ?? this.userMode,
        haptics: haptics ?? this.haptics,
        saveRecords: saveRecords ?? this.saveRecords,
        seniorModeOnboardingShown:
            seniorModeOnboardingShown ?? this.seniorModeOnboardingShown,
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
  static const _kHaptics = 'settings_haptics'; // NEW
  static const _kSaveRecords = 'settings_saveRecords'; // NEW
  static const _kSeniorModeOnboardingShown = 'settings_seniorOnboarding'; // NEW

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final senior = prefs.getBool(_kSeniorMode) ?? false;
    final contrast = prefs.getBool(_kHighContrast) ?? false;
    final scale = prefs.getDouble(_kTextScale) ?? 1.0;
    final modeIndex = prefs.getInt(_kUserMode) ?? 1;
    final mode = modeIndex == 0 ? UserMode.patient : UserMode.doctor;
    final haptics = prefs.getBool(_kHaptics) ?? true; // NEW
    final saveRecords = prefs.getBool(_kSaveRecords) ?? true; // NEW
    final onboardingShown =
        prefs.getBool(_kSeniorModeOnboardingShown) ?? false; // NEW
    notifier.value = AppSettingsData(
      seniorMode: senior,
      highContrast: contrast,
      textScale: scale,
      userMode: mode,
      haptics: haptics,
      saveRecords: saveRecords,
      seniorModeOnboardingShown: onboardingShown,
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

  static void setHaptics(bool enabled) {
    notifier.value = notifier.value.copyWith(haptics: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kHaptics, enabled),
    );
  }

  static void setSaveRecords(bool enabled) {
    notifier.value = notifier.value.copyWith(saveRecords: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kSaveRecords, enabled),
    );
  }

  static void setOnboardingShown(bool shown) {
    notifier.value = notifier.value.copyWith(seniorModeOnboardingShown: shown);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kSeniorModeOnboardingShown, shown),
    );
  }
}
