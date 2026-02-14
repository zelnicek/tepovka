import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tepovka/services/local_profile_service.dart';

class QrCodePage extends StatelessWidget {
  const QrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = LocalProfileService.isLoggedIn;
    final uid = LocalProfileService.userId ?? 'not-signed-in';
    // Encode local-only ID
    final data = 'tepovka:local:$uid';
    return Scaffold(
      appBar: AppBar(title: const Text('Můj QR kód')),
      body: Center(
        child: !loggedIn
            ? const Text('Nejprve se prosím přihlašte.')
            : QrImageView(
                data: data,
                version: QrVersions.auto,
                size: 240,
              ),
      ),
    );
  }
}
