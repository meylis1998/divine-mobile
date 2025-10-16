// ABOUTME: Router-driven active video provider
// ABOUTME: Derives active video ID from URL context, feed state, and app foreground state

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/profile_feed_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Active video ID derived from router state and app lifecycle
/// Returns null when app is backgrounded or no valid video at current index
/// Route-aware: switches feed provider based on route type
final activeVideoIdProvider = Provider<String?>((ref) {
  // Check app foreground state
  final isFg = ref.watch(appForegroundProvider).maybeWhen(
    data: (v) => v,
    orElse: () => true,
  );
  if (!isFg) return null;

  // Get current page context from router
  final ctx = ref.watch(pageContextProvider).asData?.value;
  if (ctx == null) return null;

  // Select feed provider based on route type
  AsyncValue<VideoFeedState> videosAsync;
  switch (ctx.type) {
    case RouteType.home:
      videosAsync = ref.watch(videosForHomeRouteProvider);
      break;
    case RouteType.profile:
      videosAsync = ref.watch(videosForProfileRouteProvider);
      break;
    case RouteType.hashtag:
      videosAsync = ref.watch(videosForHashtagRouteProvider);
      break;
    case RouteType.explore:
      // Explore route not yet implemented, use home feed as fallback
      videosAsync = ref.watch(videosForHomeRouteProvider);
      break;
    case RouteType.notifications:
    case RouteType.camera:
    case RouteType.settings:
      // Non-video routes - return null
      return null;
  }

  final videos = videosAsync.maybeWhen(
    data: (state) => state.videos,
    orElse: () => const [],
  );

  if (videos.isEmpty) return null;

  // Get video at current index
  final idx = (ctx.videoIndex ?? 0).clamp(0, videos.length - 1);
  return videos[idx].id;
});

/// Per-video active state (for efficient VideoFeedItem updates)
/// Returns true if the given videoId matches the current active video
final isVideoActiveProvider = Provider.family<bool, String>((ref, videoId) {
  final activeVideoId = ref.watch(activeVideoIdProvider);
  return activeVideoId == videoId;
});
