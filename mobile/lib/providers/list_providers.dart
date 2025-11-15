// ABOUTME: Riverpod providers for user lists (kind 30000) and curated video lists (kind 30005)
// ABOUTME: Manages list state and provides reactive updates for the Lists tab

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'list_providers.g.dart';

/// Provider for all user lists (kind 30000 - people lists)
@riverpod
Future<List<UserList>> userLists(Ref ref) async {
  final service = await ref.watch(userListServiceProvider.future);
  return service.lists;
}

/// Provider for all curated video lists (kind 30005)
@riverpod
Future<List<CuratedList>> curatedLists(Ref ref) async {
  final service = await ref.watch(curatedListServiceProvider.future);
  return service.lists;
}

/// Combined provider for both types of lists
@riverpod
Future<({List<UserList> userLists, List<CuratedList> curatedLists})> allLists(
    Ref ref) async {
  final userLists = await ref.watch(userListsProvider.future);
  final curatedLists = await ref.watch(curatedListsProvider.future);

  return (userLists: userLists, curatedLists: curatedLists);
}

/// Provider for videos in a specific curated list
@riverpod
Future<List<String>> curatedListVideos(Ref ref, String listId) async {
  final service = await ref.watch(curatedListServiceProvider.future);
  final list = service.getListById(listId);

  if (list == null) {
    return [];
  }

  // Return video IDs in the order specified by the list's playOrder setting
  return service.getOrderedVideoIds(listId);
}

/// Provider for videos from all members of a user list
@riverpod
Stream<List<VideoEvent>> userListMemberVideos(Ref ref, List<String> pubkeys) {
  final videoEventService = ref.watch(videoEventServiceProvider);

  // Subscribe to videos from all pubkeys in the list
  return videoEventService.subscribeToMultipleAuthorsVideos(pubkeys);
}
