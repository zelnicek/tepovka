import 'dart:io' show Platform;
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tepovka/elements/channel_clipping.dart';

/// Nejvyšší podíl přepálených pixelů červeného kanálu, který se toleruje.
/// Nad ním se ve výzkumném režimu ubírá expozice a záznam se označí.
const double kMaxRedClipFraction = 0.005;

/// Pod tuhle průměrnou hodnotu zeleného kanálu (z 255) se expozice kvůli
/// červené nestahuje. Ze zelené se počítá tep a tmavý snímek je pro ni
/// horší než přepálená červená: ve srovnání nastavení kamery na iPhonu
/// (Soliński et al., preprint 2026) dopadly nejhůř právě nejtmavší kombinace.
const double kMinGreenLevel = 20.0;

/// Nastavení kamery, jak ho hlásí iOS v jednom okamžiku.
@immutable
class CameraSettings {
  const CameraSettings(this.values);

  final Map<String, Object?> values;

  double? number(String key) {
    final v = values[key];
    return v is num && v.isFinite ? v.toDouble() : null;
  }

  String? text(String key) => values[key]?.toString();

  double? get exposureDurationS => number('exposure_duration_s');
  double? get iso => number('iso');
  double? get isoMin => number('iso_min');
  double? get exposureDurationMinS => number('exposure_duration_min_s');

  /// Zamčené jsou expozice, ostření i vyvážení bílé.
  bool get fullyLocked =>
      const {'custom', 'locked'}.contains(text('exposure_mode')) &&
      text('focus_mode') == 'locked' &&
      text('white_balance_mode') == 'locked';

  /// Veličiny, které musí zůstat po celé měření stejné.
  static const List<String> heldKeys = [
    'exposure_duration_s',
    'iso',
    'wb_gain_red',
    'wb_gain_green',
    'wb_gain_blue',
    'lens_position',
    // Zahřátý iPhone svítilnu sám ztlumí; u dlouhého měření je to skok jasu
    // uprostřed záznamu, stejně škodlivý jako změna expozice.
    'torch_level',
  ];

  /// Které z [heldKeys] se mezi tímto a pozdějším stavem změnily.
  List<String> changedIn(CameraSettings later) {
    final changed = <String>[];
    for (final key in heldKeys) {
      final a = number(key);
      final b = later.number(key);
      if (a == null || b == null) continue;
      // AVFoundation vrací floaty, drobné zaokrouhlení není změna; skutečný
      // zásah automatiky je o řády větší než půl procenta.
      final tolerance = switch (key) {
        'lens_position' => 0.01,
        'torch_level' => 0.05,
        _ => math.max(1e-9, a.abs() * 0.005),
      };
      if ((a - b).abs() > tolerance) changed.add(key);
    }
    return changed;
  }
}

@immutable
class ExposureTarget {
  const ExposureTarget({required this.durationS, required this.iso});

  final double durationS;
  final double iso;
}

/// Expozice ztlumená na [factor] (0,5 = o 1 EV).
///
/// Nejdřív se ubírá ISO: to jen zesiluje signál ze snímače, takže jeho snížení
/// nezmění počet zachycených fotonů a odstup od šumu zůstane. Délka expozice
/// se zkracuje teprve ve chvíli, kdy je ISO na minimu. Vrací null, když už
/// není kam ubrat.
ExposureTarget? reducedExposure(CameraSettings s, {double factor = 0.5}) {
  final duration = s.exposureDurationS;
  final iso = s.iso;
  if (duration == null || iso == null || duration <= 0 || iso <= 0) {
    return null;
  }
  final isoMin = math.min(s.isoMin ?? iso, iso);
  final durationMin = math.min(s.exposureDurationMinS ?? duration, duration);

  var newIso = iso * factor;
  var newDuration = duration;
  if (newIso < isoMin) {
    final remaining = newIso / isoMin;
    newIso = isoMin;
    newDuration = math.max(durationMin, duration * remaining);
  }
  final unchanged = (newIso - iso).abs() <= iso * 1e-6 &&
      (newDuration - duration).abs() <= duration * 1e-6;
  return unchanged
      ? null
      : ExposureTarget(durationS: newDuration, iso: newIso);
}

enum ExposureAction { stop, reduce, revert }

