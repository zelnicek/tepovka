import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/material_symbols_icons.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tepovka/l10n/app_localizations.dart';
import 'package:tepovka/services/measurement_quality.dart';
import 'package:tepovka/services/measurement_tags.dart';
import 'package:tepovka/widgets/info_widgets.dart';
import 'package:tepovka/widgets/settings_widgets.dart';

/// What the share card shows, gathered by the screen that opens it.
class ShareCardData {
  const ShareCardData({
    required this.bpm,
    required this.when,
    required this.durationS,
    required this.wave,
    this.quality,
    this.tags = const [],
  });

  final int bpm;
  final DateTime when;
  final int durationS;

  /// A few seconds of the pulse wave, evenly sampled, pulses pointing up.
  final List<double> wave;
  final MeasurementQuality? quality;
  final List<MeasurementTag> tags;
}

/// [seconds] of [samples] from the middle of the recording, where the
/// signal has settled and the finger has not started to move yet.
List<double> waveSnippet(List<double> samples, double fs,
    {double seconds = 6}) {
  final int n = (seconds * fs).round();
  if (samples.length <= n || n <= 0) return List<double>.from(samples);
  final int start = (samples.length - n) ~/ 2;
  return samples.sublist(start, start + n);
}

/// A picture of one measurement for Instagram, messages or the photo
/// library: the heart rate, when, a stretch of the pulse wave and the app's
/// name. Drawn at a fixed size in its own fonts and colours, so it looks the
/// same whatever the phone's text size; [render] makes it 1080 × 1350.
class ShareCard extends StatelessWidget {
  const ShareCard({super.key, required this.data});

  final ShareCardData data;

  /// 4:5, the shape Instagram shows uncropped in the feed and centred in a
  /// story.
  static const Size size = Size(360, 450);
  static const double outputWidth = 1080;

