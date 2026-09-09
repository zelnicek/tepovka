import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/app_settings.dart';
import 'package:tepovka/widgets/privacy_consent.dart';

/// Smoke tests for screens that can be built without a camera. The measurement
/// screen needs real hardware, so it is covered by the algorithm tests instead.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Widget wrap(Widget child, {Locale locale = const Locale('cs')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: child,
    );
  }

  testWidgets('consent screen builds and shows both choices', (tester) async {
    await tester.pumpWidget(wrap(const PrivacyConsentPage()));
    await tester.pumpAndSettle();

    final BuildContext context = tester.element(find.byType(PrivacyConsentPage));
    final L10n t = L10n.of(context);

    expect(find.text(t.consentTitle), findsOneWidget);
    expect(find.text(t.consentAgree), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('consent screen builds in English too', (tester) async {
    await tester.pumpWidget(
        wrap(const PrivacyConsentPage(), locale: const Locale('en')));
    await tester.pumpAndSettle();

    expect(find.text('Data processing consent'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('settings defaults are sane before anything is stored', () async {
    await AppSettings.init();
    final s = AppSettings.value;

    expect(s.language, AppLanguage.system);
    expect(s.textScale, 1.0);
    expect(s.researchFields, isNotEmpty);
  });

  test('language preference round-trips through storage', () async {
    await AppSettings.init();
    AppSettings.setLanguage(AppLanguage.english);
    expect(AppSettings.value.language, AppLanguage.english);

    await AppSettings.init(); // re-read from disk
    expect(AppSettings.value.language, AppLanguage.english);
  });
}
