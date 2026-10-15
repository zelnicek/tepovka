import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum UserMode { patient, doctor }

/// Which language the UI renders in. [system] follows the device setting and
/// falls back to Czech for locales the app does not ship.
enum AppLanguage { system, czech, english }

extension AppLanguageX on AppLanguage {
  /// null means "let the platform decide".
  Locale? get locale => switch (this) {
        AppLanguage.system => null,
        AppLanguage.czech => const Locale('cs'),
        AppLanguage.english => const Locale('en'),
      };
}

/// Format, ve kterem vyzkumny rezim uklada zaznam.
enum ExportFormat {
  /// Puvodni textovy export s hlavickou a tabulkou.
  txt,

  /// CSV s metadaty v komentarove hlavicce - pro Excel a pandas.
  csv,

  /// Vsechno v jednom objektu vcetne vrcholu a metadat - pro skripty.
  json,
}

extension ExportFormatX on ExportFormat {
  String get extension => switch (this) {
        ExportFormat.txt => 'txt',
        ExportFormat.csv => 'csv',
        ExportFormat.json => 'json',
      };

  /// Untranslated fallback. UI code should prefer the localised labels; this
  /// exists for logs and other non-user-facing output.
  String get label => switch (this) {
        ExportFormat.txt => 'TXT',
        ExportFormat.csv => 'CSV (Excel, pandas)',
        ExportFormat.json => 'JSON',
      };
}

/// Polozky, ktere se ve vyzkumnem rezimu vyplnuji pred merenim.
///
/// Deliberately not localised: these are seed values the user can rename, and
/// they are persisted verbatim. Translating them would rename fields in
/// existing installs and break exports that key off the field name.
const List<String> kDefaultResearchFields = <String>[
  'ID probanda',
  'Protokol',
  'Poznámka',
];

class AppSettingsData {
  final bool seniorMode;
  final bool highContrast;
  final double textScale; // 1.0 = default, 1.2/1.3 = larger
  final UserMode userMode;
  final bool haptics; // NEW: Haptická odezva
  final bool saveRecords; // NEW: Ukládání záznamů

  /// Vyzkumny rezim: pred merenim se vyplni metadata, export je bohatsi
  /// a da se vybrat format souboru.
  final bool researchMode;
  final ExportFormat exportFormat;

  /// UI language. Defaults to following the device.
  final AppLanguage language;

  /// Nazvy poli, ktera se pred merenim vyplnuji. Uzivatel si je muze zmenit.
  final List<String> researchFields;

  /// Daily measurement reminder, and its time as minutes after midnight.
  final bool reminderEnabled;
  final int reminderMinutes;

  const AppSettingsData({
    this.seniorMode = false,
    this.highContrast = false,
    this.textScale = 1.0,
    this.userMode = UserMode.doctor,
    this.haptics = true,
    this.saveRecords = true,
    this.researchMode = false,
    this.exportFormat = ExportFormat.txt,
    this.researchFields = kDefaultResearchFields,
    this.language = AppLanguage.system,
    this.reminderEnabled = false,
    this.reminderMinutes = 8 * 60,
  });

