import 'package:flutter/material.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/home.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:card_swiper/card_swiper.dart';

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
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'JAK TO FUNGUJE?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Scrollbar(
        thumbVisibility:
            true, // Zajistí, že je posuvník viditelný při posouvání
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: SizedBox(
                  height: 600, // Nastavení výšky Swiperu
                  child: Swiper(
                    itemBuilder: (BuildContext context, int index) {
                      return Image.asset(
                        'assets/swipe/Quide${index + 1}.png', // Cesta k obrázkům
                        fit: BoxFit.scaleDown,
                      );
                    },
                    itemCount: 7, // Počet obrázků
                    pagination: const SwiperPagination(
                      alignment: Alignment.bottomCenter, // Zarovnání teček
                      builder: DotSwiperPaginationBuilder(
                        activeColor: Colors.blue,
                        color: Color.fromARGB(255, 202, 202, 202),
                        size: 8.0,
                        activeSize: 12.0,
                      ),
                    ), // Zobrazení teček pro stránkování
                    control: const SwiperControl(
                      color: Colors.black, // Navigační šipky
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Jak funguje PPG měření?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Fotopletysmografie (PPG) měří změny objemu krve v cévách pod pokožkou. "
                "Kamera telefonu snímá intenzitu zeleného světla, které je pohlcováno krví, a analyzuje tyto změny v průběhu času.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                "Jak správně přiložit prst?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "1. Ujistěte se, že máte čistý prst bez nečistot.\n"
                "2. Jemně přiložte prst na kameru tak, aby ji zcela zakrýval.\n"
                "3. Nepřikládejte prst příliš silně, aby nedošlo ke zkreslení signálu.\n"
                "4. Aktivujte blesk pro lepší průchod světla pokožkou.",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                "Jak se vypočítá tepová frekvence?",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 10),
              const Text(
                "Algoritmus zpracuje zachycený signál následujícím způsobem:\n"
                "1. Detekuje špičky (peaky) v signálu odpovídající srdečním tepům.\n"
                "2. Spočítá časové rozdíly mezi špičkami (intervaly RR).\n"
                "3. Z těchto intervalů vypočítá tepovou frekvenci (BPM) podle vzorce:\n"
                "   BPM = 60 ÷ průměrný interval RR (v sekundách).",
                style: TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              const Text(
                "Proč zelený kanál?",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Zelené světlo je nejlépe absorbováno hemoglobinem v krvi, díky čemuž poskytuje nejpřesnější data pro analýzu průtoku krve.",
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: GNav(
        gap: 0,
        activeColor: Colors.black,
        iconSize: 24,
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
