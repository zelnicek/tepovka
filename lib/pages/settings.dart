import 'package:flutter/material.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _haptics = true;
  bool _saveRecords = true;
  bool _flashDuringMeasurement = true;

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
          SwitchListTile(
            secondary: const Icon(Symbols.vibration),
            title: const Text('Haptická odezva'),
            subtitle: const Text('Vibrace při akcích v aplikaci'),
            value: _haptics,
            onChanged: (v) => setState(() => _haptics = v),
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
