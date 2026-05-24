import 'dart:collection';
import 'dart:math';

/// NLMS (Normalized Least Mean Squares) adaptivní filtr pro odečtení
/// motion artifactů z PPG signálu pomocí akcelerometru jako reference.
///
/// Princip:
///   - Akcelerometr ze stejného zařízení nese pohybový šum, který se
///     korelovaně projevuje v PPG (pohyb prstu mění tlak na čočku, mění
///     kontakt s LED, atd.).
///   - NLMS filtr se učí lineární kombinaci posledních N vzorků reference,
///     která co nejlépe odhaduje šum v PPG.
///   - Odečteme odhadnutý šum → čistý PPG.
///
/// Reference: Widrow & Stearns 1985 (klasika), použito např. v Empatica E4,
/// Apple Watch optical HR pipeline.
///
/// Použití (každý frame):
///   final canceller = NlmsMotionCanceller(filterLength: 10);
///   final cleanPpg = canceller.update(rawPpgSample, accelMagnitude);
///
/// Tip: jako reference použij **magnitudu akcelerace** sqrt(ax²+ay²+az²)
/// minus 1g (gravitace), případně band-pass 0.5–5 Hz (rozsah lidského pohybu).
class NlmsMotionCanceller {
  /// Délka filtru (počet historických vzorků reference použitých k odhadu).
  final int filterLength;

  /// Krokový parametr učení (μ). Vyšší = rychlejší adaptace, ale méně stabilní.
  /// 0.05–0.3 je rozumné rozmezí pro PPG @ 30 Hz.
  final double stepSize;

  /// Regularizační konstanta pro normalizaci (zabraňuje dělení nulou).
  final double regularization;

  /// Adaptivní koeficienty filtru.
  final List<double> _weights;

  /// FIFO historie reference vzorků.
  final Queue<double> _refHistory = Queue<double>();

  NlmsMotionCanceller({
    this.filterLength = 10,
    this.stepSize = 0.15,
    this.regularization = 1e-3,
  }) : _weights = List<double>.filled(filterLength, 0.0);

  /// Zpracuje jeden vzorek. Vrací očištěný PPG (signál − odhad šumu).
  double update(double ppgSample, double refSample) {
    _refHistory.add(refSample);
    while (_refHistory.length > filterLength) {
      _refHistory.removeFirst();
    }
    if (_refHistory.length < filterLength) {
      // Ještě nemáme dost historie – vracíme původní.
      return ppgSample;
    }

    final ref = _refHistory.toList();

    // Odhad šumu = w · ref.
    double noiseEstimate = 0.0;
    for (int i = 0; i < filterLength; i++) {
      noiseEstimate += _weights[i] * ref[i];
    }

    // Chyba = co zbude po odečtení = "čistý" PPG.
    final cleaned = ppgSample - noiseEstimate;

    // Norma reference (s regularizací).
    double refPower = regularization;
    for (final r in ref) {
      refPower += r * r;
    }

    // NLMS update: w += (μ / ||x||²) · e · x
    final scale = stepSize / refPower;
    for (int i = 0; i < filterLength; i++) {
      _weights[i] += scale * cleaned * ref[i];
    }

    return cleaned;
  }

  void reset() {
    for (int i = 0; i < filterLength; i++) {
      _weights[i] = 0.0;
    }
    _refHistory.clear();
  }

  /// Pomocná funkce pro výpočet magnitudy akcelerace z (x, y, z).
  /// Odečte 1g (gravitace ≈ 9.81 m/s²) – výsledek je „čistá" lineární akcelerace.
  static double accelMagnitude(double ax, double ay, double az) {
    final mag = sqrt(ax * ax + ay * ay + az * az);
    return (mag - 9.81).abs();
  }
}
