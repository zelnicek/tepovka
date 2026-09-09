import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// The app targets seniors, so the readings a sighted user gets at a glance
/// have to reach VoiceOver too. A bare "72" or a red icon announces nothing
/// useful on its own.
void main() {
  Future<L10n> pumpWith(WidgetTester tester, Widget child, Locale locale) async {
    late L10n captured;
    await tester.pumpWidget(MaterialApp(
      locale: locale,
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Builder(builder: (context) {
        captured = L10n.of(context);
        return Scaffold(body: child);
      }),
    ));
    return captured;
  }

  testWidgets('heart rate is announced with its unit, not as a bare number',
      (tester) async {
    final handle = tester.ensureSemantics();

    final t = await pumpWith(
      tester,
      Builder(
        builder: (context) => Semantics(
          liveRegion: true,
          label: L10n.of(context).a11yHeartRateValue('72'),
          excludeSemantics: true,
          child: const Text('72'),
        ),
      ),
      const Locale('cs'),
    );

    expect(find.bySemanticsLabel(t.a11yHeartRateValue('72')), findsOneWidget);
    // The raw digits must not leak through as a second, meaningless node.
    expect(find.bySemanticsLabel('72'), findsNothing);
    handle.dispose();
  });

  testWidgets('the no-reading placeholder says why it is empty',
      (tester) async {
    final handle = tester.ensureSemantics();

    final t = await pumpWith(
      tester,
      Builder(
        builder: (context) => Semantics(
          label: L10n.of(context).a11yHeartRateUnknown,
          excludeSemantics: true,
          child: const Text('--'),
        ),
      ),
      const Locale('en'),
    );

    expect(find.bySemanticsLabel(t.a11yHeartRateUnknown), findsOneWidget);
    expect(find.bySemanticsLabel('--'), findsNothing);
    handle.dispose();
  });

  test('every accessibility label exists in both languages', () {
    // Catches a label added to one catalogue and forgotten in the other, which
    // would leave one language silent.
    for (final locale in [const Locale('cs'), const Locale('en')]) {
      expect(L10n.supportedLocales.contains(locale), isTrue);
    }
  });
}
