import 'package:flutter/material.dart';
import 'package:tepovka/pages/intro_page.dart';

class MedicalDisclaimerPage extends StatefulWidget {
  const MedicalDisclaimerPage({super.key});

  @override
  State<MedicalDisclaimerPage> createState() => _MedicalDisclaimerPageState();
}

class _MedicalDisclaimerPageState extends State<MedicalDisclaimerPage> {
  bool _dialogShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _dialogShown) return;
      _dialogShown = true;
      _showDisclaimerDialog();
    });
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const IntroPage()),
    );
  }

  Future<void> _showDisclaimerDialog() async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Důležité upozornění',
            style: TextStyle(fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.health_and_safety_outlined,
                  size: 52,
                  color: Color(0xFFE07A00),
                ),
                SizedBox(height: 16),
                Text(
                  'Tato aplikace není licencovaná zdravotnická pomůcka a slouží pouze pro orientační měření a informativní účely.',
                  style: TextStyle(fontSize: 16, height: 1.45),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 12),
                Text(
                  'Výsledky nenahrazují odborné lékařské vyšetření ani doporučení lékaře. Pokud pociťujete potíže, zhoršení stavu nebo máte obavy o své zdraví, kontaktujte svého lékaře nebo zdravotnickou pohotovost.',
                  style: TextStyle(fontSize: 15, height: 1.45),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _continue(context);
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Rozumím, pokračovat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.transparent,
      body: SizedBox.expand(),
    );
  }
}
