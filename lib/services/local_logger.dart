import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalLogger {
  static File? _logFile;

  static Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _logFile = File('${dir.path}/app_logs.jsonl');
      if (!await _logFile!.exists()) {
        await _logFile!.create(recursive: true);
      }
    } catch (e) {
      // ignore errors during init
    }
  }

  static Future<void> log(String level, String message,
      [Map<String, dynamic>? data]) async {
    try {
      if (_logFile == null) await init();
      final entry = {
        'ts': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
        'data': data ?? {}
      };
      await _logFile!
          .writeAsString(jsonEncode(entry) + '\n', mode: FileMode.append);
    } catch (_) {}
  }

  static Future<String?> getLogFilePath() async {
    if (_logFile == null) await init();
    return _logFile?.path;
  }
}
