import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _summaryFileName = 'measurement_summary.json';
  static const String _webPrefsKey = 'measurement_summary';

  Future<File> _getSummaryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_summaryFileName');
  }

  Future<List<Map<String, dynamic>>> readSummary() async {
    try {
      if (kIsWeb) {
        final prefs = await SharedPreferences.getInstance();
        final content = prefs.getString(_webPrefsKey);
        if (content == null || content.isEmpty) return <Map<String, dynamic>>[];
        final List<dynamic> jsonList = json.decode(content);
        return jsonList
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      } else {
        final file = await _getSummaryFile();
        if (!await file.exists()) {
          return <Map<String, dynamic>>[];
        }
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        return jsonList
            .whereType<Map<String, dynamic>>()
            .toList(growable: false);
      }
    } catch (_) {
      // If parsing fails, return empty to avoid crashing UI
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> writeSummary(List<Map<String, dynamic>> records) async {
    final content = json.encode(records);
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_webPrefsKey, content);
    } else {
      final file = await _getSummaryFile();
      await file.writeAsString(content, mode: FileMode.write);
    }
  }

  Future<void> appendRecord(Map<String, dynamic> record) async {
    final existing = await readSummary();
    final updated = List<Map<String, dynamic>>.from(existing)..add(record);
    await writeSummary(updated);
  }
}
