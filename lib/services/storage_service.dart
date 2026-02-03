import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String _summaryFileName = 'measurement_summary.json';

  Future<File> _getSummaryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_summaryFileName');
  }

  Future<List<Map<String, dynamic>>> readSummary() async {
    try {
      final file = await _getSummaryFile();
      if (!await file.exists()) {
        return <Map<String, dynamic>>[];
      }
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.whereType<Map<String, dynamic>>().toList(growable: false);
    } catch (e) {
      // If parsing fails, return empty to avoid crashing UI
      return <Map<String, dynamic>>[];
    }
  }

  Future<void> writeSummary(List<Map<String, dynamic>> records) async {
    final file = await _getSummaryFile();
    final content = json.encode(records);
    await file.writeAsString(content, mode: FileMode.write);
  }

  Future<void> appendRecord(Map<String, dynamic> record) async {
    final existing = await readSummary();
    final updated = List<Map<String, dynamic>>.from(existing)..add(record);
    await writeSummary(updated);
  }
}
