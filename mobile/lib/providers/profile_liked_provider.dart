// lib/providers/local_liked_videos_provider.dart
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:nostr_sdk/filter.dart' as nostr;

part 'profile_liked_provider.g.dart';

@riverpod
Future<List<VideoEvent>> profileLikedVideos(Ref ref, String userIdHex) async {
  final social = ref.read(socialServiceProvider);
  final nostrService = ref.read(nostrServiceProvider);

  // Only resolve cached IDs for the current user
  final currentUserHex = ref.read(authServiceProvider).currentPublicKeyHex;
  if (currentUserHex == null || currentUserHex != userIdHex) return [];

  final ids = social.likedEventIds;
  if (ids.isEmpty) return [];

  final videos = <VideoEvent>[];

  try {
    final events = await nostrService.getEvents(
      filters: [nostr.Filter(ids: ids.toList())],
    );
    for (final ev in events) {
      try {
        final v = VideoEvent.fromNostrEvent(ev);
        if (v.isSupportedOnCurrentPlatform) videos.add(v);
      } catch (_) {
        /* ignore */
      }
    }
  } catch (e) {}
  videos.sort(VideoEvent.compareByLoopsThenTime);
  return videos;
}
