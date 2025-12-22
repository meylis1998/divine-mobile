// ABOUTME: Pure universal camera screen using revolutionary Riverpod architecture
// ABOUTME: Cross-platform recording without VideoManager dependencies using pure providers

import 'dart:convert';
import 'dart:io';

import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as vine show AspectRatio;
import 'package:models/models.dart' show NativeProofData;
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/services/camera/camerawesome_mobile_camera_interface.dart';
import 'package:openvine/services/camera/enhanced_mobile_camera_interface.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/widgets/camera_permission_dialog.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/dynamic_zoom_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure universal camera screen using revolutionary single-controller Riverpod architecture
class UniversalCameraScreenPure extends ConsumerStatefulWidget {
  const UniversalCameraScreenPure({super.key});

  @override
  ConsumerState<UniversalCameraScreenPure> createState() =>
      _UniversalCameraScreenPureState();
}

class _UniversalCameraScreenPureState
    extends ConsumerState<UniversalCameraScreenPure>
    with WidgetsBindingObserver {
  String? _errorMessage;
  bool _isProcessing = false;

  // Camera control states
  FlashMode _flashMode = FlashMode.off;
  TimerDuration _timerDuration = TimerDuration.off;
  int? _countdownValue;
  bool _wasInBackground = false;

  // Track current device orientation for debugging
  DeviceOrientation? _currentOrientation;

  @override
  void initState() {
    super.initState();

    // Add app lifecycle observer to detect when user returns from Settings
    WidgetsBinding.instance.addObserver(this);

    // Log initial orientation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orientation = MediaQuery.of(context).orientation;
      _currentOrientation = orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft;
      Log.info(
        '📱 [ORIENTATION] Camera screen initial orientation: $_currentOrientation, MediaQuery: $orientation',
        category: LogCategory.video,
      );

      // Handle initial permission state after first frame
      _handleInitialPermissionState();
    });

    // CRITICAL: Dispose all video controllers when entering camera screen
    // IndexedStack keeps widgets alive, so we must force-dispose controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Force dispose all video controllers (this also clears active video)
        disposeAllVideoControllers(ref);
        Log.info(
          '🗑️ UniversalCameraScreenPure: Disposed all video controllers',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          '📹 Failed to dispose video controllers: $e',
          category: LogCategory.video,
        );
      }
    });

    Log.info(
      '📹 UniversalCameraScreenPure: Initialized',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Provider handles disposal automatically
    super.dispose();

    Log.info(
      '📹 UniversalCameraScreenPure: Disposed',
      category: LogCategory.video,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed && _wasInBackground) {
      _handleInitialPermissionState();
      _wasInBackground = false;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App going to background - clean up camera
      _disposeCameraSafely();
      _wasInBackground = true;
    }
  }

  /// Safely dispose camera without throwing exceptions
  void _disposeCameraSafely() {
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      // Stop any active recording first
      if (ref.read(vineRecordingProvider).isRecording) {
        notifier.stopSegment();
      }
      // Clean up and reset state
      notifier.cleanupAndReset();
    } catch (e) {
      Log.warning(
        '📹 Failed to cleanup camera: $e',
        category: LogCategory.video,
      );
    }
  }

  /// Handle initial permission state when screen opens
  void _handleInitialPermissionState() {
    final cameraBloc = context.read<CameraPermissionBloc>();
    final state = cameraBloc.state;

    if (state is CameraPermissionLoaded) {
      _handlePermissionStatus(state.status);
    } else if (state is CameraPermissionDenied) {
      cameraBloc.add(const CameraPermissionRefresh());
    }
  }

  /// Handle permission status changes - called from BlocListener and initial check
  Future<void> _handlePermissionStatus(CameraPermissionStatus status) async {
    switch (status) {
      case CameraPermissionStatus.authorized:
        // Permission granted - initialize camera
        _initializeCamera();
        break;

      case CameraPermissionStatus.canRequest:
        // Show pre-permission sheet and request permissions
        if (!mounted) return;
        final shouldRequest = await CameraMicrophonePrePermissionSheet.show(
          context,
        );

        if (!mounted) return;
        if (shouldRequest) {
          context.read<CameraPermissionBloc>().add(
            const CameraPermissionRequest(),
          );
        } else {
          // User tapped "Not now" - go back to home
          GoRouter.of(context).pop();
        }
        break;

      case CameraPermissionStatus.requiresSettings:
        // Show settings required sheet
        if (!mounted) return;
        final openedSettings =
            await CameraMicrophonePermissionRequiredSheet.show(
              context,
              onOpenSettings: () {
                context.read<CameraPermissionBloc>().add(
                  const CameraPermissionOpenSettings(),
                );
              },
            );

        // If user didn't open settings, go back to home
        if (!mounted) return;
        if (openedSettings != true) {
          GoRouter.of(context).pop();
        }
        break;
    }
  }

  /// Initialize the camera recording service
  Future<void> _initializeCamera() async {
    try {
      // Clean up any old temp files and reset state from previous recordings
      ref.read(vineRecordingProvider.notifier).cleanupAndReset();

      final recordingState = ref.read(vineRecordingProvider);
      if (!recordingState.isInitialized) {
        Log.info(
          '📹 Initializing recording service',
          category: LogCategory.video,
        );
        await ref.read(vineRecordingProvider.notifier).initialize();
        Log.info(
          '📹 Recording service initialized successfully',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.error(
        '📹 Camera initialization failed: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize camera: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Track orientation changes
    final mediaQueryOrientation = MediaQuery.of(context).orientation;
    final newOrientation = mediaQueryOrientation == Orientation.portrait
        ? DeviceOrientation.portraitUp
        : DeviceOrientation.landscapeLeft;

    if (_currentOrientation != newOrientation) {
      _currentOrientation = newOrientation;
      Log.warning(
        '📱 [ORIENTATION] Device orientation changed! MediaQuery: $mediaQueryOrientation, DeviceOrientation: $newOrientation',
        category: LogCategory.video,
      );
      Log.warning(
        '📱 [ORIENTATION] MediaQuery size: ${MediaQuery.of(context).size}',
        category: LogCategory.video,
      );
    }

    if (_errorMessage != null) {
      return _CameraErrorScreen(
        message: _errorMessage ?? 'Unknown error occurred',
        onRetry: _retryInitialization,
        onBack: () => Navigator.of(context).pop(),
      );
    }

    return BlocListener<CameraPermissionBloc, CameraPermissionState>(
      listenWhen: (previous, current) {
        // Only listen when state becomes loaded (e.g., after refresh from background)
        return current is CameraPermissionLoaded ||
            current is CameraPermissionDenied;
      },
      listener: (context, state) {
        if (state is CameraPermissionLoaded) {
          _handlePermissionStatus(state.status);
        } else if (state is CameraPermissionDenied) {
          GoRouter.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Consumer(
          builder: (context, ref, child) {
            final recordingState = ref.watch(vineRecordingProvider);

            // Listen for auto-stop (when recording stops without user action)
            ref.listen<VineRecordingUIState>(vineRecordingProvider, (
              previous,
              next,
            ) {
              if (previous != null &&
                  previous.isRecording &&
                  !next.isRecording &&
                  !_isProcessing) {
                // Recording stopped - check if it was max duration, manual stop, or error
                if (next.hasSegments) {
                  // Check if this was an auto-stop due to max duration (remaining time ~0ms)
                  // vs. manual segment stop (remaining time > 50ms)
                  // With 6.3s max duration, timer should stop at exactly 0ms remaining
                  if (next.remainingDuration.inMilliseconds < 50) {
                    // Has segments + virtually no remaining time = legitimate max duration auto-stop
                    Log.info(
                      '📹 Recording auto-stopped at max duration',
                      category: LogCategory.video,
                    );
                    _handleRecordingAutoStop();
                  } else {
                    // Has segments + time remaining = manual segment stop (user released button)
                    Log.debug(
                      '📹 Manual segment stop (${next.remainingDuration.inMilliseconds}ms remaining)',
                      category: LogCategory.video,
                    );
                    // Don't show "max time reached" message for manual stops
                  }
                }
              }
            });

            if (recordingState.isError) {
              return _CameraErrorScreen(
                message:
                    recordingState.errorMessage ?? 'Unknown error occurred',
                onRetry: _retryInitialization,
                onBack: () => Navigator.of(context).pop(),
              );
            }

            // Show processing overlay if processing (even if camera not initialized)
            if (_isProcessing) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: VineTheme.vineGreen),
                    SizedBox(height: 16),
                    Text(
                      'Processing video...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              );
            }

            // Show UI skeleton even when not initialized (for permission dialog background)
            return Stack(
              fit: StackFit.expand,
              children: [
                // Camera preview or placeholder
                if (recordingState.isInitialized)
                  ref.read(vineRecordingProvider.notifier).previewWidget
                else
                  const _CameraPlaceholder(),

                // Tap-anywhere-to-record gesture detector (MUST be before top bar so bar receives taps)
                Positioned.fill(
                  child: GestureDetector(
                    onTapDown: !kIsWeb && recordingState.canRecord
                        ? (_) => _startRecording()
                        : null,
                    onTapUp: !kIsWeb && recordingState.isRecording
                        ? (_) => _stopRecording()
                        : null,
                    onTapCancel: !kIsWeb && recordingState.isRecording
                        ? () => _stopRecording()
                        : null,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),

                // Top progress bar - Vine-style full width at top (AFTER gesture detector so buttons work)
                Positioned(
                  top: MediaQuery.of(context).padding.top,
                  left: 0,
                  right: 0,
                  child: _TopProgressBar(
                    progress: recordingState.progress,
                    hasSegments: recordingState.hasSegments,
                    onClose: () {
                      Log.info(
                        '📹 X CANCEL - popping back',
                        category: LogCategory.video,
                      );
                      GoRouter.of(context).pop();
                    },
                    onPublish: () {
                      Log.info(
                        '📹 > PUBLISH BUTTON PRESSED',
                        category: LogCategory.video,
                      );
                      _finishRecording();
                    },
                  ),
                ),

                // Square crop mask overlay (only shown in square mode)
                // Positioned OUTSIDE ClipRect so it's not clipped away
                if (recordingState.aspectRatio == vine.AspectRatio.square &&
                    recordingState.isInitialized)
                  LayoutBuilder(
                    builder: (context, constraints) {
                      Log.info(
                        '🎭 Building square crop mask overlay',
                        name: 'UniversalCameraScreenPure',
                        category: LogCategory.video,
                      );

                      // Use screen dimensions, not camera preview dimensions
                      final screenWidth = constraints.maxWidth;
                      final screenHeight = constraints.maxHeight;

                      Log.info(
                        '🎭 Mask dimensions: screenWidth=$screenWidth, screenHeight=$screenHeight, squareSize=$screenWidth',
                        name: 'UniversalCameraScreenPure',
                        category: LogCategory.video,
                      );

                      return _SquareCropMask(
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                      );
                    },
                  ),

                // Dynamic zoom selector (above recording controls)
                if (recordingState.isInitialized && !recordingState.isRecording)
                  const Positioned(
                    bottom: 180,
                    left: 0,
                    right: 0,
                    child: _ZoomSelectorWrapper(),
                  ),

                // Recording controls overlay (bottom)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                        ],
                      ),
                    ),
                    child: _RecordingControls(
                      isRecording: recordingState.isRecording,
                      hasSegments: recordingState.hasSegments,
                      canRecord: recordingState.canRecord,
                      recordingDuration: recordingState.recordingDuration,
                      segments: recordingState.segments,
                      onToggleRecordingWeb: _toggleRecordingWeb,
                      onStartRecording: _startRecording,
                      onStopRecording: _stopRecording,
                    ),
                  ),
                ),

                // Camera controls (right side, vertically centered)
                if (recordingState.isInitialized && !recordingState.isRecording)
                  Positioned(
                    top: 0,
                    bottom: 180, // Above the bottom recording controls
                    right: 16,
                    child: Center(
                      child: Builder(
                        builder: (context) {
                          final cameraInterface = ref
                              .read(vineRecordingProvider.notifier)
                              .cameraInterface;
                          final isFrontCamera =
                              (cameraInterface
                                      is EnhancedMobileCameraInterface &&
                                  cameraInterface.isFrontCamera) ||
                              (cameraInterface
                                      is CamerAwesomeMobileCameraInterface &&
                                  cameraInterface.isFrontCamera);

                          return _CameraControls(
                            canSwitchCamera: recordingState.canSwitchCamera,
                            isFrontCamera: isFrontCamera,
                            flashMode: _flashMode,
                            timerDuration: _timerDuration,
                            onSwitchCamera: _switchCamera,
                            onToggleFlash: _toggleFlash,
                            onToggleTimer: _toggleTimer,
                            aspectRatioToggle: _AspectRatioToggle(
                              recordingState: recordingState,
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                // Countdown overlay
                if (_countdownValue != null)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Text(
                          _countdownValue.toString(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 72,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                // Processing overlay
                if (_isProcessing)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.7),
                      child: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              color: VineTheme.vineGreen,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Processing video...',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Web-specific: Toggle recording on/off with tap
  Future<void> _toggleRecordingWeb() async {
    final state = ref.read(vineRecordingProvider);

    if (state.isRecording) {
      // Stop recording
      _finishRecording();
    } else if (state.canRecord) {
      // Start recording
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Handle timer countdown if enabled
      if (_timerDuration != TimerDuration.off) {
        await _startCountdownTimer();
      }

      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info('📹 Starting recording segment', category: LogCategory.video);
      await notifier.startRecording();
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Start recording failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Recording failed: $e');
    }
  }

  Future<void> _startCountdownTimer() async {
    final duration = _timerDuration == TimerDuration.threeSeconds ? 3 : 10;

    for (int i = duration; i > 0; i--) {
      if (!mounted) return;

      setState(() {
        _countdownValue = i;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() {
        _countdownValue = null;
      });
    }
  }

  Future<void> _stopRecording() async {
    // Just stop the current segment - don't finish the recording
    // This allows the user to record multiple segments before finalizing
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info(
        '📹 Stopping recording segment (not finishing)',
        category: LogCategory.video,
      );
      await notifier.stopSegment();

      Log.info(
        '📹 Segment stopped, user can record more or tap Publish to finish',
        category: LogCategory.video,
      );

      // Reset processing state - we're NOT processing yet, just paused between segments
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Stop segment failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Stop recording failed: $e');
    }
  }

  Future<void> _finishRecording() async {
    // Set processing state immediately so UI shows "Processing video..."
    // during the entire FFmpeg processing time
    if (_isProcessing) {
      Log.warning(
        '📹 Already processing a recording, ignoring duplicate finish call',
        category: LogCategory.video,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info(
        '📹 Finishing recording and concatenating segments',
        category: LogCategory.video,
      );

      final (videoFile, proofManifest) = await notifier.finishRecording();
      Log.info(
        '📹 Recording finished, video: ${videoFile?.path}, proof: ${proofManifest != null}',
        category: LogCategory.video,
      );

      if (videoFile != null && mounted) {
        _processRecording(videoFile, proofManifest);
      } else {
        Log.warning(
          '📹 No file returned from finishRecording',
          category: LogCategory.video,
        );
        // Reset processing state since nothing to process
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Finish recording failed: $e',
        category: LogCategory.video,
      );

      // Reset processing state on error
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      _showErrorSnackBar('Finish recording failed: $e');
    }
  }

  Future<void> _switchCamera() async {
    Log.info(
      '🔄 _switchCamera() UI button pressed',
      name: 'UniversalCameraScreenPure',
      category: LogCategory.system,
    );

    try {
      Log.info(
        '🔄 Calling vineRecordingProvider.notifier.switchCamera()...',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
      await ref.read(vineRecordingProvider.notifier).switchCamera();
      Log.info(
        '🔄 vineRecordingProvider.notifier.switchCamera() completed',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );

      // Force rebuild by calling setState
      Log.info(
        '🔄 Calling setState() to force UI rebuild',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
      setState(() {});
      Log.info(
        '🔄 setState() completed',
        name: 'UniversalCameraScreenPure',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Camera switch failed: $e',
        category: LogCategory.video,
      );
    }
  }

  void _toggleFlash() {
    Log.info('🔦 Flash button tapped', category: LogCategory.video);

    final cameraInterface = ref
        .read(vineRecordingProvider.notifier)
        .cameraInterface;

    // Update local state to cycle through: off → torch (for video recording)
    // For video, we use torch mode (continuous light) instead of flash
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
        case FlashMode.auto:
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
      }
    });

    Log.info(
      '🔦 Flash mode toggled to: $_flashMode',
      category: LogCategory.video,
    );

    // Apply the new flash mode to camera - support both camera interfaces
    if (cameraInterface is EnhancedMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else {
      Log.warning(
        '🔦 Camera interface does not support flash control',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _handleRecordingAutoStop() async {
    try {
      // Auto-stop just pauses the current segment
      // User must press publish button to finish and concatenate
      Log.info(
        '📹 Recording auto-stopped (max duration reached)',
        category: LogCategory.video,
      );

      _showSuccessSnackBar(
        'Maximum recording time reached. Press ✓ to publish.',
      );
    } catch (e) {
      Log.error(
        '📹 Failed to handle auto-stop: $e',
        category: LogCategory.video,
      );
    }
  }

  void _toggleTimer() {
    setState(() {
      switch (_timerDuration) {
        case TimerDuration.off:
          _timerDuration = TimerDuration.threeSeconds;
          break;
        case TimerDuration.threeSeconds:
          _timerDuration = TimerDuration.tenSeconds;
          break;
        case TimerDuration.tenSeconds:
          _timerDuration = TimerDuration.off;
          break;
      }
    });
    Log.info(
      '📹 Timer duration changed to: $_timerDuration',
      category: LogCategory.video,
    );
  }

  Future<void> _processRecording(
    File recordedFile,
    NativeProofData? nativeProof,
  ) async {
    // Note: _isProcessing is set by _finishRecording() before this is called
    // to ensure the "Processing video..." UI shows during FFmpeg processing

    try {
      Log.info(
        '📹 UniversalCameraScreenPure: Processing recorded file: ${recordedFile.path}',
        category: LogCategory.video,
      );

      // Create a draft for the recorded video
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Serialize NativeProofData to JSON if available
      String? proofManifestJson;
      if (nativeProof != null) {
        try {
          proofManifestJson = jsonEncode(nativeProof.toJson());
          Log.info(
            '📜 Native ProofMode data attached to draft from universal camera',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            'Failed to serialize NativeProofData for draft: $e',
            category: LogCategory.video,
          );
        }
      }

      // Get current aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);

      final draft = VineDraft.create(
        videoFile: recordedFile,
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        proofManifestJson: proofManifestJson,
        aspectRatio: recordingState.aspectRatio,
      );

      await draftService.saveDraft(draft);

      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );

        // After metadata screen returns, navigate to profile
        if (mounted) {
          disposeAllVideoControllers(ref);

          Log.info(
            '📹 Returned from metadata screen, navigating to profile',
            category: LogCategory.video,
          );

          // CRITICAL: Dispose all controllers again before navigation
          // This ensures no stale controllers exist when switching to profile tab
          Log.info(
            '🗑️ Disposed controllers before profile navigation',
            category: LogCategory.video,
          );

          // Navigate to user's own profile using GoRouter
          context.go('/profile/me/0');
          Log.info(
            '📹 Successfully navigated to profile',
            category: LogCategory.video,
          );

          // Reset processing flag after navigation
        }
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Processing failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        _showErrorSnackBar('Processing failed: $e');
      }
    }
  }

  Future<void> _retryInitialization() async {
    setState(() {
      _errorMessage = null;
    });

    // Re-check permissions and initialize
    _handleInitialPermissionState();
  }

  /// Show error snackbar at top of screen to avoid blocking controls
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar at top of screen
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VineTheme.vineGreen,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Timer duration options for delayed recording
enum TimerDuration { off, threeSeconds, tenSeconds }

/// Error screen widget displayed when camera initialization fails
class _CameraErrorScreen extends StatelessWidget {
  const _CameraErrorScreen({
    required this.message,
    required this.onRetry,
    required this.onBack,
  });

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: onBack,
        ),
        title: const Text(
          'Camera Error',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vine-style top bar with X (close), progress bar, and > (publish) buttons
class _TopProgressBar extends StatelessWidget {
  const _TopProgressBar({
    required this.progress,
    required this.hasSegments,
    required this.onClose,
    this.onPublish,
  });

  final double progress;
  final bool hasSegments;
  final VoidCallback onClose;
  final VoidCallback? onPublish;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      color: VineTheme.vineGreen,
      child: Row(
        children: [
          // X button (close/cancel) on the left
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(Icons.close, color: Colors.white, size: 28),
            ),
          ),
          // Progress bar in the middle
          Expanded(
            child: Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // > button (publish/proceed) on the right
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasSegments ? onPublish : null,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right,
                color: hasSegments
                    ? Colors.white
                    : Colors.white.withValues(alpha: 0.3),
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Recording controls widget with record button and status hints
class _RecordingControls extends StatelessWidget {
  const _RecordingControls({
    required this.isRecording,
    required this.hasSegments,
    required this.canRecord,
    required this.recordingDuration,
    required this.segments,
    this.onToggleRecordingWeb,
    this.onStartRecording,
    this.onStopRecording,
  });

  final bool isRecording;
  final bool hasSegments;
  final bool canRecord;
  final Duration recordingDuration;
  final List<dynamic> segments;
  final VoidCallback? onToggleRecordingWeb;
  final VoidCallback? onStartRecording;
  final VoidCallback? onStopRecording;

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Platform-specific instruction hint
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            (!isRecording && !hasSegments)
                ? (kIsWeb ? 'Tap to record' : 'Tap and hold anywhere to record')
                : '',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),

        // Show segment count on mobile
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              hasSegments
                  ? '${segments.length} ${segments.length == 1 ? "segment" : "segments"}'
                  : '',
              style: TextStyle(
                color: VineTheme.vineGreen.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        GestureDetector(
          onTap: kIsWeb ? onToggleRecordingWeb : null,
          onTapDown: !kIsWeb && canRecord
              ? (_) => onStartRecording?.call()
              : null,
          onTapUp: !kIsWeb && isRecording
              ? (_) => onStopRecording?.call()
              : null,
          onTapCancel: !kIsWeb && isRecording ? onStopRecording : null,
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isRecording ? Colors.red : Colors.white,
              border: Border.all(
                color: isRecording ? Colors.white : Colors.grey,
                width: 4,
              ),
            ),
            child: isRecording
                ? Center(
                    child: Text(
                      _formatDuration(recordingDuration),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.fiber_manual_record,
                    color: Colors.red,
                    size: 32,
                  ),
          ),
        ),
      ],
    );
  }
}

/// Camera controls widget (flip camera, flash, timer, aspect ratio)
class _CameraControls extends StatelessWidget {
  const _CameraControls({
    required this.canSwitchCamera,
    required this.isFrontCamera,
    required this.flashMode,
    required this.timerDuration,
    required this.onSwitchCamera,
    required this.onToggleFlash,
    required this.onToggleTimer,
    required this.aspectRatioToggle,
  });

  final bool canSwitchCamera;
  final bool isFrontCamera;
  final FlashMode flashMode;
  final TimerDuration timerDuration;
  final VoidCallback onSwitchCamera;
  final VoidCallback onToggleFlash;
  final VoidCallback onToggleTimer;
  final Widget aspectRatioToggle;

  IconData _getFlashIcon() {
    switch (flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.flashlight_on;
      case FlashMode.auto:
      case FlashMode.always:
        return Icons.flash_on;
    }
  }

  IconData _getTimerIcon() {
    switch (timerDuration) {
      case TimerDuration.off:
        return Icons.timer;
      case TimerDuration.threeSeconds:
        return Icons.timer_3;
      case TimerDuration.tenSeconds:
        return Icons.timer_10;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera switch button (front/back)
        if (canSwitchCamera) ...[
          CircularIconButton(
            onPressed: onSwitchCamera,
            icon: const Icon(
              Icons.flip_camera_ios,
              color: Colors.white,
              size: 26,
            ),
            backgroundOpacity: 0.5,
          ),
          const SizedBox(height: 12),
        ],
        // Flash toggle (only show for rear camera)
        if (!isFrontCamera) ...[
          CircularIconButton(
            onPressed: onToggleFlash,
            icon: Icon(_getFlashIcon(), color: Colors.white, size: 26),
            backgroundOpacity: 0.5,
          ),
          const SizedBox(height: 12),
        ],
        // Timer toggle
        CircularIconButton(
          onPressed: onToggleTimer,
          icon: Icon(_getTimerIcon(), color: Colors.white, size: 26),
          backgroundOpacity: 0.5,
        ),
        const SizedBox(height: 12),
        // Aspect ratio toggle
        aspectRatioToggle,
      ],
    );
  }
}

/// Aspect ratio toggle button widget
class _AspectRatioToggle extends ConsumerWidget {
  const _AspectRatioToggle({required this.recordingState});

  final VineRecordingUIState recordingState;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          recordingState.aspectRatio == vine.AspectRatio.square
              ? Icons.crop_square
              : Icons.crop_portrait,
          color: Colors.white,
          size: 28,
        ),
        onPressed: recordingState.isRecording
            ? null
            : () {
                final currentRatio = recordingState.aspectRatio;
                final newRatio =
                    recordingState.aspectRatio == vine.AspectRatio.square
                    ? vine.AspectRatio.vertical
                    : vine.AspectRatio.square;
                Log.info(
                  '🎭 Aspect ratio button pressed: $currentRatio -> $newRatio',
                  name: 'UniversalCameraScreenPure',
                  category: LogCategory.video,
                );
                ref
                    .read(vineRecordingProvider.notifier)
                    .setAspectRatio(newRatio);
              },
      ),
    );
  }
}

/// Zoom selector wrapper widget
class _ZoomSelectorWrapper extends ConsumerWidget {
  const _ZoomSelectorWrapper();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraInterface = ref
        .read(vineRecordingProvider.notifier)
        .getCameraInterface();

    // Only show zoom selector for CamerAwesome interface (iOS)
    if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      return DynamicZoomSelector(cameraInterface: cameraInterface);
    }

    // No zoom selector for other camera interfaces
    return const SizedBox.shrink();
  }
}

/// Camera placeholder widget shown while camera is initializing
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: VineTheme.vineGreen),
            const SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Square crop mask overlay widget
class _SquareCropMask extends StatelessWidget {
  const _SquareCropMask({
    required this.screenWidth,
    required this.screenHeight,
  });

  final double screenWidth;
  final double screenHeight;

  @override
  Widget build(BuildContext context) {
    // Square uses full screen width
    final squareSize = screenWidth;

    // Calculate top/bottom areas to darken (centered vertically on screen)
    final topBottomHeight = (screenHeight - squareSize) / 2;

    return Stack(
      children: [
        // Top darkened area
        if (topBottomHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // Bottom darkened area
        if (topBottomHeight > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(color: Colors.black.withValues(alpha: 0.6)),
          ),

        // Square frame outline (visual guide)
        Positioned(
          top: topBottomHeight > 0 ? topBottomHeight : 0,
          left: 0,
          width: squareSize,
          height: squareSize,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(color: VineTheme.vineGreen, width: 3),
            ),
          ),
        ),
      ],
    );
  }
}
