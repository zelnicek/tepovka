import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/elements/channel_clipping.dart';
import 'package:tepovka/pages/records.dart';
import 'package:tepovka/ppg_algo.dart';
import 'package:tepovka/services/camera_lock.dart';

/// Nastavení, jak ho vrací nativní zámek na iPhonu.
CameraSettings _settings({
  double duration = 1 / 60,
  double iso = 400,
  double isoMin = 25,
  double durationMin = 1 / 50000,
  double gainRed = 1.0,
  double lensPosition = 1.0,
  String exposureMode = 'custom',
  String whiteBalanceMode = 'locked',
  String focusMode = 'locked',
}) =>
    CameraSettings({
      'device_model': 'iPhone15,2',
      'camera_type': 'AVCaptureDeviceTypeBuiltInWideAngleCamera',
      'format': '352x288',
      'frame_duration_min_s': 1 / 60,
      'frame_duration_max_s': 1 / 60,
      'exposure_mode': exposureMode,
      'exposure_duration_s': duration,
      'iso': iso,
      'iso_min': isoMin,
      'iso_max': 3200.0,
      'exposure_duration_min_s': durationMin,
      'exposure_duration_max_s': 1.0,
      'white_balance_mode': whiteBalanceMode,
      'wb_gain_red': gainRed,
      'wb_gain_green': 1.42,
      'wb_gain_blue': 2.05,
      'wb_temperature_k': 3400.0,
      'wb_tint': 4.2,
      'focus_mode': focusMode,
      'lens_position': lensPosition,
      'torch_level': 1.0,
      'settled_before_lock': true,
    });

/// Snímek BGRA 40×40; červená v horní polovině je [topRed], v dolní [bottomRed].
CameraImage _bgraFrame({required int topRed, required int bottomRed}) {
  const int w = 40, h = 40;
  final bytes = Uint8List(w * h * 4);
  for (int y = 0; y < h; y++) {
    for (int x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      bytes[i] = 50; // B
      bytes[i + 1] = 100; // G
      bytes[i + 2] = y < h ~/ 2 ? topRed : bottomRed; // R
      bytes[i + 3] = 255; // A
    }
  }
  // ignore: deprecated_member_use
  return CameraImage.fromPlatformData({
    'format': 1111970369, // kCVPixelFormatType_32BGRA
    'width': w,
    'height': h,
    'planes': [
      {'bytes': bytes, 'bytesPerRow': w * 4, 'width': w, 'height': h},
    ],
  });
}

