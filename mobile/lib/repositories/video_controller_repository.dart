// ABOUTME: Repository for managing video player controllers with pooling and caching
// ABOUTME: Consolidates pool management, controller creation, and resource limits into single service

import 'dart:collection';

import 'package:flutter/foundation.dart' show ChangeNotifier, kIsWeb;
import 'package:openvine/providers/individual_video_providers.dart'
    show VideoControllerParams;
import 'package:openvine/services/age_verification_service.dart';
import 'package:openvine/services/blossom_auth_service.dart';
import 'package:openvine/services/video_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:video_player/video_player.dart';

/// Result of acquiring a controller from the repository.
class VideoControllerResult {
  const VideoControllerResult({
    required this.controller,
    required this.videoUrl,
    required this.isFromCache,
    required this.wasExisting,
  });

  /// The video player controller (not yet initialized if newly created).
  final VideoPlayerController controller;

  /// The final video URL used (may be normalized from .bin).
  final String videoUrl;

  /// Whether the controller was created from a cached file.
  final bool isFromCache;

  /// Whether this controller already existed in the repository.
  /// If false, the controller was just created and needs initialization.
  final bool wasExisting;
}

/// Metadata tracked for each controller in the repository.
class _ControllerEntry {
  _ControllerEntry({
    required this.controller,
    required this.videoUrl,
    required this.isFromCache,
    required this.params,
  }) : lastAccessTime = DateTime.now();

  final VideoPlayerController controller;
  final String videoUrl;
  final bool isFromCache;
  final VideoControllerParams params;
  DateTime lastAccessTime;
  bool isInitializing = true;
  bool isPlaying = false;

  void recordAccess() {
    lastAccessTime = DateTime.now();
  }
}

/// Repository for managing video player controllers.
///
/// Consolidates:
/// - Pool management (LRU eviction, concurrent controller limits)
/// - Controller creation (platform-specific, cache-aware)
/// - URL normalization (.bin extension rewriting)
/// - Auth header computation (NSFW content)
///
/// Uses shared ownership model:
/// - Repository handles: creation, caching, pool limits
/// - Provider handles: initialization, disposal (via Riverpod autoDispose)
///
/// Usage:
/// ```dart
/// final repository = ref.read(videoControllerRepositoryProvider);
///
/// // Acquire a controller (handles pool limits, eviction, creation)
/// final result = repository.acquireController(params);
///
/// // Mark playback state (protects from eviction)
/// repository.markPlaying(videoId);
/// repository.markNotPlaying(videoId);
///
/// // Release when done (in provider's onDispose)
/// repository.releaseController(videoId);
/// ```
class VideoControllerRepository extends ChangeNotifier {
  VideoControllerRepository({
    required VideoCacheManager cacheManager,
    required AgeVerificationService ageVerificationService,
    required BlossomAuthService blossomAuthService,
  }) : _cacheManager = cacheManager,
       _ageVerificationService = ageVerificationService,
       _blossomAuthService = blossomAuthService;

  final VideoCacheManager _cacheManager;
  final AgeVerificationService _ageVerificationService;
  final BlossomAuthService _blossomAuthService;

  /// Maximum concurrent video controllers allowed.
  /// Platform limits: iOS/Android support ~4-6 concurrent players.
  /// Using 4 for safety margin.
  static const int maxConcurrentControllers = 4;

  /// Controller storage with LRU ordering.
  /// LinkedHashMap maintains insertion order; we re-insert on access for LRU.
  final LinkedHashMap<String, _ControllerEntry> _controllers = LinkedHashMap();

  /// In-memory cache for auth headers by video ID.
  final Map<String, Map<String, String>> _authHeadersCache = {};

  /// Currently playing video ID (protected from eviction).
  String? _currentlyPlayingVideoId;

  // ===========================================================================
  // Public API
  // ===========================================================================

