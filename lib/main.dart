import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:tepovka/pages/intro_page.dart';
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
          home: const IntroPage(),
        );
      },
    );
  }
}
