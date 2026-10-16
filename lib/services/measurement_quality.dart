import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// Signal quality of a finished measurement.
enum MeasurementQuality { good, medium, poor }

/// Grades a measurement by the confidence (0–1) the analysis reported for its
/// heart rate. The live screen accepts a reading from 0.3, so below that the
/// result is poor; from 0.6 the spectral and autocorrelation estimates agree
/// well. Null when no confidence is known (records saved before it was
/// stored).
MeasurementQuality? measurementQualityFrom(num? confidence) {
  if (confidence == null || !confidence.isFinite) return null;
  if (confidence >= 0.6) return MeasurementQuality.good;
  if (confidence >= 0.3) return MeasurementQuality.medium;
  return MeasurementQuality.poor;
}

extension MeasurementQualityX on MeasurementQuality {
  String label(L10n t) => switch (this) {
        MeasurementQuality.good => t.qualityGood,
        MeasurementQuality.medium => t.qualityMedium,
        MeasurementQuality.poor => t.qualityBad,
      };

  Color get color => switch (this) {
        MeasurementQuality.good => const Color(0xFF1E8E3E),
        MeasurementQuality.medium => const Color(0xFFE8A317),
        MeasurementQuality.poor => const Color(0xFFE53935),
      };
}
