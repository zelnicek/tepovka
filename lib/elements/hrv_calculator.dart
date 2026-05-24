import 'dart:math';
import 'package:tepovka/elements/dsp_utils.dart';

/// Kompletní výsledek HRV analýzy.
class HrvResult {
  // Time domain
  final double meanRrMs;
  final double meanHrBpm;
  final double sdnn;
  final double rmssd;
  final double sdsd;
  final int nn50;
  final double pnn50;
  final double minRr;
  final double maxRr;

  // Geometric / Poincaré
  final double sd1;
  final double sd2;
  final double sd1Sd2Ratio;
  final double ellipseArea;

  // Frequency domain (jen pokud má smysl spočítat – viz canComputeFrequency)
  final bool canComputeFrequency;
  final double vlfPower;
  final double lfPower;
  final double hfPower;
  final double totalPower;
  final double lfNorm;
  final double hfNorm;
  final double lfHfRatio;

  // Baevsky Stress Index (správný histogramový vzorec)
  final double baevskySi;

  // Kvalita HRV výpočtu
  final int totalBeats;
  final int acceptedBeats;
  final int rejectedBeats;
  final double durationSec;

  const HrvResult({
    required this.meanRrMs,
    required this.meanHrBpm,
    required this.sdnn,
    required this.rmssd,
    required this.sdsd,
    required this.nn50,
    required this.pnn50,
    required this.minRr,
    required this.maxRr,
    required this.sd1,
    required this.sd2,
    required this.sd1Sd2Ratio,
    required this.ellipseArea,
    required this.canComputeFrequency,
    required this.vlfPower,
    required this.lfPower,
    required this.hfPower,
    required this.totalPower,
    required this.lfNorm,
    required this.hfNorm,
    required this.lfHfRatio,
    required this.baevskySi,
    required this.totalBeats,
    required this.acceptedBeats,
    required this.rejectedBeats,
    required this.durationSec,
  });

  /// Serializuje výsledek do mapy kompatibilní s existující strukturou
  /// `Record.hrv` v records.dart. Zachovává staré klíče + přidává nové.
  Map<String, dynamic> toMap() => {
        // Stávající klíče (kompatibilita)
        'meanRR': meanRrMs,
        'sdnn': sdnn,
        'rmssd': rmssd,
        'pnn50': pnn50,
        'sd1': sd1,
        'sd2': sd2,
        'sd2sd1': sd1 > 0 ? sd2 / sd1 : 0.0,
        'lf': lfNorm,
        'hf': hfNorm,
        'lfhf': lfHfRatio,
        'stressIndex': baevskySi,
        // Nové klíče
        'meanHrBpm': meanHrBpm,
        'sdsd': sdsd,
        'nn50': nn50,
        'minRr': minRr,
        'maxRr': maxRr,
        'sd1Sd2Ratio': sd1Sd2Ratio,
        'ellipseArea': ellipseArea,
        'canComputeFrequency': canComputeFrequency,
        'vlfPower': vlfPower,
        'lfPower': lfPower,
        'hfPower': hfPower,
        'totalPower': totalPower,
        'durationSec': durationSec,
        'totalBeats': totalBeats,
        'acceptedBeats': acceptedBeats,
        'rejectedBeats': rejectedBeats,
      };
}

/// HRV kalkulátor podle Task Force standardu 1996 + Malik filter +
/// správný Baevsky SI + Lomb-Scargle pro frekvenční doménu.
///
/// Klíčové vlastnosti proti staré implementaci:
///   1. **Malik ectopic filter** – odstraňuje IBI lišící se >20 % od
///      lokálního mediánu. Bez tohohle jeden ektopický tep zničí RMSSD.
///   2. **Správný Baevsky SI** – histogram-based vzorec
///      SI = AMo / (2 × Mo × MxDMn), ne `(meanRR/2σ)²`.
///   3. **Lomb-Scargle periodogram** – frekvenční doména přímo z nerovnoměrně
///      vzorkovaných NN intervalů, bez resamplingu a spectral leakage.
///   4. **Honest reporting**: LF se nepočítá pod 2 minuty, VLF pod 5 minut.
///      Jinak vrací `canComputeFrequency: false`.
///   5. **Geometric measures** (ellipse area, SD1/SD2 ratio).
class HrvCalculator {
  HrvCalculator._();

