import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tepovka/pages/intro_page.dart';
import 'package:tepovka/theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // Force light theme everywhere
      themeMode: ThemeMode.light,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('cs'),
        Locale('en'),
      ],
      home: const AnimatedSplashScreen(),
    );
  }
}

class AnimatedSplashScreen extends StatefulWidget {
  const AnimatedSplashScreen({super.key});

  @override
  _AnimatedSplashScreenState createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  // Tyto hodnoty musíš nahradit podle hodnot z LaunchScreen
  final double x = 55; // X pozice
  final double y = 270; // Y pozice
  final double width = 285; // Šířka obrázku
  final double height = 174; // Výška obrázku

  @override
  void initState() {
    super.initState();

    // Nastavení animace
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _animation = Tween<double>(begin: 1.0, end: 0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInBack),
    );

    _controller.forward();

    // Přesun na hlavní obrazovku po dokončení animace
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const IntroPage()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Nastavení pozadí
      body: Stack(
        children: [
          // Umístění animovaného obrázku s použitím hodnot pro X, Y, Width, Height
          Positioned(
            left: x,
            top: y,
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: Image.asset('assets/tepovka.png',
                      width: width, height: height), // Nahraď obrázkem
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
