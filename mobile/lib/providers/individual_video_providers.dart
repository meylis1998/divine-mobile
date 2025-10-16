// ABOUTME: Individual video controller providers using proper Riverpod Family pattern
// ABOUTME: Each video gets its own controller with automatic lifecycle management via autoDispose

import 'dart:async';
import 'package:flutter_riverpod/legacy.dart';
import 'package:video_player/video_player.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/providers/app_providers.dart';

part 'individual_video_providers.g.dart';

/// Parameters for video controller creation
class VideoControllerParams {
  const VideoControllerParams({
    required this.videoId,
    required this.videoUrl,
    this.videoEvent,
  });

  final String videoId;
  final String videoUrl;
  final dynamic videoEvent; // VideoEvent for enhanced error reporting

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoControllerParams &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          videoUrl == other.videoUrl &&
          videoEvent == other.videoEvent;

  @override
  int get hashCode => videoId.hashCode ^ videoUrl.hashCode ^ videoEvent.hashCode;

  @override
  String toString() => 'VideoControllerParams(videoId: $videoId, videoUrl: $videoUrl, hasEvent: ${videoEvent != null})';
}

/// Loading state for individual videos
class VideoLoadingState {
  const VideoLoadingState({
    required this.videoId,
    required this.isLoading,
    required this.isInitialized,
    required this.hasError,
    this.errorMessage,
  });

  final String videoId;
  final bool isLoading;
  final bool isInitialized;
  final bool hasError;
  final String? errorMessage;

