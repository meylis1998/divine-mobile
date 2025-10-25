// ABOUTME: Tests that search route does not activate videos
// ABOUTME: Verifies activeVideoIdProvider returns null when on search route

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

void main() {
  group('Search route video playback', () {
    test('activeVideoIdProvider returns null when on search route', () {
      final container = ProviderContainer(
        overrides: [
          // App is in foreground
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          // Current route is search
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.search),
            ),
          ),
        ],
      );

      final activeVideoId = container.read(activeVideoIdProvider);

      // Search route should not activate any video
      expect(activeVideoId, isNull);

      container.dispose();
    });

    test('activeVideoIdProvider returns null when on search route even if videoIndex present', () {
      final container = ProviderContainer(
        overrides: [
          // App is in foreground
          appForegroundProvider.overrideWithValue(const AsyncValue.data(true)),
          // Current route is search with index (should be ignored)
          pageContextProvider.overrideWithValue(
            const AsyncValue.data(
              RouteContext(type: RouteType.search, videoIndex: 5),
            ),
          ),
        ],
      );

      final activeVideoId = container.read(activeVideoIdProvider);

      // Search route should never activate video, even with index
      expect(activeVideoId, isNull);

      container.dispose();
    });
  });
}
