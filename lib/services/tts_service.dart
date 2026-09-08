import 'dart:io' show Platform;
import 'package:flutter_tts/flutter_tts.dart';
import 'package:tepovka/elements/signal_quality_checker.dart';
import 'package:tepovka/services/app_settings.dart';

class TtsService {
  TtsService._internal();
  static final TtsService instance = TtsService._internal();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  SignalQuality? _lastQualityAnnounced;

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

  /// [phrase] is supplied by the caller, which has a BuildContext to resolve it.
  Future<void> announceCountdown(String phrase) async {
    if (!_seniorEnabled) return;
    await _ensureInit();
    // Single clear phrase to avoid overlapping ticks
    await speak(phrase);
  }

  Future<void> announceMeasurementEnd(String phrase) async {
    await _speakWithTimeout(phrase, const Duration(milliseconds: 1500));
  }

  /// Announces a quality change. The caller passes the localised phrase,
  /// because this service has no BuildContext to look one up with.
  Future<void> announceQuality(SignalQuality quality, String phrase) async {
    if (!_seniorEnabled) return;
    // Avoid repeating same announcement
    if (_lastQualityAnnounced == quality) return;
    _lastQualityAnnounced = quality;
    await speak(phrase);
  }

  // Test helper: speak regardless of Senior mode (for diagnostics)
  Future<void> testSpeak(String phrase) async {
    await _ensureInit();
    try {
      await _tts.stop();
      await _tts.speak(phrase);
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
