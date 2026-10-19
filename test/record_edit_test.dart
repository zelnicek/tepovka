import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/pages/records.dart';
import 'package:tepovka/services/app_settings.dart';

Map<String, dynamic> stored(String time, {List<String>? tags}) => {
      'date': '2026-10-19',
      'time': time,
      'averageBPM': 0,
      'notes': 'puvodni',
      'dataForPlot': [1.0, 2.0],
      if (tags != null) 'tags': tags,
      'footTimesSec': [0.5, 1.4],
    };

void main() {
  group('patchRecords', () {
    test('changes only the named record and only the given fields', () {
      final List<Map<String, dynamic>> history = [
        stored('08:00:00'),
        stored('09:00:00', tags: ['rest']),
      ];
      final out = patchRecords(history, {
        '2026-10-19_09:00:00': {
          'notes': 'po kave',
          'tags': ['caffeine'],
        },
      });
      expect(out.first, history.first);
      expect(out.last['notes'], 'po kave');
      expect(out.last['tags'], ['caffeine']);
      // A value the list computes in memory is not written.
      expect(out.last['averageBPM'], 0);
      // Fields this version does not know survive.
      expect(out.last['footTimesSec'], [0.5, 1.4]);
    });

    test('a null value removes the field', () {
      final out = patchRecords([
        stored('09:00:00', tags: ['rest'])
      ], {
        '2026-10-19_09:00:00': {'tags': null},
      });
      expect(out.single.containsKey('tags'), isFalse);
    });

    test('a key that names no record changes nothing', () {
      final history = [stored('08:00:00')];
      expect(
          patchRecords(history, {
            '2026-10-19_10:00:00': {'notes': 'x'}
          }),
          history);
    });
  });

  group('Record', () {
    test('copyWithJson keeps the rest of the record', () {
      final Record r = Record.fromJson(stored('09:00:00', tags: ['rest']));
      final Record edited = r.copyWithJson({
        'tags': ['morning', 'rest'],
        'notes': 'nova',
      });
      expect(edited.tags, ['morning', 'rest']);
      expect(edited.notesContent, 'nova');
      expect(edited.dataForPlot, r.dataForPlot);
      expect(edited.extra['footTimesSec'], [0.5, 1.4]);
    });

    test('measuredFrameRate comes from the frame times', () {
      final Record r = Record.fromJson({
        ...stored('09:00:00'),
        'frameTimestampsMs': [
          for (int i = 0; i < 25; i++) 1000 + i * 1000 ~/ 24
        ],
      });
      expect(r.measuredFrameRate, 24);
    });

    test('measuredFrameRate is null with nothing to measure it from', () {
      final Record r = Record.fromJson({
        'date': '2026-10-19',
        'time': '09:00:00',
        'duration': 30,
      });
      expect(r.measuredFrameRate, isNull);
    });
  });

  group('combinedTextScale', () {
    test('the iPhone setting and the slider multiply', () {
      expect(combinedTextScale(1.1, 1.2), closeTo(1.32, 1e-9));
    });

    test('stays within the range the screens are laid out for', () {
      expect(combinedTextScale(3.0, 1.4), kMaxTextScale);
      expect(combinedTextScale(0.5, 1.0), kMinTextScale);
      expect(combinedTextScale(1.0, 1.0), 1.0);
    });
  });
}
