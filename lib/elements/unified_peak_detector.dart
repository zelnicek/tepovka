import 'dart:math';
import 'package:tepovka/elements/dsp_utils.dart';

/// Detekovaný peak se sub-sample přesností.
class PpgPeak {
  /// Frakční index v původním signálu (sub-sample přesnost).
  /// Pozn.: pro IBI použij rozdíl `(p2.fractionalIndex - p1.fractionalIndex) / fs`.
  final double fractionalIndex;

  /// Čas v sekundách od začátku signálu.
  final double timeSec;

  /// Hodnota signálu v peaku (po parabolické interpolaci).
  final double value;

  /// Lokální prominence (relativní výška vůči okolnímu mediánu).
  final double prominence;

  const PpgPeak({
    required this.fractionalIndex,
    required this.timeSec,
    required this.value,
    required this.prominence,
  });
}

/// Jednotný PPG peak detektor – **single source of truth**.
///
/// Klíčové vlastnosti proti staré implementaci:
///   1. **Sub-sample parabolická interpolace polohy peaku** – řeší kvantizaci
///      IBI při fs=30Hz (33 ms krok → ~1 ms efektivně). Bez tohohle jsou
///      RMSSD/pNN50 na smartphone PPG nepoužitelně zašuměné.
///   2. **Adaptivní lokální threshold** (median + k·MAD) místo mean+k·std –
///      robustnější vůči ektopickým peakům a saturaci.
///   3. **Refractory period** (min distance) odvozená z očekávané HR
///      (default 40–200 BPM = 0.3–1.5 s mezi peaky).
///   4. **Prominence check** v lokálním okně proti dvojitým peakům
///      (dicrotic notch je 0.15–0.3 s po hlavním peaku, prominence ho odřízne).
///   5. **Zero-phase preprocessing** dostupné jako optional flag pro
///      retrospektivní recompute (live by zůstal causal).
///
/// **DŮLEŽITÉ – polarita vstupu:**
/// Detektor hledá lokální **maxima**. Pokud máš signál, kde pulzy směřují
/// dolů (např. raw camera intensity, kde absorpce při systole snižuje
/// odraženou intenzitu), musíš ho **invertovat** před voláním
/// (`signal.map((v) => -v).toList()`).
///
/// Použití:
///   final detector = UnifiedPpgPeakDetector(fs: 30.0);
///   final peaks = detector.detect(signal, zeroPhase: true);
///   final ibisMs = detector.ibisMs(peaks);
class UnifiedPpgPeakDetector {
  /// Vzorkovací frekvence v Hz.
  final double fs;

  /// Minimální HR pro detekci (default 40 BPM).
  final double minBpm;

  /// Maximální HR pro detekci (default 200 BPM).
  final double maxBpm;

  /// Bandpass spodní cutoff v Hz (typ. 0.7 Hz = 42 BPM).
  final double bandLow;

  /// Bandpass horní cutoff v Hz (typ. 3.5 Hz = 210 BPM).
  final double bandHigh;

  /// Šíře lokálního okna pro prominence + threshold v sekundách.
  final double localWindowSec;

  /// Threshold = median + thresholdK * MAD.
  final double thresholdK;

  /// Prominence = peak musí být alespoň prominenceK * MAD nad lokálním minem.
  final double prominenceK;

  const UnifiedPpgPeakDetector({
    required this.fs,
    this.minBpm = 40.0,
    this.maxBpm = 200.0,
    this.bandLow = 0.7,
    this.bandHigh = 3.5,
    this.localWindowSec = 1.0,
    this.thresholdK = 0.3,
    this.prominenceK = 0.4,
  });

  int get _minDistanceSamples => (fs * 60.0 / maxBpm).round().clamp(2, 1000);
  int get _maxDistanceSamples => (fs * 60.0 / minBpm).round().clamp(3, 100000);
  int get _localWindowSamples =>
      (fs * localWindowSec).round().clamp(5, 10000);