  // Frekvenční pásma dle Task Force 1996.
  static const double _vlfLow = 0.003;
  static const double _vlfHigh = 0.04;
  static const double _lfLow = 0.04;
  static const double _lfHigh = 0.15;
  static const double _hfLow = 0.15;
  static const double _hfHigh = 0.40;

  // Minimální délka záznamu pro spolehlivé spektrum.
  static const double _minDurationForLf = 120.0;
  static const double _minDurationForVlf = 300.0;

  /// Spočítá kompletní HRV z IBI intervalů v ms.
  /// Vrací [HrvResult] – pole `canComputeFrequency` říká, jestli má smysl
  /// brát LF/HF vážně (true pouze pokud délka záznamu ≥ 120 s).
  static HrvResult compute(List<double> rawIbisMs) {
    final totalBeats = rawIbisMs.length;
    if (rawIbisMs.length < 4) {
      return _empty(totalBeats);
    }

    // Krok 1: Malik filter – odstraní ektopické tepy a artefakty.
    final cleaned = malikFilter(rawIbisMs);
    if (cleaned.length < 4) {
      return _empty(totalBeats);
    }

    final acceptedBeats = cleaned.length;
    final rejectedBeats = totalBeats - acceptedBeats;

    // Krok 2: Time-domain metriky.
    final meanRr = DspUtils.mean(cleaned);
    final sdnn = DspUtils.std(cleaned);

    // Successive differences.
    final diffs = <double>[];
    for (int i = 1; i < cleaned.length; i++) {
      diffs.add(cleaned[i] - cleaned[i - 1]);
    }
    final sdsd = diffs.isEmpty ? 0.0 : DspUtils.std(diffs);

    double sumSqDiff = 0.0;
    int nn50Count = 0;
    for (final d in diffs) {
      sumSqDiff += d * d;
      if (d.abs() > 50.0) nn50Count++;
    }
    final rmssd = diffs.isEmpty ? 0.0 : sqrt(sumSqDiff / diffs.length);
    final pnn50 = diffs.isEmpty ? 0.0 : (nn50Count / diffs.length) * 100.0;

    // Krok 3: Poincaré (geometric).
    // SD1 = std diferencí / sqrt(2). SD2 odvozené z SDNN a SD1.
    final sd1 = diffs.isEmpty ? 0.0 : sdsd / sqrt(2);
    final sd2sq = 2 * sdnn * sdnn - sd1 * sd1;
    final sd2 = sd2sq > 0 ? sqrt(sd2sq) : 0.0;
    final sd1Sd2 = sd1 > 0 ? sd2 / sd1 : 0.0;
    final ellipseArea = pi * sd1 * sd2;

    // Krok 4: Baevsky Stress Index (správný histogramový vzorec).
    final baevsky = _baevskySi(cleaned);

    // Krok 5: Frekvenční doména přes Lomb-Scargle – jen pokud délka stačí.
    // Cumulativní časové body NN intervalů (každý NN má svůj čas).
    final times = <double>[0.0];
    for (int i = 0; i < cleaned.length; i++) {
      times.add(times.last + cleaned[i] / 1000.0);
    }
    final durationSec = times.last;

    final canFreq = durationSec >= _minDurationForLf;
    double vlf = 0, lf = 0, hf = 0, total = 0;
    double lfNorm = 0, hfNorm = 0, lfHf = 0;

    if (canFreq) {
      // Detrend NN intervaly (odečti střední hodnotu pro spektrum).
      final centered =
          cleaned.map((v) => v - meanRr).toList();
      // Časy NN intervalů = čas druhého peaku (begin..N).
      final nnTimes = times.sublist(1);

      lf = _lombScarglePower(nnTimes, centered, _lfLow, _lfHigh);
      hf = _lombScarglePower(nnTimes, centered, _hfLow, _hfHigh);
      if (durationSec >= _minDurationForVlf) {
        vlf = _lombScarglePower(nnTimes, centered, _vlfLow, _vlfHigh);
      }
      total = vlf + lf + hf;
      final lfHfTotal = lf + hf;
      if (lfHfTotal > 0) {
        lfNorm = (lf / lfHfTotal) * 100.0;
        hfNorm = (hf / lfHfTotal) * 100.0;
      }
      lfHf = hf > 0 ? lf / hf : 0.0;
    }

    return HrvResult(
      meanRrMs: meanRr,
      meanHrBpm: meanRr > 0 ? 60000.0 / meanRr : 0.0,
      sdnn: sdnn,
      rmssd: rmssd,
      sdsd: sdsd,
      nn50: nn50Count,
      pnn50: pnn50,
      minRr: cleaned.reduce(min),
      maxRr: cleaned.reduce(max),
      sd1: sd1,
      sd2: sd2,
      sd1Sd2Ratio: sd1Sd2,
      ellipseArea: ellipseArea,
      canComputeFrequency: canFreq,
      vlfPower: vlf,
      lfPower: lf,
      hfPower: hf,
      totalPower: total,
      lfNorm: lfNorm,
      hfNorm: hfNorm,
      lfHfRatio: lfHf,
      baevskySi: baevsky,
      totalBeats: totalBeats,
      acceptedBeats: acceptedBeats,
      rejectedBeats: rejectedBeats,
      durationSec: durationSec,
    );
  }

