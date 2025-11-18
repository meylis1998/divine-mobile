// ABOUTME: Screen displaying list of users who follow the profile being viewed
// ABOUTME: Shows user profiles with follow/unfollow buttons and navigation to their profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;
import 'package:openvine/mixins/nostr_list_fetch_mixin.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/utils/unified_logger.dart';

class FollowersScreen extends ConsumerStatefulWidget {
  const FollowersScreen(
      {super.key, required this.pubkey, required this.displayName});

  final String pubkey;
  final String displayName;

  @override
  ConsumerState<FollowersScreen> createState() => _FollowersScreenState();
}

class _FollowersScreenState extends ConsumerState<FollowersScreen>
    with NostrListFetchMixin {
  // Mixin state variables
  List<String> _followers = [];
  bool _isLoading = true;
  String? _error;

  @override
  List<String> get userList => _followers;

  @override
  set userList(List<String> value) => _followers = value;

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String? get error => _error;

  @override
  set error(String? value) => _error = value;

  @override
  void initState() {
    super.initState();
    loadList();
  }

  @override
  Future<void> fetchList() async {
    final nostrService = ref.read(nostrServiceProvider);

    // Check if we have any connected relays before subscribing
    if (nostrService.connectedRelayCount == 0) {
      Log.warning('No relays connected when fetching followers',
          name: 'FollowersScreen', category: LogCategory.relay);
      setError('Not connected to any relays. Please check your connection and try again.');
      return;
    }

    // Track if we've received any events to distinguish "no followers" from "connection issue"
    bool hasReceivedEvents = false;

    // Subscribe to kind 3 events that mention this pubkey in p tags
    final subscription = nostrService.subscribeToEvents(
      filters: [
        nostr_sdk.Filter(
          kinds: [3], // Contact lists
          p: [widget.pubkey], // Events that mention this pubkey
        ),
      ],
      onEose: () {
        // EOSE fired - subscription is complete
        if (mounted) {
          completeLoading();
        }
      },
    );

    // Process events immediately as they arrive for real-time updates
    subscription.listen(
      (event) {
        hasReceivedEvents = true;

        // Each author who has this pubkey in their contact list is a follower
        if (!_followers.contains(event.pubkey)) {
          if (mounted) {
            setState(() {
              _followers.add(event.pubkey);
              completeLoading(); // Stop loading as soon as we have first follower
            });
          }
        }
      },
      onError: (error) {
        Log.error('Error in followers subscription: $error',
            name: 'FollowersScreen', category: LogCategory.relay);
        // Only show connection error if we haven't received any events yet
        if (!hasReceivedEvents && mounted) {
          setError('Error loading followers. Please try again.');
        }
      },
      onDone: () {
        // Stream completed naturally
        if (mounted) {
          completeLoading();
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: buildAppBar(context, '${widget.displayName}\'s Followers'),
      body: buildListBody(
        context,
        _followers,
        _navigateToProfile,
        emptyMessage: 'No followers yet',
        emptyIcon: Icons.people_outline,
      ),
    );
  }

  void _navigateToProfile(String pubkey) {
    context.goProfile(pubkey, 0);
  }
}
