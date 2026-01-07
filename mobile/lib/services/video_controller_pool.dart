// ABOUTME: Global video controller pool enforcing hard limit on concurrent controllers
// ABOUTME: Uses LRU eviction to prevent platform resource exhaustion (iOS/Android ~4-6 player limit)

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Global pool managing video controller lifecycle with hard limits.
///
/// Enforces a maximum number of concurrent video controllers to prevent
/// platform resource exhaustion. iOS and Android support approximately
/// 4-6 concurrent video players before hitting resource limits.
///
/// Uses LRU (Least Recently Used) eviction strategy:
/// - Currently playing video is protected from eviction
/// - Oldest non-playing controller is evicted when at capacity
///
/// Usage:
/// ```dart
/// final pool = ref.read(videoControllerPoolProvider);
///
/// // Before creating a controller
/// if (pool.isAtLimit) {
///   final evictId = pool.getEvictionCandidate();
///   if (evictId != null) {
///     // Invalidate that controller's provider
///   }
/// }
/// pool.requestSlot(videoId);
///
/// // When video starts playing
/// pool.markPlaying(videoId);
///
/// // When video stops playing
/// pool.markNotPlaying(videoId);
///
/// // On controller disposal
/// pool.releaseSlot(videoId);
/// ```
class VideoControllerPool extends ChangeNotifier {
  /// Maximum concurrent video controllers allowed.
  /// Platform limits: iOS/Android support ~4-6 concurrent players.
  /// Using 4 for safety margin.
  static const int maxConcurrentControllers = 4;

  /// LRU tracking: LinkedHashMap maintains insertion order.
  /// We move entries to end on access to implement LRU.
  /// Value is last access timestamp for debugging/logging.
  final LinkedHashMap<String, DateTime> _accessOrder = LinkedHashMap();

  /// Currently playing video ID (protected from eviction).
  /// Only one video plays at a time in the feed.
  String? _currentlyPlayingVideoId;

  /// Track controllers that are currently initializing.
  /// Prevents double-initialization during async init.
  final Set<String> _initializingControllers = {};

  /// Register a controller slot request.
  ///
  /// Call this before creating a new controller.
  /// Returns true if slot was granted, false if already registered.
  bool requestSlot(String videoId) {
    if (_accessOrder.containsKey(videoId)) {
      // Already registered - just update access time
      recordAccess(videoId);
      return false;
    }

    _accessOrder[videoId] = DateTime.now();
    _initializingControllers.add(videoId);

    Log.debug(
      '🎬 [POOL] Slot requested for $videoId (count: ${_accessOrder.length}/$maxConcurrentControllers)',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );

    notifyListeners();
    return true;
  }

  /// Mark controller as done initializing.
  ///
  /// Call this after controller.initialize() completes.
  void markInitialized(String videoId) {
    _initializingControllers.remove(videoId);
    Log.debug(
      '🎬 [POOL] Controller initialized: $videoId',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );
  }

  /// Mark a video as currently playing.
  ///
  /// Protected videos cannot be evicted.
  /// Call when video starts playback.
  void markPlaying(String videoId) {
    _currentlyPlayingVideoId = videoId;
    recordAccess(videoId);

    Log.debug(
      '▶️ [POOL] Now playing: $videoId',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  /// Mark a video as no longer playing.
  ///
  /// Video becomes eligible for eviction.
  /// Call when video pauses or stops.
  void markNotPlaying(String videoId) {
    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;

      Log.debug(
        '⏸️ [POOL] Stopped playing: $videoId',
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );

      notifyListeners();
    }
  }

  /// Update LRU access time for a video.
  ///
  /// Moves the video to end of LinkedHashMap (most recently used).
  /// Call on any controller access (play, pause, seek, etc.)
  void recordAccess(String videoId) {
    if (!_accessOrder.containsKey(videoId)) return;

    // Remove and re-add to move to end (most recent)
    _accessOrder.remove(videoId);
    _accessOrder[videoId] = DateTime.now();
  }

  /// Release a controller slot.
  ///
  /// Call in provider's onDispose callback.
  void releaseSlot(String videoId) {
    final existed = _accessOrder.remove(videoId) != null;
    _initializingControllers.remove(videoId);

    if (_currentlyPlayingVideoId == videoId) {
      _currentlyPlayingVideoId = null;
    }

    if (existed) {
      Log.debug(
        '🗑️ [POOL] Slot released: $videoId (count: ${_accessOrder.length}/$maxConcurrentControllers)',
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );
      notifyListeners();
    }
  }

  /// Get the video ID to evict (oldest non-playing controller).
  ///
  /// Returns null if no eviction candidate available.
  /// Skips:
  /// - Currently playing video
  /// - Controllers still initializing
  String? getEvictionCandidate() {
    // LinkedHashMap iterates in insertion order (oldest first due to LRU updates)
    for (final videoId in _accessOrder.keys) {
      // Skip currently playing video
      if (videoId == _currentlyPlayingVideoId) continue;

      // Skip controllers still initializing
      if (_initializingControllers.contains(videoId)) continue;

      Log.debug(
        '🎯 [POOL] Eviction candidate: $videoId',
        name: 'VideoControllerPool',
        category: LogCategory.video,
      );
      return videoId;
    }

    return null;
  }

  /// Get all video IDs to evict to make room for new controllers.
  ///
  /// Returns list of video IDs sorted by access time (oldest first).
  /// Useful when multiple slots are needed.
  List<String> getEvictionCandidates(int count) {
    final candidates = <String>[];

    for (final videoId in _accessOrder.keys) {
      if (candidates.length >= count) break;

      // Skip currently playing video
      if (videoId == _currentlyPlayingVideoId) continue;

      // Skip controllers still initializing
      if (_initializingControllers.contains(videoId)) continue;

      candidates.add(videoId);
    }

    return candidates;
  }

  /// Current number of registered controllers.
  int get activeCount => _accessOrder.length;

  /// Check if pool is at maximum capacity.
  bool get isAtLimit => _accessOrder.length >= maxConcurrentControllers;

  /// Number of slots available for new controllers.
  int get availableSlots => (maxConcurrentControllers - _accessOrder.length)
      .clamp(0, maxConcurrentControllers);

  /// Currently playing video ID (for debugging).
  String? get currentlyPlayingVideoId => _currentlyPlayingVideoId;

  /// Check if a specific video has a registered slot.
  bool hasSlot(String videoId) => _accessOrder.containsKey(videoId);

  /// Check if a specific video is currently initializing.
  bool isInitializing(String videoId) =>
      _initializingControllers.contains(videoId);

  /// Get all registered video IDs (for debugging).
  List<String> get registeredVideoIds => _accessOrder.keys.toList();

  /// Clear all slots (useful when navigating away from feed).
  void clear() {
    _accessOrder.clear();
    _initializingControllers.clear();
    _currentlyPlayingVideoId = null;

    Log.info(
      '🧹 [POOL] Cleared all slots',
      name: 'VideoControllerPool',
      category: LogCategory.video,
    );

    notifyListeners();
  }

  @override
  void dispose() {
    _accessOrder.clear();
    _initializingControllers.clear();
    super.dispose();
  }

  @override
  String toString() {
    return 'VideoControllerPool('
        'active: $activeCount/$maxConcurrentControllers, '
        'playing: $_currentlyPlayingVideoId, '
        'initializing: ${_initializingControllers.length}'
        ')';
  }
}
