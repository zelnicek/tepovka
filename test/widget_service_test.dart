import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/widget_service.dart';

Map<String, dynamic> _record(String startedAt, int bpm, {String? level}) => {
      'date': startedAt.substring(0, 10),
      'time': startedAt.substring(11, 19),
      'startedAt': startedAt,
      'averageBPM': bpm,
      if (level != null) 'signalQuality': {'level': level},
    };

void main() {
  final L10n cs = lookupL10n(const Locale('cs'));

  test('shows the latest reading with a heart rate, whatever the order', () {
    final Map<String, Object?> p = WidgetService.payload([
      _record('2026-10-16T09:10:00', 72, level: 'good'),
      _record('2026-10-14T19:40:00', 69),
      _record('2026-10-16T09:20:00', 0, level: 'poor'), // no reading
      _record('2026-10-15T08:15:00', 75),
    ], cs, 'cs');
    expect(p['bpm'], 72);
    expect(p['quality'], 'good');
    expect(
        p['atMs'],
        DateTime.parse('2026-10-16T09:10:00')
            .millisecondsSinceEpoch
            .toDouble());
    expect(p['recent'], [69, 75, 72]);
    expect((p['labels'] as Map)['measure'], 'Změřit tep');
  });

  test('keeps only the last seven for the bars', () {
    final Map<String, Object?> p = WidgetService.payload([
      for (int day = 1; day <= 10; day++)
        _record('2026-10-${day.toString().padLeft(2, '0')}T08:00:00', 60 + day),
    ], cs, 'cs');
    expect(p['recent'], [64, 65, 66, 67, 68, 69, 70]);
  });

  test('says there is nothing yet when the history is empty', () {
    final Map<String, Object?> p = WidgetService.payload([], cs, 'cs');
    expect(p['bpm'], isNull);
    expect(p['atMs'], isNull);
    expect(p['recent'], isEmpty);
    expect((p['labels'] as Map)['empty'], cs.homeNoMeasurementsTitle);
  });
}
