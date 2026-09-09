import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';

class CameraBody extends StatefulWidget {
  final CameraDescription cameraDescription;
  final void Function(CameraController) onCameraReady;
  final void Function(CameraImage) onImageAvailable;

  const CameraBody({
    super.key,
    required this.cameraDescription,
    required this.onCameraReady,
    required this.onImageAvailable,
  });

  @override
  State<CameraBody> createState() => _CameraBodyState();
}

class _CameraBodyState extends State<CameraBody> {
  CameraController? _cameraController;
  Future<void>? _initializeControllerFuture;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  /// Pozadovana snimkovaci frekvence, od nejlepsi po nouzovou.
  ///
  /// Bez explicitniho pozadavku si iOS pri tmave scene — a prst pritisknuty
  /// na objektiv tmava scena je — prodlouzi expozici a spadne na nejnizsi
  /// snimkovaci frekvenci formatu. V merenich z leta 2026 to bylo shodne
  /// 23,96–24,00 fps u vsech telefonu a zaznamu. Nastaveni fps zamkne na iOS
  /// minimalni i maximalni delku snimku, takze expozice nemuze byt delsi nez
  /// 1/fps a frekvence se prestane propadat.
  ///
  /// Vyssi fps znamena jemnejsi intervaly mezi tepy (pri 60 fps krok 17 ms
  /// misto 42 ms), coz je rozdil mezi orientacnim a pouzitelnym HRV.
  static const List<int?> _preferredFps = [60, 30, null];

  Future<void> _initializeCamera() async {
    for (final int? fps in _preferredFps) {
      // PPG only needs the mean intensity of a small ROI, so the stream runs at
      // the lowest preset. High presets (e.g. 12 MP on iPhone 12) make every
      // frame cost millions of per-pixel operations on the UI isolate, which is
      // what caused the dropped frames.
      final controller = CameraController(
        widget.cameraDescription,
        ResolutionPreset.low,
        enableAudio: false,
        fps: fps,
        imageFormatGroup: Platform.isIOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );

      try {
        _cameraController = controller;
        _initializeControllerFuture = controller.initialize();
        await _initializeControllerFuture;

        if (mounted) {
          setState(() {});
          widget.onCameraReady(controller);
        }
        return;
      } catch (e) {
        // Ne kazdy telefon zvladne kazdy format; zkusi se nizsi frekvence
        // a nakonec puvodni chovani bez pozadavku.
        debugPrint('Camera init at ${fps ?? 'default'} fps failed: $e');
        _cameraController = null;
        try {
          await controller.dispose();
        } catch (e) {
          debugPrint('Discarding failed camera controller: $e');
        }
      }
    }
  }

  @override
  void dispose() {
    if (_cameraController != null) {
      try {
        if (_cameraController!.value.isStreamingImages) {
          _cameraController!.stopImageStream();
        }
      } catch (e) {
        debugPrint('Stopping image stream on dispose failed: $e');
      }
      try {
        _cameraController!.dispose();
      } catch (e) {
        debugPrint('Camera dispose failed: $e');
      }
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializeControllerFuture == null) {
      return const Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        ),
      );
    }

    return FutureBuilder<void>(
      future: _initializeControllerFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.done) {
          if (_cameraController != null &&
              _cameraController!.value.isInitialized) {
            // Fill whatever circular slot the parent gives us instead of a
            // hard-coded 100x100 box (which overflowed on smaller phones).
            final Size previewSize =
                _cameraController!.value.previewSize ?? const Size(720, 1280);
            return ClipOval(
              child: FittedBox(
                fit: BoxFit.cover,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: previewSize.height,
                  height: previewSize.width,
                  child: CameraPreview(_cameraController!),
                ),
              ),
            );
          } else {
            return const Center(child: Text('Camera not initialized.'));
          }
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          return const Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            ),
          );
        }
      },
    );
  }
}