  /// Malik filter (1989) – ektopické a artefakční tepy.
  /// Interval RR[i] je akceptován, pokud se neliší o víc než `threshold`
  /// (defaultně 20 %) od referenční hodnoty (klouzavý medián).
  /// Odmítnuté intervaly se *odstraní*, nenahrazují se – v HRV literatuře
  /// je nahrazování zdroj artefaktů.
  static List<double> malikFilter(List<double> ibisMs,
      {double threshold = 0.2, int referenceWindow = 5}) {
    if (ibisMs.length < 3) return List<double>.from(ibisMs);
    final cleaned = <double>[];
    for (int i = 0; i < ibisMs.length; i++) {
      final start = max(0, i - referenceWindow);
      final end = min(ibisMs.length, i + referenceWindow + 1);
      // Reference = medián okolí *bez* aktuálního bodu.
      final neighbors = <double>[];
      for (int j = start; j < end; j++) {
        if (j != i) neighbors.add(ibisMs[j]);
      }
      if (neighbors.isEmpty) {
        cleaned.add(ibisMs[i]);
        continue;
      }
      final ref = DspUtils.median(neighbors);
      if (ref < 1.0) continue;
      final deviation = (ibisMs[i] - ref).abs() / ref;
      if (deviation <= threshold) {
        cleaned.add(ibisMs[i]);
      }
      // jinak vyřaď
    }
    return cleaned;
  }

  /// Baevsky Stress Index podle původního Baevského vzorce 1984.
  /// SI = AMo / (2 × Mo × MxDMn)
  /// - Mo (mode): nejčastější RR (v ms)
  /// - AMo (mode amplitude): % intervalů spadajících do mode binu
  /// - MxDMn: rozsah RR (max - min) v sekundách
  static double _baevskySi(List<double> rrMs) {
    if (rrMs.length < 4) return 0.0;
    final minRr = rrMs.reduce(min);
    final maxRr = rrMs.reduce(max);
    if (maxRr - minRr < 1.0) return 0.0;

    // Histogram s bin width 50 ms (Baevsky standard).
    const binWidthMs = 50.0;
    final firstBin = (minRr / binWidthMs).floor() * binWidthMs;
    final numBins = ((maxRr - firstBin) / binWidthMs).ceil() + 1;
    final counts = List<int>.filled(numBins, 0);
    for (final v in rrMs) {
      final idx = ((v - firstBin) / binWidthMs).floor();
      if (idx >= 0 && idx < numBins) counts[idx]++;
    }
    // Najdi mode bin.
    int modeBinIdx = 0;
    int modeBinCount = 0;
    for (int i = 0; i < counts.length; i++) {
      if (counts[i] > modeBinCount) {
        modeBinCount = counts[i];
        modeBinIdx = i;
      }
    }
    final moMs = firstBin + (modeBinIdx + 0.5) * binWidthMs;
    final aMoPct = (modeBinCount / rrMs.length) * 100.0;
    final mxDmnSec = (maxRr - minRr) / 1000.0;
    if (moMs < 1.0 || mxDmnSec < 1e-6) return 0.0;
    // Mo se v Baevského vzorci dosazuje v sekundách.
    return aMoPct / (2.0 * (moMs / 1000.0) * mxDmnSec);
  }

