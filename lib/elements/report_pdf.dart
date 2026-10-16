import 'dart:math';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:tepovka/l10n/app_localizations.dart';

/// One measurement in the report, already formatted by the caller, which has
/// the locale. [quality] is 'good', 'medium', 'poor' or null.
class ReportEntry {
  const ReportEntry({
    required this.date,
    required this.time,
    required this.durationS,
    required this.bpm,
    this.sdnnMs,
    this.rmssdMs,
    this.quality,
    this.note = '',
  });

  final String date;
  final String time;
  final int durationS;
  final int bpm;

  /// Only for measurements long enough to read HRV from; null otherwise.
  final double? sdnnMs;
  final double? rmssdMs;
  final String? quality;
  final String note;
}

/// The report's text, resolved by the caller from [L10n].
class ReportLabels {
  ReportLabels.of(L10n t)
      : title = t.reportTitle,
        measurements = t.reportMeasurements,
        average = t.reportAverage,
        range = t.reportRange,
        sdnn = t.reportSdnn,
        chartTitle = t.reportChartTitle,
        tableTitle = t.reportTableTitle,
        colDate = t.reportColDate,
        colTime = t.reportColTime,
        colDuration = t.reportColDuration,
        colBpm = t.reportColBpm,
        colQuality = t.reportColQuality,
        colNote = t.reportColNote,
        disclaimer = t.reportDisclaimer,
        bpmUnit = t.homeBpmUnit,
        qualityGood = t.qualityGood,
        qualityMedium = t.qualityMedium,
        qualityPoor = t.qualityBad,
        qualityUnknown = t.reportQualityUnknown,
        page = t.reportPage,
        seconds = t.homeSecondsSuffix;

  final String title;
  final String measurements;
  final String average;
  final String range;
  final String sdnn;
  final String chartTitle;
  final String tableTitle;
  final String colDate;
  final String colTime;
  final String colDuration;
  final String colBpm;
  final String colQuality;
  final String colNote;
  final String disclaimer;
  final String bpmUnit;
  final String qualityGood;
  final String qualityMedium;
  final String qualityPoor;

  /// Records saved before signal quality was graded.
  final String qualityUnknown;
  final String Function(int page, int pages) page;
  final String Function(int seconds) seconds;

  String? qualityLabel(String? q) => switch (q) {
        'good' => qualityGood,
        'medium' => qualityMedium,
        'poor' => qualityPoor,
        _ => null,
      };
}

const PdfColor _accent = PdfColor.fromInt(0xFFE53935);
const PdfColor _amber = PdfColor.fromInt(0xFFE8A317);
const PdfColor _muted = PdfColor.fromInt(0xFFBDBDBD);
const PdfColor _ungraded = PdfColor.fromInt(0xFFF6C9C6);
const PdfColor _grey = PdfColor.fromInt(0xFF6E6D6D);
const PdfColor _hairline = PdfColor.fromInt(0xFFE0E0E0);

