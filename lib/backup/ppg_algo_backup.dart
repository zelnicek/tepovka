import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'dart:math';

class PPGAlgorithm {
  double yAxisMax = 110;
  double yAxisMin = 100;

  List<double> _intensityValues = [];
  List<double> _intensityValues2 = [];
  List<double> _derivaceValues = [];
  double _currentHeartRate = 0.0;
  double? _lastAverageIntensity;
  int stack = 150;
  double _frameRate = 0;
  List<double> _ppg_plot = [];
  List<int> _timestamps = [];
  List<double> _bpm_total = [];
  double average = 0;
  List<double> frames_list = [];

  // Add Standard Deviation Calculation Method
  double calculateStandardDeviation() {
    if (_intensityValues.isEmpty) return 0.0;

    double mean = calculateAverage(_intensityValues); // Calculate mean
    double sumOfSquaredDifferences = _intensityValues
        .map((dataPoint) => pow(dataPoint - mean, 2))
        .reduce((a, b) => a + b)
        .toDouble(); // Cast result to double

    return sqrt(sumOfSquaredDifferences / _intensityValues.length);
  }

  void processImage(CameraImage image) {
    int currentTime = DateTime.now().millisecondsSinceEpoch;

    if (_timestamps.isNotEmpty) {
      int lastTime = _timestamps.last;
      int interval = currentTime - lastTime;

      if (interval > 0) {
        double currentFrameRate =
            1000 / interval; // v snímcích za sekundu (fps)
        _frameRate = (_frameRate == 0)
            ? currentFrameRate
            : (_frameRate + currentFrameRate) / 2; // Průměrná fps
      }
    }

    _timestamps.add(currentTime);

    final double averageIntensity = _calculateAverageIntensity(image);

    _intensityValues.add(averageIntensity);
    _intensityValues2.add(averageIntensity);

    if (_intensityValues.length > stack) {
      _intensityValues = applyLowPassFilter(_intensityValues, 8.5, _frameRate);
      _intensityValues2 =
          applyLowPassFilter(_intensityValues2, 8.5, _frameRate);
      //_ppg_plot = applyLowPassFilter(_ppg_plot, 8.5, _frameRate);
      print('Frame rate: $_frameRate fps');
      frames_list.add(_frameRate);
      print("frames list> $frames_list");
      _currentHeartRate = _calculateHeartRate(_frameRate);
      _intensityValues.clear(); // Vymaž signál, jakmile se spočítá srdeční tep
      _timestamps.clear();
      _derivaceValues.clear();
    }
  }

  double _calculateAverageIntensity(CameraImage image) {
    double total = 0;
    int count = 0;

    for (int planeIndex = 0; planeIndex < image.planes.length; planeIndex++) {
      final Plane plane = image.planes[planeIndex];
      final Uint8List bytes = plane.bytes;
      for (int i = 0; i < bytes.length; i += 4) {
        //int r = bytes[i + 0];
        int g = bytes[i + 1];
        int b = bytes[i + 2];
        total += (b + g) / 2;
        count++;
      }
    }
    double averageIntensity = count > 0 ? total / count : 0;
    _ppg_plot.add(averageIntensity);
    return averageIntensity;
  }

  double _calculateHeartRate(double fps) {
    _derivaceValues = _movingAverage(_intensityValues, 5);
    _derivaceValues = derivace(_derivaceValues);
    List<List<double>> peaks = minfinder(_derivaceValues);

    if (calculateMedian(_intensityValues) < 80) {
      _intensityValues.clear();
    }

    if (_intensityValues.length == 0) {
      yAxisMax = 0;
      yAxisMin = 0;
    } else {
      yAxisMax = _intensityValues.reduce(max);
      yAxisMin = _intensityValues.reduce(min);
    }

    List<double> peakValues = peaks[1];
    if (peaks.isEmpty) {
      return 0.0;
    }

    List<double> peakIndex = peaks[0];
    List<double> intervals = [];

    for (int i = 0; i < peakValues.length - 1; i++) {
      double interval = (peakIndex[i + 1] - peakIndex[i]);
      intervals.add(interval);
    }

    if (intervals.isEmpty) {
      return 0.0;
    }

    double sumIntervals = intervals.reduce((a, b) => a + b);
    double intervalAverage = sumIntervals / intervals.length;

    double normalizedRate = 60 / (intervalAverage / 30);

    if (_intensityValues.isEmpty) {
      return 0.0;
    }
    if (normalizedRate > 200) {
      normalizedRate = 0;
    }

    _bpm_total.add(normalizedRate);
    return normalizedRate;
  }

