// ABOUTME: Tests that videos are properly paused when switching between tabs
// ABOUTME: Ensures videos on inactive tabs don't play in background

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';

/// Test widget that simulates tab listener behavior from video_feed_screen.dart
class TabWithListener extends ConsumerWidget {
  const TabWithListener({
    required this.tabIndex,
    required this.child,
    super.key,
  });

  final int tabIndex;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Listen for tab changes and clear active video when tab is hidden
    ref.listen(
      tabVisibilityProvider,
      (prev, next) {
        if (next != tabIndex) {
          // This tab is no longer visible - clear active video
          ref.read(activeVideoProvider.notifier).clearActiveVideo();
        }
      },
    );

    return child;
  }
}

void main() {
  group('Tab Navigation Video Pause Tests', () {
    testWidgets('Switching to different tab clears active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Setup: Create test widget with tabs
      final testVideoId = 'test-video-tab-1';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DefaultTabController(
              length: 4,
              child: Scaffold(
                body: TabBarView(
                  children: [
                    // Tab 0: Home Feed (with listener)
                    TabWithListener(
                      tabIndex: 0,
                      child: const Center(child: Text('Home')),
                    ),
                    // Tab 1: Activity
                    const Center(child: Text('Activity')),
                    // Tab 2: Explore (with listener)
                    TabWithListener(
                      tabIndex: 2,
                      child: const Center(child: Text('Explore')),
                    ),
                    // Tab 3: Profile (with listener)
                    TabWithListener(
                      tabIndex: 3,
                      child: const Center(child: Text('Profile')),
                    ),
                  ],
                ),
                bottomNavigationBar: const TabBar(
                  tabs: [
                    Tab(icon: Icon(Icons.home)),
                    Tab(icon: Icon(Icons.explore)),
                    Tab(icon: Icon(Icons.add)),
                    Tab(icon: Icon(Icons.person)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure postFrameCallbacks have executed (listeners are set up)
      await tester.pump();
      await tester.pump();

      // Set active video and update tab visibility to tab 0
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      // Verify setup: video is active
      expect(container.read(activeVideoProvider).currentVideoId, equals(testVideoId));

      // Action: Switch to tab 1 (Activity - no listener, so should trigger tab 0's listener)
      await tester.tap(find.byIcon(Icons.explore));
      await tester.pumpAndSettle();

      // Update tab visibility - this triggers listeners
      container.read(tabVisibilityProvider.notifier).state = 1;
      await tester.pump();
      await tester.pump(); // Extra pump for listener to execute

      // Assert: Active video should be cleared
      // Note: This will fail until we implement the tab listener in video_feed_screen.dart
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should be cleared when switching tabs',
      );
    });

    testWidgets('Switching to Settings tab clears active video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-settings';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                body: TabBarView(
                  children: [
                    const Center(child: Text('Feed')),
                    const Center(child: Text('Settings')),
                  ],
                ),
                bottomNavigationBar: const TabBar(
                  tabs: [
                    Tab(text: 'Feed'),
                    Tab(text: 'Settings'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup: Video playing on Feed tab
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      expect(container.read(activeVideoProvider).currentVideoId, equals(testVideoId));

      // Action: Switch to Settings tab
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      container.read(tabVisibilityProvider.notifier).state = 1;
      await tester.pump();

      // Assert: Active video cleared
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Active video should be cleared when navigating to Settings',
      );
    });

    testWidgets('Returning to original tab does not auto-play previous video', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-return';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DefaultTabController(
              length: 2,
              child: Scaffold(
                body: TabBarView(
                  children: [
                    const Center(child: Text('Home')),
                    const Center(child: Text('Profile')),
                  ],
                ),
                bottomNavigationBar: const TabBar(
                  tabs: [
                    Tab(text: 'Home'),
                    Tab(text: 'Profile'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup: Video playing on Home tab
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      // Switch to Profile tab
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      container.read(tabVisibilityProvider.notifier).state = 1;
      await tester.pump();

      // Verify video was cleared
      expect(container.read(activeVideoProvider).currentVideoId, isNull);

      // Action: Return to Home tab
      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      // Assert: Active video should still be null (not auto-resumed)
      expect(
        container.read(activeVideoProvider).currentVideoId,
        isNull,
        reason: 'Video should not auto-resume when returning to tab',
      );
    });

    testWidgets('Rapid tab switching maintains cleared state', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final testVideoId = 'test-video-rapid';

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            home: DefaultTabController(
              length: 4,
              child: Scaffold(
                body: const TabBarView(
                  children: [
                    Center(child: Text('Tab 0')),
                    Center(child: Text('Tab 1')),
                    Center(child: Text('Tab 2')),
                    Center(child: Text('Tab 3')),
                  ],
                ),
                bottomNavigationBar: TabBar(
                  tabs: List.generate(4, (i) => Tab(text: 'Tab $i')),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Setup: Video active on tab 0
      container.read(activeVideoProvider.notifier).setActiveVideo(testVideoId);
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      // Rapidly switch through tabs
      for (int i = 1; i < 4; i++) {
        await tester.tap(find.text('Tab $i'));
        await tester.pumpAndSettle();
        container.read(tabVisibilityProvider.notifier).state = i;
        await tester.pump();

        // Assert: Active video should be null after each switch
        expect(
          container.read(activeVideoProvider).currentVideoId,
          isNull,
          reason: 'Active video should be cleared on tab $i',
        );
      }

      // Return to tab 0
      await tester.tap(find.text('Tab 0'));
      await tester.pumpAndSettle();
      container.read(tabVisibilityProvider.notifier).state = 0;
      await tester.pump();

      // Still should be null (no auto-resume)
      expect(container.read(activeVideoProvider).currentVideoId, isNull);
    });
  });
}
