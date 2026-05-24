import 'package:tepovka/elements/dsp_utils.dart';

/// Perfusion Index – relativní míra prokrvení tkáně.
///
/// **Důležitě**: Toto NENÍ klinické SpO2. Smartphone kamera nemá IR LED
/// (klinický oximetr používá poměr R/IR pro odhad saturace; bez IR je výsledek
/// nespolehlivý a neměl by se interpretovat jako saturace kyslíku).
///
/// Místo toho počítáme Perfusion Index = AC/DC poměr × 100, který:
///   - nevyžaduje kalibraci proti referenčnímu oximetru,
///   - je dobře definovaný i bez IR (z červeného kanálu, kde je hemoglobin
///     nejvíc absorbuje viditelné světlo),
///   - vyjadřuje sílu pulzu (0.02–20 % v klinické praxi; reálné smartphone
///     hodnoty bývají 0.5–8 %),
///   - se v klinické praxi používá jako *indikátor kvality* pulzu a perfuze.
///
/// Reference: Lima & Bakker 2005, "Noninvasive monitoring of peripheral
/// perfusion". Masimo Rainbow PI.
///
/// Použití:
///   final pi = PerfusionIndex(fs: 30.0);
///   for each frame: pi.addSample(red);
///   final pct = pi.currentPi; // např. 3.2 (= 3.2 %)
class PerfusionIndex {
  final double fs;
  final List<double> _redSamples = [];

  double _currentPi = 0.0;
  double get currentPi => _currentPi;

  final List<double> _piHistory = [];

  /// EMA smoothing alpha pro stabilní UI hodnotu.
  static const double _smoothingAlpha = 0.2;

  PerfusionIndex({this.fs = 30.0});

  void addSample(double red) {
    _redSamples.add(red);
    // ~3 s okno – dostatečné pro 2+ pulzy i při HR 40 BPM.
    final maxSamples = (fs * 3).round();
    if (_redSamples.length > maxSamples) {
      _redSamples.removeAt(0);
    }
    if (_redSamples.length >= (fs * 2).round()) {
      _calculate();
    }
  }

  void _calculate() {
    final dc = DspUtils.mean(_redSamples);
    if (dc < 50.0) {
      // Slabé světlo / chybí kontakt – nepočítej, signál není validní.
      return;
    }

    // Pulzatilní složka po bandpass 0.7–3.5 Hz (zero-phase pro retro symetrii).
    final ac = DspUtils.bandpass(_redSamples, 0.7, 3.5, fs);
    if (ac.length < 10) return;

    // AC amplituda – peak-to-peak / 2 z robustního percentilního rozsahu.
    final sorted = List<double>.from(ac)..sort();
    final p5 = sorted[(sorted.length * 0.05).floor()];
    final p95 = sorted[(sorted.length * 0.95).floor()];
    final acAmplitude = (p95 - p5) / 2.0;
    if (acAmplitude < 0.1) return;

    final piValue = (acAmplitude / dc) * 100.0;

    if (_currentPi == 0.0) {
      _currentPi = piValue;
    } else {
      _currentPi = _currentPi * (1 - _smoothingAlpha) + piValue * _smoothingAlpha;
    }
    _piHistory.add(_currentPi);
  }

  /// Medián PI z celého měření – stabilní hodnota do summary.
  double getSummaryPi() {
    if (_piHistory.isEmpty) return 0.0;
    return DspUtils.median(_piHistory);
  }

  /// Klasifikace síly pulzu pro UX:
  /// - < 0.5 %: velmi slabý (špatný kontakt / studené prsty)
  /// - 0.5–2 %: slabý
  /// - 2–5 %: normální
  /// - > 5 %: silný
  String classifyPi(double pi) {
    if (pi < 0.5) return 'Velmi slabý pulz';
    if (pi < 2.0) return 'Slabý pulz';
    if (pi < 5.0) return 'Normální pulz';
    return 'Silný pulz';
  }

  void reset() {
    _redSamples.clear();
    _piHistory.clear();
    _currentPi = 0.0;
  }
}
