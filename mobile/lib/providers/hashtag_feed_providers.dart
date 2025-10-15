// ABOUTME: Hashtag-specific feed provider for route-driven HashtagScreenRouter
// ABOUTME: Returns videos filtered by hashtag based on route context

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/state/video_feed_state.dart';

/// Hashtag feed state for a specific hashtag
/// Returns AsyncValue<VideoFeedState> filtered by hashtag from route
final videosForHashtagRouteProvider =
    Provider<AsyncValue<VideoFeedState>>((ref) {
  final contextAsync = ref.watch(pageContextProvider);

  return contextAsync.when(
    data: (ctx) {
      if (ctx.type != RouteType.hashtag) {
        // Not on hashtag route - return loading
        return const AsyncValue.loading();
      }

      // TODO: Implement actual hashtag feed fetching based on ctx.hashtag
      // For now, return empty feed until we wire up real hashtag feed provider
      return AsyncValue.data(VideoFeedState(
        videos: const [],
        hasMoreContent: false,
        isLoadingMore: false,
      ));
    },
    loading: () => const AsyncValue.loading(),
    error: (e, st) => AsyncValue.error(e, st),
  );
});
