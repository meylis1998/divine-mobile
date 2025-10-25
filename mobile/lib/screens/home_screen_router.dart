// ABOUTME: Router-driven HomeScreen implementation (clean room)
// ABOUTME: Pure presentation with no lifecycle mutations - URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/mixins/async_value_ui_helpers_mixin.dart';
import 'package:openvine/mixins/page_controller_sync_mixin.dart';
import 'package:openvine/mixins/video_prefetch_mixin.dart';
import 'package:openvine/providers/home_screen_controllers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/widgets/video_feed_item.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Router-driven HomeScreen - PageView syncs with URL bidirectionally
class HomeScreenRouter extends ConsumerStatefulWidget {
  const HomeScreenRouter({super.key});

  @override
  ConsumerState<HomeScreenRouter> createState() => _HomeScreenRouterState();
}

class _HomeScreenRouterState extends ConsumerState<HomeScreenRouter>
    with VideoPrefetchMixin, PageControllerSyncMixin, AsyncValueUIHelpersMixin {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;
  String? _currentVideoId; // Track the video ID we're currently viewing
  bool _urlUpdateScheduled = false; // Prevent infinite rebuild loops

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Check if user follows anyone - redirect to explore if not
    final socialState = ref.watch(social.socialProvider);
    if (socialState.isInitialized && socialState.followingPubkeys.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.go('/explore');
        }
      });
    }

    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return buildAsyncUI(
      pageContext,
      onData: (ctx) {
        // Only handle home routes
        if (ctx.type != RouteType.home) {
          return const Center(child: Text('Not a home route'));
        }

        int urlIndex = 0;

        // Determine target index from route context

        // Get video data from home feed
        final videosAsync = ref.watch(videosForHomeRouteProvider);

        return buildAsyncUI(
          videosAsync,
          onData: (state) {
            final videos = state.videos;

            // Determine target index from route context
            if (ctx.eventId != null) {
              // Event-based routing: find video by ID
              final targetIndex = videos.indexWhere((v) => v.id == ctx.eventId);
              urlIndex = targetIndex != -1 ? targetIndex : 0;
              Log.debug(
                '📍 Event-based routing: eventId=${ctx.eventId} → index=$urlIndex',
                name: 'HomeScreenRouter',
                category: LogCategory.video,
              );
            } else {
              // Legacy index-based routing
              urlIndex = (ctx.videoIndex ?? 0).clamp(0, videos.length - 1);
            }

            if (videos.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.video_library_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No videos available',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Follow some creators to see their videos here',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            final itemCount = videos.length;

            // Initialize controller once with URL index
            if (_controller == null) {
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              _controller = PageController(initialPage: safeIndex);
              _lastUrlIndex = safeIndex;
              _currentVideoId = videos[safeIndex].id; // Remember which video we're showing
            }

            // Check if video list changed (e.g., reordered due to social provider update)
            // If current video moved to different index, update URL to maintain position
            bool urlUpdatePending = false;
            if (_currentVideoId != null && videos.isNotEmpty && !_urlUpdateScheduled) {
              final currentVideoIndex = videos.indexWhere((v) => v.id == _currentVideoId);
              if (currentVideoIndex != -1 && currentVideoIndex != urlIndex) {
                // Video we're viewing is now at a different index - update URL silently
                Log.debug(
                  '📍 Video $_currentVideoId moved from index $urlIndex → $currentVideoIndex, updating URL',
                  name: 'HomeScreenRouter',
                  category: LogCategory.video,
                );
                _urlUpdateScheduled = true; // Prevent multiple pending updates
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _urlUpdateScheduled = false; // Reset flag after update
                  // Use event-based routing (always use event ID, not index)
                  context.go(buildRoute(
                    RouteContext(
                      type: RouteType.home,
                      eventId: _currentVideoId,
                    ),
                  ));
                });
                urlUpdatePending = true;
              }
            }

            // Sync controller when URL changes externally (back/forward/deeplink)
            // OR when videos list changes (e.g., social provider loads)
            // Skip if URL update is already pending from reorder detection
            if (!urlUpdatePending &&
                shouldSync(
                  urlIndex: urlIndex,
                  lastUrlIndex: _lastUrlIndex,
                  controller: _controller,
                  targetIndex: urlIndex.clamp(0, itemCount - 1),
                )) {
              _lastUrlIndex = urlIndex;
              _currentVideoId = videos[urlIndex.clamp(0, itemCount - 1)].id; // Update tracked video
              syncPageController(
                controller: _controller!,
                targetIndex: urlIndex,
                itemCount: itemCount,
              );
            }

            // Prefetch profiles for adjacent videos (±1 index) only when URL index changes
            if (urlIndex != _lastPrefetchIndex) {
              _lastPrefetchIndex = urlIndex;
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              final pubkeysToPrefetech = <String>[];

              // Prefetch previous video's profile
              if (safeIndex > 0) {
                pubkeysToPrefetech.add(videos[safeIndex - 1].pubkey);
              }

              // Prefetch next video's profile
              if (safeIndex < itemCount - 1) {
                pubkeysToPrefetech.add(videos[safeIndex + 1].pubkey);
              }

              // Schedule prefetch for next frame to avoid doing work during build
              if (pubkeysToPrefetech.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  ref.read(userProfileProvider.notifier)
                      .prefetchProfilesImmediately(pubkeysToPrefetech);
                });
              }
            }

            return RefreshIndicator(
              onRefresh: () => ref.read(homeRefreshControllerProvider).refresh(),
              child: PageView.builder(
                key: const Key('home-video-page-view'),
                itemCount: videos.length,
                controller: _controller,
                scrollDirection: Axis.vertical,
                onPageChanged: (newIndex) {
                  // Update tracked video ID
                  _currentVideoId = videos[newIndex].id;

                  // Guard: only navigate if URL doesn't match
                  if (newIndex != urlIndex) {
                    // Use event-based routing (always use event ID, not index)
                    context.go(buildRoute(
                      RouteContext(
                        type: RouteType.home,
                        eventId: videos[newIndex].id,
                      ),
                    ));
                  }

                  // Trigger pagination near end
                  if (newIndex >= itemCount - 2) {
                    ref.read(homePaginationControllerProvider).maybeLoadMore();
                  }

                  // Prefetch videos around current index
                  checkForPrefetch(currentIndex: newIndex, videos: videos);

                  Log.debug('📄 Page changed to index $newIndex (${videos[newIndex].id}...)',
                      name: 'HomeScreenRouter', category: LogCategory.video);
                },
                itemBuilder: (context, index) {
                  return VideoFeedItem(
                    key: ValueKey('video-${videos[index].id}'),
                    video: videos[index],
                    index: index,
                    hasBottomNavigation: true,
                    contextTitle: '', // Home feed has no context title
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
