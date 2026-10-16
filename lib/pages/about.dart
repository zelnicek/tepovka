import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/measure_guide.dart';
import 'package:tepovka/elements/responsive.dart';
import 'package:tepovka/widgets/info_widgets.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> {
  int _selectedIndex = 2;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // Pokud je karta již vybraná, nedělejte nic
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    // Přepnutí na novou stránku podle vybraného indexu
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
          MaterialPageRoute(builder: (context) => const About()),
        );
        break;
    }
  }

  Widget _step(BuildContext context, IconData icon, String text,
      {Color color = Colors.black87}) {
    final r = Responsive.of(context);
    return Expanded(
      // Without side padding the three captions ran into each other and read
      // as one sentence across the columns.
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: r.spaceXs),
        child: Column(
          children: [
            Icon(icon, size: r.iconLg, color: color),
            SizedBox(height: r.spaceXs),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: r.fontSmall, height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tip(BuildContext context, String text) {
    final r = Responsive.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: r.spaceXs),
      child: Row(
        children: [
          Icon(Icons.check_circle_outline,
              size: r.iconMd, color: Colors.green.shade600),
          SizedBox(width: r.spaceMd),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: r.fontBodyLg)),
          ),
        ],
      ),
    );
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
          L10n.of(context).aboutPageTitle,
          style: TextStyle(fontSize: r.fontTitle, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Scrollbar(
          thumbVisibility: true,
          child: SingleChildScrollView(
            padding: r.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The guide is the most useful thing on this page, so it leads.
                InfoCard(
                  color: kInfoAccentTint,
                  onTap: () => MeasureGuide.open(context),
                  child: Row(
                    children: [
                      Container(
                        width: r.iconXl + r.spaceSm,
                        height: r.iconXl + r.spaceSm,
                        decoration: const BoxDecoration(
                            color: Colors.white, shape: BoxShape.circle),
                        child: Icon(Icons.touch_app_outlined,
                            color: kInfoAccent, size: r.iconMd),
                      ),
                      SizedBox(width: r.spaceMd),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10n.of(context).guideTitle,
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: r.fontTitle,
                                  color: kInfoAccent),
                            ),
                            Text(
                              L10n.of(context).aboutGuideSubtitle,
                              style: TextStyle(
                                  fontSize: r.fontBody,
                                  color: const Color(0xFFB3261E)),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: kInfoAccent),
                    ],
                  ),
                ),
                InfoSectionLabel(L10n.of(context).howSectionPrinciple),
                InfoCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _step(context, Icons.lightbulb_outline,
                          L10n.of(context).howStepLight),
                      _step(context, Icons.photo_camera_outlined,
                          L10n.of(context).howStepCamera),
                      _step(context, Icons.favorite_border,
                          L10n.of(context).howStepPulse,
                          color: kInfoAccent),
                    ],
                  ),
                ),
                InfoSectionLabel(L10n.of(context).howSectionFinger),
                InfoCard(
                  child: Column(
                    children: [
                      _tip(context, L10n.of(context).howTipCover),
                      _tip(context, L10n.of(context).howTipLight),
                      _tip(context, L10n.of(context).howTipStill),
                    ],
                  ),
                ),
                SizedBox(height: r.spaceMd),
                InfoCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        L10n.of(context).howAccuracyLabel,
                        style: TextStyle(
                            fontSize: r.fontSmall, color: kInfoSecondaryText),
                      ),
                      Text(
                        L10n.of(context).howAccuracyValue,
                        style: TextStyle(
                            fontSize: r.fontDisplay,
                            fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: r.spaceXs),
                      Text(
                        L10n.of(context).howAccuracyNote,
                        style: TextStyle(
                            fontSize: r.fontSmall,
                            height: 1.4,
                            color: kInfoSecondaryText),
                      ),
                    ],
                  ),
                ),
                // Every original section is still here, folded away for
                // whoever wants the detail.
                InfoSectionLabel(L10n.of(context).howSectionDetails),
                InfoDetailsCard(items: [
                  (
                    L10n.of(context).aboutHowPpgTitle,
                    L10n.of(context).aboutHowPpgBody
                  ),
                  (
                    L10n.of(context).aboutFingerTitle,
                    L10n.of(context).aboutFingerBody
                  ),
                  (
                    L10n.of(context).aboutBeforeStartTitle,
                    L10n.of(context).aboutBeforeStartBody
                  ),
                  (
                    L10n.of(context).aboutProcessingTitle,
                    L10n.of(context).aboutProcessingBody
                  ),
                  (
                    L10n.of(context).aboutHeartRateTitle,
                    L10n.of(context).aboutHeartRateBody
                  ),
                  (
                    L10n.of(context).aboutGreenChannelTitle,
                    L10n.of(context).aboutGreenChannelBody
                  ),
                  (
                    L10n.of(context).aboutAccuracyTitle,
                    L10n.of(context).aboutAccuracyBody
                  ),
                ]),
                SizedBox(height: r.spaceXl),
              ],
            ),
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
          GButton(icon: Symbols.family_home, text: L10n.of(context).navMenu),
          GButton(icon: Symbols.ecg_heart, text: L10n.of(context).navMeasure),
          GButton(icon: Symbols.help, text: L10n.of(context).navInfo),
        ],
      ),
    );
  }
}