  /// Acquire a controller for the given params.
  ///
  /// Returns existing controller if already in repository, otherwise creates new.
  /// Handles pool limits internally - may evict LRU controller if at capacity.
  /// Controller is NOT initialized if newly created - caller must initialize.
  VideoControllerResult acquireController(VideoControllerParams params) {
    final videoId = params.videoId;

    // Check if we already have this controller
    final existing = _controllers[videoId];
    if (existing != null) {
      _recordAccess(videoId);
      Log.debug(
        '🎬 [REPO] Returning existing controller for $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return VideoControllerResult(
        controller: existing.controller,
        videoUrl: existing.videoUrl,
        isFromCache: existing.isFromCache,
        wasExisting: true,
      );
    }

    // Evict if at capacity
    if (isAtLimit) {
      final evictId = _getEvictionCandidate();
      if (evictId != null) {
        _evictController(evictId);
      }
    }

    // Create new controller
    final result = _createController(params);

    // Store in cache
    _controllers[videoId] = _ControllerEntry(
      controller: result.controller,
      videoUrl: result.videoUrl,
      isFromCache: result.isFromCache,
      params: params,
    );

    Log.info(
      '🎬 [REPO] Created controller for $videoId (count: ${_controllers.length}/$maxConcurrentControllers)',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();

    return VideoControllerResult(
      controller: result.controller,
      videoUrl: result.videoUrl,
      isFromCache: result.isFromCache,
      wasExisting: false,
    );
  }

  /// Release a controller from the repository.
  ///
  /// Call in provider's onDispose callback.
  /// Does NOT dispose the controller - caller handles disposal.
  void releaseController(String videoId) {
    final entry = _controllers.remove(videoId);

    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }

    if (entry != null) {
      Log.debug(
        '🗑️ [REPO] Released controller for $videoId (count: ${_controllers.length}/$maxConcurrentControllers)',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      notifyListeners();
    }
  }

  /// Mark controller as initialized (no longer initializing).
  void markInitialized(String videoId) {
    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isInitializing = false;
      Log.debug(
        '✅ [REPO] Controller initialized: $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
    }
  }

  /// Mark controller as currently playing (protects from eviction).
  void markPlaying(String videoId) {
    _currentlyPlayingVideoId = videoId;
    _recordAccess(videoId);

    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isPlaying = true;
    }

    Log.debug(
      '▶️ [REPO] Now playing: $videoId',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  /// Mark controller as not playing (eligible for eviction).
  void markNotPlaying(String videoId) {
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }

    final entry = _controllers[videoId];
    if (entry != null) {
      entry.isPlaying = false;

      Log.debug(
        '⏸️ [REPO] Stopped playing: $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );

      notifyListeners();
    }
  }

  /// Check if repository has a controller for this video.
  bool hasController(String videoId) => _controllers.containsKey(videoId);

  /// Get the controller if it exists (for checking state).
  VideoPlayerController? getController(String videoId) =>
      _controllers[videoId]?.controller;

  /// Whether video caching should be triggered.
  bool shouldCacheVideo(VideoControllerParams params) {
    if (kIsWeb) return false;
    final cachedFile = _cacheManager.getCachedVideoSync(params.videoId);
    return cachedFile == null || !cachedFile.existsSync();
  }

  /// Generate and cache auth headers for future use.
  Future<void> cacheAuthHeaders(VideoControllerParams params) async {
    if (!_ageVerificationService.isAdultContentVerified) return;
    if (!_blossomAuthService.canCreateHeaders) return;
    if (params.videoEvent == null) return;
    if (_authHeadersCache.containsKey(params.videoId)) return;

    try {
      final videoEvent = params.videoEvent as dynamic;
      final sha256 = videoEvent.sha256 as String?;

      if (sha256 == null || sha256.isEmpty) return;

      String? serverUrl;
      try {
        final uri = Uri.parse(params.videoUrl);
        serverUrl = '${uri.scheme}://${uri.host}';
      } catch (e) {
        Log.warning(
          'Failed to parse video URL for server: $e',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
        return;
      }

      final authHeader = await _blossomAuthService.createGetAuthHeader(
        sha256Hash: sha256,
        serverUrl: serverUrl,
      );

      if (authHeader != null) {
        _authHeadersCache[params.videoId] = {'Authorization': authHeader};
        Log.info(
          '✅ Cached auth header for video ${params.videoId}',
          name: 'VideoControllerRepository',
          category: LogCategory.video,
        );
      }
    } catch (error) {
      Log.debug(
        'Failed to generate auth headers: $error',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
    }
  }

  // ===========================================================================
  // Pool Status Getters
  // ===========================================================================

  /// Current number of controllers in repository.
  int get activeCount => _controllers.length;

  /// Number of slots available for new controllers.
  int get availableSlots => (maxConcurrentControllers - _controllers.length)
      .clamp(0, maxConcurrentControllers);

  /// Whether repository is at maximum capacity.
  bool get isAtLimit => _controllers.length >= maxConcurrentControllers;

  /// Currently playing video ID.
  String? get currentlyPlayingVideoId => _currentlyPlayingVideoId;

  /// Get the cache manager for external caching operations.
  VideoCacheManager get cacheManager => _cacheManager;

  /// All registered video IDs (for debugging).
  List<String> get registeredVideoIds => _controllers.keys.toList();

  /// Clear all controllers (useful when navigating away from feed).
  void clear() {
    _controllers.clear();
    _currentlyPlayingVideoId = null;

    Log.info(
      '🧹 [REPO] Cleared all controllers',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _controllers.clear();
    _authHeadersCache.clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'VideoControllerRepository('
        'active: $activeCount/$maxConcurrentControllers, '
        'playing: $_currentlyPlayingVideoId'
        ')';
  }

  // ===========================================================================
  // Private Methods
  // ===========================================================================

  /// Update LRU access time for a video.
  void _recordAccess(String videoId) {
    final entry = _controllers.remove(videoId);
    if (entry != null) {
      entry.recordAccess();
      _controllers[videoId] = entry; // Re-insert at end (most recent)
    }
  }

  /// Get the video ID to evict (oldest non-playing, non-initializing).
  String? _getEvictionCandidate() {
    for (final videoId in _controllers.keys) {
      final entry = _controllers[videoId]!;

      // Skip currently playing video
      if (videoId == _currentlyPlayingVideoId) continue;

      // Skip controllers still initializing
      if (entry.isInitializing) continue;

      Log.debug(
        '🎯 [REPO] Eviction candidate: $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return videoId;
    }

    return null;
  }

  /// Evict a controller from the repository.
  void _evictController(String videoId) {
    final entry = _controllers.remove(videoId);
    if (entry != null) {
      Log.info(
        '🔄 [REPO] Evicting controller for $videoId',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
    }
  }

  /// Create a new controller for the given params.
  VideoControllerResult _createController(VideoControllerParams params) {
    // Normalize URL (.bin extension handling)
    final videoUrl = _normalizeVideoUrl(params);

    // Get auth headers if available
    final authHeaders = _getAuthHeaders(params);

    // Create controller based on platform
    if (kIsWeb) {
      return _createWebController(params, videoUrl, authHeaders);
    } else {
      return _createNativeController(params, videoUrl, authHeaders);
    }
  }

  /// Create controller for web platform.
  VideoControllerResult _createWebController(
    VideoControllerParams params,
    String videoUrl,
    Map<String, String>? authHeaders,
  ) {
    Log.debug(
      '🌐 Web platform - using NETWORK URL for video ${params.videoId}',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: videoUrl,
      isFromCache: false,
      wasExisting: false,
    );
  }

  /// Create controller for native platforms (uses cache when available).
  VideoControllerResult _createNativeController(
    VideoControllerParams params,
    String videoUrl,
    Map<String, String>? authHeaders,
  ) {
    final cachedFile = _cacheManager.getCachedVideoSync(params.videoId);

    if (cachedFile != null && cachedFile.existsSync()) {
      Log.info(
        '✅ Using CACHED FILE for video ${params.videoId}: ${cachedFile.path}',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );

      final controller = VideoPlayerController.file(cachedFile);

      return VideoControllerResult(
        controller: controller,
        videoUrl: videoUrl,
        isFromCache: true,
        wasExisting: false,
      );
    }

    Log.debug(
      '📡 Using NETWORK URL for video ${params.videoId}',
      name: 'VideoControllerRepository',
      category: LogCategory.video,
    );

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      httpHeaders: authHeaders ?? {},
    );

    return VideoControllerResult(
      controller: controller,
      videoUrl: videoUrl,
      isFromCache: false,
      wasExisting: false,
    );
  }

  /// Normalize .bin URLs based on MIME type.
  String _normalizeVideoUrl(VideoControllerParams params) {
    String videoUrl = params.videoUrl;

    if (videoUrl.toLowerCase().endsWith('.bin') && params.videoEvent != null) {
      final videoEvent = params.videoEvent as dynamic;
      final mimeType = videoEvent.mimeType as String?;

      if (mimeType != null) {
        String? newExtension;
        if (mimeType.contains('webm')) {
          newExtension = '.webm';
        } else if (mimeType.contains('mp4')) {
          newExtension = '.mp4';
        }

        if (newExtension != null) {
          videoUrl = videoUrl.substring(0, videoUrl.length - 4) + newExtension;
          Log.debug(
            '🔧 Normalized .bin URL based on MIME type $mimeType: $newExtension',
            name: 'VideoControllerRepository',
            category: LogCategory.video,
          );
        }
      }
    }

    return videoUrl;
  }

  /// Get auth headers for a video.
  Map<String, String>? _getAuthHeaders(VideoControllerParams params) {
    if (!_ageVerificationService.isAdultContentVerified) {
      return null;
    }

    if (!_blossomAuthService.canCreateHeaders || params.videoEvent == null) {
      return null;
    }

    final cachedHeaders = _authHeadersCache[params.videoId];
    if (cachedHeaders != null) {
      Log.debug(
        '🔐 Using cached auth headers for video ${params.videoId}',
        name: 'VideoControllerRepository',
        category: LogCategory.video,
      );
      return cachedHeaders;
    }

    return null;
  }
}
