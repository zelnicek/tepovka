import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/pages/records.dart';
import 'package:tepovka/services/measurement_tags.dart';

Map<String, dynamic> _record({Object? tags}) => {
      'date': '2026-10-16',
      'time': '09:10:00',
      'averageBPM': 72,
      'notes': 'Po obědě',
      'duration': 30,
      if (tags != null) 'tags': tags,
    };

void main() {
  test('reads stored tag names and skips ones it does not know', () {
    expect(MeasurementTag.fromNames(['rest', 'yoga', 'caffeine']),
        [MeasurementTag.rest, MeasurementTag.caffeine]);
  });

  test('only exercise, coffee and stress count as raising the heart rate', () {
    expect(
      MeasurementTag.values.where((t) => t.raisesHeartRate),
      [
        MeasurementTag.exercise,
        MeasurementTag.caffeine,
        MeasurementTag.stress,
      ],
    );
  });

  test('a record keeps its tags and its note through saving', () {
    final Record back = Record.fromJson(
        Record.fromJson(_record(tags: ['morning', 'rest'])).toJson());
    expect(back.measurementTags, [MeasurementTag.morning, MeasurementTag.rest]);
    expect(back.notesContent, 'Po obědě');
  });

  test('older records without tags stay as they were', () {
    final Record old = Record.fromJson(_record());
    expect(old.tags, isEmpty);
    expect(old.toJson().containsKey('tags'), isFalse);
  });
}
