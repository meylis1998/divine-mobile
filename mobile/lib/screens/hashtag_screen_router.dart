// ABOUTME: Router-driven HashtagScreen implementation
// ABOUTME: Pure presentation with no lifecycle mutations - URL is source of truth

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/hashtag_feed_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';

/// Router-driven HashtagScreen - PageView syncs with URL bidirectionally
class HashtagScreenRouter extends ConsumerStatefulWidget {
  const HashtagScreenRouter({super.key});

  @override
  ConsumerState<HashtagScreenRouter> createState() =>
      _HashtagScreenRouterState();
}

class _HashtagScreenRouterState extends ConsumerState<HashtagScreenRouter> {
  PageController? _controller;
  int? _lastUrlIndex;
  int? _lastPrefetchIndex;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Read derived context from router
    final pageContext = ref.watch(pageContextProvider);

    return pageContext.when(
      data: (ctx) {
        // Only handle hashtag routes
        if (ctx.type != RouteType.hashtag) {
          return const Center(child: Text('Not a hashtag route'));
        }

        final urlIndex = ctx.videoIndex ?? 0;

        // Get video data from hashtag feed
        final videosAsync = ref.watch(videosForHashtagRouteProvider);

        return videosAsync.when(
          data: (state) {
            final videos = state.videos;

            if (videos.isEmpty) {
              return const HashtagEmptyState();
            }

            final itemCount = videos.length;

            // Initialize controller once with URL index
            if (_controller == null) {
              final safeIndex = urlIndex.clamp(0, itemCount - 1);
              _controller = PageController(initialPage: safeIndex);
              _lastUrlIndex = safeIndex;
            }

            // Sync controller when URL changes externally (back/forward/deeplink)
            // Use post-frame to avoid calling jumpToPage during build
            if (urlIndex != _lastUrlIndex && _controller!.hasClients) {
              _lastUrlIndex = urlIndex;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted || !_controller!.hasClients) return;
                final safeIndex = urlIndex.clamp(0, itemCount - 1);
                final currentPage = _controller!.page?.round() ?? 0;
                if (currentPage != safeIndex) {
                  _controller!.jumpToPage(safeIndex);
                }
              });
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
                  ref
                      .read(userProfileProvider.notifier)
                      .prefetchProfilesImmediately(pubkeysToPrefetech);
                });
              }
            }

            return PageView.builder(
              controller: _controller,
              itemCount: itemCount,
              onPageChanged: (newIndex) {
                // Guard: only navigate if URL doesn't match
                if (newIndex != urlIndex) {
                  context.go(buildRoute(
                    RouteContext(
                      type: RouteType.hashtag,
                      hashtag: ctx.hashtag,
                      videoIndex: newIndex,
                    ),
                  ));
                }
              },
              itemBuilder: (context, index) {
                final video = videos[index];
                return HashtagVideoCell(
                  video: video,
                  index: index,
                  total: videos.length,
                );
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => Center(
            child: Text('Error: $error'),
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(child: Text('Error: $error')),
    );
  }
}

/// Minimal video cell for displaying hashtag video in tests
class HashtagVideoCell extends StatelessWidget {
  const HashtagVideoCell({
    required this.video,
    required this.index,
    required this.total,
    super.key,
  });

  final VideoEvent video;
  final int index;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Hashtag $index/$total',
            style: const TextStyle(fontSize: 24),
          ),
          const SizedBox(height: 16),
          Text('ID: ${video.id}'),
        ],
      ),
    );
  }
}

/// Empty state widget shown when hashtag has no videos
class HashtagEmptyState extends StatelessWidget {
  const HashtagEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.tag, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No videos found',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
