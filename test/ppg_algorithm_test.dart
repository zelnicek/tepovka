import 'package:flutter_test/flutter_test.dart';
import 'package:tepovka/ppg_algo.dart';

void main() {
  group('PPG Algorithm Tests', () {
    late PPGAlgorithm ppgAlgorithm;

    setUp(() {
      ppgAlgorithm = PPGAlgorithm();
    });

    group('calculateStandardDeviation', () {
      test('Empty list returns 0', () {
        expect(ppgAlgorithm.calculateStandardDeviation([]), equals(0.0));
      });

      test('Single value returns 0', () {
        expect(ppgAlgorithm.calculateStandardDeviation([5.0]), equals(0.0));
      });

      test('Identical values return 0', () {
        final values = [3.0, 3.0, 3.0, 3.0];
        expect(ppgAlgorithm.calculateStandardDeviation(values),
            closeTo(0.0, 0.001));
      });

      test('Known dataset calculates correct std dev', () {
        // For [1, 2, 3, 4, 5]: mean=3, std_dev≈1.414
        final values = [1.0, 2.0, 3.0, 4.0, 5.0];
        final result = ppgAlgorithm.calculateStandardDeviation(values);
        expect(result, closeTo(1.4142, 0.001));
      });

      test('Normal PPG signal variation', () {
        // Simulate realistic PPG signal values (in AU)
        final values = [
          100.0,
          105.2,
          102.1,
          98.5,
          101.3,
          103.8,
          99.2,
          102.5,
          104.1,
          100.5
        ];
        final result = ppgAlgorithm.calculateStandardDeviation(values);
        expect(result, greaterThan(0.0));
        expect(result, lessThan(10.0)); // PPG typically has low variation
      });

      test('Returns positive value for non-identical data', () {
        final values = [1.0, 2.0, 3.0];
        expect(
            ppgAlgorithm.calculateStandardDeviation(values), greaterThan(0.0));
      });
    });

    group('PPGAlgorithm State Management', () {
      test('Algorithm initializes with zero HR', () {
        expect(ppgAlgorithm.getCurrentHeartRate(), equals(0.0));
      });

      test('Algorithm initializes with zero RR', () {
        expect(ppgAlgorithm.getCurrentRespiratoryRate(), equals(0.0));
      });

      test('Algorithm initializes with empty frames buffer', () {
        expect(ppgAlgorithm.getFrames().isEmpty, true);
      });

      test('Reset clears all metrics', () {
        ppgAlgorithm.reset();
        expect(ppgAlgorithm.getCurrentHeartRate(), equals(0.0));
        expect(ppgAlgorithm.getCurrentRespiratoryRate(), equals(0.0));
      });
    });

    group('HRV Metrics Validity', () {
      test('SDNN returns valid range (0-500 ms)', () {
        final sdnn = ppgAlgorithm.getSdnn();
        expect(sdnn, greaterThanOrEqualTo(0.0));
        expect(sdnn, lessThanOrEqualTo(500.0));
      });

      test('RMSSD returns valid range (0-500 ms)', () {
        final rmssd = ppgAlgorithm.getRmssd();
        expect(rmssd, greaterThanOrEqualTo(0.0));
        expect(rmssd, lessThanOrEqualTo(500.0));
      });

      test('pNN50 returns percentage (0-100%)', () {
        final pnn50 = ppgAlgorithm.getPnn50();
        expect(pnn50, greaterThanOrEqualTo(0.0));
        expect(pnn50, lessThanOrEqualTo(100.0));
      });

      test('SD1 returns reasonable range (0-200 ms)', () {
        final sd1 = ppgAlgorithm.getSd1();
        expect(sd1, greaterThanOrEqualTo(0.0));
        expect(sd1, lessThanOrEqualTo(200.0));
      });

      test('SD2 returns reasonable range (0-500 ms)', () {
        final sd2 = ppgAlgorithm.getSd2();
        expect(sd2, greaterThanOrEqualTo(0.0));
        expect(sd2, lessThanOrEqualTo(500.0));
      });
    });

    group('Heart Rate Validity', () {
      test('getCurrentHeartRate returns value in valid range', () {
        final hr = ppgAlgorithm.getCurrentHeartRate();
        expect(hr, greaterThanOrEqualTo(0.0));
        expect(hr, lessThanOrEqualTo(200.0)); // Clamped in algorithm
      });

      test('currentHeartRate getter returns value in valid range', () {
        final hr = ppgAlgorithm.currentHeartRate;
        expect(hr, greaterThanOrEqualTo(0.0));
        expect(hr, lessThanOrEqualTo(200.0));
      });

      test('Heart rate starts at 0', () {
        final ppg = PPGAlgorithm();
        expect(ppg.getCurrentHeartRate(), equals(0.0));
      });
    });

    group('Respiratory Rate Validity', () {
      test('getCurrentRespiratoryRate returns value in valid range', () {
        final rr = ppgAlgorithm.getCurrentRespiratoryRate();
        expect(rr, greaterThanOrEqualTo(0.0));
        expect(rr, lessThanOrEqualTo(30.0)); // Clamped in algorithm
      });

      test('Respiratory rate starts at 0', () {
        final ppg = PPGAlgorithm();
        expect(ppg.getCurrentRespiratoryRate(), equals(0.0));
      });
    });

    group('Data Plotting', () {
      test('dataToPlot returns a list', () {
        final plot = ppgAlgorithm.dataToPlot();
        expect(plot, isA<List<double>>());
      });

      test('dataToPlot returns empty list initially', () {
        final ppg = PPGAlgorithm();
        expect(ppg.dataToPlot().isEmpty, true);
      });
    });
  });
}