void main() {
  group('ChannelClipping', () {
    test('počítá podíl přes snímky i nejhorší snímek', () {
      final c = ChannelClipping()
        ..addFrame(samples: 100, red: 50, green: 0, blue: 0)
        ..addFrame(samples: 100, red: 10, green: 2, blue: 0);
      expect(c.frames, 2);
      expect(c.redFraction, closeTo(0.30, 1e-9));
      expect(c.redMaxFrameFraction, closeTo(0.50, 1e-9));
      expect(c.greenFraction, closeTo(0.01, 1e-9));
      expect(c.blueFraction, 0);
    });

    test('snímek bez pixelů se nezapočítá', () {
      final c = ChannelClipping()..addFrame(samples: 0, red: 0, green: 0, blue: 0);
      expect(c.frames, 0);
      expect(c.redFraction, 0);
    });

    test('kopie je nezávislá a reset nuluje', () {
      final c = ChannelClipping()..addFrame(samples: 10, red: 5, green: 0, blue: 0);
      final copy = c.copy();
      c.reset();
      expect(c.frames, 0);
      expect(c.redMaxFrameFraction, 0);
      expect(copy.frames, 1);
      expect(copy.redFraction, closeTo(0.5, 1e-9));
    });
  });

  group('PPGAlgorithm a přepálené pixely', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.iOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('počítá přepálenou červenou ve skutečném zpracování snímku', () {
      final algo = PPGAlgorithm();
      algo.processImage(_bgraFrame(topRed: 255, bottomRed: 255));
      // ROI je prostřední polovina snímku; polovina ROI leží v horní půlce.
      algo.processImage(_bgraFrame(topRed: 255, bottomRed: 200));

      final rec = algo.recordingClipping;
      expect(rec.frames, 2);
      expect(rec.redMaxFrameFraction, closeTo(1.0, 1e-9));
      expect(rec.redFraction, closeTo(0.75, 1e-9));
      expect(rec.greenFraction, 0);
      expect(rec.blueFraction, 0);
    });

    test('okno pro ladění expozice se po odečtení vynuluje', () {
      final algo = PPGAlgorithm();
      algo.processImage(_bgraFrame(topRed: 255, bottomRed: 255));
      expect(algo.takeClipWindow().redFraction, closeTo(1.0, 1e-9));
      expect(algo.takeClipWindow().frames, 0);
      algo.processImage(_bgraFrame(topRed: 200, bottomRed: 200));
      expect(algo.takeClipWindow().redFraction, 0);
      // Záznam mezitím počítá dál, nezávisle na okně.
      expect(algo.recordingClipping.frames, 2);
    });

    test('statistika záznamu se nuluje na jeho začátku i při resetu', () {
      final algo = PPGAlgorithm();
      algo.processImage(_bgraFrame(topRed: 255, bottomRed: 255));
      algo.resetRecordingClipping();
      expect(algo.recordingClipping.frames, 0);
      algo.processImage(_bgraFrame(topRed: 255, bottomRed: 255));
      algo.reset();
      expect(algo.recordingClipping.frames, 0);
      expect(algo.takeClipWindow().frames, 0);
    });
  });

  group('CameraSettings', () {
    test('plně zamčené jen s expozicí, ostřením i vyvážením bílé', () {
      expect(_settings().fullyLocked, isTrue);
      expect(_settings(exposureMode: 'locked').fullyLocked, isTrue);
      expect(_settings(whiteBalanceMode: 'auto').fullyLocked, isFalse);
      expect(_settings(focusMode: 'auto_once').fullyLocked, isFalse);
    });

    test('zaokrouhlení float není změna, zásah automatiky ano', () {
      final start = _settings();
      expect(start.changedIn(_settings(iso: 400.4)), isEmpty);
      expect(start.changedIn(_settings(iso: 500, gainRed: 1.3)),
          ['iso', 'wb_gain_red']);
    });

    test('poloha čočky má absolutní toleranci', () {
      final start = _settings(lensPosition: 0.0);
      expect(start.changedIn(_settings(lensPosition: 0.005)), isEmpty);
      expect(start.changedIn(_settings(lensPosition: 0.05)), ['lens_position']);
    });

    test('chybějící nebo neplatná hodnota se nepočítá jako změna', () {
      final start = CameraSettings(const {'iso': 400.0});
      expect(start.changedIn(CameraSettings(const {})), isEmpty);
      expect(start.changedIn(CameraSettings(const {'iso': double.nan})), isEmpty);
    });
  });

  group('reducedExposure', () {
    test('nejdřív ubírá ISO, délka expozice zůstává', () {
      final t = reducedExposure(_settings(iso: 400))!;
      expect(t.iso, closeTo(200, 1e-9));
      expect(t.durationS, closeTo(1 / 60, 1e-12));
    });

    test('na minimu ISO bere zbytek z délky expozice', () {
      // 40 -> 20 by šlo pod minimum 25: ISO 25 a délka × 0,8
      final t = reducedExposure(_settings(iso: 40, isoMin: 25))!;
      expect(t.iso, closeTo(25, 1e-9));
      expect(t.durationS, closeTo((1 / 60) * 0.8, 1e-12));
      // celkem stále přesně o 1 EV
      expect((t.iso * t.durationS) / (40 * (1 / 60)), closeTo(0.5, 1e-9));
    });

    test('vrací null, když je ISO i délka na minimu', () {
      expect(
          reducedExposure(
              _settings(iso: 25, isoMin: 25, duration: 1e-4, durationMin: 1e-4)),
          isNull);
    });

    test('bez hodnot expozice nic nenavrhne', () {
      expect(reducedExposure(CameraSettings(const {})), isNull);
    });
  });

  group('buildCameraReport', () {
    ChannelClipping clipping(double redFraction) => ChannelClipping()
      ..addFrame(samples: 1000, red: (redFraction * 1000).round(), green: 0, blue: 0);

    test('bez nativního zámku (Android) přizná, že zámek jen požadoval', () {
      final r = buildCameraReport(
        initial: null,
        locked: null,
        atEnd: null,
        exposureReductionSteps: 0,
        clipping: clipping(0.0),
      );
      expect(r.lines['camera_lock'], 'requested_only');
      expect(r.lines['camera_settings_held'], 'unknown');
      expect(r.settingsHeld, isNull);
      expect(r.lines['clipped_red_pct'], '0.00');
      expect(r.lines.containsKey('camera_iso'), isFalse);
    });

    test('úplný zámek, který vydržel, se všemi hodnotami', () {
      final s = _settings();
      final r = buildCameraReport(
        initial: s,
        locked: s,
        atEnd: s,
        exposureReductionSteps: 0,
        clipping: clipping(0.001),
      );
      expect(r.settingsHeld, isTrue);
      expect(r.redClipped, isFalse);
      expect(r.lines['camera_lock'], 'full');
      expect(r.lines['camera_settings_held'], 'yes');
      expect(r.lines['camera_settled_before_lock'], 'yes');
      expect(r.lines['camera_type'], 'WideAngleCamera');
      expect(r.lines['camera_fps_range'], '60.0-60.0');
      expect(r.lines['camera_iso'], '400.0');
      expect(r.lines['camera_exposure_change_ev'], '0.00');
      expect(r.lines['camera_wb_gain_blue'], '2.0500');
      expect(r.lines['clipped_red_pct'], '0.10');
    });

    test('stažená expozice se zapíše v krocích i v EV', () {
      final r = buildCameraReport(
        initial: _settings(iso: 400),
        locked: _settings(iso: 100),
        atEnd: _settings(iso: 100),
        exposureReductionSteps: 2,
        clipping: null,
      );
      expect(r.lines['camera_exposure_reduction_steps'], '2');
      expect(r.lines['camera_exposure_change_ev'], '-2.00');
      expect(r.lines['camera_iso'], '100.0');
      expect(r.lines.containsKey('clipped_red_pct'), isFalse);
    });

    test('změna během měření se pozná a zapíše se i konečná hodnota', () {
      final r = buildCameraReport(
        initial: _settings(),
        locked: _settings(),
        atEnd: _settings(iso: 640, gainRed: 1.2),
        exposureReductionSteps: 0,
        clipping: clipping(0.02),
      );
      expect(r.settingsHeld, isFalse);
      expect(r.redClipped, isTrue);
      expect(r.lines['camera_settings_held'], 'no (iso wb_gain_red)');
      expect(r.lines['camera_iso_end'], '640.0');
      expect(r.lines['camera_wb_gain_red_end'], '1.2');
    });

    test('částečný zámek bez vyvážení bílé je vidět', () {
      final s = _settings(whiteBalanceMode: 'auto');
      final r = buildCameraReport(
          initial: s, locked: s, atEnd: s, exposureReductionSteps: 0, clipping: null);
      expect(r.lines['camera_lock'], 'partial');
    });
  });

  group('Record', () {
    test('nastavení kamery přežije uložení a načtení', () {
      final record = Record(
        date: '2026-10-06',
        time: '10:00:00',
        averageBPM: 70,
        notesContent: '',
        dataForPlot: const [0.0, 1.0],
        bpmList: const [],
        frames: const [],
        duration: 30,
        metadata: const {'ID probanda': 'P01'},
        cameraSettings: const {'camera_lock': 'full', 'camera_iso': '400.0'},
        hrv: const {},
        respiratoryRate: 0.0,
        bpmHistory: const [],
        rawRgbSamples: const [],
        hrr: const {},
        recoveryChart: const {},
      );
      final restored = Record.fromJson(record.toJson());
      expect(restored.cameraSettings, record.cameraSettings);
      expect(restored.metadata, record.metadata);
    });

    test('starší záznam bez nastavení kamery se načte s prázdnou mapou', () {
      final restored = Record.fromJson({'date': '2026-08-11', 'time': '14:17:25'});
      expect(restored.cameraSettings, isEmpty);
    });
  });

  group('decideExposureStep', () {
    ExposureDecision decide({
      int frames = 18,
      double red = 0.0,
      double green = 60,
      int steps = 0,
    }) =>
        decideExposureStep(
          frames: frames,
          redClipFraction: red,
          greenMean: green,
          stepsTaken: steps,
          maxSteps: 4,
        );

    test('nepřepálená červená: nic se nemění', () {
      final d = decide(red: 0.001);
      expect(d.action, ExposureAction.stop);
      expect(d.reason, 'red_ok');
    });

    test('přepálená červená a dost světla v zelené: ubrat', () {
      final d = decide(red: 0.2, green: 60);
      expect(d.action, ExposureAction.reduce);
      expect(d.reason, 'red_clipped');
    });

    test('krok, který stáhl zelenou do tmy, se vrátí', () {
      final d = decide(red: 0.2, green: kMinGreenLevel - 1, steps: 2);
      expect(d.action, ExposureAction.revert);
      expect(d.reason, 'green_floor');
    });

    test('vrací se i tehdy, když už je červená v pořádku', () {
      // Tep se počítá ze zelené, ta má přednost před nepřepálenou červenou.
      final d = decide(red: 0.0, green: kMinGreenLevel - 1, steps: 1);
      expect(d.action, ExposureAction.revert);
    });

    test('zelená tmavá už od automatiky: neubírat a nic nevracet', () {
      final d = decide(red: 0.2, green: kMinGreenLevel - 1, steps: 0);
      expect(d.action, ExposureAction.stop);
      expect(d.reason, 'green_floor');
    });

    test('po vyčerpání kroků se skončí', () {
      final d = decide(red: 0.2, green: 60, steps: 4);
      expect(d.action, ExposureAction.stop);
      expect(d.reason, 'max_steps');
    });

    test('bez snímků se nerozhoduje', () {
      expect(decide(frames: 1, red: 0.5).reason, 'no_frames');
    });
  });

  group('Svítilna', () {
    CameraSettings torch(double level) =>
        CameraSettings({'torch_level': level});

    test('ztlumení zahřátého blesku se pozná jako změna', () {
      expect(torch(1.0).changedIn(torch(0.7)), ['torch_level']);
    });

    test('drobné kolísání úrovně změna není', () {
      expect(torch(1.0).changedIn(torch(0.98)), isEmpty);
    });
  });

  test('důvod zastavení expozice jde do exportu', () {
    final s = _settings();
    final r = buildCameraReport(
      initial: s,
      locked: s,
      atEnd: s,
      exposureReductionSteps: 0,
      clipping: null,
      exposureStopReason: 'green_floor',
    );
    expect(r.lines['camera_exposure_reduction_stop'], 'green_floor');
    final bez = buildCameraReport(
        initial: s, locked: s, atEnd: s, exposureReductionSteps: 0, clipping: null);
    expect(bez.lines.containsKey('camera_exposure_reduction_stop'), isFalse);
  });
}
