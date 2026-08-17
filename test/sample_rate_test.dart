import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/pages/records.dart';

/// Kamera reálně dodává kolem 24 fps, ne nominálních 30. Když se časová osa
/// počítá z pevných 30 Hz, je zrychlená o ~25 % a všechno odvozené z intervalů
/// (BPM, HRV) je posunuté. Měření proti EKG (Faros 180) a oxymetru v srpnu 2026
/// ukázalo poměr 1.232 (95% CI 1.222–1.243).
Record _record({
  int samples = 720,
  int duration = 30,
  double sampleRateHz = 0.0,
  List<int> stamps = const [],
  List<double> frames = const [],
}) {
  return Record(
    date: '2026-08-11',
    time: '14:17:25',
    averageBPM: 80,
    notesContent: '',
    dataForPlot: List<double>.filled(samples, 0.0),
    bpmList: const [],
    frames: frames,
    duration: duration,
    sampleRateHz: sampleRateHz,
    frameTimestampsMs: stamps,
    hrv: const {},
    respiratoryRate: 0.0,
    bpmHistory: const [],
    rawRgbSamples: const [],
    hrr: const {},
    recoveryChart: const {},
  );
}

void main() {
  group('Record.effectiveSampleRate', () {
    test('počítá frekvenci ze skutečných razítek snímků', () {
      // 24 fps => krok 41.667 ms
      final stamps = List<int>.generate(240, (i) => 1000 + (i * 1000 / 24).round());
      final fs = _record(samples: 240, stamps: stamps).effectiveSampleRate;
      expect(fs, closeTo(24.0, 0.1));
    });

    test('razítka mají přednost před uloženou hodnotou', () {
      final stamps = List<int>.generate(240, (i) => (i * 1000 / 24).round());
      final fs = _record(samples: 240, stamps: stamps, sampleRateHz: 30.0)
          .effectiveSampleRate;
      expect(fs, closeTo(24.0, 0.1));
    });

    test('bez razítek použije uloženou změřenou frekvenci', () {
      expect(_record(sampleRateHz: 23.8).effectiveSampleRate,
          closeTo(23.8, 1e-9));
    });

    test('starý záznam bez razítek se odvodí z počtu vzorků a délky', () {
      // Přesně tenhle případ jsou data z měření 2026: 720 vzorků na 30 s.
      expect(_record().effectiveSampleRate, closeTo(24.0, 1e-9));
      expect(_record(samples: 2160, duration: 90).effectiveSampleRate,
          closeTo(24.0, 1e-9));
    });

    test('nesmyslné hodnoty spadnou na nominálních 30 Hz', () {
      expect(_record(samples: 5, duration: 0).effectiveSampleRate,
          equals(kNominalSampleRate));
      expect(
          _record(samples: 720, duration: 30, sampleRateHz: 5000)
              .effectiveSampleRate,
          closeTo(24.0, 1e-9)); // nesmyslná uložená fs se ignoruje
    });

    test('krátká série razítek se ignoruje', () {
      final stamps = List<int>.generate(4, (i) => i * 100);
      expect(_record(stamps: stamps).effectiveSampleRate,
          closeTo(24.0, 1e-9)); // spadne na odvození z délky
    });
  });
}
