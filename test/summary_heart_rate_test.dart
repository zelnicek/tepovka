import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/pages/summary_page.dart';

/// The result screen shows the heart rate from the feet of the pulse wave,
/// and says so plainly when a recording gives none. It used to put 70 bpm
/// in its place without a word.
void main() {
  Summary summaryOf(List<double> data) => Summary(
        // The live estimate; the screen no longer falls back on it.
        averageBPM: 70,
        data: data,
        bpmList: const [],
        frames: const [],
        recordingDuration: 20,
        startedAt: DateTime(2026, 10, 17, 8),
        respiratoryRate: 0,
        bpmHistory: const [],
        rawRgbSamples: const [],
        sdnn: 0,
        rmssd: 0,
        pnn50: 0,
        sd1: 0,
        sd2: 0,
        spo2: 0,
        bpmConfidence: 0,
        bpmSnrScore: 0,
        bpmHarmonicScore: 0,
        bpmAutocorrScore: 0,
      );

  Future<L10n> pump(WidgetTester tester, List<double> data) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    late L10n t;
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('cs'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
      home: Builder(builder: (context) {
        t = L10n.of(context);
        return summaryOf(data);
      }),
    ));
    await tester.pump();
    return t;
  }

  testWidgets('shows the heart rate from the feet', (tester) async {
    // 72 bpm at 30 frames a second for 20 s, pulses up.
    final List<double> wave = [
      for (int i = 0; i < 600; i++)
        sin(2 * pi * 1.2 * i / 30) + 0.4 * sin(4 * pi * 1.2 * i / 30)
    ];
    final L10n t = await pump(tester, wave);
    expect(find.textContaining('72', findRichText: true), findsWidgets);
    expect(find.text(t.commonSave), findsOneWidget);
    expect(find.text(t.summaryNoHeartRate), findsNothing);
  });

  testWidgets('says when there is no heart rate instead of making one up',
      (tester) async {
    final L10n t = await pump(tester, List.filled(600, 0.0));
    expect(find.text(t.summaryNoHeartRate), findsOneWidget);
    expect(
        find.textContaining(t.homeNoReading, findRichText: true), findsWidgets);
    expect(find.textContaining('70', findRichText: true), findsNothing);
    // Nothing to save; the main button measures again.
    expect(find.text(t.commonSave), findsNothing);
    expect(find.text(t.summaryMeasureAgain), findsOneWidget);
  });
}
