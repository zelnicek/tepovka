import 'package:flutter/material.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:tepovka/services/local_profile_service.dart';
import 'package:tepovka/widgets/info_widgets.dart';

/// The profile QR code alone and large, for the doctor to scan. White, not
/// the grey canvas, so the code has the most contrast.
class QrCodePage extends StatelessWidget {
  const QrCodePage({super.key});

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final L10n t = L10n.of(context);
    final loggedIn = LocalProfileService.isLoggedIn;
    final uid = LocalProfileService.userId ?? 'not-signed-in';
    // Encode local-only ID
    final data = 'tepovka:local:$uid';
    final qrSize = (MediaQuery.sizeOf(context).width * 0.78)
        .clamp(200.0, 360.0)
        .toDouble();
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          t.loginMyQr,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
        ),
      ),
      body: Center(
        child: !loggedIn
            ? Padding(
                padding: r.pagePadding,
                child: Text(
                  t.loginSignInFirst,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: r.fontBodyLg, color: kInfoSecondaryText),
                ),
              )
            : QrImageView(
                data: data,
                version: QrVersions.auto,
                size: qrSize,
              ),
      ),
    );
  }
}
