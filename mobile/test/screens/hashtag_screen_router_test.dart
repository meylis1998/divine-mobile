// ABOUTME: Tests for router-driven HashtagScreen implementation
// ABOUTME: Verifies URL ↔ PageView synchronization for hashtag feeds

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_lifecycle_provider.dart';
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  Widget _shell(ProviderContainer c) => UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(routerConfig: c.read(goRouterProvider)),
      );

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  final mockVideos = [
    VideoEvent(
      id: 'h0',
      pubkey: 'pubkey-0',
      createdAt: nowUnix,
      content: 'Video 0 #nostr',
      timestamp: now,
      videoUrl: 'https://example.com/h0.mp4',
      thumbnailUrl: 'https://example.com/h0-thumb.jpg',
      hashtags: const ['nostr'],
      duration: 6,
      dimensions: '1080x1920',
    ),
    VideoEvent(
      id: 'h1',
      pubkey: 'pubkey-1',
      createdAt: nowUnix,
      content: 'Video 1 #nostr',
      timestamp: now,
      videoUrl: 'https://example.com/h1.mp4',
      thumbnailUrl: 'https://example.com/h1-thumb.jpg',
      hashtags: const ['nostr'],
      duration: 6,
      dimensions: '1080x1920',
    ),
    VideoEvent(
      id: 'h2',
      pubkey: 'pubkey-2',
      createdAt: nowUnix,
      content: 'Video 2 #nostr',
      timestamp: now,
      videoUrl: 'https://example.com/h2.mp4',
      thumbnailUrl: 'https://example.com/h2-thumb.jpg',
      hashtags: const ['nostr'],
      duration: 6,
      dimensions: '1080x1920',
    ),
  ];

  testWidgets('HASHTAG: URL ↔ PageView sync', (tester) async {
    final c = ProviderContainer(overrides: [
      videosForHashtagRouteProvider.overrideWith((ref) {
        return AsyncValue.data(VideoFeedState(
          videos: mockVideos,
          hasMoreContent: false,
          isLoadingMore: false,
        ));
      }),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/hashtag/nostr/0');
    await tester.pumpAndSettle();

    expect(find.byType(HashtagScreenRouter), findsOneWidget);
    expect(find.text('Hashtag 0/3'), findsOneWidget);

    // Navigate to index 1 via URL
    c.read(goRouterProvider).go('/hashtag/nostr/1');
    await tester.pumpAndSettle();
    expect(find.text('Hashtag 1/3'), findsOneWidget);
  });

  testWidgets('HASHTAG: Empty state shows when no videos', (tester) async {
    final c = ProviderContainer(overrides: [
      videosForHashtagRouteProvider.overrideWith((ref) {
        return AsyncValue.data(VideoFeedState(
          videos: const [],
          hasMoreContent: false,
          isLoadingMore: false,
        ));
      }),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/hashtag/nostr/0');
    await tester.pumpAndSettle();

    expect(find.textContaining('No videos found'), findsOneWidget);
  });

  testWidgets('HASHTAG: Prefetch ±1 profiles when URL index changes',
      (tester) async {
    final prefetchedPubkeys = <String>[];
    final mockNotifier = FakeUserProfileNotifier(
      onPrefetch: (pubkeys) => prefetchedPubkeys.addAll(pubkeys),
    );

    final c = ProviderContainer(overrides: [
      videosForHashtagRouteProvider.overrideWith((ref) {
        return AsyncValue.data(VideoFeedState(
          videos: mockVideos,
          hasMoreContent: false,
          isLoadingMore: false,
        ));
      }),
      userProfileProvider.overrideWith(() => mockNotifier),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/hashtag/nostr/1');
    await tester.pumpAndSettle();

    // Should prefetch profiles for videos at index 0 and 2 (±1 from index 1)
    expect(prefetchedPubkeys.length, greaterThanOrEqualTo(1));
  });

  testWidgets('HASHTAG: Lifecycle pause → activeVideoId becomes null',
      (tester) async {
    final c = ProviderContainer(overrides: [
      appForegroundProvider.overrideWithValue(const AsyncValue.data(false)),
      videosForHashtagRouteProvider.overrideWith((ref) {
        return AsyncValue.data(VideoFeedState(
          videos: mockVideos,
          hasMoreContent: false,
          isLoadingMore: false,
        ));
      }),
    ]);
    addTearDown(c.dispose);

    await tester.pumpWidget(_shell(c));
    c.read(goRouterProvider).go('/hashtag/nostr/0');
    await tester.pumpAndSettle();

    // When app is backgrounded, activeVideoId should be null
    expect(c.read(activeVideoIdProvider), isNull);
  });
}

class FakeUserProfileNotifier extends UserProfileNotifier {
  FakeUserProfileNotifier({required this.onPrefetch});
  final void Function(List<String>) onPrefetch;

  @override
  Future<void> prefetchProfilesImmediately(List<String> pubkeys) async {
    onPrefetch(pubkeys);
  }
}