  @override
  Widget build(BuildContext context) {
    final L10n t = L10n.of(context);
    final String locale = Localizations.localeOf(context).toString();
    String date, time;
    try {
      date = DateFormat.yMMMMd(locale).format(data.when);
      time = DateFormat.jm(locale).format(data.when);
    } catch (_) {
      date = '${data.when.day}. ${data.when.month}. ${data.when.year}';
      time = '${data.when.hour}:${data.when.minute.toString().padLeft(2, '0')}';
    }
    final List<String> facts = [
      if (data.quality != null) t.a11ySignalQuality(data.quality!.label(t)),
      t.homeSecondsSuffix(data.durationS),
      for (final MeasurementTag tag in data.tags) tag.label(t),
    ];

    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.noScaling),
      child: Container(
        width: size.width,
        height: size.height,
        padding: const EdgeInsets.fromLTRB(26, 26, 26, 22),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFFDECEA)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(9),
                  child: Image.asset('assets/tepovka_icon.png',
                      width: 38, height: 38),
                ),
                const SizedBox(width: 10),
                const Text('Tepovka',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black)),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(date,
                        style: const TextStyle(
                            fontSize: 13, color: kInfoSecondaryText)),
                    Text(time,
                        style: const TextStyle(
                            fontSize: 13, color: kInfoSecondaryText)),
                  ],
                ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${data.bpm}',
                  style: const TextStyle(
                    fontSize: 104,
                    height: 0.95,
                    fontWeight: FontWeight.w800,
                    color: Colors.black,
                    letterSpacing: -3,
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.favorite, color: kInfoAccent, size: 30),
                      Text(t.homeBpmUnit,
                          style: const TextStyle(
                              fontSize: 22, color: kInfoSecondaryText)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(t.shareCardHeartRate,
                style:
                    const TextStyle(fontSize: 15, color: kInfoSecondaryText)),
            const SizedBox(height: 22),
            SizedBox(
              height: 86,
              width: double.infinity,
              child: CustomPaint(painter: _WavePainter(data.wave)),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final String fact in facts)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFF2C4C0)),
                    ),
                    child: Text(fact,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF8A2A24))),
                  ),
              ],
            ),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(t.shareCardFooter,
                      style: const TextStyle(
                          fontSize: 11, color: kInfoSecondaryText)),
                ),
                Opacity(
                  opacity: 0.85,
                  child: Image.asset('assets/Text_loading.png', height: 24),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The pulse wave as one red line over a pale fill, scaled to the box with
/// the extremes trimmed, so one spike cannot flatten the rest.
class _WavePainter extends CustomPainter {
  _WavePainter(this.wave);

  final List<double> wave;

  @override
  void paint(Canvas canvas, Size size) {
    if (wave.length < 2) return;
    final List<double> sorted = List<double>.from(wave)..sort();
    final double lo = sorted[(sorted.length * 0.02).floor()];
    final double hi =
        sorted[min(sorted.length - 1, (sorted.length * 0.98).ceil())];
    final double span = hi - lo == 0 ? 1 : hi - lo;
    Offset at(int i) => Offset(
          size.width * i / (wave.length - 1),
          size.height * (1 - ((wave[i] - lo) / span).clamp(-0.05, 1.05)),
        );

    final Path line = Path()..moveTo(at(0).dx, at(0).dy);
    for (int i = 1; i < wave.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    final Path fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(0, size.height),
          [
            kInfoAccent.withValues(alpha: 0.18),
            kInfoAccent.withValues(alpha: 0)
          ],
        ),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = kInfoAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.wave != wave;
}

/// A sheet with the card as it will look and a Share button, which hands a
/// 1080 × 1350 PNG to the system share sheet (Instagram, Messages, Photos).
Future<void> showShareCardSheet(BuildContext context, ShareCardData data) {
  final L10n t = L10n.of(context);
  final GlobalKey boundaryKey = GlobalKey();
  bool busy = false;

  Future<void> share(BuildContext sheetContext, StateSetter setState) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final RenderBox? box = sheetContext.findRenderObject() as RenderBox?;
    final Rect? origin =
        box == null ? null : box.localToGlobal(Offset.zero) & box.size;
    setState(() => busy = true);
    try {
      final RenderRepaintBoundary boundary = boundaryKey.currentContext!
          .findRenderObject()! as RenderRepaintBoundary;
      // The preview may be scaled to fit; the boundary inside draws at the
      // card's own size, so the picture is always full resolution.
      final ui.Image image = await boundary.toImage(
          pixelRatio: ShareCard.outputWidth / ShareCard.size.width);
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final Directory dir = await getTemporaryDirectory();
      final String stamp = DateFormat('yyyy-MM-dd_HHmm').format(data.when);
      final File file = File('${dir.path}/Tepovka_${data.bpm}bpm_$stamp.png');
      await file.writeAsBytes(png!.buffer.asUint8List());
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'image/png')],
        sharePositionOrigin: origin,
      ));
    } catch (e) {
      debugPrint('Share card failed: $e');
      messenger.showSnackBar(SnackBar(content: Text(t.shareCardFailed)));
    } finally {
      if (sheetContext.mounted) setState(() => busy = false);
    }
  }

  return showSettingsSheet<void>(
    context,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setState) {
        final double maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.58;
        return SettingsSheet(
          title: t.shareCardTitle,
          children: [
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxHeight),
                child: AspectRatio(
                  aspectRatio: ShareCard.size.aspectRatio,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x22000000),
                            blurRadius: 18,
                            offset: Offset(0, 6)),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(18),
                      child: FittedBox(
                        child: RepaintBoundary(
                          key: boundaryKey,
                          child: ShareCard(data: data),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            SettingsPrimaryButton(
              icon: Symbols.ios_share,
              label: t.shareCardShare,
              busy: busy,
              onPressed: () => share(sheetContext, setState),
            ),
          ],
        );
      },
    ),
  );
}
