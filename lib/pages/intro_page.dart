import 'package:flutter/material.dart';
import 'package:tepovka/pages/about.dart';
import 'package:tepovka/pages/info_app.dart';

import 'package:tepovka/pages/records.dart';
import 'package:google_nav_bar/google_nav_bar.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:flutter/services.dart';
import 'package:tepovka/home.dart';

class IntroPage extends StatefulWidget {
  const IntroPage({super.key});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  bool _isTapped = false;
  bool _isTapped2 = false;
  bool _isTapped3 = false;
  bool _isTapped4 = false;
  int _selectedIndex = 0;
  bool _is_medical = false;

  void _onItemTapped(int index) {
    if (_selectedIndex == index) {
      // Pokud je karta již vybraná, nedělejte nic
      return;
    }
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
          MaterialPageRoute(builder: (context) => const About()),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final double screenHeight = MediaQuery.sizeOf(context).height;
    final double cardWidthFull = screenWidth * 0.9;
    final double cardHeight = screenHeight * 0.18;
    final double cardWidthHalf = (screenWidth / 2) - (screenWidth * 0.05);
    final double paddingSmall = screenWidth * 0.02;
    final double paddingMedium = screenWidth * 0.04;
    final double fontSizeLarge = screenWidth * 0.05;
    final double fontSizeMedium = screenWidth * 0.045;
    final double fontSizeSmall = screenWidth * 0.04;
    final double imageScaleFull = screenWidth * 0.0015;
    final double imageScaleHalf = screenWidth * 0.0018;
    final double iconSize = screenWidth * 0.06;

    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 242, 242, 242),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color.fromARGB(255, 242, 242, 242),
        centerTitle: true,
        elevation: 0,
        title: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'DOMOVSKÁ STRÁNKA',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 20,
              ),
            ),
          ],
        ),
      ),
      body: Center(
          child: Column(children: [
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() {
              _isTapped = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              _isTapped = false;
            });

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => Home()),
            );
          },
          onTapCancel: () {
            setState(() {
              _isTapped = false;
            });
          },
          child: AnimatedScale(
            scale: _isTapped ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(paddingSmall),
                  child: Container(
                    margin: EdgeInsets.only(top: paddingSmall),
                    padding: const EdgeInsets.only(top: 0),
                    width: cardWidthFull,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'ZAČÍT MĚŘENÍ',
                          style: TextStyle(
                            fontSize: fontSizeMedium,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  right: -5,
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: EdgeInsets.only(top: 0, bottom: paddingMedium),
                      child: Transform.scale(
                        scale: imageScaleFull,
                        child: Image.asset(
                          'assets/ppg.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        GestureDetector(
          onTapDown: (_) {
            HapticFeedback.selectionClick();
            setState(() {
              _isTapped2 = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              _isTapped2 = false;
            });

            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const RecordsPage()),
            );
          },
          onTapCancel: () {
            setState(() {
              _isTapped2 = false;
            });
          },
          child: AnimatedScale(
            scale: _isTapped2 ? 0.9 : 1.0,
            duration: const Duration(milliseconds: 100),
            child: Stack(
              children: [
                Padding(
                  padding: EdgeInsets.all(paddingSmall),
                  child: Container(
                    margin: EdgeInsets.only(top: paddingSmall),
                    padding: const EdgeInsets.only(top: 0),
                    width: cardWidthFull,
                    height: cardHeight,
                    decoration: BoxDecoration(
                      color: const Color.fromARGB(255, 255, 255, 255),
                      border: Border.all(
                        color: Colors.white,
                        width: 3,
                      ),
                      borderRadius: const BorderRadius.all(
                        Radius.circular(15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          spreadRadius: 0,
                          blurRadius: 10,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          'ZÁZNAMY',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color.fromARGB(255, 0, 0, 0),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                Positioned.fill(
                  right: 0,
                  bottom: paddingMedium,
                  child: Transform.scale(
                    scale: imageScaleFull * 0.95,
                    child: Image.asset(
                      'assets/folder.png',
                      fit: BoxFit.fitHeight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTapDown: (_) {
                HapticFeedback.selectionClick();
                setState(() {
                  _isTapped3 = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _isTapped3 = false;
                });
                // Navigate to the next page
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const About()),
                );
              },
              onTapCancel: () {
                setState(() {
                  _isTapped3 = false;
                });
              },
              child: AnimatedScale(
                scale: _isTapped3 ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(paddingSmall),
                      child: Container(
                        margin: EdgeInsets.only(top: paddingSmall),
                        padding: const EdgeInsets.only(top: 0),
                        width: cardWidthHalf,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'JAK TO FUNGUJE?',
                              style: TextStyle(
                                fontSize: fontSizeSmall,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      right: 0,
                      bottom: paddingMedium,
                      child: Transform.scale(
                        scale: imageScaleHalf,
                        child: Image.asset(
                          'assets/Help2.png',
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            GestureDetector(
              onTapDown: (_) {
                HapticFeedback.selectionClick();
                setState(() {
                  _isTapped4 = true;
                });
              },
              onTapUp: (_) {
                setState(() {
                  _isTapped4 = false;
                });

                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfoApp()),
                );
              },
              onTapCancel: () {
                setState(() {
                  _isTapped4 = false;
                });
              },
              child: AnimatedScale(
                scale: _isTapped4 ? 0.9 : 1.0,
                duration: const Duration(milliseconds: 100),
                child: Stack(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(paddingSmall),
                      child: Container(
                        margin: EdgeInsets.only(top: paddingSmall),
                        padding: const EdgeInsets.only(top: 0),
                        width: cardWidthHalf,
                        height: cardHeight,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 255, 255, 255),
                          border: Border.all(
                            color: Colors.white,
                            width: 3,
                          ),
                          borderRadius: const BorderRadius.all(
                            Radius.circular(15),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              spreadRadius: 0,
                              blurRadius: 10,
                              offset: const Offset(0, 0),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'O APLIKACI',
                              style: TextStyle(
                                fontSize: fontSizeSmall,
                                color: Color.fromARGB(255, 0, 0, 0),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned.fill(
                      right: 0,
                      bottom: paddingMedium,
                      child: Transform.scale(
                        scale: imageScaleHalf * 0.85,
                        child: Image.asset(
                          'assets/tepovka.png',
                          fit: BoxFit.fitHeight,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        Container(
          margin: EdgeInsets.only(top: paddingSmall),
          width: screenWidth * 0.5,
          child: Padding(
            padding: EdgeInsets.only(top: paddingMedium, bottom: paddingMedium),
            child: Image.asset(
              'assets/Text_loading.png',
              opacity: const AlwaysStoppedAnimation(.5),
            ),
          ),
        ),
      ])),
      bottomNavigationBar: GNav(
        tabMargin: EdgeInsets.symmetric(horizontal: paddingSmall),
        gap: paddingSmall,
        activeColor: Colors.black,
        iconSize: iconSize,
        haptic: true,
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
