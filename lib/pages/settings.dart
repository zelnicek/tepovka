import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/pages/login_page.dart';
import 'package:tepovka/pages/qr_code_page.dart';
import 'package:tepovka/services/local_profile_service.dart';

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

  @override
  void initState() {
    super.initState();
    final s = AppSettings.value;
    _seniorMode = s.seniorMode;
    _highContrast = s.highContrast;
    _textScale = s.textScale;
    _userMode = s.userMode;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: true,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        title: const Text(
          'NASTAVENÍ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: ListView(
        children: [
          const ListTile(
            title: Text(
              'Dostupnost a čitelnost',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 4),
          const ListTile(
            title: Text('Režim zobrazení'),
            subtitle:
                Text('Zvolte: Pacient (zjednodušené) nebo Lékař (detailní)'),
          ),
          RadioListTile<UserMode>(
            value: UserMode.patient,
            groupValue: _userMode,
            title: const Text('Režim pacienta'),
            subtitle: const Text('Jednoduché zobrazení – semafor'),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _userMode = v);
              AppSettings.setUserMode(v);
            },
          ),
          RadioListTile<UserMode>(
            value: UserMode.doctor,
            groupValue: _userMode,
            title: const Text('Režim lékaře'),
            subtitle: const Text('Detailní metriky HRV, zotavení'),
            onChanged: (v) {
              if (v == null) return;
              setState(() => _userMode = v);
              AppSettings.setUserMode(v);
            },
          ),
          const Divider(height: 24),
          SwitchListTile(
            secondary: const Icon(Symbols.settings_accessibility),
            title: const Text('Senior mód'),
            subtitle: const Text('Větší prvky a lepší čitelnost'),
            value: _seniorMode,
            onChanged: (v) {
              setState(() => _seniorMode = v);
              AppSettings.setSeniorMode(v);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.contrast),
            title: const Text('Vysoký kontrast'),
            subtitle: const Text('Černý text na bílém pozadí'),
            value: _highContrast,
            onChanged: (v) {
              setState(() => _highContrast = v);
              AppSettings.setHighContrast(v);
            },
          ),
          ListTile(
            leading: const Icon(Symbols.format_size),
            title: const Text('Velikost textu'),
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
          const ListTile(
            title: Text(
              'Obecné',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          SwitchListTile(
            secondary: const Icon(Symbols.vibration),
            title: const Text('Haptická odezva'),
            subtitle: const Text('Vibrace při akcích v aplikaci'),
            value: _haptics,
            onChanged: (v) => setState(() => _haptics = v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.login),
            title: const Text('Přihlášení'),
            subtitle: Text(
              !LocalProfileService.isLoggedIn
                  ? 'Nepřihlášen'
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
              title: const Text('Odhlásit se'),
              subtitle:
                  const Text('Odstraní aktivní přihlášení na tomto zařízení'),
              onTap: () async {
                await LocalProfileService.signOutLocal();
                if (!mounted) return;
                setState(() {});
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Odhlášeno'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.qr_code),
            title: const Text('Můj QR kód pro lékaře'),
            subtitle: const Text('Umožní rychlé vyhledání záznamů'),
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
            title: const Text('Ukládat záznamy lokálně'),
            subtitle: const Text('Uloží měření do zařízení'),
            value: _saveRecords,
            onChanged: (v) => setState(() => _saveRecords = v),
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Symbols.flash_on),
            title: const Text('Blesk během měření'),
            subtitle: const Text('Zlepšuje průchod světla při PPG'),
            value: _flashDuringMeasurement,
            onChanged: (v) => setState(() => _flashDuringMeasurement = v),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Symbols.language),
            title: const Text('Jazyk aplikace'),
            subtitle: const Text('Připravujeme'),
            trailing: const Icon(Symbols.chevron_right),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}
