import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

class LocalProfileService {
  static const _kLoggedIn = 'local_profile_logged_in';
  static const _kUserId = 'local_profile_id';
  static const _kDisplayName = 'local_profile_name';
  static const _kPin = 'local_profile_pin';

  static bool _initialized = false;
  static bool _loggedIn = false;
  static String? _userId;
  static String? _displayName;
  static String? _pin;

  static bool get isInitialized => _initialized;
  static bool get isLoggedIn => _loggedIn;
  static String? get userId => _userId;
  static String? get displayName => _displayName;
  static String? get pin => _pin;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedIn = prefs.getBool(_kLoggedIn) ?? false;
    _userId = prefs.getString(_kUserId);
    _displayName = prefs.getString(_kDisplayName);
    _pin = prefs.getString(_kPin);
    _initialized = true;
  }

  static Future<void> signInLocal({required String name, String? pin}) async {
    final prefs = await SharedPreferences.getInstance();
    // If no ID exists, generate a short local ID
    _userId ??= _generateShortId(12);
    _displayName = name.trim();
    _pin = (pin ?? '').trim().isEmpty ? null : pin!.trim();
    _loggedIn = true;
    await prefs.setBool(_kLoggedIn, true);
    await prefs.setString(_kUserId, _userId!);
    await prefs.setString(_kDisplayName, _displayName!);
    if (_pin != null) {
      await prefs.setString(_kPin, _pin!);
    } else {
      await prefs.remove(_kPin);
    }
  }

  static Future<void> signOutLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _loggedIn = false;
    await prefs.setBool(_kLoggedIn, false);
  }

  static String _generateShortId(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final rnd = Random.secure();
    return String.fromCharCodes(
      List.generate(length, (_) => chars.codeUnitAt(rnd.nextInt(chars.length))),
    );
  }
}
