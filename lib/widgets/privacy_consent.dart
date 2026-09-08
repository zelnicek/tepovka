import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:flutter/services.dart';

class PrivacyConsentPage extends StatefulWidget {
  const PrivacyConsentPage({super.key});

  @override
  State<PrivacyConsentPage> createState() => _PrivacyConsentPageState();
}

class _PrivacyConsentPageState extends State<PrivacyConsentPage> {
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('privacy_consent', true);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const IntroPage()),
    );
  }

  Future<void> _decline() async {
    // If user declines, close the app (no functionality without consent)
    await SystemChannels.platform.invokeMethod('SystemNavigator.pop');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.of(context).consentTitle),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Image.asset(
                            'assets/Text_loading.png',
                            height: 72,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      Text(
                        L10n.of(context).consentBody,
                      ),
                      const SizedBox(height: 16),
                      Text(L10n.of(context).consentWhatItDoesTitle),
                      const SizedBox(height: 8),
                      Text(
                          L10n.of(context).consentBullet1),
                      Text(L10n.of(context).consentBullet2),
                      Text(
                          L10n.of(context).consentBullet3),
                      const SizedBox(height: 16),
                      Text(
                          L10n.of(context).consentQuestion),
                    ],
                  ),
                ),
              ),
              if (_saving) const Center(child: CircularProgressIndicator()),
              if (!_saving)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _accept,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(L10n.of(context).consentAgree),
                      ),
                      ElevatedButton(
                        onPressed: _decline,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade400,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 28, vertical: 12),
                          textStyle: const TextStyle(fontSize: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(L10n.of(context).consentDecline),
                      ),
                    ],
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
