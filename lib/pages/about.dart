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
                          padding: EdgeInsets.symmetric(horizontal: r.spaceSm),
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
                    'Fotopletysmografie (PPG) měří změny objemu krve v cévách pod pokožkou. '
                    'S každým tepem projde prstem víc krve, ta pohltí víc světla a snímek z kamery '
                    'na okamžik potemní. Aplikace z každého snímku spočítá průměrný jas v ploše '
                    'pod prstem a z toho, jak se v čase mění, odečte tep.'),
                heading('Jak správně přiložit prst?'),
                body('1. Ujistěte se, že máte čistý prst bez nečistot.\n'
                    '2. Jemně přiložte prst na kameru tak, aby ji zcela zakrýval.\n'
                    '3. Nepřikládejte prst příliš silně, aby nedošlo ke zkreslení signálu.\n'
                    '4. Svítilna se zapne sama během odpočtu — nechte prst v klidu, než měření začne.'),
                heading('Co se děje před začátkem měření'),
                body(
                    'Během odpočtu 3–2–1 aplikace rozsvítí svítilnu, počká, až se ustálí automatika '
                    'kamery, a zamkne expozici i zaostření. Bez zámku by automatika kompenzovala '
                    'právě ty změny jasu, které tep tvoří. Teprve pak začne samotný záznam, aby '
                    'jeho začátek nebyl zatížený rozsvěcením a rozjezdem filtrů.'),
                heading('Jak se signál zpracovává'),
                body(
                    '1. Z každého snímku se vezme průměr zeleného kanálu v ploše pod prstem; '
                    'když je zelená příliš tmavá, použije se červený kanál.\n'
                    '2. Adaptivní filtr s údaji z akcelerometru potlačí vliv pohybu ruky.\n'
                    '3. Následuje mediánový filtr proti ojedinělým výkyvům, odečtení pomalu se '
                    'měnící složky (dýchání, prokrvení) a jemné vyhlazení.\n'
                    '4. Kamera nedodává snímky přesně pravidelně, proto se pracuje se skutečnou '
                    'snímkovací frekvencí měřenou z časových značek snímků — v praxi bývá kolem '
                    '24 snímků za sekundu, ne 30.'),
                heading('Jak se vypočítá tepová frekvence?'),
                body(
                    'Během měření se tep odhaduje ze spektra signálu a z autokorelace v posledních '
                    'sekundách; když je odhad málo spolehlivý, aplikace raději nic nezobrazí, než '
                    'aby ukázala nepodložené číslo.\n'
                    'Ve výsledku a v historii se pak tep počítá z detekovaných vrcholů: najdou se '
                    'špičky odpovídající jednotlivým tepům, změří se intervaly mezi nimi a tep '
                    'vyjde jako 60 ÷ průměrný interval v sekundách. Poloha každé špičky se '
                    'dopočítává i mezi snímky, aby intervaly nebyly omezené krokem snímání.'),
                heading('Proč zelený kanál?'),
                body(
                    'Zelené světlo pohlcuje hemoglobin nejsilněji, takže se v něm změny prokrvení '
                    'projeví nejvýrazněji. Červený kanál se přes prst přesvítí snáz, a slouží proto '
                    'jako záloha, když je zelená příliš tmavá.'),
                heading('Jak přesné to je'),
                body(
                    'Zpracování jsme v srpnu 2026 ověřovali proti EKG holteru Bittium Faros 180 '
                    'a pulznímu oxymetru na měřeních s 13 účastníky. Na uložených záznamech '
                    'přepočtených stejným detektorem, jaký používá aplikace, se tep shodoval '
                    's EKG s průměrnou odchylkou pod 2 bpm — srovnatelně s tím, jak si odpovídají '
                    'oba referenční přístroje navzájem.\n'
                    'Přesnost ale závisí na kvalitě signálu: při pohybu, slabém prokrvení nebo '
                    'špatně přiloženém prstu je odhad výrazně horší. U každého měření proto '
                    'najdete i hodnocení kvality — měření označené jako špatné neberte vážně.\n'
                    'Parametry variability (SDNN, RMSSD) berte jen orientačně; na ně je snímkovací '
                    'frekvence kamery hrubá. Aplikace není zdravotnický prostředek a neslouží '
                    'k diagnostice.'),
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
