// ABOUTME: Screen for starting a new DM conversation with a user.
// ABOUTME: Shows followed contacts and allows searching for users by name.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/npub_hex.dart';

/// Screen for starting a new conversation by selecting or searching for a user.
///
/// Shows:
/// - Search field at top for filtering/searching
/// - List of followed users when no search query
/// - Search results when user types a query
class NewConversationScreen extends ConsumerStatefulWidget {
  /// Creates a new conversation screen.
  const NewConversationScreen({super.key});

  @override
  ConsumerState<NewConversationScreen> createState() =>
      _NewConversationScreenState();
}

class _NewConversationScreenState extends ConsumerState<NewConversationScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Search results with their relevance scores for sorting.
  final Map<String, _SearchResult> _searchResultsMap = {};
  bool _isSearching = false;
  bool _isSearchingRemote = false;
  String _currentQuery = '';
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Get sorted search results by relevance score (higher = better match).
  List<String> get _searchResults {
    final entries = _searchResultsMap.entries.toList()
      ..sort((a, b) => b.value.score.compareTo(a.value.score));
    return entries.map((e) => e.key).toList();
  }

  /// Calculate relevance score for a profile against a query.
  /// Higher score = better match. Returns 0 if no text match found.
  int _calculateRelevanceScore(
    UserProfile profile,
    String queryLower, {
    bool isFollowing = false,
  }) {
    var score = 0;

    // Check various fields for matches
    final displayName = profile.bestDisplayName.toLowerCase();
    final name = (profile.name ?? '').toLowerCase();
    final nip05 = (profile.nip05 ?? '').toLowerCase();

    // Exact match is highest priority (100 points)
    if (displayName == queryLower ||
        name == queryLower ||
        nip05.split('@').first == queryLower) {
      score += 100;
    }
    // Starts with query (50 points)
    else if (displayName.startsWith(queryLower) ||
        name.startsWith(queryLower) ||
        nip05.startsWith(queryLower)) {
      score += 50;
    }
    // Contains query (20 points)
    else if (displayName.contains(queryLower) ||
        name.contains(queryLower) ||
        nip05.contains(queryLower)) {
      score += 20;
    }

    // Only apply boosts if there's a text match (score > 0)
    // Otherwise non-matching results would appear just because they're followed
    if (score > 0) {
      // Boost for followed users (+30 points)
      if (isFollowing) {
        score += 30;
      }

      // Boost for having a profile picture (+5 points)
      if (profile.picture?.isNotEmpty == true) {
        score += 5;
      }

      // Boost for having a verified NIP-05 (+10 points)
      if (profile.nip05?.isNotEmpty == true) {
        score += 10;
      }
    }

    return score;
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();

    if (query == _currentQuery) return;

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        _performSearch(query);
      }
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _currentQuery = query;
      _isSearching = true;
      _searchResultsMap.clear();
    });

    if (query.isEmpty) {
      setState(() {
        _isSearching = false;
      });
      return;
    }

    // Check if query is a valid npub/nprofile/hex - if so, validate and select
    final hexPubkey = npubToHexOrNull(query);
    if (hexPubkey != null && hexPubkey.length == 64) {
      // Valid pubkey format - trigger profile fetch and add to results
      ref.read(userProfileServiceProvider).fetchProfile(hexPubkey);
      setState(() {
        _searchResultsMap[hexPubkey] = _SearchResult(score: 200);
        _isSearching = false;
      });
      return;
    }

    final queryLower = query.toLowerCase();
    final followRepository = ref.read(followRepositoryProvider);
    final userProfileService = ref.read(userProfileServiceProvider);
    final followingPubkeys = followRepository.followingPubkeys.toSet();

    // Search ALL cached profiles (not just followed users)
    // This includes profiles from videos, interactions, etc.
    for (final profile in userProfileService.allProfiles.values) {
      final score = _calculateRelevanceScore(
        profile,
        queryLower,
        isFollowing: followingPubkeys.contains(profile.pubkey),
      );
      if (score > 0) {
        _searchResultsMap[profile.pubkey] = _SearchResult(score: score);
      }
    }

    setState(() {
      _isSearching = false;
    });

    // Also search remote relays (with 10-second timeout)
    // This populates the cache with more profiles for future searches
    _searchRemote(query, followingPubkeys);
  }

  Future<void> _searchRemote(String query, Set<String> followingPubkeys) async {
    if (query.isEmpty || query.length < 2) return;

    setState(() => _isSearchingRemote = true);

    try {
      final userProfileService = ref.read(userProfileServiceProvider);
      final queryLower = query.toLowerCase();

      // Use the non-streaming search which has a 10-second timeout
      final results = await userProfileService.searchUsers(query, limit: 30);

      if (!mounted || _currentQuery != query) return;

      for (final profile in results) {
        // Skip if already in results (from local search)
        if (_searchResultsMap.containsKey(profile.pubkey)) continue;

        // Calculate relevance score
        final score = _calculateRelevanceScore(
          profile,
          queryLower,
          isFollowing: followingPubkeys.contains(profile.pubkey),
        );

        // Only add if there's some relevance (score > 0)
        if (score > 0) {
          _searchResultsMap[profile.pubkey] = _SearchResult(score: score);
        }
      }

      if (mounted) {
        setState(() => _isSearchingRemote = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSearchingRemote = false);
      }
    }
  }

  void _selectUser(String pubkey) {
    // Navigate to conversation screen, replacing this screen
    context.go('/messages/$pubkey');
  }

  Future<void> _handlePaste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null) {
      _searchController.text = data!.text!;
    }
  }

  @override
  Widget build(BuildContext context) {
    final followRepository = ref.watch(followRepositoryProvider);
    final followingPubkeys = followRepository.followingPubkeys;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          // Search field
          Container(
            color: VineTheme.cardBackground,
            padding: const EdgeInsets.all(16),
            child: TextField(
              key: const Key('new_conversation_input'),
              controller: _searchController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or paste npub...',
                hintStyle: TextStyle(color: Colors.grey[500]),
                filled: true,
                fillColor: Colors.grey[900],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: VineTheme.vineGreen),
                ),
                prefixIcon: _isSearching || _isSearchingRemote
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VineTheme.vineGreen,
                          ),
                        ),
                      )
                    : Icon(Icons.search, color: Colors.grey[500]),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: Icon(Icons.paste, color: Colors.grey[500]),
                      onPressed: _handlePaste,
                      tooltip: 'Paste from clipboard',
                    ),
                    if (_searchController.text.isNotEmpty)
                      IconButton(
                        icon: Icon(Icons.clear, color: Colors.grey[500]),
                        onPressed: () {
                          _searchController.clear();
                          _performSearch('');
                        },
                      ),
                  ],
                ),
              ),
              maxLines: 1,
              autocorrect: false,
              enableSuggestions: false,
            ),
          ),

          // Content
          Expanded(
            child: _currentQuery.isNotEmpty
                ? _buildSearchResults()
                : _buildFollowingList(followingPubkeys),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    if (_searchResultsMap.isEmpty && !_isSearching && !_isSearchingRemote) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No users found for "$_currentQuery"',
              style: TextStyle(fontSize: 16, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different name or paste an npub',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _searchResults.length + (_isSearchingRemote ? 1 : 0),
      itemBuilder: (context, index) {
        if (_isSearchingRemote && index == _searchResults.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: Text(
                'Searching more users...',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        final pubkey = _searchResults[index];
        return _UserListTile(pubkey: pubkey, onTap: () => _selectUser(pubkey));
      },
    );
  }

  Widget _buildFollowingList(List<String> followingPubkeys) {
    if (followingPubkeys.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[700]),
            const SizedBox(height: 16),
            Text(
              'No contacts yet',
              style: TextStyle(fontSize: 18, color: Colors.grey[400]),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow users to see them here,\nor search by name above',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Text(
            'People you follow',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            itemCount: followingPubkeys.length,
            itemBuilder: (context, index) {
              final pubkey = followingPubkeys[index];
              return _UserListTile(
                pubkey: pubkey,
                onTap: () => _selectUser(pubkey),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A list tile showing a user's avatar and display name.
class _UserListTile extends ConsumerWidget {
  const _UserListTile({required this.pubkey, required this.onTap});

  final String pubkey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(fetchUserProfileProvider(pubkey));

    return profileAsync.when(
      data: (profile) => _buildTile(context, profile),
      loading: () => _buildTile(context, null, isLoading: true),
      error: (_, __) => _buildTile(context, null),
    );
  }

  Widget _buildTile(
    BuildContext context,
    UserProfile? profile, {
    bool isLoading = false,
  }) {
    // Show display name if available, otherwise show npub (not hex)
    final displayName =
        profile?.bestDisplayName ??
        _formatNpubForDisplay(NostrKeyUtils.encodePubKey(pubkey));
    final imageUrl = profile?.picture;

    return ListTile(
      key: Key('user_tile_$pubkey'),
      leading: CircleAvatar(
        radius: 24,
        backgroundColor: VineTheme.cardBackground,
        backgroundImage: imageUrl != null && imageUrl.isNotEmpty
            ? NetworkImage(imageUrl)
            : null,
        child: imageUrl == null || imageUrl.isEmpty
            ? Icon(
                Icons.person,
                color: VineTheme.vineGreen.withValues(alpha: 0.7),
              )
            : null,
      ),
      title: isLoading
          ? Container(
              height: 16,
              width: 120,
              decoration: BoxDecoration(
                color: Colors.grey[800],
                borderRadius: BorderRadius.circular(4),
              ),
            )
          : Text(
              displayName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      subtitle: profile?.nip05 != null && profile!.nip05!.isNotEmpty
          ? Text(
              profile.nip05!,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            )
          : null,
      onTap: onTap,
    );
  }

  /// Format npub for display with ellipsis in middle.
  String _formatNpubForDisplay(String npub) {
    if (npub.length <= 20) return npub;
    // Show first 12 chars + ... + last 8 chars (e.g., npub1abc123...xyz789)
    return '${npub.substring(0, 12)}...${npub.substring(npub.length - 8)}';
  }
}

/// Holds a search result with its relevance score.
class _SearchResult {
  const _SearchResult({required this.score});

  /// Relevance score (higher = better match).
  final int score;
}