  List<List<double>> peakfinder(List<double> a, {double? threshold}) {
    var N = a.length - 2;
    var ix = <double>[];
    var ax = <double>[];

    if (threshold != null) {
      for (var i = 1; i <= N; i++) {
        if (a[i - 1] <= a[i] && a[i] >= a[i + 1] && a[i] >= threshold) {
          ix.add(i.toDouble());
          ax.add(a[i]);
        }
      }
    } else {
      for (var i = 1; i <= N; i++) {
        if (a[i - 1] <= a[i] && a[i] >= a[i + 1]) {
          ix.add(i.toDouble());
          ax.add(a[i]);
        }
      }
    }
    return [ix, ax];
  }

  List<List<double>> minfinder(List<double> a) {
    double globalMin =
        a.reduce((value, element) => element < value ? element : value);
    double threshold = globalMin * 0.25;
    var N = a.length - 2;
    var ix = <double>[];
    var ax = <double>[];

    for (var i = 1; i <= N; i++) {
      if (a[i - 1] >= a[i] && a[i] <= a[i + 1] && a[i] <= threshold) {
        ix.add(i.toDouble());
        ax.add(a[i]);
      }
    }

    return [ix, ax];
  }

  double getCurrentHeartRate() {
    return _currentHeartRate;
  }

  double getAverageIntensity() {
    return _lastAverageIntensity ?? 0.0;
  }

  List<int> getIntensityValues() {
    return _intensityValues.map((e) => e.toInt()).toList();
  }

  List<double> _movingAverage(List<double> values, int windowSize) {
    List<double> averages = [];
    for (int i = 0; i <= values.length - windowSize; i++) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        sum += values[i + j];
      }
      averages.add(sum / windowSize);
    }
    return averages;
  }

  List<double> derivace(List<double> data) {
    List<double> derivative = [];
    for (int i = 0; i < data.length - 1; i++) {
      double diff = (data[i + 1] - data[i]) / 1;
      derivative.add(diff);
    }
    return derivative;
  }

  List<double> data_to_plot() {
    return _intensityValues2;
  }

  List<double> getPPGplot() {
    return _ppg_plot;
  }

  double calculateAverage(List<double> values) {
    if (values.isEmpty) {
      return 0;
    }
    double sum = values.reduce((a, b) => a + b);
    return sum / values.length;
  }

  double getMax() {
    if (yAxisMax > 120) {
      return 110;
    }
    return yAxisMax;
  }

  double getMin() {
    if (yAxisMin < 90) {
      return 100;
    }
    return yAxisMin;
  }

  double getSummary() {
    if (_bpm_total.isNotEmpty) {
      _bpm_total.removeWhere((item) => item == 0);
      _bpm_total.removeAt(0);

      // Použití mediánu místo průměru
      return calculateMedian(_bpm_total);
    }
    return 0;
  }

  List<double> applyLowPassFilter(
      List<double> signal, double cutoffFrequency, double samplingRate) {
    // Vypočítáme konstantu filtru
    double rc = 1.0 / (2 * pi * cutoffFrequency); // RC konstanta
    double dt = 1.0 / samplingRate; // Doba mezi vzorky
    double alpha = dt / (rc + dt); // Váhovací koeficient filtru

    List<double> filteredSignal = [];
    double previousValue = signal[0]; // Inicializace s první hodnotou signálu

    for (int i = 0; i < signal.length; i++) {
      // Aplikace filtru na aktuální vzorek
      double filteredValue =
          previousValue + alpha * (signal[i] - previousValue);
      filteredSignal.add(filteredValue);
      previousValue = filteredValue; // Aktualizace předchozí hodnoty
    }

    return filteredSignal;
  }

  List<double> get_Frames() {
    print(frames_list);

    // Vypočítáme průměr všech hodnot v `frames_list`
    final double average = frames_list.isNotEmpty
        ? frames_list.reduce((a, b) => a + b) / frames_list.length
        : 0.0; // Pokud je seznam prázdný, průměr bude 0.0

    // Přidáme průměr jako poslední prvek seznamu
    final List<double> result = List.from(frames_list)..add(average);

    return result;
  }

  double calculateMedian(List<double> values) {
    if (values.isEmpty) {
      return 0.0; // Pokud seznam hodnot není dostupný, vracíme 0
    }
    List<double> sortedValues = List.from(values)..sort(); // Seřadíme hodnoty
    int middleIndex = sortedValues.length ~/ 2; // Najdeme střední index

    // Pokud je počet hodnot lichý, vrátíme prostřední hodnotu
    if (sortedValues.length % 2 == 1) {
      return sortedValues[middleIndex];
    } else {
      // Pokud je počet hodnot sudý, vrátíme průměr dvou prostředních hodnot
      return (sortedValues[middleIndex - 1] + sortedValues[middleIndex]) / 2;
    }
  }
}
