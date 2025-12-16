// ABOUTME: Screen displaying list of users followed by the profile being viewed
// ABOUTME: Shows user profiles with follow/unfollow buttons and navigation to their profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/following_list_notifier.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingListProvider(pubkey));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: Colors.white,
        title: Text(
          '${displayName}\'s Following',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: followingAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: Colors.purple),
        ),
        error: (error, _) => _ErrorView(
          error: error.toString(),
          onRetry: () =>
              ref.read(followingListProvider(pubkey).notifier).refresh(),
        ),
        data: (following) => following.isEmpty
            ? const _EmptyView()
            : _FollowingList(
                following: following,
                onNavigateToProfile: (pubkey) => context.goProfile(pubkey, 0),
              ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final void Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 48),
          const SizedBox(height: 16),
          Text(
            error,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined, color: Colors.grey, size: 48),
          const SizedBox(height: 16),
          Text(
            'Not following anyone yet',
            style: const TextStyle(color: Colors.white, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FollowingList extends StatelessWidget {
  const _FollowingList({
    required this.following,
    required this.onNavigateToProfile,
  });

  final List<String> following;
  final void Function(String) onNavigateToProfile;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: following.length,
      itemBuilder: (context, index) {
        final followedPubkey = following[index];
        return UserProfileTile(
          pubkey: followedPubkey,
          onTap: () => onNavigateToProfile(followedPubkey),
        );
      },
    );
  }
}
