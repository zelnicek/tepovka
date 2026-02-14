import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tepovka/services/local_profile_service.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tepovka/pages/qr_code_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _busy = false;

  final _nameController = TextEditingController();
  final _pinController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = LocalProfileService.isLoggedIn;
    final uid = LocalProfileService.userId ?? '';
    final name = LocalProfileService.displayName ?? '';
    final qrData = 'tepovka:local:$uid';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Přihlášení'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: loggedIn
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Můj QR kód',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        children: [
                          QrImageView(
                            data: qrData,
                            version: QrVersions.auto,
                            size: 220,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Profil: $name',
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'ID: ${uid.isNotEmpty ? uid.substring(0, 6) + '…' : '—'}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Lékař na svém mobilu otevře kameru nebo QR skener a naskenuje tento kód. Pokud skener není dostupný, může ručně zadat vaše ID.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                        builder: (_) => const QrCodePage()),
                                  );
                                },
                                icon: const Icon(Icons.fullscreen),
                                label: const Text('Na celé obrazovce'),
                              ),
                              const SizedBox(width: 12),
                              TextButton.icon(
                                onPressed: () async {
                                  await Clipboard.setData(
                                    ClipboardData(text: uid),
                                  );
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content:
                                          Text('ID zkopírováno do schránky'),
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.copy),
                                label: const Text('Kopírovat ID'),
                              ),
                              const SizedBox(width: 12),
                              TextButton.icon(
                                onPressed: () async {
                                  await Share.share('Tepovka ID: $uid');
                                },
                                icon: const Icon(Icons.ios_share),
                                label: const Text('Sdílet'),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          const Divider(),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () async {
                              await LocalProfileService.signOutLocal();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Odhlášeno'),
                                  duration: Duration(seconds: 2),
                                ),
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.logout),
                            label: const Text('Odhlásit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.redAccent,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  const Text(
                    'Lokální profil',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Jméno',
                      hintText: 'Zadejte vaše jméno',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _pinController,
                    decoration: const InputDecoration(
                      labelText: 'PIN (volitelné)',
                      hintText: '4–6 číslic pro zámek profilu',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    obscureText: true,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy
                        ? null
                        : () async {
                            final nameInput = _nameController.text.trim();
                            final pin = _pinController.text.trim();
                            if (nameInput.isEmpty) return;
                            setState(() => _busy = true);
                            await LocalProfileService.init();
                            await LocalProfileService.signInLocal(
                              name: nameInput,
                              pin: pin.isEmpty ? null : pin,
                            );
                            setState(() => _busy = false);
                            if (mounted) setState(() {});
                          },
                    icon: const FaIcon(FontAwesomeIcons.userPlus),
                    label: const Text('Uložit profil a zobrazit QR'),
                  ),
                  const Spacer(),
                  if (_busy) const Center(child: CircularProgressIndicator()),
                ],
              ),
      ),
    );
  }
}