  /// Detekuje peaky v signálu. Vrací seřazené dle časové pozice.
  ///
  /// `zeroPhase`: pokud true, aplikuje forward-backward bandpass
  /// (filtfilt) → eliminuje fázové zpoždění. Použij pro retrospektivní
  /// analýzu uložených záznamů. Pro live (osciloskop view) ponech false,
  /// protože zero-phase vyžaduje znalost budoucích vzorků.
  List<PpgPeak> detect(List<double> rawSignal, {bool zeroPhase = false}) {
    if (rawSignal.length < fs.round()) return const [];

    // Bandpass filter (zero-phase pro retrospektivu, causal pro live).
    final filtered = DspUtils.bandpass(
      rawSignal,
      bandLow,
      bandHigh,
      fs,
      zeroPhase: zeroPhase,
    );
    if (filtered.length < 30) return const [];

    final peaks = <PpgPeak>[];
    int lastPeakIdx = -_minDistanceSamples;

    for (int i = 1; i < filtered.length - 1; i++) {
      // Local maximum check.
      if (!(filtered[i - 1] < filtered[i] &&
          filtered[i] > filtered[i + 1])) {
        continue;
      }

      // Lokální okno pro robustní statistiku.
      final start = max(0, i - _localWindowSamples);
      final end = min(filtered.length, i + _localWindowSamples + 1);
      final window = filtered.sublist(start, end);
      final localMedian = DspUtils.median(window);
      final localMad = DspUtils.mad(window);
      final effectiveMad = max(localMad, 1e-6);

      final threshold = localMedian + thresholdK * effectiveMad;
      if (filtered[i] < threshold) continue;

      // Lokální minimum pro prominence.
      double localMin = filtered[start];
      for (int j = start + 1; j < end; j++) {
        if (filtered[j] < localMin) localMin = filtered[j];
      }
      final prominence = filtered[i] - localMin;
      if (prominence < prominenceK * effectiveMad) continue;

      // Refractory period.
      final dist = i - lastPeakIdx;
      if (dist < _minDistanceSamples) {
        // Pokud nový kandidát je vyšší, nahradíme.
        if (peaks.isNotEmpty && filtered[i] > peaks.last.value) {
          final refined = DspUtils.parabolicVertex(
              filtered[i - 1], filtered[i], filtered[i + 1], i);
          peaks[peaks.length - 1] = PpgPeak(
            fractionalIndex: refined.index,
            timeSec: refined.index / fs,
            value: refined.value,
            prominence: prominence,
          );
          lastPeakIdx = i;
        }
        continue;
      }

      // Sub-sample parabolická interpolace polohy peaku.
      // Tohle je kritické pro IBI přesnost při fs=30Hz: kvantizace
      // klesne z 33 ms na ~1 ms.
      final refined = DspUtils.parabolicVertex(
          filtered[i - 1], filtered[i], filtered[i + 1], i);

      peaks.add(PpgPeak(
        fractionalIndex: refined.index,
        timeSec: refined.index / fs,
        value: refined.value,
        prominence: prominence,
      ));
      lastPeakIdx = i;
    }

    return peaks;
  }

  /// Vrátí IBI (inter-beat intervals) v milisekundách z detekovaných peaků.
  /// Filtruje fyziologicky nemožné intervaly (mimo min/max HR rozsah).
  List<double> ibisMs(List<PpgPeak> peaks) {
    if (peaks.length < 2) return const [];
    final ibis = <double>[];
    final minIbiMs = 60000.0 / maxBpm;
    final maxIbiMs = 60000.0 / minBpm;
    for (int i = 1; i < peaks.length; i++) {
      final dtSec = peaks[i].timeSec - peaks[i - 1].timeSec;
      final dtMs = dtSec * 1000.0;
      if (dtMs >= minIbiMs && dtMs <= maxIbiMs) {
        ibis.add(dtMs);
      }
    }
    return ibis;
  }

  /// Spočítá průměrnou BPM z detekovaných peaků (medián IBI – robust).
  double bpmFromPeaks(List<PpgPeak> peaks) {
    final ibis = ibisMs(peaks);
    if (ibis.isEmpty) return 0.0;
    final medianIbiMs = DspUtils.median(ibis);
    if (medianIbiMs < 1.0) return 0.0;
    return 60000.0 / medianIbiMs;
  }
}
