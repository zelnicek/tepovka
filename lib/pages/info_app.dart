import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:tepovka/pages/settings.dart';
import 'package:tepovka/elements/responsive.dart';

class InfoApp extends StatefulWidget {
  const InfoApp({super.key});

  @override
  State<InfoApp> createState() => _InfoAppState();
}

class _InfoAppState extends State<InfoApp> {
  int _selectedIndex = -1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
        break;
      case 1:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
        break;
      case 2:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const InfoApp()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    final double socialIconSize = r.isCompact ? 30.0 : 38.0;
    final double coffeeWidth =
        (r.width * 0.42).clamp(130.0, 180.0).toDouble();
    final double coffeeHeight = coffeeWidth * 0.53;
    final double socialSpacing = r.isCompact ? 10.0 : 16.0;
    final double vutLogoWidth = (r.width * 0.55).clamp(160.0, 220.0).toDouble();
    final double vutLogoHeight = vutLogoWidth * 0.5;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'O NÁS',
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: r.fontTitleLg),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Symbols.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: r.pagePadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'O projektu Tepovka',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: r.fontTitle),
              ),
              SizedBox(height: r.spaceSm),
              Text(
                'Ahoj!\n'
                'S radostí Vám představujeme naši aplikaci s názvem Tepovka, která vzniká v rámci soutěže organizované Fakultou elektrotechniky a komunikačních technologií na Vysokém učení technickém v Brně. '
                'Tento projekt je výsledkem naší spolupráce v týmu, který spojuje nadšení pro biomedicínské inženýrství a snahu přinášet inovativní řešení do každodenního života.\n\n'
                'Naším cílem je vytvořit aplikaci, která umožní měření srdeční frekvence jednoduše pomocí smartphonu s kamerou a bleskem. Tato funkce je pouhým začátkem. V budoucnu plánujeme rozšířit aplikaci o pokročilejší funkce, jako je měření saturace kyslíku v krvi (oximetrie), detekce srdečních arytmií nebo dokonce měření krevního tlaku – pokud výzkumy ukáží, že je tato technologie proveditelná.\n\n'
                'Aplikace vzniká za podpory VUT, které poskytuje nejen technologické zázemí, ale také odborné vedení, díky kterému můžeme naše nápady realizovat.',
                style: TextStyle(fontSize: r.fontBodyLg),
              ),
              SizedBox(height: r.spaceXl),
              Text(
                'Náš tým',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: r.fontTitle),
              ),
              SizedBox(height: r.spaceSm),
              Text(
                'Jsme studenti biomedicínského inženýrství a spojuje nás vášeň pro vývoj zdravotnických technologií. Náš tým tvoří:\n'
                '- Štěpán Zelníček\n'
                '- David Vavroušek\n'
                '- Jakub Kovář\n\n'
                'Každý z nás přispívá svými specifickými dovednostmi – od programování, přes design aplikací až po analýzu biologických dat. Naším hlavním cílem je vytvořit uživatelsky přívětivou a zároveň technologicky pokročilou aplikaci, která bude sloužit široké veřejnosti.',
                style: TextStyle(fontSize: r.fontBodyLg),
              ),
              SizedBox(height: r.spaceXl),
              Text(
                'Sledujte a podpořte nás',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: r.fontTitle),
              ),
              SizedBox(height: r.spaceSm),
              Wrap(
                alignment: WrapAlignment.start,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: socialSpacing,
                spacing: socialSpacing,
                children: [
                  OutlinedButton.icon(
                    onPressed: () async {
                      final Uri url = Uri.parse('https://www.mojetepovka.cz');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                    icon: const Icon(Icons.language),
                    label: const Text('Web'),
                  ),
                  IconButton(
                    icon: Icon(
                      FontAwesomeIcons.linkedin,
                      size: socialIconSize,
                      color: const Color.fromARGB(255, 42, 94, 252),
                    ),
                    onPressed: () async {
                      final Uri url =
                          Uri.parse('https://www.linkedin.com/company/tepovka');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      FontAwesomeIcons.instagram,
                      size: socialIconSize,
                      color: Colors.pink,
                    ),
                    onPressed: () async {
                      final Uri url = Uri.parse(
                        'https://www.instagram.com/tepovka?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw==',
                      );
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                  ),
                  GestureDetector(
                    onTap: () async {
                      final Uri url =
                          Uri.parse('https://www.buymeacoffee.com/tepovka');
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url);
                      } else {
                        throw 'Could not launch $url';
                      }
                    },
                    child: Image.asset(
                      'assets/bmc.png',
                      width: coffeeWidth,
                      height: coffeeHeight,
                    ),
                  ),
                ],
              ),
              SizedBox(height: r.spaceXl),
              Text(
                'Jsme nadšeni z možnosti sdílet naši cestu s Vámi a budeme rádi, když nás podpoříte a budete sledovat naše pokroky. Těšíme se na společné objevování nových možností v oblasti digitálního zdravotnictví!',
                style: TextStyle(
                    fontSize: r.fontBodyLg, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: r.spaceXxl),
              GestureDetector(
                onTap: () async {
                  final Uri url = Uri.parse('https://www.vut.cz');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url);
                  } else {
                    throw 'Could not launch $url';
                  }
                },
                child: Image.asset(
                  'assets/vut_heart-removebg-preview.png',
                  width: vutLogoWidth,
                  height: vutLogoHeight,
                ),
              ),
              Text(
                'Za podpory VUT. Děkujeme',
                style: TextStyle(
                    fontStyle: FontStyle.italic, fontSize: r.fontBody),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GNav(
        gap: 0,
        activeColor: Colors.black,
        iconSize: r.iconMd,
        backgroundColor: Colors.white,
        color: Colors.grey,
        selectedIndex: _selectedIndex,
        onTabChange: _onItemTapped,
        tabs: const [
          GButton(
            icon: Symbols.family_home,
            text: 'MENU',
          ),
          GButton(
            icon: Symbols.ecg_heart,
            text: 'MĚŘENÍ',
          ),
          GButton(
            icon: Symbols.help,
            text: 'INFO',
          ),
        ],
      ),
    );
  }
}