  VideoLoadingState copyWith({
    String? videoId,
    bool? isLoading,
    bool? isInitialized,
    bool? hasError,
    String? errorMessage,
  }) {
    return VideoLoadingState(
      videoId: videoId ?? this.videoId,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      hasError: hasError ?? this.hasError,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is VideoLoadingState &&
          runtimeType == other.runtimeType &&
          videoId == other.videoId &&
          isLoading == other.isLoading &&
          isInitialized == other.isInitialized &&
          hasError == other.hasError &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(videoId, isLoading, isInitialized, hasError, errorMessage);

  @override
  String toString() => 'VideoLoadingState(videoId: $videoId, isLoading: $isLoading, isInitialized: $isInitialized, hasError: $hasError, errorMessage: $errorMessage)';
}

/// Provider for individual video controllers with autoDispose
/// Each video gets its own controller instance
@riverpod
VideoPlayerController individualVideoController(
  Ref ref,
  VideoControllerParams params,
) {
  // Riverpod-native lifecycle: keep controller alive with 30s cache timeout
  final link = ref.keepAlive();
  Timer? cacheTimer;

  // Riverpod lifecycle hooks for idiomatic cache behavior
  ref.onCancel(() {
    // Last listener removed - start 30s cache timeout
    cacheTimer = Timer(const Duration(seconds: 30), () {
      link.close(); // Allow autoDispose after 30s of no listeners
    });
  });

  ref.onResume(() {
    // New listener added - cancel the disposal timer
    cacheTimer?.cancel();
  });

  Log.info('🎬 Creating VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
      name: 'IndividualVideoController', category: LogCategory.system);

  // Create controller - networkUrl automatically uses HTTP cache for fast reloads
  final controller = VideoPlayerController.networkUrl(
    Uri.parse(params.videoUrl),
  );

  // Cache video in background for future use (non-blocking)
  // Use unawaited to explicitly mark as fire-and-forget
  final videoCache = openVineVideoCache;
  unawaited(
    ref.read(brokenVideoTrackerProvider.future).then((tracker) {
      videoCache.cacheVideo(params.videoUrl, params.videoId, brokenVideoTracker: tracker).catchError((error) {
        Log.warning('⚠️ Background video caching failed: $error',
            name: 'IndividualVideoController', category: LogCategory.video);
        return null; // Return null on error
      });
    }).catchError((trackerError) {
      // Fallback without broken video tracker if it fails to load
      videoCache.cacheVideo(params.videoUrl, params.videoId).catchError((error) {
        Log.warning('⚠️ Background video caching failed: $error',
            name: 'IndividualVideoController', category: LogCategory.video);
        return null; // Return null on error
      });
    }),
  );

  // Initialize the controller
  final initFuture = controller.initialize().timeout(
    const Duration(seconds: 15),
    onTimeout: () => throw TimeoutException('Video initialization timed out'),
  );

  initFuture.then((_) {
    Log.info('✅ VideoPlayerController initialized for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.system);

    // Set looping for Vine-like behavior
    controller.setLooping(true);

    // Controller is initialized and paused - widget will control playback
    Log.debug('⏸️ Video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}... initialized and paused (widget controls playback)',
        name: 'IndividualVideoController', category: LogCategory.system);
  }).catchError((error) {
    final videoIdDisplay = params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId;

    // Enhanced error logging with full Nostr event details
    final errorMessage = error.toString();
    var logMessage = '❌ VideoPlayerController initialization failed for video $videoIdDisplay...: $errorMessage';

    if (params.videoEvent != null) {
      final event = params.videoEvent as dynamic;
      logMessage += '\n📋 Full Nostr Event Details:';
      logMessage += '\n   • Event ID: ${event.id}';
      logMessage += '\n   • Pubkey: ${event.pubkey}';
      logMessage += '\n   • Content: ${event.content}';
      logMessage += '\n   • Video URL: ${event.videoUrl}';
      logMessage += '\n   • Title: ${event.title ?? 'null'}';
      logMessage += '\n   • Duration: ${event.duration ?? 'null'}';
      logMessage += '\n   • Dimensions: ${event.dimensions ?? 'null'}';
      logMessage += '\n   • MIME Type: ${event.mimeType ?? 'null'}';
      logMessage += '\n   • File Size: ${event.fileSize ?? 'null'}';
      logMessage += '\n   • SHA256: ${event.sha256 ?? 'null'}';
      logMessage += '\n   • Thumbnail URL: ${event.thumbnailUrl ?? 'null'}';
      logMessage += '\n   • Hashtags: ${event.hashtags ?? []}';
      logMessage += '\n   • Created At: ${DateTime.fromMillisecondsSinceEpoch(event.createdAt * 1000)}';
      if (event.rawTags != null && event.rawTags.isNotEmpty) {
        logMessage += '\n   • Raw Tags: ${event.rawTags}';
      }
    } else {
      logMessage += '\n⚠️  No Nostr event details available (consider passing videoEvent to VideoControllerParams)';
    }

    Log.error(logMessage, name: 'IndividualVideoController', category: LogCategory.system);

    // Check for corrupted cache file (OSStatus error -12848 or "media may be damaged")
    if (_isCacheCorruption(errorMessage)) {
      Log.warning('🗑️ Detected corrupted cache for video $videoIdDisplay... - removing and will retry',
          name: 'IndividualVideoController', category: LogCategory.video);

      // Remove corrupted cache file and invalidate provider to trigger retry
      videoCache.removeCorruptedVideo(params.videoId).then((_) {
        if (ref.mounted) {
          Log.info('🔄 Invalidating provider to retry download for video $videoIdDisplay...',
              name: 'IndividualVideoController', category: LogCategory.video);
          ref.invalidateSelf();
        }
      }).catchError((removeError) {
        Log.error('❌ Failed to remove corrupted cache: $removeError',
            name: 'IndividualVideoController', category: LogCategory.video);
      });
    } else if (_isVideoError(errorMessage) && ref.mounted) {
      // Mark video as broken for errors that indicate the video URL is non-functional
      ref.read(brokenVideoTrackerProvider.future).then((tracker) {
        // Double-check still mounted before marking broken
        if (ref.mounted) {
          tracker.markVideoBroken(params.videoId, 'Playback initialization failed: $errorMessage');
        }
      }).catchError((trackerError) {
        Log.warning('Failed to mark video as broken: $trackerError',
            name: 'IndividualVideoController', category: LogCategory.system);
      });
    }
  });

  // AutoDispose: Cleanup controller when provider is disposed
  ref.onDispose(() {
    cacheTimer?.cancel();
    Log.info('🧹 Disposing VideoPlayerController for video ${params.videoId.length > 8 ? params.videoId.substring(0, 8) : params.videoId}...',
        name: 'IndividualVideoController', category: LogCategory.system);
    // Defer controller disposal to avoid triggering listener callbacks during lifecycle
    // This prevents "Cannot use Ref inside life-cycles" errors when listeners try to access providers
    Future.microtask(() {
      controller.dispose();
    });
  });

  // NOTE: Play/pause logic has been moved to VideoFeedItem widget
  // The provider only manages controller lifecycle, NOT playback state
  // This ensures videos can only play when widget is mounted and visible

  return controller;
}

/// Check if error indicates a corrupted cache file
bool _isCacheCorruption(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('osstatus error -12848') ||
         lowerError.contains('media may be damaged') ||
         lowerError.contains('cannot open') ||
         (lowerError.contains('failed to load video') && lowerError.contains('damaged'));
}

/// Check if error indicates a broken/non-functional video
bool _isVideoError(String errorMessage) {
  final lowerError = errorMessage.toLowerCase();
  return lowerError.contains('404') ||
         lowerError.contains('not found') ||
         lowerError.contains('invalid statuscode: 404') ||
         lowerError.contains('httpexception') ||
         lowerError.contains('timeout') ||
         lowerError.contains('connection refused') ||
         lowerError.contains('network error') ||
         lowerError.contains('video initialization timed out');
}

/// Provider for video loading state
@riverpod
VideoLoadingState videoLoadingState(
  Ref ref,
  VideoControllerParams params,
) {
  final controller = ref.watch(individualVideoControllerProvider(params));

  if (controller.value.hasError) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: false,
      hasError: true,
      errorMessage: controller.value.errorDescription,
    );
  }

  if (controller.value.isInitialized) {
    return VideoLoadingState(
      videoId: params.videoId,
      isLoading: false,
      isInitialized: true,
      hasError: false,
    );
  }

  return VideoLoadingState(
    videoId: params.videoId,
    isLoading: true,
    isInitialized: false,
    hasError: false,
  );
}

/// Active video state with previous video tracking for proper pause handling
class ActiveVideoState {
  const ActiveVideoState({this.currentVideoId, this.previousVideoId});

