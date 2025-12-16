// ABOUTME: Riverpod provider for managing a user's following list with reactive updates
// ABOUTME: Handles both current user (from socialProvider) and other users (from Nostr relay)

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'following_list_notifier.g.dart';

/// Notifier for managing a user's following list
@riverpod
class FollowingListNotifier extends _$FollowingListNotifier {
  @override
  Future<List<String>> build(String pubkey) async {
    final authService = ref.read(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    if (isCurrentUser) {
      final socialState = ref.watch(socialProvider);
      return socialState.followingPubkeys;
    }

    // For other users, fetch from SocialService
    final socialService = ref.read(socialServiceProvider);
    return socialService
        .getFollowingListForUser(pubkey)
        .first
        .timeout(const Duration(seconds: 5));
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
  }
}
