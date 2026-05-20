import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tepovka/pages/medical_disclaimer_page.dart';
import 'package:tepovka/theme.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/services/local_profile_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSettings.init();
  await LocalProfileService.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppSettingsData>(
      valueListenable: AppSettings.notifier,
      builder: (context, settings, _) {
        // Choose base theme
        ThemeData baseTheme =
            settings.highContrast ? AppTheme.highContrastLight : AppTheme.light;

        // Apply senior-friendly adjustments when enabled
        if (settings.seniorMode) {
          baseTheme = baseTheme.copyWith(
            materialTapTargetSize: MaterialTapTargetSize.padded,
            iconButtonTheme: IconButtonThemeData(
              style: IconButton.styleFrom(iconSize: 28),
            ),
            textTheme: baseTheme.textTheme.copyWith(
              titleLarge:
                  baseTheme.textTheme.titleLarge?.copyWith(fontSize: 24),
              titleMedium:
                  baseTheme.textTheme.titleMedium?.copyWith(fontSize: 22),
              bodyLarge: baseTheme.textTheme.bodyLarge?.copyWith(fontSize: 18),
              bodyMedium:
                  baseTheme.textTheme.bodyMedium?.copyWith(fontSize: 16),
            ),
          );
        }

        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: baseTheme,
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
          builder: (context, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.textScale),
              ),
              child: child!,
            );
          },
          home: const AnimatedSplashScreen(),
        );
      },
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
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (context) => const MedicalDisclaimerPage()),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final shortestSide =
            constraints.biggest.shortestSide.clamp(0.0, double.infinity);
        final imageWidth = (shortestSide * 0.72).clamp(220.0, 320.0);
        final imageHeight = imageWidth * (174 / 285);

        return Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _animation.value,
                  child: SizedBox(
                    width: imageWidth,
                    height: imageHeight,
                    child: Image.asset(
                      'assets/tepovka.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}
