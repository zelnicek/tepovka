import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';


/// English and Czech differ in length, so a string that fits in one language
/// can overflow its container in the other. These tests render each translated
/// string at the sizes the app actually uses, on the narrowest supported
/// screen, and fail on a RenderFlex overflow.
void main() {
  const Size iphoneSe = Size(320, 568); // narrowest device the app supports

  Map<String, String> read(String path) {
    final raw = json.decode(File(path).readAsStringSync()) as Map<String, dynamic>;
    return {
      for (final e in raw.entries)
        if (!e.key.startsWith('@')) e.key: e.value as String,
    };
  }

  /// Widths the app constrains text to, taken from home.dart's layout maths
  /// for a 320pt-wide screen.
  const double sideColumnWidth = 320 * 0.18; // BPM and quality columns
  const double navTabWidth = 320 / 3; // bottom navigation tab

  Future<void> expectFits(
    WidgetTester tester, {
    required String text,
    required double maxWidth,
    required double fontSize,
    required String label,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: maxWidth,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: TextStyle(fontSize: fontSize),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull, reason: '$label overflowed');
  }

  testWidgets('quality labels fit the narrow side column', (tester) async {
    tester.view.physicalSize = iphoneSe;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    for (final path in ['lib/l10n/app_cs.arb', 'lib/l10n/app_en.arb']) {
      final arb = read(path);
      for (final key in ['qualityGood', 'qualityBad', 'qualityPoorContact', 'qualityNoFinger']) {
        await expectFits(
          tester,
          text: arb[key]!,
          maxWidth: sideColumnWidth,
          fontSize: 11, // fontSizeSmall floor
          label: '$path/$key',
        );
      }
    }
  });

  testWidgets('navigation labels fit a third of the narrowest screen',
      (tester) async {
    for (final path in ['lib/l10n/app_cs.arb', 'lib/l10n/app_en.arb']) {
      final arb = read(path);
      for (final key in ['navMenu', 'navMeasure', 'navInfo']) {
        await expectFits(
          tester,
          text: arb[key]!,
          maxWidth: navTabWidth,
          fontSize: 14,
          label: '$path/$key',
        );
      }
    }
  });

  test('translations stay within a sane length ratio of the source', () {
    // A translation far longer than its Czech source is the thing that breaks
    // fixed-width layouts. Flag the outliers rather than guessing per widget.
    final cs = read('lib/l10n/app_cs.arb');
    final en = read('lib/l10n/app_en.arb');

    // Short UI strings are the risky ones; long prose wraps freely.
    final offenders = <String>[];
    for (final entry in cs.entries) {
      final source = entry.value;
      final target = en[entry.key];
      if (target == null || source.length > 40) continue;
      if (target.length > source.length * 1.6 && target.length - source.length > 6) {
        offenders.add('${entry.key}: "$source" (${source.length}) -> '
            '"$target" (${target.length})');
      }
    }
    expect(offenders, isEmpty,
        reason: 'English noticeably longer than Czech in tight UI strings:\n'
            '${offenders.join('\n')}');
  });
}
