import 'dart:ui';

import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/app_settings.dart';

/// The language the app speaks, for text made outside the widget tree (the
/// reminder, the home-screen widget): the one chosen in Settings, else the
/// phone's when the app has it, else Czech, the same rule as in main.dart.
Locale appLocale(AppSettingsData settings) {
  final Locale? chosen = settings.language.locale;
  if (chosen != null) return chosen;
  final String device = PlatformDispatcher.instance.locale.languageCode;
  return Locale(
      L10n.supportedLocales.any((locale) => locale.languageCode == device)
          ? device
          : 'cs');
}
