import 'package:tepovka/ppg_algo.dart';

class WebVideoStream {
  WebVideoStream(this.assetPath);

  final String assetPath;

  bool get isRunning => false;

  Future<void> start(void Function(RgbMeans rgbMeans) onFrame) {
    return Future.error(
      UnsupportedError('WebVideoStream is only available on Flutter Web.'),
    );
  }

  Future<void> stop() async {}
}
