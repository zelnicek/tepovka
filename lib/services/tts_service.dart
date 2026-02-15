import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tepovka/services/app_settings.dart';

class TtsService {
  TtsService._internal();
  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  String? _lastQualityAnnounced;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    // Configure Czech voice and sensible defaults
    // Try to set Czech language if available, fallback gracefully
    try {
      final langs = await _tts.getLanguages;
      if (langs is List) {
        String? chosen;
        if (langs.contains('cs-CZ')) {
          chosen = 'cs-CZ';
        } else if (langs.any((l) => ('$l').startsWith('cs'))) {
          chosen = langs.firstWhere((l) => ('$l').startsWith('cs')).toString();
        }
        await _tts.setLanguage(chosen ?? 'cs-CZ');
      } else {
        await _tts.setLanguage('cs-CZ');
      }
    } catch (_) {
      await _tts.setLanguage('cs-CZ');
    }
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);

    // Prefer speaker and playback category on iOS (works in silent mode)
    if (Platform.isIOS) {
      try {
        await _tts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
        );
      } catch (_) {
        // ignore
      }
    }

    // Prefer Czech voice if available
    try {
      final voices = await _tts.getVoices;
      if (voices is List) {
        final cz = voices.cast<dynamic>().firstWhere(
          (v) {
            try {
              final m = Map<String, dynamic>.from(v as Map);
              final locale = (m['locale'] ?? '').toString().toLowerCase();
              final name = (m['name'] ?? '').toString().toLowerCase();
              return locale.contains('cs') || name.contains('czech');
            } catch (_) {
              return false;
            }
          },
          orElse: () => null,
        );
        if (cz != null) {
          await _tts.setVoice(Map<String, String>.from(cz as Map));
        }
      }
    } catch (_) {
      // ignore
    }
    _initialized = true;
  }

  bool get _seniorEnabled => AppSettings.value.seniorMode;

  Future<void> speak(String text) async {
    if (!_seniorEnabled) return;
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // silently ignore TTS errors
    }
  }

  Future<void> announceCountdown() async {
    if (!_seniorEnabled) return;
    await _ensureInit();
    // Single clear phrase to avoid overlapping ticks
    await speak('Nahrávání začne za tři, dva, jedna.');
  }

  Future<void> announceMeasurementEnd() async {
    await _speakWithTimeout(
        'Měření ukončeno.', const Duration(milliseconds: 1500));
  }

  Future<void> announceQuality(String quality) async {
    if (!_seniorEnabled) return;
    // Avoid repeating same announcement
    if (_lastQualityAnnounced == quality) return;
    _lastQualityAnnounced = quality;
    switch (quality) {
      case 'Dobrá':
        await speak('Signál je dobrý.');
        break;
      case 'Špatná':
        await speak('Signál je horší, nehýbejte se.');
        break;
      case 'Špatný kontakt':
        await speak('Špatný kontakt s kamerou.');
        break;
      case 'Žádný prst':
        await speak('Přiložte prst na kameru.');
        break;
      default:
        // No announcement for other custom labels
        break;
    }
  }

  // Test helper: speak regardless of Senior mode (for diagnostics)
  Future<void> testSpeak() async {
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak('Testovací hlas funguje.');
    } catch (_) {
      // ignore
    }
  }

  Future<void> _speakWithTimeout(String text, Duration timeout) async {
    await _ensureInit();
    bool finished = false;
    try {
      // Interrupt any current speech for clarity
      await _tts.stop();
      final speakFuture = _tts.speak(text).then((_) => finished = true);
      await Future.any([speakFuture, Future.delayed(timeout)]);
      if (!finished) {
        // Stop if timed out to avoid lingering playback
        await _tts.stop();
      }
    } catch (_) {
      // ignore errors
    }
  }
}
