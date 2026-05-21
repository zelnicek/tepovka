import 'package:flutter/material.dart';
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
        title: const Text('Souhlas se zpracováním dat'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
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
            const Text(
              'Provoz aplikace vyžaduje zpracování obrazových snímků z fotoaparátu k výpočtu srdeční frekvence a souvisejících metrik.\n\nAplikace neodesílá vaše snímky na servery a data ukládá pouze lokálně, pokud s tím výslovně souhlasíte.\n\nDůležité: tato aplikace není lékařský přístroj. Hodnoty jako SpO2 jsou orientační a nemusí být ihned dostupné nebo přesné. Nepoužívejte aplikaci jako náhradu lékařského zařízení — při obavách vyhledejte odbornou lékařskou pomoc.',
            ),
            const SizedBox(height: 16),
            const Text('Co aplikace dělá:'),
            const SizedBox(height: 8),
            const Text('- Zpracování snímků z fotoaparátu pro PPG analýzu.'),
            const Text('- Ukládání souhrnných výsledků lokálně.'),
            const Text('- Neodesílání surových obrazových dat bez souhlasu.'),
            const SizedBox(height: 16),
            const Text('Souhlasíte se zpracováním dat potřebných pro měření?'),
            const Spacer(),
            if (_saving) const Center(child: CircularProgressIndicator()),
            if (!_saving)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ElevatedButton(
                    onPressed: _accept,
                    child: const Text('Souhlasím'),
                  ),
                  ElevatedButton(
                    onPressed: _decline,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                    ),
                    child: const Text('Nechci'),
                  ),
                ],
              )
          ],
        ),
      ),
    );
  }
}
