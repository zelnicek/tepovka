// The demo predates package:web; dart:html still works for a JS build.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui;
import 'package:tepovka/ppg_algo.dart';

class WebVideoStream {
  WebVideoStream(this.assetPath) {
    // Create the video element up front so it can also be shown in the UI via HtmlElementView.
    _video = html.VideoElement()
      ..muted = true
      ..loop = true
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.borderRadius = '50%'
      ..style.backgroundColor = 'black';
    _video!.setAttribute('playsinline', 'true');
    _registerViewFactory();
  }

  final String assetPath;

  html.VideoElement? _video;
  html.CanvasElement? _canvas;
  html.CanvasRenderingContext2D? _ctx;
  Timer? _timer;
  bool _isRunning = false;
  static bool _viewFactoryRegistered = false;

  void _registerViewFactory() {
    if (_viewFactoryRegistered) return;
    // Expose the video element to Flutter as a platform view so we can show the PPG asset.
    ui.platformViewRegistry.registerViewFactory(
      'ppg-video',
      (int viewId) => _video!,
    );
    _viewFactoryRegistered = true;
  }

  bool get isRunning => _isRunning;

  Future<void> start(void Function(RgbMeans rgbMeans) onFrame) async {
    if (_isRunning) return;
    _isRunning = true;

    _video ??= html.VideoElement();
    _video!
      ..src = assetPath
      ..muted = true
      ..loop = true
      ..autoplay = true;
    _video!.setAttribute('playsinline', 'true');

    final completer = Completer<void>();
    _video!.onError.first.then((_) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError('Failed to load video asset $assetPath'),
        );
      }
    });
    _video!.onCanPlay.first.then((_) {
      if (!completer.isCompleted) {
        completer.complete();
      }
    });
    _video!.load();
    await completer.future;
    await _video!.play();

    const int targetWidth = 160;
    const int targetHeight = 120;
    _canvas = html.CanvasElement(width: targetWidth, height: targetHeight);
    _ctx = _canvas!.getContext('2d', {'willReadFrequently': true})
        as html.CanvasRenderingContext2D?;
    _ctx ??= _canvas!.context2D;

    const frameInterval = Duration(milliseconds: 33); // ~30 FPS
    _timer = Timer.periodic(frameInterval, (_) {
      final video = _video;
      final ctx = _ctx;
      if (!_isRunning || video == null || ctx == null) return;
      if (video.videoWidth == 0 || video.videoHeight == 0) return;

      ctx
        ..save()
        ..clearRect(0, 0, targetWidth, targetHeight)
        ..drawImageScaled(video, 0, 0, targetWidth, targetHeight)
        ..restore();

      final imageData = ctx.getImageData(0, 0, targetWidth, targetHeight);
      final data = imageData.data;
      double totalR = 0;
      double totalG = 0;
      double totalB = 0;
      final int count = data.length ~/ 4;
      for (int i = 0; i < data.length; i += 4) {
        totalR += data[i];
        totalG += data[i + 1];
        totalB += data[i + 2];
      }
      if (count > 0) {
        final rgb = RgbMeans(
          red: totalR / count,
          green: totalG / count,
          blue: totalB / count,
        );
        onFrame(rgb);
      }
    });
  }

  Future<void> stop() async {
    _isRunning = false;
    _timer?.cancel();
    _timer = null;
    _video?.pause();
    _video?.currentTime = 0;
    _canvas = null;
    _ctx = null;
  }
}
