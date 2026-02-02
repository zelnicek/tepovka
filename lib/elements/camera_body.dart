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

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameraDescription,
      ResolutionPreset.high,
    );

    try {
      _initializeControllerFuture = _cameraController!.initialize();
      await _initializeControllerFuture;

      if (mounted) {
        setState(() {});
        widget.onCameraReady(_cameraController!);

        // Start image stream only if the controller is initialized
        if (_cameraController!.value.isInitialized) {
          _cameraController!.startImageStream((image) {
            widget.onImageAvailable(image);
          });
        }
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
    }
  }

  @override
  void dispose() {
    if (_cameraController != null) {
      _cameraController!.stopImageStream(); // Stop the image stream safely
      _cameraController!.dispose(); // Dispose of the controller
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
            return SizedBox(
              width: 100,
              height: 100,
              child: ClipOval(
                child: CameraPreview(_cameraController!),
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
