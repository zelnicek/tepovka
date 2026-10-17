import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/pages/records.dart';
import 'package:tepovka/services/measurement_watch.dart';

void main() {
  group('MotionMonitor', () {
    test('a still phone is not moving', () {
      final m = MotionMonitor();
      for (int i = 0; i < 30; i++) {
        m.add(0.03, -0.02, 0.04);
      }
      expect(m.moving, isFalse);
    });

    test('walking is moving, and it settles again once still', () {
      final m = MotionMonitor();
      for (int i = 0; i < 15; i++) {
        m.add(i.isEven ? 1.5 : -1.2, 0.4, 0.8);
      }
      expect(m.moving, isTrue);
      for (int i = 0; i < 15; i++) {
        m.add(0.02, 0.01, 0.02);
      }
      expect(m.moving, isFalse);
    });

    test('a reading between the thresholds keeps the last state', () {
      final m = MotionMonitor();
      for (int i = 0; i < 15; i++) {
        m.add(0.4, 0, 0);
      }
      // 0.4 m/s² is below the start but above the stop threshold.
      expect(m.moving, isFalse);
      for (int i = 0; i < 15; i++) {
        m.add(1.0, 0, 0);
      }
      for (int i = 0; i < 15; i++) {
        m.add(0.4, 0, 0);
      }
      expect(m.moving, isTrue);
    });
  });

  group('extending the measurement', () {
    SteadinessLog log(int seconds, {int moving = 0, int noRate = 0}) {
      final l = SteadinessLog();
      for (int i = 0; i < seconds; i++) {
        l.add(movingSecond: i < moving, heartRateFound: i >= noRate);
      }
      return l;
    }

    test('a steady recording ends on time', () {
      expect(shouldExtendMeasurement(log(30), alreadyExtended: false), isFalse);
    });

    test('a third of it moving or without a heart rate runs on, once', () {
      expect(
          shouldExtendMeasurement(log(30, moving: 10), alreadyExtended: false),
          isTrue);
      expect(
          shouldExtendMeasurement(log(30, noRate: 10), alreadyExtended: false),
          isTrue);
      expect(
          shouldExtendMeasurement(log(30, moving: 10), alreadyExtended: true),
          isFalse);
    });

    test('the record keeps how steady it was', () {
      expect(log(30, moving: 4, noRate: 6).toJson(10), {
        'seconds': 30,
        'unsettledSeconds': 6,
        'movingSeconds': 4,
        'extendedSeconds': 10,
      });
    });
  });

  test('research mode keeps the motion of each second', () {
    final m = MotionMonitor();
    final l = SteadinessLog();
    for (int s = 0; s < 3; s++) {
      for (int i = 0; i < 15; i++) {
        m.add(s == 1 ? 1.0 : 0.02, 0, 0);
      }
      l.add(movingSecond: m.moving, heartRateFound: true, motionRms: m.rms);
    }
    final Map<String, Object> json = l.toJson(0, monitor: m);
    expect(json['motionRmsPerSecond'], [0.02, 1.0, 0.02]);
    expect(json['motionThresholds'], [0.5, 0.3]);
    expect(json['movingSeconds'], 1);
    // Outside research mode no trace is kept.
    expect(
        SteadinessLog().toJson(0, monitor: m).containsKey('motionRmsPerSecond'),
        isFalse);
  });

  test('rewriting the history keeps fields the list does not know', () {
    final Map<String, dynamic> saved = {
      'date': '2026-10-17',
      'time': '08:00:00',
      'averageBPM': 72,
      'notes': '',
      'dataForPlot': [0.0, 1.0],
      'duration': 20,
      'rrIntervalsMs': [830.0, 845.0],
      'footTimesSec': [0.4, 1.23],
      'measurementWatch': {'seconds': 20, 'extendedSeconds': 0},
    };
    final Map<String, dynamic> rewritten = Record.fromJson(saved).toJson();
    expect(rewritten['rrIntervalsMs'], saved['rrIntervalsMs']);
    expect(rewritten['footTimesSec'], saved['footTimesSec']);
    expect(rewritten['measurementWatch'], saved['measurementWatch']);
    expect(rewritten['averageBPM'], 72);
  });
}
