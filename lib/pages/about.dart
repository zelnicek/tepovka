import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:card_swiper/card_swiper.dart';
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
    final double swiperHeight = (r.height * 0.48).clamp(220.0, 460.0);

    Widget heading(String text) => Padding(
          padding: EdgeInsets.only(bottom: r.spaceSm),
          child: Text(
            text,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: r.fontTitle),
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
              'JAK TO FUNGUJE?',
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
                Center(
                  child: SizedBox(
                    width: r.width,
                    height: swiperHeight,
                    child: Swiper(
                      itemBuilder: (BuildContext context, int index) {
                        return Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: r.spaceSm),
                          child: Image.asset(
                            'assets/swipe/Quide${index + 1}.png',
                            fit: BoxFit.contain,
                          ),
                        );
                      },
                      itemCount: 7,
                      pagination: const SwiperPagination(
                        alignment: Alignment.bottomCenter,
                        builder: DotSwiperPaginationBuilder(
                          activeColor: Colors.blue,
                          color: Color.fromARGB(255, 202, 202, 202),
                          size: 8.0,
                          activeSize: 12.0,
                        ),
                      ),
                      control: const SwiperControl(color: Colors.black),
                    ),
                  ),
                ),
                SizedBox(height: r.spaceXl),
                heading('Jak funguje PPG měření?'),
                body(
                    'Fotopletysmografie (PPG) měří změny objemu krve v cévách pod pokožkou. Kamera telefonu snímá intenzitu zeleného světla, které je pohlcováno krví, a analyzuje tyto změny v průběhu času.'),
                heading('Jak správně přiložit prst?'),
                body(
                    '1. Ujistěte se, že máte čistý prst bez nečistot.\n'
                    '2. Jemně přiložte prst na kameru tak, aby ji zcela zakrýval.\n'
                    '3. Nepřikládejte prst příliš silně, aby nedošlo ke zkreslení signálu.\n'
                    '4. Aktivujte blesk pro lepší průchod světla pokožkou.'),
                heading('Jak se vypočítá tepová frekvence?'),
                body(
                    'Algoritmus zpracuje zachycený signál následujícím způsobem:\n'
                    '1. Detekuje špičky (peaky) v signálu odpovídající srdečním tepům.\n'
                    '2. Spočítá časové rozdíly mezi špičkami (intervaly RR).\n'
                    '3. Z těchto intervalů vypočítá tepovou frekvenci (BPM) podle vzorce:\n'
                    '   BPM = 60 ÷ průměrný interval RR (v sekundách).'),
                heading('Proč zelený kanál?'),
                body(
                    'Zelené světlo je nejlépe absorbováno hemoglobinem v krvi, díky čemuž poskytuje nejpřesnější data pro analýzu průtoku krve.'),
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
        tabs: const [
          GButton(icon: Symbols.family_home, text: 'MENU'),
          GButton(icon: Symbols.ecg_heart, text: 'MĚŘENÍ'),
          GButton(icon: Symbols.help, text: 'INFO'),
        ],
      ),
    );
  }
}