  /// Lomb-Scargle periodogram – power integrovaná v daném frekvenčním pásmu.
  /// Pracuje přímo s nerovnoměrně vzorkovanými daty (RR jako funkce
  /// kumulativního času) – žádný resampling, žádný spectral leakage
  /// z lineární interpolace.
  ///
  /// `times` v sekundách, `values` v ms (s odečtenou střední hodnotou).
  /// Vrací integrovaný výkon v ms²·Hz.
  static double _lombScarglePower(
    List<double> times,
    List<double> values,
    double fLow,
    double fHigh,
  ) {
    if (times.length != values.length || times.length < 4) return 0.0;
    final n = times.length;

    // Frekvenční mřížka – Δf = 1 / (4·T) je standardní oversampling.
    final duration = times.last - times.first;
    if (duration < 1.0) return 0.0;
    final df = 1.0 / (4.0 * duration);
    final fStart = max(fLow, df);
    final fEnd = fHigh;
    if (fStart >= fEnd) return 0.0;
    final numFreqs = ((fEnd - fStart) / df).ceil();

    double sumYY = 0.0;
    for (final v in values) sumYY += v * v;
    final variance = sumYY / n;
    if (variance < 1e-12) return 0.0;

    double totalPower = 0.0;
    for (int k = 0; k < numFreqs; k++) {
      final f = fStart + k * df;
      final omega = 2 * pi * f;

      // Lomb-Scargle: spočítej tau pro decoupling sin/cos.
      double sumSin2wt = 0.0, sumCos2wt = 0.0;
      for (final t in times) {
        sumSin2wt += sin(2 * omega * t);
        sumCos2wt += cos(2 * omega * t);
      }
      final tau = atan2(sumSin2wt, sumCos2wt) / (2 * omega);

      double sumYC = 0, sumYS = 0, sumCC = 0, sumSS = 0;
      for (int i = 0; i < n; i++) {
        final arg = omega * (times[i] - tau);
        final c = cos(arg);
        final s = sin(arg);
        sumYC += values[i] * c;
        sumYS += values[i] * s;
        sumCC += c * c;
        sumSS += s * s;
      }
      if (sumCC < 1e-12 || sumSS < 1e-12) continue;
      final power =
          0.5 * ((sumYC * sumYC) / sumCC + (sumYS * sumYS) / sumSS);
      totalPower += power * df;
    }
    return totalPower;
  }

  static HrvResult _empty(int totalBeats) => HrvResult(
        meanRrMs: 0,
        meanHrBpm: 0,
        sdnn: 0,
        rmssd: 0,
        sdsd: 0,
        nn50: 0,
        pnn50: 0,
        minRr: 0,
        maxRr: 0,
        sd1: 0,
        sd2: 0,
        sd1Sd2Ratio: 0,
        ellipseArea: 0,
        canComputeFrequency: false,
        vlfPower: 0,
        lfPower: 0,
        hfPower: 0,
        totalPower: 0,
        lfNorm: 0,
        hfNorm: 0,
        lfHfRatio: 0,
        baevskySi: 0,
        totalBeats: totalBeats,
        acceptedBeats: 0,
        rejectedBeats: totalBeats,
        durationSec: 0,
      );
}