  final String? currentVideoId;
  final String? previousVideoId;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ActiveVideoState &&
          currentVideoId == other.currentVideoId &&
          previousVideoId == other.previousVideoId;

  @override
  int get hashCode => currentVideoId.hashCode ^ previousVideoId.hashCode;
}

/// Active video state notifier that tracks transitions
/// @Deprecated Use active_video_provider.dart (pure derived). This notifier will be removed.
@Deprecated('Use active_video_provider.dart (pure derived). This notifier will be removed.')
class ActiveVideoNotifier extends StateNotifier<ActiveVideoState> {
  ActiveVideoNotifier() : super(const ActiveVideoState()) {
    assert(() {
      // Loud at dev time if anything still constructs this
      // ignore: avoid_print
      print('⚠️  DEPRECATED: ActiveVideoNotifier constructed. Migrate to active_video_provider.dart');
      return true;
    }());
  }

  /// Get the current active video ID (null if no video is active)
  String? get currentVideoId => state.currentVideoId;

  void setActiveVideo(String videoId) {
    // TEMPORARY: Tripwire disabled for gradual migration
    // TODO: Re-enable after all files migrated to active_video_provider.dart
    // No-op - derived provider handles active state
  }

  void clearActiveVideo() {
    // TEMPORARY: Tripwire disabled for gradual migration
    // TODO: Re-enable after all files migrated to active_video_provider.dart
    // No-op - derived provider handles active state
  }
}

/// Provider for tracking which video is currently active
final activeVideoProvider = StateNotifierProvider<ActiveVideoNotifier, ActiveVideoState>((ref) {
  return ActiveVideoNotifier();
});

/// Provider for checking if a specific video is currently active
@riverpod
bool isVideoActive(Ref ref, String videoId) {
  final activeVideoState = ref.watch(activeVideoProvider);
  final isActive = activeVideoState.currentVideoId == videoId;
  Log.debug('🔍 isVideoActive: videoId=${videoId.length > 8 ? videoId.substring(0, 8) : videoId}..., activeVideoId=${activeVideoState.currentVideoId != null && activeVideoState.currentVideoId!.length > 8 ? activeVideoState.currentVideoId!.substring(0, 8) : activeVideoState.currentVideoId ?? 'null'}, isActive=$isActive',
      name: 'IsVideoActive', category: LogCategory.system);
  return isActive;
}

// NOTE: PrewarmManager removed - using Riverpod-native lifecycle (onCancel/onResume + 30s timeout)
