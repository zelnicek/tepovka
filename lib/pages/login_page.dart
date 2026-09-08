import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
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
    final qrSize =
        (MediaQuery.sizeOf(context).width * 0.68).clamp(180.0, 220.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).settingsLogin),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: loggedIn
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      L10n.of(context).loginMyQr,
                      style: TextStyle(
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
                              size: qrSize,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Profil: $name',
                              style: const TextStyle(fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ID: ${uid.isNotEmpty ? uid.substring(0, 6) + '…' : '—'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              L10n.of(context).loginQrHint,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                          builder: (_) => const QrCodePage()),
                                    );
                                  },
                                  icon: const Icon(Icons.fullscreen),
                                  label: Text(L10n.of(context).loginFullscreen),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Clipboard.setData(
                                      ClipboardData(text: uid),
                                    );
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content:
                                            Text(L10n.of(context).loginIdCopied),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                  },
                                  icon: const Icon(Icons.copy),
                                  label: Text(L10n.of(context).loginCopyId),
                                ),
                                TextButton.icon(
                                  onPressed: () async {
                                    await Share.share('Tepovka ID: $uid');
                                  },
                                  icon: const Icon(Icons.ios_share),
                                  label: Text(L10n.of(context).loginShare),
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
                                  SnackBar(
                                    content: Text(L10n.of(context).settingsLoggedOut),
                                    duration: Duration(seconds: 2),
                                  ),
                                );
                                setState(() {});
                              },
                              icon: const Icon(Icons.logout),
                              label: Text(L10n.of(context).loginLogout),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),
                    Text(
                      L10n.of(context).loginLocalProfile,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: L10n.of(context).loginName,
                        hintText: L10n.of(context).loginNameHint,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _pinController,
                      decoration: InputDecoration(
                        labelText: L10n.of(context).loginPin,
                        hintText: L10n.of(context).loginPinHint,
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
                      label: Text(L10n.of(context).loginSaveProfile),
                    ),
                    const SizedBox(height: 16),
                    if (_busy) const Center(child: CircularProgressIndicator()),
                  ],
                ),
        ),
      ),
    );
  }
}
