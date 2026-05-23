import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class StorageService {
  static const String _summaryFileName = 'measurement_summary.json';
  static const String _exportTxtFileName = 'measurement_export.txt';

  Future<File> _getSummaryFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_summaryFileName');
  }

  Future<File> _getExportTxtFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$_exportTxtFileName');
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

  Future<void> appendRecordTxt(Map<String, dynamic> record) async {
    final file = await _getExportTxtFile();
    final buffer = StringBuffer();
    buffer.writeln('=== Tepovka measurement ===');
    buffer.writeln('date: ${record['date'] ?? ''}');
    buffer.writeln('time: ${record['time'] ?? ''}');
    buffer.writeln('averageBPM: ${record['averageBPM'] ?? ''}');
    buffer.writeln('respiratoryRate: ${record['respiratoryRate'] ?? ''}');
    buffer.writeln('spo2: ${record['spo2'] ?? ''}');
    final confidence =
        (record['confidence'] as Map?)?.cast<String, dynamic>() ??
            <String, dynamic>{};
    buffer.writeln('bpmConfidence: ${confidence['bpmConfidence'] ?? ''}');
    buffer.writeln('snrScore: ${confidence['snrScore'] ?? ''}');
    buffer.writeln('harmonicScore: ${confidence['harmonicScore'] ?? ''}');
    buffer.writeln('autocorrScore: ${confidence['autocorrScore'] ?? ''}');
    buffer.writeln('ciLowerBpm: ${confidence['ciLowerBpm'] ?? ''}');
    buffer.writeln('ciUpperBpm: ${confidence['ciUpperBpm'] ?? ''}');
    buffer.writeln('--- raw RGB samples ---');
    final rawRgbSamples = (record['rawRgbSamples'] as List?) ?? const [];
    for (int i = 0; i < rawRgbSamples.length; i++) {
      final sample = (rawRgbSamples[i] as Map?)?.cast<String, dynamic>() ??
          <String, dynamic>{};
      buffer.writeln(
          '$i,${sample['red'] ?? ''},${sample['green'] ?? ''},${sample['blue'] ?? ''}');
    }
    buffer.writeln('');
    await file.writeAsString(buffer.toString(), mode: FileMode.append);
  }
}