/// Co udělat s expozicí po vyhodnocení posledního okna snímků, a proč.
@immutable
class ExposureDecision {
  const ExposureDecision(this.action, this.reason);

  final ExposureAction action;

  /// Důvod pro export: red_ok, red_clipped, green_floor, max_steps, no_frames.
  final String reason;
}

/// Rozhodne o dalším kroku stahování expozice kvůli přepálené červené.
///
/// Přednost má zelená: když ji poslední krok stáhl pod [kMinGreenLevel],
/// krok se vrátí, i kdyby červená zůstala přepálená. Přepálení se pak
/// pozná v exportu i z varování a měření se dá zopakovat s jiným prstem.
ExposureDecision decideExposureStep({
  required int frames,
  required double redClipFraction,
  required double greenMean,
  required int stepsTaken,
  required int maxSteps,
}) {
  if (frames < 3) return const ExposureDecision(ExposureAction.stop, 'no_frames');
  if (stepsTaken > 0 && greenMean < kMinGreenLevel) {
    return const ExposureDecision(ExposureAction.revert, 'green_floor');
  }
  if (redClipFraction <= kMaxRedClipFraction) {
    return const ExposureDecision(ExposureAction.stop, 'red_ok');
  }
  if (greenMean < kMinGreenLevel) {
    return const ExposureDecision(ExposureAction.stop, 'green_floor');
  }
  if (stepsTaken >= maxSteps) {
    return const ExposureDecision(ExposureAction.stop, 'max_steps');
  }
  return const ExposureDecision(ExposureAction.reduce, 'red_clipped');
}

/// Nativní zámek kamery. Je jen na iOS; jinde vrací null a měří se dál se
/// zámkem expozice a ostření z pluginu `camera`, bez vyvážení bílé.
class CameraLock {
  static const MethodChannel _channel = MethodChannel('tepovka/camera_lock');

  static bool get isAvailable => !kIsWeb && Platform.isIOS;

  /// Počká na doběhnutí automatiky a zmrazí expozici, ostření a vyvážení bílé.
  static Future<CameraSettings?> lock(String cameraId) =>
      _call('lock', {'cameraId': cameraId, 'settleTimeoutMs': 1500});

  static Future<CameraSettings?> setExposure(
          String cameraId, ExposureTarget target) =>
      _call('setExposure', {
        'cameraId': cameraId,
        'durationS': target.durationS,
        'iso': target.iso,
      });

  static Future<CameraSettings?> snapshot(String cameraId) =>
      _call('snapshot', {'cameraId': cameraId});

  static Future<void> unlock(String cameraId) =>
      _call('unlock', {'cameraId': cameraId});

  static Future<CameraSettings?> _call(
      String method, Map<String, Object> args) async {
    if (!isAvailable) return null;
    try {
      final raw =
          await _channel.invokeMapMethod<String, Object?>(method, args);
      return raw == null ? null : CameraSettings(Map.unmodifiable(raw));
    } on PlatformException catch (e) {
      debugPrint('Camera lock $method failed: ${e.message}');
    } on MissingPluginException {
      debugPrint('Camera lock $method unavailable');
    }
    return null;
  }
}

/// Co se během měření dělo s kamerou.
@immutable
class CameraReport {
  const CameraReport({
    required this.lines,
    required this.settingsHeld,
    required this.redClipFraction,
  });

  /// Řádky do hlavičky exportu, ve stálém pořadí.
  final Map<String, String> lines;

  /// Zda nastavení vydrželo celé měření; null, když se to nedá ověřit.
  final bool? settingsHeld;

  /// Podíl přepálených pixelů červeného kanálu za celý záznam.
  final double redClipFraction;

  bool get redClipped => redClipFraction > kMaxRedClipFraction;
}

