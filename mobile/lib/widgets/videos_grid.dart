import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';

class VideosGrid extends ConsumerWidget {
  const VideosGrid({
    super.key,
    required this.videos,
    required this.userIdHex,
    this.badgeIcon,
    required this.noVideoIcon,
    required this.noVideosTitle,
    required this.noVideosMessage,
    required this.logContext,
    this.onRefresh,
  });

  final List<VideoEvent> videos;
  final String userIdHex;
  final IconData? badgeIcon;
  final IconData noVideoIcon;
  final String noVideosTitle;
  final String noVideosMessage;
  final String logContext;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (videos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(noVideoIcon, color: Colors.grey, size: 64),
            const SizedBox(height: 16),
            Text(
              noVideosTitle,
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              noVideosMessage,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 32),
            if (onRefresh != null)
              IconButton(
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh,
                  color: VineTheme.vineGreen,
                  size: 28,
                ),
                tooltip: 'Refresh',
              ),
          ],
        ),
      );
    }

    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(2),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              if (index >= videos.length) {
                return DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.cardBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                      strokeWidth: 2,
                    ),
                  ),
                );
              }

              final videoEvent = videos[index];
              return GestureDetector(
                onTap: () {
                  final npub = NostrKeyUtils.encodePubKey(userIdHex);
                  Log.info(
                    '🎯 $logContext GRID TAP: gridIndex=$index, '
                    'npub=$npub, videoId=${videoEvent.id}',
                    category: LogCategory.video,
                  );
                  // Navigate to fullscreen video mode using GoRouter
                  context.goProfile(npub, index);
                  Log.info(
                    '✅ $logContext: Called goProfile($npub, $index)',
                    category: LogCategory.video,
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: VineTheme.cardBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child:
                              videoEvent.thumbnailUrl != null &&
                                  videoEvent.thumbnailUrl!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: videoEvent.thumbnailUrl!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => DecoratedBox(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                      gradient: LinearGradient(
                                        colors: [
                                          VineTheme.vineGreen.withValues(
                                            alpha: 0.3,
                                          ),
                                          Colors.blue.withValues(alpha: 0.3),
                                        ],
                                      ),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: VineTheme.whiteText,
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) =>
                                      DecoratedBox(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          gradient: LinearGradient(
                                            colors: [
                                              VineTheme.vineGreen.withValues(
                                                alpha: 0.3,
                                              ),
                                              Colors.blue.withValues(
                                                alpha: 0.3,
                                              ),
                                            ],
                                          ),
                                        ),
                                        child: const Center(
                                          child: Icon(
                                            Icons.play_circle_outline,
                                            color: VineTheme.whiteText,
                                            size: 24,
                                          ),
                                        ),
                                      ),
                                )
                              : DecoratedBox(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(4),
                                    gradient: LinearGradient(
                                      colors: [
                                        VineTheme.vineGreen.withValues(
                                          alpha: 0.3,
                                        ),
                                        Colors.blue.withValues(alpha: 0.3),
                                      ],
                                    ),
                                  ),
                                  child: const Center(
                                    child: Icon(
                                      Icons.play_circle_outline,
                                      color: VineTheme.whiteText,
                                      size: 24,
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const Center(
                        child: Icon(
                          Icons.play_circle_filled,
                          color: Colors.white70,
                          size: 32,
                        ),
                      ),
                      if (badgeIcon != null)
                        Positioned(
                          top: 4,
                          right: 4,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Icon(
                              badgeIcon,
                              color: VineTheme.vineGreen,
                              size: 16,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }, childCount: videos.length),
          ),
        ),
      ],
    );
  }
}