/// A report of several measurements for the doctor: who and when, a summary,
/// the heart rate of each measurement as bars, and a table. [entries] are
/// oldest first. [headerLines] are shown under the title (patient, period,
/// date of the report).
Future<Uint8List> buildReportPdf({
  required List<ReportEntry> entries,
  required ReportLabels labels,
  required List<String> headerLines,
}) async {
  // Roboto carries the Czech letters; the PDF's built-in fonts do not.
  final pw.Font regular =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Regular.ttf'));
  final pw.Font bold =
      pw.Font.ttf(await rootBundle.load('assets/fonts/Roboto-Bold.ttf'));
  final pw.MemoryImage logo = pw.MemoryImage(
      (await rootBundle.load('assets/Text_loading.png')).buffer.asUint8List());

  final List<int> bpms = [
    for (final ReportEntry e in entries)
      if (e.bpm > 0) e.bpm
  ];
  final List<double> sdnns = [
    for (final ReportEntry e in entries)
      if (e.sdnnMs != null) e.sdnnMs!
  ];
  final bool showHrv = sdnns.isNotEmpty;

  pw.Widget stat(String label, String value) => pw.Expanded(
        child: pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _hairline),
            borderRadius: pw.BorderRadius.circular(6),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(label,
                  style: const pw.TextStyle(fontSize: 9, color: _grey)),
              pw.SizedBox(height: 3),
              pw.Text(value, style: pw.TextStyle(fontSize: 16, font: bold)),
            ],
          ),
        ),
      );

  final List<pw.Widget> stats = [
    stat(labels.measurements, '${entries.length}'),
    if (bpms.isNotEmpty) ...[
      stat(labels.average,
          '${(bpms.reduce((a, b) => a + b) / bpms.length).round()} ${labels.bpmUnit}'),
      stat(
          labels.range,
          bpms.reduce(min) == bpms.reduce(max)
              ? '${bpms.reduce(min)} ${labels.bpmUnit}'
              : '${bpms.reduce(min)}–${bpms.reduce(max)} ${labels.bpmUnit}'),
    ],
    if (showHrv)
      stat(labels.sdnn,
          '${(sdnns.reduce((a, b) => a + b) / sdnns.length).round()} ms'),
  ];

  PdfColor barColor(String? q) => switch (q) {
        'medium' => _amber,
        'poor' => _muted,
        'good' => _accent,
        _ => _ungraded,
      };

  pw.Widget chart() {
    final int lo = bpms.reduce(min);
    final int hi = bpms.reduce(max);
    const double height = 90;
    final List<ReportEntry> shown = [
      for (final ReportEntry e in entries)
        if (e.bpm > 0) e
    ];
    pw.Widget legend(PdfColor color, String label) => pw.Row(children: [
          pw.Container(
              width: 7,
              height: 7,
              decoration:
                  pw.BoxDecoration(color: color, shape: pw.BoxShape.circle)),
          pw.SizedBox(width: 3),
          pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: _grey)),
          pw.SizedBox(width: 10),
        ]);
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.SizedBox(
              width: 26,
              height: height,
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text('$hi',
                      style: const pw.TextStyle(fontSize: 8, color: _grey)),
                  pw.Text('$lo',
                      style: const pw.TextStyle(fontSize: 8, color: _grey)),
                ],
              ),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(
              child: pw.SizedBox(
                height: height,
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    for (int i = 0; i < shown.length; i++) ...[
                      if (i > 0) pw.SizedBox(width: shown.length > 40 ? 1 : 3),
                      pw.Expanded(
                        child: pw.Container(
                          height: hi == lo
                              ? height * 0.6
                              : height *
                                  (0.15 +
                                      0.85 * (shown[i].bpm - lo) / (hi - lo)),
                          decoration: pw.BoxDecoration(
                            color: barColor(shown[i].quality),
                            borderRadius: pw.BorderRadius.circular(1.5),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 6),
        pw.Padding(
          padding: const pw.EdgeInsets.only(left: 32),
          child: pw.Row(children: [
            legend(_accent, labels.qualityGood),
            legend(_amber, labels.qualityMedium),
            legend(_muted, labels.qualityPoor),
            if (shown.any((e) => labels.qualityLabel(e.quality) == null))
              legend(_ungraded, labels.qualityUnknown),
          ]),
        ),
      ],
    );
  }

  String fmt(double? v) => v == null ? '—' : v.round().toString();

  final List<String> headers = [
    labels.colDate,
    labels.colTime,
    labels.colDuration,
    '${labels.colBpm} (${labels.bpmUnit})',
    if (showHrv) ...['SDNN (ms)', 'RMSSD (ms)'],
    labels.colQuality,
    labels.colNote,
  ];
  final List<List<String>> rows = [
    for (final ReportEntry e in entries)
      [
        e.date,
        e.time,
        labels.seconds(e.durationS),
        e.bpm > 0 ? '${e.bpm}' : '—',
        if (showHrv) ...[fmt(e.sdnnMs), fmt(e.rmssdMs)],
        labels.qualityLabel(e.quality) ?? '—',
        e.note,
      ],
  ];
  final int noteColumn = headers.length - 1;

  final pw.Document doc = pw.Document(
    title: labels.title,
    creator: 'Tepovka',
  );
  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 36),
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
      footer: (context) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: _hairline, height: 12),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text(labels.disclaimer,
                    style: const pw.TextStyle(fontSize: 7.5, color: _grey)),
              ),
              pw.SizedBox(width: 16),
              pw.Text(labels.page(context.pageNumber, context.pagesCount),
                  style: const pw.TextStyle(fontSize: 8, color: _grey)),
            ],
          ),
        ],
      ),
      build: (context) => [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Expanded(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(labels.title,
                      style: pw.TextStyle(fontSize: 20, font: bold)),
                  pw.SizedBox(height: 6),
                  for (final String line in headerLines)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 2),
                      child: pw.Text(line,
                          style:
                              const pw.TextStyle(fontSize: 10, color: _grey)),
                    ),
                ],
              ),
            ),
            pw.Image(logo, width: 80),
          ],
        ),
        pw.SizedBox(height: 16),
        pw.Row(
          children: [
            for (int i = 0; i < stats.length; i++) ...[
              if (i > 0) pw.SizedBox(width: 8),
              stats[i],
            ],
          ],
        ),
        if (bpms.length >= 2) ...[
          pw.SizedBox(height: 18),
          pw.Text(labels.chartTitle,
              style: pw.TextStyle(fontSize: 12, font: bold)),
          pw.SizedBox(height: 8),
          chart(),
        ],
        pw.SizedBox(height: 18),
        pw.Text(labels.tableTitle,
            style: pw.TextStyle(fontSize: 12, font: bold)),
        pw.SizedBox(height: 6),
        pw.TableHelper.fromTextArray(
          headers: headers,
          data: rows,
          headerStyle: pw.TextStyle(fontSize: 8.5, font: bold),
          headerAlignment: pw.Alignment.centerLeft,
          cellStyle: const pw.TextStyle(fontSize: 8.5),
          headerDecoration:
              const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF2F2F2)),
          border: const pw.TableBorder(
            horizontalInside: pw.BorderSide(color: _hairline, width: 0.5),
            bottom: pw.BorderSide(color: _hairline, width: 0.5),
          ),
          cellPadding:
              const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          cellAlignment: pw.Alignment.centerLeft,
          cellAlignments: {
            for (int c = 2; c < noteColumn - 1; c++)
              c: pw.Alignment.centerRight,
          },
          columnWidths: {
            noteColumn: const pw.FlexColumnWidth(2.2),
          },
        ),
      ],
    ),
  );
  return doc.save();
}
