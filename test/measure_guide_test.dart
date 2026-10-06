import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tepovka/elements/signal_quality_checker.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/pages/measure_guide.dart';

/// Návod musí přečíst a projít i člověk, který aplikaci nikdy neviděl, na
/// nejužším podporovaném telefonu a v obou jazycích.
void main() {
  const Size iphoneSe = Size(320, 568);

  setUp(() => SharedPreferences.setMockInitialValues({}));

  /// Aplikace s tlačítkem, které návod otevře, jako to dělá obrazovka měření.
  Widget host(Locale locale) => MaterialApp(
        locale: locale,
        localizationsDelegates: L10n.localizationsDelegates,
        supportedLocales: L10n.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => MeasureGuide.open(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );

  Future<void> openGuide(WidgetTester tester, Locale locale) async {
    tester.view.physicalSize = iphoneSe * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(host(locale));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  for (final locale in const [Locale('cs'), Locale('en')]) {
    testWidgets('celý návod se projde a vejde na iPhone SE ($locale)', (tester) async {
      await openGuide(tester, locale);
      final t = lookupL10n(locale);
      final titles = [
        t.guideRestTitle,
        t.guideCoverTitle,
        t.guidePreviewTitle,
        t.guideStillTitle,
        t.guideResultTitle,
      ];

      for (var i = 0; i < titles.length; i++) {
        expect(find.text(titles[i]), findsOneWidget, reason: 'krok ${i + 1}');
        expect(tester.takeException(), isNull, reason: 'krok ${i + 1} přetekl');
        final last = i == titles.length - 1;
        // Přeskočit je na všech krocích kromě posledního.
        expect(find.text(t.guideSkip), last ? findsNothing : findsOneWidget);
        await tester.tap(find.text(last ? t.guideDone : t.guideNext));
        await tester.pumpAndSettle();
      }

      // Poslední tlačítko návod zavře a vrátí uživatele na měření.
      expect(find.byType(MeasureGuide), findsNothing);
      expect(find.text('open'), findsOneWidget);
    });
  }

  testWidgets('poslední krok připomene, že nejde o zdravotnický prostředek',
      (tester) async {
    await openGuide(tester, const Locale('cs'));
    final t = lookupL10n(const Locale('cs'));
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.text(t.guideNext));
      await tester.pumpAndSettle();
    }
    expect(find.text(t.guideDisclaimer), findsOneWidget);
  });

  testWidgets('Přeskočit návod zavře', (tester) async {
    await openGuide(tester, const Locale('cs'));
    await tester.tap(find.text(lookupL10n(const Locale('cs')).guideSkip));
    await tester.pumpAndSettle();
    expect(find.byType(MeasureGuide), findsNothing);
  });

  testWidgets('po prvním otevření se návod sám neukáže znovu', (tester) async {
    expect(await MeasureGuide.shouldShowOnFirstVisit(), isTrue);
    await openGuide(tester, const Locale('cs'));
    expect(await MeasureGuide.shouldShowOnFirstVisit(), isFalse);
  });

  test('každý stav signálu má vlastní pokyn v obou jazycích', () {
    for (final locale in const [Locale('cs'), Locale('en')]) {
      final t = lookupL10n(locale);
      final hints = SignalQuality.values.map((q) => measureHint(t, q)).toList();
      expect(hints.every((h) => h.isNotEmpty), isTrue);
      expect(hints.toSet().length, SignalQuality.values.length,
          reason: 'pokyny se nesmí opakovat ($locale)');
    }
  });
}
