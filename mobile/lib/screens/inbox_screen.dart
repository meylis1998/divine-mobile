// ABOUTME: Screen displaying a list of DM conversations for the inbox.
// ABOUTME: Shows conversation previews with avatar, name, timestamp, and unread count.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Screen displaying a list of DM conversations.
///
/// Shows all conversations sorted by most recent message, with:
/// - Avatar (from user profile or placeholder)
/// - Display name (from user profile or truncated pubkey)
/// - Message preview
/// - Timestamp
/// - Unread badge when applicable
class InboxScreen extends ConsumerStatefulWidget {
  /// Creates an inbox screen.
  const InboxScreen({super.key});

  @override
  ConsumerState<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends ConsumerState<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(dmConversationsProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      body: conversationsAsync.when(
        data: (conversations) => _buildConversationList(conversations),
        loading: () => const Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.grey[700]),
              const SizedBox(height: 16),
              Text(
                'Failed to load conversations',
                style: TextStyle(fontSize: 18, color: Colors.grey[400]),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: const Key('new_message_fab'),
        onPressed: _navigateToNewConversation,
        backgroundColor: VineTheme.vineGreen,
        child: const Icon(Icons.edit, color: Colors.white),
      ),
    );
  }

  /// Build the list of conversations with pull-to-refresh.
  Widget _buildConversationList(List<Conversation> conversations) {
    if (conversations.isEmpty) {
      return _buildEmptyState();
    }

    // Sort conversations by lastMessageAt (newest first)
    final sortedConversations = List<Conversation>.from(conversations)
      ..sort((a, b) => b.lastMessageAt.compareTo(a.lastMessageAt));

    return RefreshIndicator(
      color: VineTheme.vineGreen,
      onRefresh: _handleRefresh,
      child: ListView.builder(
        itemCount: sortedConversations.length,
        itemBuilder: (context, index) {
          final conversation = sortedConversations[index];
          return _ConversationListItem(
            conversation: conversation,
            onTap: () => _navigateToConversation(conversation.peerPubkey),
          );
        },
      ),
    );
  }

  /// Build empty state when no conversations exist.
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey[700]),
          const SizedBox(height: 16),
          Text(
            'No messages yet',
            style: TextStyle(fontSize: 18, color: Colors.grey[400]),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to start\na new conversation',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// Handle pull-to-refresh by invalidating the provider.
  Future<void> _handleRefresh() async {
    // Invalidate the provider to force a refresh
    ref.invalidate(dmConversationsProvider);
    // Wait a moment for the new data to arrive
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }

  /// Navigate to the conversation screen for a specific peer.
  void _navigateToConversation(String peerPubkey) {
    context.go('/messages/$peerPubkey');
  }

  /// Navigate to the new conversation screen.
  void _navigateToNewConversation() {
    context.go('/messages/new');
  }
}

/// A single conversation list item widget.
class _ConversationListItem extends ConsumerWidget {
  const _ConversationListItem({
    required this.conversation,
    required this.onTap,
  });

  final Conversation conversation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fetch user profile for avatar and display name
    final profileAsync = ref.watch(
      fetchUserProfileProvider(conversation.peerPubkey),
    );

    // Build semantic label for accessibility
    // Use display name or generic fallback (never truncate Nostr IDs)
    final displayName = profileAsync.value?.bestDisplayName ?? 'this user';
    final unreadLabel = conversation.hasUnread
        ? ', ${conversation.unreadCount} unread message${conversation.unreadCount > 1 ? 's' : ''}'
        : '';
    final previewLabel = conversation.lastMessagePreview ?? '';

    return Semantics(
      label: 'Conversation with $displayName$unreadLabel. $previewLabel',
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            border: Border(
              bottom: BorderSide(color: Colors.grey[800]!, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Avatar
              _buildAvatar(profileAsync),
              const SizedBox(width: 12),
              // Content (name, preview, timestamp)
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name and timestamp row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: _buildDisplayName(profileAsync)),
                        const SizedBox(width: 8),
                        Text(
                          _formatTimestamp(conversation.lastMessageAt),
                          style: TextStyle(
                            fontSize: 12,
                            color: conversation.hasUnread
                                ? VineTheme.vineGreen
                                : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    // Message preview and unread badge row
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            conversation.lastMessagePreview ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14,
                              color: conversation.hasUnread
                                  ? Colors.white
                                  : Colors.grey[400],
                              fontWeight: conversation.hasUnread
                                  ? FontWeight.w500
                                  : FontWeight.normal,
                            ),
                          ),
                        ),
                        if (conversation.hasUnread) ...[
                          const SizedBox(width: 8),
                          _buildUnreadBadge(),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build the avatar widget from profile data or placeholder.
  Widget _buildAvatar(AsyncValue<UserProfile?> profileAsync) {
    return profileAsync.when(
      data: (profile) {
        final imageUrl = profile?.picture;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          return CircleAvatar(
            radius: 24,
            backgroundImage: NetworkImage(imageUrl),
            backgroundColor: VineTheme.cardBackground,
          );
        }
        return _buildPlaceholderAvatar();
      },
      loading: () => _buildPlaceholderAvatar(),
      error: (_, __) => _buildPlaceholderAvatar(),
    );
  }

  /// Build a placeholder avatar when no profile image is available.
  Widget _buildPlaceholderAvatar() {
    // Generate a color based on the pubkey for visual distinction
    final colorIndex = conversation.peerPubkey.hashCode % 5;
    final colors = [
      VineTheme.vineGreen,
      VineTheme.commentBlue,
      Colors.purple,
      Colors.orange,
      Colors.teal,
    ];

    return CircleAvatar(
      radius: 24,
      backgroundColor: colors[colorIndex].withValues(alpha: 0.3),
      child: Icon(Icons.person, color: colors[colorIndex], size: 24),
    );
  }

  /// Build the display name widget from profile data or pubkey.
  Widget _buildDisplayName(AsyncValue<UserProfile?> profileAsync) {
    return profileAsync.when(
      data: (profile) {
        final displayName = profile?.bestDisplayName;
        if (displayName != null && displayName.isNotEmpty) {
          return Text(
            displayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: conversation.hasUnread
                  ? FontWeight.bold
                  : FontWeight.w500,
              color: Colors.white,
            ),
          );
        }
        return _buildPubkeyDisplay();
      },
      loading: () => _buildPubkeyDisplay(),
      error: (_, __) => _buildPubkeyDisplay(),
    );
  }

  /// Build a display widget for the pubkey with UI ellipsis.
  Widget _buildPubkeyDisplay() {
    // Display pubkey with overflow handling (UI truncation, not string truncation)
    return Text(
      conversation.peerPubkey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 16,
        fontWeight: conversation.hasUnread ? FontWeight.bold : FontWeight.w500,
        color: Colors.white,
      ),
    );
  }

  /// Build the unread count badge.
  Widget _buildUnreadBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: VineTheme.vineGreen,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '${conversation.unreadCount}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Format a timestamp for display.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );

    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    final time = '$hour:$minute';

    if (messageDate == today) {
      return time;
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
