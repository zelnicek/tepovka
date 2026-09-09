import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/pages/login_page.dart';
import 'package:tepovka/pages/qr_code_page.dart';
import 'package:tepovka/services/local_profile_service.dart';
import 'package:tepovka/services/tts_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/services/local_logger.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _haptics = true;
  bool _saveRecords = true;
  bool _flashDuringMeasurement = true;
  late bool _seniorMode;
  late bool _highContrast;
  late double _textScale;
  late UserMode _userMode;
  late bool _researchMode;
  late ExportFormat _exportFormat;
  late List<String> _researchFields;
  int _measurementsCount = 0;
  String _lastMeasurement = '-';

  @override
  void initState() {
    super.initState();
    final s = AppSettings.value;
    _seniorMode = s.seniorMode;
    _highContrast = s.highContrast;
    _textScale = s.textScale;
    _userMode = s.userMode;
    _haptics = s.haptics;
    _saveRecords = s.saveRecords;
    _researchMode = s.researchMode;
    _exportFormat = s.exportFormat;
    _researchFields = s.researchFields;
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

  Future<void> _openLog() async {
    try {
      final path = await LocalLogger.getLogFilePath();
      if (path != null && await File(path).exists()) {
        await OpenFilex.open(path);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).settingsLogNotFound)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.of(context).settingsLogOpenError('$e'))));
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
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).settingsLogNotFound)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.of(context).settingsLogShareError('$e'))));
    }
  }

  Future<void> _clearLog() async {
    try {
      final path = await LocalLogger.getLogFilePath();
      if (path != null && await File(path).exists()) {
        await File(path).delete();
        await LocalLogger.init(); // recreate
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(L10n.of(context).settingsLogCleared)));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(L10n.of(context).settingsLogNotFound)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(L10n.of(context).settingsLogDeleteError('$e'))));
    }
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
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsData settings = AppSettings.value;
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        title: Text(
          L10n.of(context).settingsTitle,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        children: [
          ListTile(
            title: Text(
              L10n.of(context).settingsAccessibilitySection,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          ListTile(
            title: Text(L10n.of(context).settingsDisplayMode),
            subtitle:
                Text(L10n.of(context).settingsDisplayModeHint),
          ),
          RadioGroup<UserMode>(
            groupValue: _userMode,
            onChanged: (v) {
              if (v == null) return;
              setState(() => _userMode = v);
              AppSettings.setUserMode(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<UserMode>(
                  value: UserMode.patient,
                  title: Text(L10n.of(context).settingsPatientMode),
                  subtitle: Text(L10n.of(context).settingsPatientModeHint),
                ),
                RadioListTile<UserMode>(
                  value: UserMode.doctor,
                  title: Text(L10n.of(context).settingsDoctorMode),
                  subtitle: Text(L10n.of(context).settingsDoctorModeHint),
                ),
              ],
            ),
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Symbols.settings_accessibility),
            title: Text(L10n.of(context).settingsSeniorMode),
            subtitle: Text(L10n.of(context).settingsSeniorModeHint),
            value: _seniorMode,
            onChanged: (v) {
              setState(() => _seniorMode = v);
              AppSettings.setSeniorMode(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.contrast),
            title: Text(L10n.of(context).settingsHighContrast),
            subtitle: Text(L10n.of(context).settingsHighContrastHint),
            value: _highContrast,
            onChanged: (v) {
              setState(() => _highContrast = v);
              AppSettings.setHighContrast(v);
            },
          ),
          ListTile(
            leading: const Icon(Symbols.format_size),
            title: Text(L10n.of(context).settingsTextSize),
            subtitle: Text('${(_textScale * 100).round()}%'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Slider(
              min: 1.0,
              max: 1.4,
              divisions: 4,
              label: '${(_textScale * 100).round()}%',
              value: _textScale,
              onChanged: (v) {
                setState(() => _textScale = v);
                AppSettings.setTextScale(v);
              },
            ),
          ),
          const Divider(height: 24),
          // ─── Apple Health transparency (Apple Review 2.5.1) ─────
          const ListTile(
            title: Text(
              'Apple Health',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: Image.asset(
              'assets/Icon - Apple Health.png',
              width: 28,
              height: 28,
            ),
            title: Text(L10n.of(context).settingsAppleHealth),
            subtitle: Text(
              L10n.of(context).settingsAppleHealthBody,
            ),
            isThreeLine: true,
          ),
          ListTile(
            leading: const Icon(Symbols.settings),
            title: Text(L10n.of(context).settingsManagePermissions),
            subtitle: Text(
              L10n.of(context).settingsManagePermissionsHint,
            ),
          ),
          const Divider(height: 24),
          ListTile(
            title: Text(
              L10n.of(context).settingsGeneralSection,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: Text(L10n.of(context).settingsTestVoice),
            subtitle: Text(L10n.of(context).settingsTestVoiceHint),
            onTap: () async {
              await TtsService.instance
                  .testSpeak(L10n.of(context).ttsTestVoice);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(L10n.of(context).settingsPlayingTestVoice)),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.vibration),
            title: Text(L10n.of(context).settingsHaptics),
            subtitle: Text(L10n.of(context).settingsHapticsHint),
            value: _haptics,
            onChanged: (v) {
              setState(() => _haptics = v);
              AppSettings.setHaptics(v);
            },
          ),
          const Divider(height: 1),
          ListTile(
            dense: true,
            title: Text(
              L10n.of(context).settingsResearchSection,
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.6),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.science),
            title: Text(L10n.of(context).settingsResearchMode),
            subtitle: Text(
                L10n.of(context).settingsResearchModeHint),
            value: _researchMode,
            onChanged: (v) {
              setState(() => _researchMode = v);
              AppSettings.setResearchMode(v);
            },
          ),
          if (_researchMode) ...[
            ListTile(
              leading: const Icon(Symbols.description),
              title: Text(L10n.of(context).settingsExportFormat),
              subtitle: Text(_exportFormatLabel(_exportFormat)),
              trailing: const Icon(Symbols.chevron_right),
              onTap: _pickExportFormat,
            ),
            ListTile(
              leading: const Icon(Symbols.list_alt),
              title: Text(L10n.of(context).settingsResearchFields),
              subtitle: Text(_researchFields.join(' · ')),
              trailing: const Icon(Symbols.chevron_right),
              onTap: _editResearchFields,
            ),
          ],
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.login),
            title: Text(L10n.of(context).settingsLogin),
            subtitle: Text(
              !LocalProfileService.isLoggedIn
                  ? L10n.of(context).settingsNotLoggedIn
                  : 'Profil: ${LocalProfileService.displayName ?? 'Uživatel'} (${(LocalProfileService.userId ?? '').substring(0, 6)}…) ',
            ),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LoginPage()),
              );
            },
          ),
          if (LocalProfileService.isLoggedIn)
            ListTile(
              leading: const Icon(Symbols.logout),
              title: Text(L10n.of(context).settingsLogout),
              subtitle:
                  Text(L10n.of(context).settingsLogoutHint),
              onTap: () async {
                await LocalProfileService.signOutLocal();
                if (!context.mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(L10n.of(context).settingsLoggedOut),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.qr_code),
            title: Text(L10n.of(context).settingsMyQrForDoctor),
            subtitle: Text(L10n.of(context).settingsMyQrForDoctorHint),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QrCodePage()),
              );
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Symbols.folder),
            title: Text(L10n.of(context).settingsStoreLocally),
            subtitle: Text(L10n.of(context).settingsStoreLocallyHint),
            value: _saveRecords,
            onChanged: (v) {
              setState(() => _saveRecords = v);
              AppSettings.setSaveRecords(v);
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Symbols.flash_on),
            title: Text(L10n.of(context).settingsTorchDuring),
            subtitle: Text(L10n.of(context).settingsTorchDuringHint),
            value: _flashDuringMeasurement,
            onChanged: (v) => setState(() => _flashDuringMeasurement = v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.language),
            title: Text(L10n.of(context).settingsAppLanguage),
            subtitle: Text(_languageLabel(settings.language)),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () => _pickLanguage(settings.language),
          ),
          const Divider(height: 24),
          ListTile(
            title: Text(
              L10n.of(context).settingsLogSection,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.insights),
            title: Text(L10n.of(context).settingsLocalCount),
            subtitle: Text('$_measurementsCount'),
          ),
          ListTile(
            leading: const Icon(Icons.access_time),
            title: Text(L10n.of(context).settingsLastMeasurement),
            subtitle: Text(_lastMeasurement),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _openLog,
                  icon: const Icon(Icons.open_in_new),
                  label: Text(L10n.of(context).settingsOpenLog),
                ),
                ElevatedButton.icon(
                  onPressed: _shareLog,
                  icon: const Icon(Icons.share),
                  label: Text(L10n.of(context).settingsShareLog),
                ),
                ElevatedButton.icon(
                  onPressed: _clearLog,
                  icon: const Icon(Icons.delete),
                  label: Text(L10n.of(context).settingsClearLog),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
