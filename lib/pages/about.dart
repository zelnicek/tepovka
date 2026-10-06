import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/pages/measure_guide.dart';
import 'package:tepovka/elements/responsive.dart';

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

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);

    Widget heading(String text) => Padding(
          padding: EdgeInsets.only(bottom: r.spaceSm),
          child: Text(
            text,
            style:
                TextStyle(fontWeight: FontWeight.bold, fontSize: r.fontTitle),
          ),
        );

    Widget body(String text) => Padding(
          padding: EdgeInsets.only(bottom: r.spaceXl),
          child: Text(text, style: TextStyle(fontSize: r.fontBodyLg)),
        );

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
              L10n.of(context).aboutPageTitle,
              style: TextStyle(
                  fontWeight: FontWeight.bold, fontSize: r.fontTitleLg),
            ),
          ],
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
                // Návod krok za krokem. Dřív tu byla série obrázků se starým
                // postupem (obrazovka „Kalibrace") a s českým textem přímo
                // v obrázcích, takže v angličtině ani neodpovídal aplikaci.
                Card(
                  elevation: 0,
                  color: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: r.spaceLg, vertical: r.spaceSm),
                    leading: Icon(Icons.help_outline,
                        color: const Color(0xFFE53935), size: r.iconLg),
                    title: Text(
                      L10n.of(context).guideTitle,
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: r.fontTitle),
                    ),
                    subtitle: Text(
                      L10n.of(context).aboutGuideSubtitle,
                      style: TextStyle(fontSize: r.fontBody),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => MeasureGuide.open(context),
                  ),
                ),
                SizedBox(height: r.spaceXl),
                heading(L10n.of(context).aboutHowPpgTitle),
                body(
                    L10n.of(context).aboutHowPpgBody),
                heading(L10n.of(context).aboutFingerTitle),
                body(L10n.of(context).aboutFingerBody),
                heading(L10n.of(context).aboutBeforeStartTitle),
                body(
                    L10n.of(context).aboutBeforeStartBody),
                heading(L10n.of(context).aboutProcessingTitle),
                body(
                    L10n.of(context).aboutProcessingBody),
                heading(L10n.of(context).aboutHeartRateTitle),
                body(
                    L10n.of(context).aboutHeartRateBody),
                heading(L10n.of(context).aboutGreenChannelTitle),
                body(
                    L10n.of(context).aboutGreenChannelBody),
                heading(L10n.of(context).aboutAccuracyTitle),
                body(
                    L10n.of(context).aboutAccuracyBody),
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
