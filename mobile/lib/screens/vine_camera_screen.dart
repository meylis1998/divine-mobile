// ABOUTME: Main camera screen with orientation fix and full recording features
// ABOUTME: Uses exact camera preview structure from experimental app to ensure proper orientation

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';

class VineCameraScreen extends StatefulWidget {
  const VineCameraScreen({super.key});

  @override
  State<VineCameraScreen> createState() => _VineCameraScreenState();
}

class _VineCameraScreenState extends State<VineCameraScreen> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _errorMessage;
  FlashMode _flashMode = FlashMode.off;
  List<CameraDescription> _availableCameras = [];
  int _currentCameraIndex = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _availableCameras = await availableCameras();
      if (_availableCameras.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras found';
        });
        return;
      }

      // Use the first camera (usually back camera)
      _currentCameraIndex = 0;
      final camera = _availableCameras[_currentCameraIndex];

      // Initialize camera controller
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();

      // Lock camera orientation to portrait
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);

      // Set initial flash mode
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
    }
  }

  // Mobile recording: press-hold pattern
  Future<void> _startRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (_isRecording) return;

    try {
      await _controller!.startVideoRecording();
      setState(() {
        _isRecording = true;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording error: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      return;
    }
    if (!_isRecording) return;

    try {
      await _controller!.stopVideoRecording();
      setState(() {
        _isRecording = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Recording error: $e';
      });
    }
  }

  // Web recording: toggle pattern
  Future<void> _toggleRecordingWeb() async {
    if (_isRecording) {
      await _stopRecording();
    } else {
      await _startRecording();
    }
  }

  bool get _canRecord => _controller != null && _controller!.value.isInitialized && !_isRecording;

  // Toggle flash mode: off → torch → off
  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      final newMode = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
      await _controller!.setFlashMode(newMode);
      setState(() {
        _flashMode = newMode;
      });
    } catch (e) {
      // Flash might not be available on this camera
    }
  }

  // Switch between front and back cameras
  Future<void> _switchCamera() async {
    if (_availableCameras.length <= 1) return;
    if (_controller == null || !_controller!.value.isInitialized) return;

    try {
      // Dispose old controller first
      await _controller!.dispose();

      // Switch to next camera
      _currentCameraIndex = (_currentCameraIndex + 1) % _availableCameras.length;
      final camera = _availableCameras[_currentCameraIndex];

      // Initialize new camera
      _controller = CameraController(
        camera,
        ResolutionPreset.high,
        enableAudio: true,
      );

      await _controller!.initialize();
      await _controller!.lockCaptureOrientation(DeviceOrientation.portraitUp);
      await _controller!.setFlashMode(_flashMode);

      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to switch camera: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.white, fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    if (!_isInitialized || _controller == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        // Mobile: press-hold to record (tap down = start, tap up = stop)
        onTapDown: !kIsWeb && _canRecord ? (_) => _startRecording() : null,
        onTapUp: !kIsWeb && _isRecording ? (_) => _stopRecording() : null,
        onTapCancel: !kIsWeb && _isRecording ? () => _stopRecording() : null,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          fit: StackFit.expand,
          children: [
          // Camera preview - full screen without black bars
          // EXACT structure from experimental app
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.previewSize!.height,
                height: _controller!.value.previewSize!.width,
                child: CameraPreview(_controller!),
              ),
            ),
          ),

          // Back button
          Positioned(
            top: 60,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white, size: 32),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Camera controls (Flash, Switch Camera) at top-right
          Positioned(
            top: 60,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Flash button
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: _toggleFlash,
                  ),
                ),
                const SizedBox(height: 16),
                // Switch camera button
                if (_availableCameras.length > 1)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(
                        Icons.flip_camera_ios,
                        color: Colors.white,
                        size: 28,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ),
              ],
            ),
          ),

          // Recording button at the bottom (visible on web, hidden on mobile)
          if (kIsWeb)
            Positioned(
              bottom: 40,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _toggleRecordingWeb,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isRecording ? Colors.red : Colors.white,
                      border: Border.all(
                        color: Colors.white,
                        width: 4,
                      ),
                    ),
                    child: _isRecording
                        ? const Center(
                            child: Icon(
                              Icons.stop,
                              color: Colors.white,
                              size: 40,
                            ),
                          )
                        : null,
                  ),
                ),
              ),
            ),

          // Recording indicator
          if (_isRecording)
            Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.fiber_manual_record,
                        color: Colors.white,
                        size: 16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'RECORDING',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Bottom control bar with gradient
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 120,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withOpacity(0.8),
                  ],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Cancel button (X)
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 32),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    // Center space for recording button (mobile) or info
                    const SizedBox(width: 80),
                    // Placeholder for future Publish button
                    const SizedBox(width: 48),
                  ],
                ),
              ),
            ),
          ),
          ],
        ), // End of Stack
      ), // End of GestureDetector
    );
  }
}
