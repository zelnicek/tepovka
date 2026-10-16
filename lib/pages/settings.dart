import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/pages/diagnostics_page.dart';
import 'package:tepovka/pages/login_page.dart';
import 'package:tepovka/pages/qr_code_page.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/services/local_profile_service.dart';
import 'package:tepovka/services/reminder_service.dart';
import 'package:tepovka/services/tts_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/widgets/settings_widgets.dart';

/// Settings, grouped by topic into cards like the rest of the app.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  static const Color _canvas = Color.fromARGB(255, 242, 242, 242);
  static const Color _blue = Color(0xFF1A73E8);
  static const Color _green = Color(0xFF1E8E3E);
  static const Color _purple = Color(0xFF7B3FE4);

  late bool _haptics;
  late bool _seniorMode;
  late bool _highContrast;
  late double _textScale;
  late UserMode _userMode;
  late bool _researchMode;
  late ExportFormat _exportFormat;
  late List<String> _researchFields;
  late bool _reminderEnabled;
  late int _reminderMinutes;
  int _measurementsCount = 0;
  String? _version;

  @override
  void initState() {
    super.initState();
    final s = AppSettings.value;
    _seniorMode = s.seniorMode;
    _highContrast = s.highContrast;
    _textScale = s.textScale;
    _userMode = s.userMode;
    _haptics = s.haptics;
    _researchMode = s.researchMode;
    _exportFormat = s.exportFormat;
    _researchFields = s.researchFields;
    _reminderEnabled = s.reminderEnabled;
    _reminderMinutes = s.reminderMinutes;
    _loadLocalStats();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() => _version = '${info.version} (${info.buildNumber})');
      }
    } catch (e) {
      debugPrint('No package info: $e');
    }
  }

  Future<void> _loadLocalStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(
          () => _measurementsCount = prefs.getInt('measurements_count') ?? 0);
    } catch (e) {
      debugPrint('Failed to load local stats: $e');
    }
  }

  /// Switching the reminder on asks for notification permission first; when
  /// it is refused the switch stays off and points to the system settings.
  Future<void> _setReminderEnabled(bool enabled) async {
    if (enabled && !await ReminderService.requestPermission()) {
      if (!mounted) return;
      final L10n t = L10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.settingsReminderDenied),
        action: SnackBarAction(
          label: t.settingsReminderOpenSettings,
          onPressed: ReminderService.openSystemSettings,
        ),
      ));
      return;
    }
    if (!mounted) return;
    setState(() => _reminderEnabled = enabled);
    AppSettings.setReminderEnabled(enabled);
    await ReminderService.reschedule();
  }

  Future<void> _pickReminderTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
          hour: _reminderMinutes ~/ 60, minute: _reminderMinutes % 60),
      helpText: L10n.of(context).settingsReminderTime,
    );
    if (picked == null || !mounted) return;
    final int minutes = picked.hour * 60 + picked.minute;
    setState(() => _reminderMinutes = minutes);
    AppSettings.setReminderMinutes(minutes);
    await ReminderService.reschedule();
  }

  Future<void> _pickExportFormat() async {
    final picked = await showDialog<ExportFormat>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(L10n.of(context).settingsExportFormat),
        children: [
          RadioGroup<ExportFormat>(
            groupValue: _exportFormat,
            onChanged: (v) => Navigator.of(context).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final format in ExportFormat.values)
                  RadioListTile<ExportFormat>(
                    value: format,
                    title: Text(_exportFormatLabel(format)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked == null) return;
    setState(() => _exportFormat = picked);
    AppSettings.setExportFormat(picked);
  }

  Future<void> _editResearchFields() async {
    final controller = TextEditingController(text: _researchFields.join('\n'));
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(L10n.of(context).settingsPreMeasurementFields),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(L10n.of(context).settingsPreMeasurementFieldsHint,
                style: TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            TextField(
              controller: controller,
              maxLines: 6,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(L10n.of(context).commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(L10n.of(context).commonSave),
          ),
        ],
      ),
    );
    if (saved != true) return;
    AppSettings.setResearchFields(controller.text.split('\n'));
    setState(() => _researchFields = AppSettings.value.researchFields);
  }

  String _exportFormatLabel(ExportFormat format) {
    final L10n t = L10n.of(context);
    return switch (format) {
      ExportFormat.txt => t.exportFormatTxt,
      ExportFormat.csv => 'CSV (Excel, pandas)',
      ExportFormat.json => t.exportFormatJson,
    };
  }

  String _languageLabel(AppLanguage language) {
    final L10n t = L10n.of(context);
    return switch (language) {
      AppLanguage.system => t.settingsLanguageSystem,
      AppLanguage.czech => t.settingsLanguageCzech,
      AppLanguage.english => t.settingsLanguageEnglish,
    };
  }

  Future<void> _pickLanguage(AppLanguage current) async {
    final AppLanguage? picked = await showDialog<AppLanguage>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(L10n.of(context).settingsAppLanguage),
        children: [
          RadioGroup<AppLanguage>(
            groupValue: current,
            onChanged: (value) => Navigator.pop(context, value),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final AppLanguage option in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: option,
                    title: Text(_languageLabel(option)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (picked != null && picked != current) {
      AppSettings.setLanguage(picked);
      // Planned reminders carry their text; redraw them in the new language.
      unawaited(ReminderService.reschedule());
      if (mounted) setState(() {});
    }
  }

  Future<void> _playVoiceSample() async {
    final L10n t = L10n.of(context);
    await TtsService.instance.testSpeak(t.ttsTestVoice);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(t.settingsPlayingTestVoice)),
    );
  }

  /// What the app writes to Health and where its access is managed. iOS has
  /// no link straight to an app's Health permissions, so it says where.
  void _showHealthInfo() {
    final L10n t = L10n.of(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        final r = Responsive.of(context);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(r.spaceXl, 0, r.spaceXl, r.spaceXl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/Icon - Apple Health.png',
                        width: r.iconLg, height: r.iconLg),
                    SizedBox(width: r.spaceMd),
                    Expanded(
                      child: Text(
                        t.settingsAppleHealth,
                        style: TextStyle(
                            fontSize: r.fontTitle, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: r.spaceMd),
                Text(t.settingsAppleHealthBody,
                    style: TextStyle(fontSize: r.fontBody, height: 1.4)),
                SizedBox(height: r.spaceLg),
                Text(t.settingsManagePermissions,
                    style: TextStyle(
                        fontSize: r.fontBody, fontWeight: FontWeight.w600)),
                SizedBox(height: r.spaceXs),
                Text(t.settingsManagePermissionsHint,
                    style: TextStyle(
                        fontSize: r.fontBody, color: kInfoSecondaryText)),
              ],
            ),
          ),
        );
      },
    );
  }

  String _profileSubtitle(L10n t) {
    if (!LocalProfileService.isLoggedIn) return t.settingsNotLoggedIn;
    final String id = LocalProfileService.userId ?? '';
    return t.settingsProfile(
      LocalProfileService.displayName ?? t.settingsProfileUnnamed,
      id.length > 6 ? id.substring(0, 6) : id,
    );
  }

  Future<void> _logout() async {
    await LocalProfileService.signOutLocal();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(L10n.of(context).settingsLoggedOut),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _open(Widget page) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    // Login and diagnostics change what the rows show.
    if (mounted) setState(() {});
    _loadLocalStats();
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final AppSettingsData settings = AppSettings.value;
    return Scaffold(
      backgroundColor: _canvas,
      appBar: AppBar(
        backgroundColor: _canvas,
        // Material 3 tints the bar when content scrolls under it.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          t.settingsTitle,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
            r.pagePadding.left, 0, r.pagePadding.right, r.spaceXl),
        children: [
          InfoSectionLabel(t.settingsSectionMeasurement),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.notifications,
              tint: kInfoAccent,
              title: t.settingsReminder,
              subtitle: t.settingsReminderHint,
              trailing: SettingsSwitch(
                  value: _reminderEnabled, onChanged: _setReminderEnabled),
              onTap: () => _setReminderEnabled(!_reminderEnabled),
            ),
            if (_reminderEnabled)
              SettingsRow(
                icon: Symbols.schedule,
                tint: kInfoAccent,
                title: t.settingsReminderTime,
                value: TimeOfDay(
                        hour: _reminderMinutes ~/ 60,
                        minute: _reminderMinutes % 60)
                    .format(context),
                chevron: true,
                onTap: _pickReminderTime,
              ),
          ]),
          InfoSectionLabel(t.settingsSectionDisplay),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.language,
              tint: _blue,
              title: t.settingsAppLanguage,
              value: _languageLabel(settings.language),
              chevron: true,
              onTap: () => _pickLanguage(settings.language),
            ),
            SettingsRow(
              icon: Symbols.person,
              tint: _blue,
              title: t.settingsDisplayMode,
              subtitle: _userMode == UserMode.patient
                  ? t.settingsPatientModeHint
                  : t.settingsDoctorModeHint,
              below: SettingsSegments<UserMode>(
                options: [
                  (UserMode.patient, t.settingsPatientModeShort),
                  (UserMode.doctor, t.settingsDoctorModeShort),
                ],
                selected: _userMode,
                onSelected: (v) {
                  setState(() => _userMode = v);
                  AppSettings.setUserMode(v);
                },
              ),
            ),
            SettingsRow(
              icon: Symbols.format_size,
              tint: _blue,
              title: t.settingsTextSize,
              value: '${(_textScale * 100).round()} %',
              below: SliderTheme(
                data: SliderThemeData(
                  activeTrackColor: kInfoAccent,
                  inactiveTrackColor: kInfoAccentTint,
                  thumbColor: kInfoAccent,
                  overlayColor: kInfoAccent.withValues(alpha: 0.12),
                  valueIndicatorColor: kInfoAccent,
                ),
                child: Slider(
                  min: 1.0,
                  max: 1.4,
                  divisions: 4,
                  label: '${(_textScale * 100).round()} %',
                  value: _textScale,
                  onChanged: (v) {
                    setState(() => _textScale = v);
                    AppSettings.setTextScale(v);
                  },
                ),
              ),
            ),
            SettingsRow(
              icon: Symbols.settings_accessibility,
              tint: _blue,
              title: t.settingsSeniorMode,
              subtitle: t.settingsSeniorModeHint,
              trailing: SettingsSwitch(
                value: _seniorMode,
                onChanged: (v) {
                  setState(() => _seniorMode = v);
                  AppSettings.setSeniorMode(v);
                },
              ),
              onTap: () {
                setState(() => _seniorMode = !_seniorMode);
                AppSettings.setSeniorMode(_seniorMode);
              },
            ),
            SettingsRow(
              icon: Symbols.contrast,
              tint: _blue,
              title: t.settingsHighContrast,
              subtitle: t.settingsHighContrastHint,
              trailing: SettingsSwitch(
                value: _highContrast,
                onChanged: (v) {
                  setState(() => _highContrast = v);
                  AppSettings.setHighContrast(v);
                },
              ),
              onTap: () {
                setState(() => _highContrast = !_highContrast);
                AppSettings.setHighContrast(_highContrast);
              },
            ),
          ]),
          InfoSectionLabel(t.settingsSectionSound),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.volume_up,
              title: t.settingsVoiceGuidance,
              subtitle: t.settingsVoiceSample,
              chevron: true,
              onTap: _playVoiceSample,
            ),
            SettingsRow(
              icon: Symbols.vibration,
              title: t.settingsHaptics,
              subtitle: t.settingsHapticsHint,
              trailing: SettingsSwitch(
                value: _haptics,
                onChanged: (v) {
                  setState(() => _haptics = v);
                  AppSettings.setHaptics(v);
                },
              ),
              onTap: () {
                setState(() => _haptics = !_haptics);
                AppSettings.setHaptics(_haptics);
              },
            ),
          ]),
          InfoSectionLabel(t.settingsSectionData),
          SettingsCard(children: [
            // Apple Health transparency (Apple Review 2.5.1).
            SettingsRow(
              image: 'assets/Icon - Apple Health.png',
              title: t.settingsHealthShort,
              subtitle: t.settingsHealthShortHint,
              chevron: true,
              onTap: _showHealthInfo,
            ),
            SettingsRow(
              icon: Symbols.lock,
              tint: _green,
              title: t.settingsDataLocal,
              subtitle: t.settingsDataLocalHint,
            ),
          ]),
          InfoSectionLabel(t.settingsResearchSection),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.science,
              tint: _purple,
              title: t.settingsResearchMode,
              subtitle: t.settingsResearchModeHint,
              trailing: SettingsSwitch(
                value: _researchMode,
                onChanged: (v) {
                  setState(() => _researchMode = v);
                  AppSettings.setResearchMode(v);
                },
              ),
              onTap: () {
                setState(() => _researchMode = !_researchMode);
                AppSettings.setResearchMode(_researchMode);
              },
            ),
            if (_researchMode) ...[
              SettingsRow(
                icon: Symbols.description,
                tint: _purple,
                title: t.settingsExportFormat,
                subtitle: _exportFormatLabel(_exportFormat),
                chevron: true,
                onTap: _pickExportFormat,
              ),
              SettingsRow(
                icon: Symbols.list_alt,
                tint: _purple,
                title: t.settingsResearchFields,
                subtitle: _researchFields.join(' · '),
                chevron: true,
                onTap: _editResearchFields,
              ),
            ],
          ]),
          InfoSectionLabel(t.settingsSectionProfile),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.login,
              title: t.settingsLogin,
              subtitle: _profileSubtitle(t),
              chevron: true,
              onTap: () => _open(const LoginPage()),
            ),
            if (LocalProfileService.isLoggedIn)
              SettingsRow(
                icon: Symbols.logout,
                title: t.settingsLogout,
                subtitle: t.settingsLogoutHint,
                onTap: _logout,
              ),
            SettingsRow(
              icon: Symbols.qr_code,
              title: t.settingsMyQrForDoctor,
              subtitle: t.settingsMyQrForDoctorHint,
              chevron: true,
              onTap: () => _open(const QrCodePage()),
            ),
          ]),
          InfoSectionLabel(t.settingsSectionSupport),
          SettingsCard(children: [
            SettingsRow(
              icon: Symbols.bug_report,
              title: t.settingsDiagnostics,
              subtitle: t.recordsMeasurementsCount(_measurementsCount),
              chevron: true,
              onTap: () => _open(const DiagnosticsPage()),
            ),
          ]),
          if (_version != null) ...[
            SizedBox(height: r.spaceXl),
            Center(
              child: Text(
                'Tepovka · ${t.infoVersion(_version!)}',
                style:
                    TextStyle(fontSize: r.fontCaption, color: Colors.black38),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