  AppSettingsData copyWith({
    bool? seniorMode,
    bool? highContrast,
    double? textScale,
    UserMode? userMode,
    bool? haptics,
    bool? saveRecords,
    bool? researchMode,
    ExportFormat? exportFormat,
    List<String>? researchFields,
    AppLanguage? language,
    bool? reminderEnabled,
    int? reminderMinutes,
  }) =>
      AppSettingsData(
        seniorMode: seniorMode ?? this.seniorMode,
        highContrast: highContrast ?? this.highContrast,
        textScale: textScale ?? this.textScale,
        userMode: userMode ?? this.userMode,
        haptics: haptics ?? this.haptics,
        saveRecords: saveRecords ?? this.saveRecords,
        researchMode: researchMode ?? this.researchMode,
        exportFormat: exportFormat ?? this.exportFormat,
        researchFields: researchFields ?? this.researchFields,
        language: language ?? this.language,
        reminderEnabled: reminderEnabled ?? this.reminderEnabled,
        reminderMinutes: reminderMinutes ?? this.reminderMinutes,
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
  static const _kResearchMode = 'settings_researchMode';
  static const _kExportFormat = 'settings_exportFormat';
  static const _kResearchFields = 'settings_researchFields';
  static const _kLanguage = 'settings_language';
  static const _kReminderEnabled = 'settings_reminderEnabled';
  static const _kReminderMinutes = 'settings_reminderMinutes';

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final senior = prefs.getBool(_kSeniorMode) ?? false;
    final contrast = prefs.getBool(_kHighContrast) ?? false;
    final scale = prefs.getDouble(_kTextScale) ?? 1.0;
    final modeIndex = prefs.getInt(_kUserMode) ?? 1;
    final mode = modeIndex == 0 ? UserMode.patient : UserMode.doctor;
    final haptics = prefs.getBool(_kHaptics) ?? true; // NEW
    final saveRecords = prefs.getBool(_kSaveRecords) ?? true; // NEW
    final research = prefs.getBool(_kResearchMode) ?? false;
    final formatIndex = prefs.getInt(_kExportFormat) ?? 0;
    final fields = prefs.getStringList(_kResearchFields);
    final langIndex = prefs.getInt(_kLanguage) ?? 0;
    final reminderEnabled = prefs.getBool(_kReminderEnabled) ?? false;
    final reminderMinutes = prefs.getInt(_kReminderMinutes) ?? 8 * 60;
    notifier.value = AppSettingsData(
      seniorMode: senior,
      highContrast: contrast,
      textScale: scale,
      userMode: mode,
      haptics: haptics,
      saveRecords: saveRecords,
      researchMode: research,
      exportFormat: ExportFormat
          .values[formatIndex.clamp(0, ExportFormat.values.length - 1)],
      researchFields:
          (fields == null || fields.isEmpty) ? kDefaultResearchFields : fields,
      language:
          AppLanguage.values[langIndex.clamp(0, AppLanguage.values.length - 1)],
      reminderEnabled: reminderEnabled,
      reminderMinutes: reminderMinutes.clamp(0, 24 * 60 - 1),
    );
  }

  static void setLanguage(AppLanguage language) {
    notifier.value = notifier.value.copyWith(language: language);
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_kLanguage, language.index),
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

  static void setResearchMode(bool enabled) {
    notifier.value = notifier.value.copyWith(researchMode: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kResearchMode, enabled),
    );
  }

  static void setExportFormat(ExportFormat format) {
    notifier.value = notifier.value.copyWith(exportFormat: format);
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_kExportFormat, format.index),
    );
  }

  static void setResearchFields(List<String> fields) {
    final cleaned = fields
        .map((f) => f.trim())
        .where((f) => f.isNotEmpty)
        .toList(growable: false);
    notifier.value = notifier.value.copyWith(
      researchFields: cleaned.isEmpty ? kDefaultResearchFields : cleaned,
    );
    SharedPreferences.getInstance().then(
      (p) => p.setStringList(_kResearchFields, cleaned),
    );
  }

  static void setReminderEnabled(bool enabled) {
    notifier.value = notifier.value.copyWith(reminderEnabled: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kReminderEnabled, enabled),
    );
  }

  static void setReminderMinutes(int minutes) {
    notifier.value = notifier.value.copyWith(reminderMinutes: minutes);
    SharedPreferences.getInstance().then(
      (p) => p.setInt(_kReminderMinutes, minutes),
    );
  }

  static void setSaveRecords(bool enabled) {
    notifier.value = notifier.value.copyWith(saveRecords: enabled);
    SharedPreferences.getInstance().then(
      (p) => p.setBool(_kSaveRecords, enabled),
    );
  }
}
