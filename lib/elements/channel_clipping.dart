/// Kolik pixelů v ROI narazilo na strop 8bitového rozsahu, po kanálech.
///
/// Přepálený pixel nemá pulzní složku: když je na 255, změna objemu krve se
/// do jeho hodnoty už nepropíše. U červeného kanálu se to s rozsvíceným
/// bleskem stává snadno — automatika expozice měří hlavně zelenou, která je
/// přes prst tmavá, a vytáhne expozici tak, že červená narazí na strop. Pro
/// tep to nevadí, ten se počítá ze zelené; pro odhad saturace, který stojí na
/// poměru červené a zelené, by to byla data k ničemu.
class ChannelClipping {
  /// Hodnota, od které se pixel bere jako přepálený. Tónová křivka kamery
  /// stlačuje světla k 255 postupně, takže hranice je kousek pod stropem.
  static const int level = 250;

  int _frames = 0;
  int _samples = 0;
  int _red = 0;
  int _green = 0;
  int _blue = 0;
  double _maxRed = 0;
  double _maxGreen = 0;
  double _maxBlue = 0;

  /// Přidá jeden snímek: počet čtených pixelů a kolik z nich bylo v každém
  /// kanálu přepálených.
  void addFrame({
    required int samples,
    required int red,
    required int green,
    required int blue,
  }) {
    if (samples <= 0) return;
    _frames++;
    _samples += samples;
    _red += red;
    _green += green;
    _blue += blue;
    if (red / samples > _maxRed) _maxRed = red / samples;
    if (green / samples > _maxGreen) _maxGreen = green / samples;
    if (blue / samples > _maxBlue) _maxBlue = blue / samples;
  }

  int get frames => _frames;

  /// Podíl přepálených pixelů přes všechny snímky (0–1).
  double get redFraction => _samples == 0 ? 0 : _red / _samples;
  double get greenFraction => _samples == 0 ? 0 : _green / _samples;
  double get blueFraction => _samples == 0 ? 0 : _blue / _samples;

  /// Podíl v nejhorším jednotlivém snímku (0–1).
  double get redMaxFrameFraction => _maxRed;
  double get greenMaxFrameFraction => _maxGreen;
  double get blueMaxFrameFraction => _maxBlue;

  ChannelClipping copy() => ChannelClipping()
    .._frames = _frames
    .._samples = _samples
    .._red = _red
    .._green = _green
    .._blue = _blue
    .._maxRed = _maxRed
    .._maxGreen = _maxGreen
    .._maxBlue = _maxBlue;

  void reset() {
    _frames = 0;
    _samples = 0;
    _red = 0;
    _green = 0;
    _blue = 0;
    _maxRed = 0;
    _maxGreen = 0;
    _maxBlue = 0;
  }
}
