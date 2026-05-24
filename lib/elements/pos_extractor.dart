import 'dart:collection';
import 'package:tepovka/elements/dsp_utils.dart';

/// POS (Plane-Orthogonal-to-Skin) algoritmus pro extrakci PPG signálu
/// z RGB kanálů. Wang et al. 2017, "Algorithmic Principles of Remote PPG".
///
/// Proč POS místo green-only:
///   - Motion artifact se v R, G, B kanálech projevuje korelovaně (změna
///     intenzity světla mění všechny tři stejně). POS projekce do roviny
///     ortogonální na intenzitní osu většinu motion artifactu odečte.
///   - Pulzatilní komponenta má jinou barvu (oxyHb absorbuje červenou,
///     deoxyHb modrou) → projeví se odlišně v R vs. G vs. B a v projekci
///     zůstane.
///   - Benchmark UBFC-RPPG dataset: POS ~30 % lepší SNR proti green-only,
///     ~50 % lepší proti raw R.
///
/// Použití (streaming):
///   final pos = PosExtractor(fs: 30.0);
///   for each frame:
///     final value = pos.update(red, green, blue);
///     // value je nový PPG vzorek (případně 0 dokud se nenaplní okno)
class PosExtractor {
  /// Délka POS okna v sekundách (standard 1.6 s dle Wang 2017).
  static const double windowSeconds = 1.6;

  final double fs;
  final int windowSize;

  final Queue<double> _red = Queue<double>();
  final Queue<double> _green = Queue<double>();
  final Queue<double> _blue = Queue<double>();

  /// Akumulovaný overlap-add výstup. Při novém vzorku se rolling buffer
  /// posune, vypočte se nový POS segment a přidá se na konec s overlap.
  final List<double> _output = [];

  PosExtractor({this.fs = 30.0}) : windowSize = (windowSeconds * fs).round();

  /// Přidá nový RGB vzorek, vrátí latest hodnotu PPG signálu (POS).
  /// Pokud ještě není naplněné okno, vrací 0.
  double update(double r, double g, double b) {
    _red.add(r);
    _green.add(g);
    _blue.add(b);
    if (_red.length > windowSize) {
      _red.removeFirst();
      _green.removeFirst();
      _blue.removeFirst();
    }

    if (_red.length < windowSize) {
      _output.add(0.0);
      return 0.0;
    }

    final rWin = _red.toList();
    final gWin = _green.toList();
    final bWin = _blue.toList();

    // Krok 1: Temporal normalizace (Cn = C / mean(C)).
    final rMean = DspUtils.mean(rWin);
    final gMean = DspUtils.mean(gWin);
    final bMean = DspUtils.mean(bWin);
    if (rMean < 1.0 || gMean < 1.0 || bMean < 1.0) {
      _output.add(0.0);
      return 0.0;
    }

    final rNorm = rWin.map((v) => v / rMean).toList();
    final gNorm = gWin.map((v) => v / gMean).toList();
    final bNorm = bWin.map((v) => v / bMean).toList();

    // Krok 2: Projekce do roviny ortogonální na intenzitní osu.
    //   X = G - B
    //   Y = -2R + G + B
    final n = windowSize;
    final x = List<double>.filled(n, 0.0);
    final y = List<double>.filled(n, 0.0);
    for (int i = 0; i < n; i++) {
      x[i] = gNorm[i] - bNorm[i];
      y[i] = -2.0 * rNorm[i] + gNorm[i] + bNorm[i];
    }

    // Krok 3: Alpha tuning – sladění variance X a Y.
    final stdX = DspUtils.std(x);
    final stdY = DspUtils.std(y);
    if (stdY < 1e-9) {
      _output.add(0.0);
      return 0.0;
    }
    final alpha = stdX / stdY;

    // Krok 4: Kombinovaný PPG signál h = X + alpha * Y.
    // Odečíst střední hodnotu – AC komponenta.
    final h = List<double>.filled(n, 0.0);
    double hMean = 0.0;
    for (int i = 0; i < n; i++) {
      h[i] = x[i] + alpha * y[i];
      hMean += h[i];
    }
    hMean /= n;
    for (int i = 0; i < n; i++) {
      h[i] -= hMean;
    }

    // Krok 5: Overlap-add. Bereme jen poslední vzorek okna jako nový output.
    // (Plný overlap-add jako v paperu vyžaduje sdílený stav buffer délky
    // 2*window; pro real-time live signál stačí brát „latest" hodnotu –
    // pro retrospektivní recompute z pole RGB vzorků viz extractBatch.)
    final latest = h.last;
    _output.add(latest);
    return latest;
  }

  /// Vrátí celý dosud nasbíraný POS signál.
  List<double> get signal => List<double>.unmodifiable(_output);

  void reset() {
    _red.clear();
    _green.clear();
    _blue.clear();
    _output.clear();
  }

  /// Offline batch extrakce z hotových RGB polí – pro recompute z uloženého
  /// záznamu. Implementuje plný overlap-add dle Wang 2017.
  static List<double> extractBatch({
    required List<double> red,
    required List<double> green,
    required List<double> blue,
    required double fs,
  }) {
    final n = red.length;
    if (n < 30) return List<double>.filled(n, 0.0);
    final win = (windowSeconds * fs).round().clamp(8, n);
    final h = List<double>.filled(n, 0.0);

    for (int start = 0; start <= n - win; start++) {
      final end = start + win;
      double rM = 0.0, gM = 0.0, bM = 0.0;
      for (int i = start; i < end; i++) {
        rM += red[i];
        gM += green[i];
        bM += blue[i];
      }
      rM /= win;
      gM /= win;
      bM /= win;
      if (rM < 1.0 || gM < 1.0 || bM < 1.0) continue;

      final x = List<double>.filled(win, 0.0);
      final y = List<double>.filled(win, 0.0);
      for (int i = 0; i < win; i++) {
        final rNorm = red[start + i] / rM;
        final gNorm = green[start + i] / gM;
        final bNorm = blue[start + i] / bM;
        x[i] = gNorm - bNorm;
        y[i] = -2 * rNorm + gNorm + bNorm;
      }
      final stdX = DspUtils.std(x);
      final stdY = DspUtils.std(y);
      if (stdY < 1e-9) continue;
      final alpha = stdX / stdY;

      double segMean = 0.0;
      final seg = List<double>.filled(win, 0.0);
      for (int i = 0; i < win; i++) {
        seg[i] = x[i] + alpha * y[i];
        segMean += seg[i];
      }
      segMean /= win;

      // Overlap-add do výstupu.
      for (int i = 0; i < win; i++) {
        h[start + i] += seg[i] - segMean;
      }
    }

    return h;
  }
}
