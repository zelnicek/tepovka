import 'dart:math';
import 'package:tepovka/elements/dsp_utils.dart';

/// Kvalitativní úroveň PPG signálu.
enum SqaLevel { excellent, good, acceptable, poor, noSignal }

/// Detailní výsledek hodnocení kvality.
class SqaResult {
  final SqaLevel level;
  final double score; // 0–100
  final double snrDb;
  final double skewness;
  final double kurtosis;
  final double periodicity;
  final double spectralPurity;
  final String reason;

  const SqaResult({
    required this.level,
    required this.score,
    required this.snrDb,
    required this.skewness,
    required this.kurtosis,
    required this.periodicity,
    required this.spectralPurity,
    required this.reason,
  });
}

/// SQA = Signal Quality Assessment podle akademických prací 2023+.
///
/// Kombinuje 4 nezávislé deskriptory:
///   1. **Spectral purity** – kolik energie je v HR pásmu (0.7–3.5 Hz)
///      vs. celkem. Čistý PPG: > 0.4.
///   2. **Skewness** – PPG má charakteristický asymetrický tvar (rychlý
///      vzestup, pomalý pokles). Skewness ~ -0.5 až +0.5 pro reálný PPG.
///      Vysoká |skewness| = saturace nebo extrémní artefakt.
///   3. **Kurtosis** – tail-heaviness rozdělení amplitud. PPG je platykurtic
///      (kurtosis < 3). Vysoký kurtosis = ostré spiky/motion.
///   4. **Periodicity** – maximum normalizované autokorelace v HR pásmu.
///      Periodický PPG: > 0.5.
///
/// Plus heuristika pro „žádný prst" (low / saturated intensity).
///
/// Reference: Elgendi 2016 "Optimal Signal Quality Index for Photoplethysmogram";
/// Orphanidou 2015; Pereira 2020.
class SignalQualityIndex {
  /// Vzorkovací frekvence v Hz.
  final double fs;

  /// Minimální HR pro periodicity check.
  final double minBpm;

  /// Maximální HR pro periodicity check.
  final double maxBpm;

  const SignalQualityIndex({
    required this.fs,
    this.minBpm = 40.0,
    this.maxBpm = 200.0,
  });

  /// Hodnotí kvalitu okna ze surového (zpracovaného PPG) signálu.
  /// Doporučená délka okna: 4–6 sekund (umožní 3+ cykly i pro nejnižší HR).
  SqaResult evaluate(List<double> ppgWindow, {double? rawIntensityMean}) {
    if (ppgWindow.length < (fs * 2).round()) {
      return const SqaResult(
        level: SqaLevel.noSignal,
        score: 0,
        snrDb: 0,
        skewness: 0,
        kurtosis: 0,
        periodicity: 0,
        spectralPurity: 0,
        reason: 'Příliš krátký signál',
      );
    }

    // 1. Detekce „bez prstu" / saturace na základě raw intensity.
    if (rawIntensityMean != null) {
      if (rawIntensityMean < 30.0) {
        return const SqaResult(
          level: SqaLevel.noSignal,
          score: 0,
          snrDb: 0,
          skewness: 0,
          kurtosis: 0,
          periodicity: 0,
          spectralPurity: 0,
          reason: 'Příliš tmavé – přiložte prst přes blesk',
        );
      }
      if (rawIntensityMean > 250.0) {
        return const SqaResult(
          level: SqaLevel.noSignal,
          score: 0,
          snrDb: 0,
          skewness: 0,
          kurtosis: 0,
          periodicity: 0,
          spectralPurity: 0,
          reason: 'Přesvětleno – uvolněte tlak prstu',
        );
      }
    }

    // 2. Spectral purity (energie v HR pásmu / celková energie).
    final spectralPurity = _spectralPurity(ppgWindow);

    // 3. Skewness, kurtosis.
    final skew = _skewness(ppgWindow);
    final kurt = _kurtosis(ppgWindow);

    // 4. Periodicity – max normalizované autokorelace v HR pásmu.
    final periodicity = _maxPeriodicity(ppgWindow);

    // 5. SNR aproximace z spectral purity (10·log10(p/(1-p))).
    final snrDb = spectralPurity > 0 && spectralPurity < 1
        ? 10.0 * (log(spectralPurity / (1 - spectralPurity)) / ln10)
        : 0.0;

    // Composite score (0–100). Empirické váhy podle Elgendi 2016.
    final periodicityScore = (periodicity.clamp(0.0, 1.0)) * 100;
    final purityScore = (spectralPurity.clamp(0.0, 1.0)) * 100;
    final skewScore = (1.0 - (skew.abs() / 3.0).clamp(0.0, 1.0)) * 100;
    final kurtScore = (1.0 - ((kurt - 1.5).abs() / 5.0).clamp(0.0, 1.0)) * 100;

    final score = (0.4 * periodicityScore +
            0.3 * purityScore +
            0.15 * skewScore +
            0.15 * kurtScore)
        .clamp(0.0, 100.0);

    SqaLevel level;
    String reason;
    if (score >= 80) {
      level = SqaLevel.excellent;
      reason = 'Výborná kvalita';
    } else if (score >= 65) {
      level = SqaLevel.good;
      reason = 'Dobrá kvalita';
    } else if (score >= 45) {
      level = SqaLevel.acceptable;
      reason = 'Přijatelná, držte klidněji';
    } else if (periodicity < 0.2) {
      level = SqaLevel.poor;
      reason = 'Nepravidelný puls / pohyb';
    } else if (spectralPurity < 0.15) {
      level = SqaLevel.poor;
      reason = 'Vysoký šum mimo HR pásmo';
    } else {
      level = SqaLevel.poor;
      reason = 'Špatná kvalita signálu';
    }

    return SqaResult(
      level: level,
      score: score,
      snrDb: snrDb,
      skewness: skew,
      kurtosis: kurt,
      periodicity: periodicity,
      spectralPurity: spectralPurity,
      reason: reason,
    );
  }

