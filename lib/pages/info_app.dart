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
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';

class InfoApp extends StatefulWidget {
  const InfoApp({super.key});

  @override
  State<InfoApp> createState() => _InfoAppState();
}

class _InfoAppState extends State<InfoApp> {
  int _selectedIndex = -1;

  /// Shown in the header so a bug report can name the exact build.
  String? _version;
  bool _projectExpanded = false;

  /// Proper names, the same in every language.
  static const List<String> _team = [
    'Štěpán Zelníček',
    'David Vavroušek',
    'Jakub Kovář',
    'Jakub Kaša',
  ];

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((info) {
      if (!mounted) return;
      setState(() => _version = '${info.version} (${info.buildNumber})');
    }).catchError((Object e) {
      debugPrint('Could not read app version: $e');
    });
  }

  Future<void> _open(String url) async {
    final Uri uri = Uri.parse(url);
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) debugPrint('Could not open $url');
  }

  Widget _member(BuildContext context, String name) {
    final r = Responsive.of(context);
    final String initials = name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p.characters.first.toUpperCase())
        .join();
    return Expanded(
      child: Column(
        children: [
          Container(
            width: r.iconXl + r.spaceMd,
            height: r.iconXl + r.spaceMd,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
                color: kInfoAccentTint, shape: BoxShape.circle),
            child: Text(
              initials,
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: r.fontBody,
                  color: const Color(0xFFB3261E)),
            ),
          ),
          SizedBox(height: r.spaceXs),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: TextStyle(fontSize: r.fontSmall, height: 1.25),
          ),
        ],
      ),
    );
  }

  Widget _linkTile(BuildContext context, IconData icon, Color iconColor,
      String label, String url) {
    final r = Responsive.of(context);
    return Expanded(
      child: InfoCard(
        onTap: () => _open(url),
        padding:
            EdgeInsets.symmetric(vertical: r.spaceMd, horizontal: r.spaceXs),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: Column(
            children: [
              Icon(icon, size: r.iconMd, color: iconColor),
              SizedBox(height: r.spaceXs),
              Text(label, style: TextStyle(fontSize: r.fontSmall)),
            ],
          ),
        ),
      ),
    );
  }

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

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        // Material 3 tints the bar when content scrolls under it, which shows
        // as a grey-green band over the white cards.
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          L10n.of(context).introAboutApp,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Image.asset('assets/tepovka_icon.png',
                        width: r.iconXl * 2, height: r.iconXl * 2),
                  ),
                  SizedBox(height: r.spaceSm),
                  Text('Tepovka',
                      style: TextStyle(
                          fontSize: r.fontHeadline,
                          fontWeight: FontWeight.bold)),
                  if (_version != null)
                    Text(
                      L10n.of(context).infoVersion(_version!),
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText),
                    ),
                ],
              ),
              SizedBox(height: r.spaceXl),
              InfoCard(
                onTap: () =>
                    setState(() => _projectExpanded = !_projectExpanded),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      L10n.of(context).infoProjectTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: r.fontTitle),
                    ),
                    SizedBox(height: r.spaceXs),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      alignment: Alignment.topCenter,
                      child: Text(
                        _projectExpanded
                            ? L10n.of(context).infoIntro
                            : L10n.of(context).infoProjectSummary,
                        style: TextStyle(fontSize: r.fontBody, height: 1.45),
                      ),
                    ),
                    SizedBox(height: r.spaceSm),
                    Text(
                      _projectExpanded
                          ? L10n.of(context).infoReadLess
                          : L10n.of(context).infoReadMore,
                      style: TextStyle(
                          fontSize: r.fontBody,
                          fontWeight: FontWeight.w600,
                          color: kInfoAccent),
                    ),
                  ],
                ),
              ),
              InfoSectionLabel(L10n.of(context).infoTeamTitle),
              InfoCard(
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [for (final n in _team) _member(context, n)],
                    ),
                    SizedBox(height: r.spaceMd),
                    Text(
                      L10n.of(context).infoTeamIntro,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: r.fontSmall, color: kInfoSecondaryText),
                    ),
                  ],
                ),
              ),
              InfoSectionLabel(L10n.of(context).infoFollowTitle),
              Row(
                children: [
                  _linkTile(context, Icons.language, Colors.black87,
                      L10n.of(context).infoWeb, 'https://www.mojetepovka.cz'),
                  SizedBox(width: r.spaceSm),
                  _linkTile(
                      context,
                      FontAwesomeIcons.linkedin,
                      const Color.fromARGB(255, 42, 94, 252),
                      'LinkedIn',
                      'https://www.linkedin.com/company/tepovka'),
                  SizedBox(width: r.spaceSm),
                  _linkTile(
                      context,
                      FontAwesomeIcons.instagram,
                      Colors.pink,
                      'Instagram',
                      'https://www.instagram.com/tepovka?utm_source=ig_web_button_share_sheet&igsh=ZDNlZDc0MzIxNw=='),
                ],
              ),
              SizedBox(height: r.spaceMd),
              InfoCard(
                onTap: () => _open('https://www.vut.cz'),
                child: Row(
                  children: [
                    Image.asset('assets/vut_heart-removebg-preview.png',
                        height: r.iconXl * 1.3),
                    SizedBox(width: r.spaceMd),
                    Expanded(
                      child: Text(
                        L10n.of(context).infoSupportedBy,
                        style: TextStyle(fontSize: r.fontBody),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: r.spaceXl),
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
