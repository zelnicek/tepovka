import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:tepovka/l10n/app_localizations.dart';

/// Circumstances of a measurement, picked with a tap after measuring, next
/// to the free note. Stored by [name], so labels and order can change
/// without touching saved records.
enum MeasurementTag {
  rest,
  morning,
  exercise,
  caffeine,
  stress;

  /// Tags that lift the heart rate above resting. The weekly trend leaves
  /// these readings out, so it follows the resting heart rate.
  bool get raisesHeartRate =>
      this == exercise || this == caffeine || this == stress;

  /// The tags stored in a record, ignoring names this version does not know.
  static List<MeasurementTag> fromNames(Iterable<String> names) => [
        for (final String name in names)
          ...MeasurementTag.values.where((t) => t.name == name),
      ];
}

extension MeasurementTagX on MeasurementTag {
  String label(L10n t) => switch (this) {
        MeasurementTag.rest => t.tagRest,
        MeasurementTag.morning => t.tagMorning,
        MeasurementTag.exercise => t.tagExercise,
        MeasurementTag.caffeine => t.tagCaffeine,
        MeasurementTag.stress => t.tagStress,
      };

  IconData get icon => switch (this) {
        MeasurementTag.rest => Symbols.self_improvement,
        MeasurementTag.morning => Symbols.wb_twilight,
        MeasurementTag.exercise => Symbols.directions_run,
        MeasurementTag.caffeine => Symbols.coffee,
        MeasurementTag.stress => Symbols.bolt,
      };
}
