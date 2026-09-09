// pdf_create.dart

import 'package:flutter/foundation.dart';

import 'package:tepovka/l10n/app_localizations.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

/// Text the PDF needs, resolved by the caller which still has a BuildContext.
class PdfLabels {
  final String title;
  final String Function(String) date;
  final String Function(String) time;
  final String Function(String) averageBpm;
  final String Function(String) duration;
  final String Function(String) notes;
  final String hrvMetrics;
  final String signalChart;

  const PdfLabels({
    required this.title,
    required this.date,
    required this.time,
    required this.averageBpm,
    required this.duration,
    required this.notes,
    required this.hrvMetrics,
    required this.signalChart,
  });

  factory PdfLabels.of(L10n t) => PdfLabels(
        title: t.pdfTitle,
        date: t.pdfDate,
        time: t.pdfTime,
        averageBpm: t.pdfAverageBpm,
        duration: t.pdfDuration,
        notes: t.pdfNotes,
        hrvMetrics: t.pdfHrvMetrics,
        signalChart: t.pdfSignalChart,
      );
}

Future<String?> createPdf({
  required int averageBPM,
  required String notes,
  required int duration,
  required Map<String, String> hrvMetrics,
  required Uint8List? chartImageBytes,
  required String formattedDate,
  required String formattedTime,
  required PdfLabels labels,
}) async {
  try {
    final pdf = pw.Document();
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttf = pw.Font.ttf(fontData.buffer.asByteData());
    final logoData = await rootBundle.load('assets/Text_loading.png');
    final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());
    pw.ImageProvider? chartImage;
    if (chartImageBytes != null) {
      chartImage = pw.MemoryImage(chartImageBytes);
    }
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Stack(
            children: [
              pw.Positioned(
                  top: 0,
                  right: 0,
                  child: pw.Image(
                    logoImage,
                    width: 100,
                    height: 100,
                  )),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(labels.title,
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.SizedBox(height: 20),
                  pw.Text(labels.date(formattedDate),
                      style: pw.TextStyle(font: ttf)),
                  pw.Text(labels.time(formattedTime),
                      style: pw.TextStyle(font: ttf)),
                  pw.Text(labels.averageBpm('$averageBPM'),
                      style: pw.TextStyle(font: ttf)),
                  pw.Text(labels.duration('$duration'),
                      style: pw.TextStyle(font: ttf)),
                  pw.Text(labels.notes(notes), style: pw.TextStyle(font: ttf)),
                  pw.SizedBox(height: 20),
                  pw.Text(labels.hrvMetrics,
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.TableHelper.fromTextArray(
                    headers: ['Metrika', 'Hodnota'],
                    data: hrvMetrics.entries
                        .map((e) => [e.key, e.value])
                        .toList(),
                    headerStyle: pw.TextStyle(font: ttf),
                    cellStyle: pw.TextStyle(font: ttf),
                  ),
                  pw.SizedBox(height: 20),
                  if (chartImage != null) ...[
                    pw.Text(labels.signalChart,
                        style: pw.TextStyle(
                            fontSize: 18,
                            fontWeight: pw.FontWeight.bold,
                            font: ttf)),
                    pw.Image(chartImage, width: 500, height: 150),
                  ],
                ],
              ),
            ],
          );
        },
      ),
    );

    final directory = await getApplicationDocumentsDirectory();
    final pdfFile = File(
        '${directory.path}/hrv_report_${formattedDate}_$formattedTime.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile.path;
  } catch (e) {
    debugPrint('Error creating PDF: $e');
    return null;
  }
}
