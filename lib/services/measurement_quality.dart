import 'package:flutter/material.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// Signal quality of a finished measurement, as graded by
/// `assessRecording` in `elements/spectral_quality.dart`.
enum MeasurementQuality { good, medium, poor }

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
