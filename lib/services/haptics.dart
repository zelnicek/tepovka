import 'package:flutter/services.dart';
import 'package:tepovka/services/app_settings.dart';

/// Haptic feedback that honours the Vibration switch in Settings. The app
/// used to call [HapticFeedback] directly, so turning the switch off did
/// nothing.
class Haptics {
  Haptics._();

  static bool get enabled => AppSettings.value.haptics;

  static void selection() {
    if (enabled) HapticFeedback.selectionClick();
  }

  static void light() {
    if (enabled) HapticFeedback.lightImpact();
  }

  static void medium() {
    if (enabled) HapticFeedback.mediumImpact();
  }
}