  // ─── Interní výpočty ──────────────────────────────────────────────

  double _skewness(List<double> x) {
    if (x.length < 3) return 0.0;
    final m = DspUtils.mean(x);
    final s = DspUtils.std(x);
    if (s < 1e-9) return 0.0;
    double sumCube = 0.0;
    for (final v in x) {
      final d = (v - m) / s;
      sumCube += d * d * d;
    }
    return sumCube / x.length;
  }

  double _kurtosis(List<double> x) {
    if (x.length < 4) return 0.0;
    final m = DspUtils.mean(x);
    final s = DspUtils.std(x);
    if (s < 1e-9) return 0.0;
    double sumQuad = 0.0;
    for (final v in x) {
      final d = (v - m) / s;
      sumQuad += d * d * d * d;
    }
    return sumQuad / x.length;
  }

  /// Spectral purity = energie ve frekvenčním pásmu HR / celková energie.
  /// Aproximace bez explicitní FFT – přes pásmově propustný filtr
  /// (Butterworth bandpass) a poměr výkonů.
  double _spectralPurity(List<double> x) {
    final bandPower = _power(DspUtils.bandpass(x, 0.7, 3.5, fs));
    final totalPower = _power(x);
    if (totalPower < 1e-12) return 0.0;
    return (bandPower / totalPower).clamp(0.0, 1.0);
  }

  double _power(List<double> x) {
    if (x.isEmpty) return 0.0;
    double sum = 0.0;
    final m = DspUtils.mean(x);
    for (final v in x) {
      final d = v - m;
      sum += d * d;
    }
    return sum / x.length;
  }

  /// Max normalizované autokorelace v HR pásmu (0.7–3.5 Hz).
  /// 1.0 = perfektně periodický, 0 = bez periodicity.
  double _maxPeriodicity(List<double> x) {
    if (x.length < 30) return 0.0;
    final m = DspUtils.mean(x);
    final centered = x.map((v) => v - m).toList();
    double r0 = 0.0;
    for (final v in centered) r0 += v * v;
    if (r0 < 1e-12) return 0.0;

    final minLag = (fs * 60.0 / maxBpm).floor().clamp(2, x.length ~/ 2);
    final maxLag = (fs * 60.0 / minBpm).ceil().clamp(minLag + 1, x.length ~/ 2);

    double best = 0.0;
    for (int lag = minLag; lag <= maxLag; lag++) {
      double rL = 0.0;
      final n = centered.length - lag;
      for (int i = 0; i < n; i++) {
        rL += centered[i] * centered[i + lag];
      }
      final norm = rL / r0;
      if (norm > best) best = norm;
    }
    return best.clamp(0.0, 1.0);
  }
}
