import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// Guards the localisation groundwork: both catalogues must stay in step, and
/// the app must actually resolve to the right one.
Future<L10n> _load(WidgetTester tester, Locale locale) async {
  late L10n captured;
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    localizationsDelegates: L10n.localizationsDelegates,
    supportedLocales: L10n.supportedLocales,
    home: Builder(builder: (context) {
      captured = L10n.of(context);
      return const SizedBox.shrink();
    }),
  ));
  return captured;
}

void main() {
  test('every Czech key has an English translation and vice versa', () {
    Map<String, dynamic> read(String path) =>
        json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;

    final cs = read('lib/l10n/app_cs.arb').keys
        .where((k) => !k.startsWith('@'))
        .toSet();
    final en = read('lib/l10n/app_en.arb').keys
        .where((k) => !k.startsWith('@'))
        .toSet();

    expect(cs.difference(en), isEmpty, reason: 'missing English translations');
    expect(en.difference(cs), isEmpty, reason: 'orphaned English keys');
    expect(cs, isNotEmpty);
  });

  testWidgets('resolves Czech', (tester) async {
    final t = await _load(tester, const Locale('cs'));
    expect(t.homeReady, 'Připraveno k měření');
    expect(t.qualityGood, 'Dobrá');
  });

  testWidgets('resolves English', (tester) async {
    final t = await _load(tester, const Locale('en'));
    expect(t.homeReady, 'Ready to measure');
    expect(t.qualityGood, 'Good');
  });

  testWidgets('placeholders substitute in both languages', (tester) async {
    final cs = await _load(tester, const Locale('cs'));
    expect(cs.recordsDeleteSelected(3), contains('3'));
    expect(cs.metricsBreathsPerMinute('12.4'), contains('12.4'));

    final en = await _load(tester, const Locale('en'));
    expect(en.recordsDeleteSelected(3), 'Delete selected (3)');
    expect(en.metricsBreathsPerMinute('12.4'), '12.4 breaths/min');
  });

  testWidgets('trend caption declines the Czech plural correctly',
      (tester) async {
    // Czech counts take different forms: "poslední 3 měření" but
    // "posledních 5 měření". A single template would be wrong for one of them.
    final cs = await _load(tester, const Locale('cs'));
    expect(cs.homeTrendCaption(2, '70'), 'Poslední 2 měření · průměr 70 bpm');
    expect(cs.homeTrendCaption(4, '70'), 'Poslední 4 měření · průměr 70 bpm');
    expect(cs.homeTrendCaption(5, '70'), 'Posledních 5 měření · průměr 70 bpm');
    expect(cs.homeTrendCaption(7, '70'), 'Posledních 7 měření · průměr 70 bpm');

    final en = await _load(tester, const Locale('en'));
    expect(en.homeTrendCaption(3, '70'), 'Last 3 measurements · average 70 bpm');
  });
}
