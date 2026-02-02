// pdf_create.dart
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/services.dart';

Future<String?> createPdf({
  required int averageBPM,
  required String notes,
  required int duration,
  required Map<String, String> hrvMetrics,
  required Uint8List? chartImageBytes,
  required String formattedDate,
  required String formattedTime,
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
                  pw.Text('Měření tepové frekvence a HRV',
                      style: pw.TextStyle(
                          fontSize: 24,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.SizedBox(height: 20),
                  pw.Text('Datum: $formattedDate',
                      style: pw.TextStyle(font: ttf)),
                  pw.Text('Čas: $formattedTime',
                      style: pw.TextStyle(font: ttf)),
                  pw.Text('Průměrný BPM: $averageBPM',
                      style: pw.TextStyle(font: ttf)),
                  pw.Text('Délka měření: $duration sekund',
                      style: pw.TextStyle(font: ttf)),
                  pw.Text('Poznámky: $notes', style: pw.TextStyle(font: ttf)),
                  pw.SizedBox(height: 20),
                  pw.Text('HRV Metriky:',
                      style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                          font: ttf)),
                  pw.Table.fromTextArray(
                    headers: ['Metrika', 'Hodnota'],
                    data: hrvMetrics.entries
                        .map((e) => [e.key, e.value])
                        .toList(),
                    headerStyle: pw.TextStyle(font: ttf),
                    cellStyle: pw.TextStyle(font: ttf),
                  ),
                  pw.SizedBox(height: 20),
                  if (chartImage != null) ...[
                    pw.Text('Graf signálu:',
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
        '${directory.path}/hrv_report_${formattedDate}_${formattedTime}.pdf');
    await pdfFile.writeAsBytes(await pdf.save());
    return pdfFile.path;
  } catch (e) {
    print('Error creating PDF: $e');
    return null;
  }
}