/// Sestaví souhrn pro export.
///
/// [initial] je stav po zamčení, [locked] po případném ubrání expozice
/// (bez ubírání jsou totožné) a [atEnd] stav na konci záznamu.
CameraReport buildCameraReport({
  required CameraSettings? initial,
  required CameraSettings? locked,
  required CameraSettings? atEnd,
  required int exposureReductionSteps,
  required ChannelClipping? clipping,
  String? exposureStopReason,
}) {
  final lines = <String, String>{};
  String fixed(double? v, int digits) => v == null ? '' : v.toStringAsFixed(digits);
  String pct(double v) => (v * 100).toStringAsFixed(2);

  lines['camera_lock'] = locked == null
      ? 'requested_only'
      : (locked.fullyLocked ? 'full' : 'partial');

  bool? held;
  if (locked != null && atEnd != null) {
    final changed = locked.changedIn(atEnd);
    held = changed.isEmpty;
    lines['camera_settings_held'] = held ? 'yes' : 'no (${changed.join(' ')})';
    for (final key in changed) {
      lines['camera_${key}_end'] = '${atEnd.number(key)}';
    }
  } else {
    lines['camera_settings_held'] = 'unknown';
  }

  if (locked != null) {
    final settled = locked.values['settled_before_lock'];
    if (settled is bool) {
      lines['camera_settled_before_lock'] = settled ? 'yes' : 'no';
    }
    lines['camera_device_model'] = locked.text('device_model') ?? '';
    lines['camera_type'] = (locked.text('camera_type') ?? '')
        .replaceFirst('AVCaptureDeviceTypeBuiltIn', '');
    lines['camera_format'] = locked.text('format') ?? '';
    final minFrame = locked.number('frame_duration_min_s');
    final maxFrame = locked.number('frame_duration_max_s');
    if (minFrame != null && maxFrame != null && minFrame > 0 && maxFrame > 0) {
      lines['camera_fps_range'] = '${(1 / maxFrame).toStringAsFixed(1)}-'
          '${(1 / minFrame).toStringAsFixed(1)}';
    }
    lines['camera_exposure_mode'] = locked.text('exposure_mode') ?? '';
    lines['camera_exposure_duration_s'] = fixed(locked.exposureDurationS, 6);
    lines['camera_iso'] = fixed(locked.iso, 1);
    lines['camera_exposure_reduction_steps'] = '$exposureReductionSteps';
    if (exposureStopReason != null) {
      lines['camera_exposure_reduction_stop'] = exposureStopReason;
    }
    final d0 = initial?.exposureDurationS, i0 = initial?.iso;
    final d1 = locked.exposureDurationS, i1 = locked.iso;
    if (d0 != null && i0 != null && d1 != null && i1 != null && d0 > 0 && i0 > 0) {
      final ev = math.log((d1 * i1) / (d0 * i0)) / math.ln2;
      lines['camera_exposure_change_ev'] = ev.toStringAsFixed(2);
    }
    lines['camera_white_balance_mode'] = locked.text('white_balance_mode') ?? '';
    lines['camera_wb_gain_red'] = fixed(locked.number('wb_gain_red'), 4);
    lines['camera_wb_gain_green'] = fixed(locked.number('wb_gain_green'), 4);
    lines['camera_wb_gain_blue'] = fixed(locked.number('wb_gain_blue'), 4);
    lines['camera_wb_temperature_k'] = fixed(locked.number('wb_temperature_k'), 0);
    lines['camera_wb_tint'] = fixed(locked.number('wb_tint'), 1);
    lines['camera_focus_mode'] = locked.text('focus_mode') ?? '';
    lines['camera_lens_position'] = fixed(locked.number('lens_position'), 3);
    lines['camera_torch_level'] = fixed(locked.number('torch_level'), 2);
  }

  final red = clipping != null && clipping.frames > 0 ? clipping.redFraction : 0.0;
  if (clipping != null && clipping.frames > 0) {
    lines['clipping_level'] = '${ChannelClipping.level}';
    lines['clipped_red_pct'] = pct(clipping.redFraction);
    lines['clipped_red_max_frame_pct'] = pct(clipping.redMaxFrameFraction);
    lines['clipped_green_pct'] = pct(clipping.greenFraction);
    lines['clipped_green_max_frame_pct'] = pct(clipping.greenMaxFrameFraction);
    lines['clipped_blue_pct'] = pct(clipping.blueFraction);
    lines['clipped_blue_max_frame_pct'] = pct(clipping.blueMaxFrameFraction);
  }

  lines.removeWhere((_, v) => v.isEmpty);
  return CameraReport(lines: lines, settingsHeld: held, redClipFraction: red);
}
