import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
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
              L10n.of(context).infoTitle,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: r.fontTitleLg),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: L10n.of(context).a11yOpenSettings,
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
                L10n.of(context).infoIntro,
                style: TextStyle(fontSize: r.fontBodyLg),
              ),
              SizedBox(height: r.spaceXl),
              Text(
                L10n.of(context).infoTeamTitle,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: r.fontTitle),
              ),
              SizedBox(height: r.spaceSm),
              Text(
                L10n.of(context).infoTeamBody,
                style: TextStyle(fontSize: r.fontBodyLg),
              ),
              SizedBox(height: r.spaceXl),
              Text(
                L10n.of(context).infoFollowTitle,
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
                    label: Text(L10n.of(context).infoWeb),
                  ),
                  IconButton(
                    tooltip: 'LinkedIn',
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
                    tooltip: 'Instagram',
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
                ],
              ),
              SizedBox(height: r.spaceXl),
              Text(
                L10n.of(context).infoFollowBody,
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
                L10n.of(context).infoSupportedBy,
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
        tabs: [
          GButton(
            icon: Symbols.family_home,
            text: L10n.of(context).navMenu,
          ),
          GButton(
            icon: Symbols.ecg_heart,
            text: L10n.of(context).navMeasure,
          ),
          GButton(
            icon: Symbols.help,
            text: L10n.of(context).navInfo,
          ),
        ],
      ),
    );
  }
}
