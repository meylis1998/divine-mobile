// ABOUTME: Screen displaying a DM conversation thread with a single user.
// ABOUTME: Supports sending messages, viewing history, and marking as read.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/services/nip17_inbox_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Screen for displaying and interacting with a DM conversation.
///
/// Shows the message thread with a single user, allows sending new messages,
/// and marks the conversation as read when opened.
class ConversationScreen extends ConsumerStatefulWidget {
  /// Creates a conversation screen.
  const ConversationScreen({required this.peerPubkey, super.key});

  /// The pubkey of the conversation partner.
  final String peerPubkey;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    // Mark conversation as read when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Mark the conversation as read.
  Future<void> _markAsRead() async {
    try {
      await ref
          .read(dmRepositoryProvider)
          .markConversationRead(widget.peerPubkey);
    } catch (e, stackTrace) {
      Log.error(
        'Failed to mark conversation as read: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Send a message to the peer.
  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final messageService = ref.read(nip17MessageServiceProvider);
      final result = await messageService.sendPrivateMessage(
        recipientPubkey: widget.peerPubkey,
        content: content,
      );

      if (result.success && result.rumorEventId != null) {
        // Save outgoing message to repository
        await ref
            .read(dmRepositoryProvider)
            .saveOutgoingMessage(
              rumorId: result.rumorEventId!,
              giftWrapId: result.giftWrapEventId!,
              recipientPubkey: widget.peerPubkey,
              content: content,
              createdAt: DateTime.now(),
            );

        // Clear text field on success
        _messageController.clear();

        Log.info('Message sent successfully', category: LogCategory.system);
      } else {
        // Show error to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.error ?? 'Failed to send message'),
              backgroundColor: VineTheme.likeRed,
            ),
          );
        }
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to send message: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: VineTheme.likeRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(
      conversationMessagesProvider(widget.peerPubkey),
    );

    return Scaffold(
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              data: (messages) => _buildMessageList(messages),
              loading: () => const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
              error: (error, stack) => Center(
                child: Text(
                  'Failed to load messages',
                  style: TextStyle(color: Colors.grey[400]),
                ),
              ),
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  /// Build the scrollable message list.
  Widget _buildMessageList(List<DmMessage> messages) {
    if (messages.isEmpty) {
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
              'Start the conversation!',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    // Messages are sorted newest first from the provider,
    // but we want newest at bottom for chat UI
    final sortedMessages = messages.reversed.toList();

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: sortedMessages.length,
      itemBuilder: (context, index) {
        final message = sortedMessages[index];
        return _buildMessageBubble(message, index);
      },
    );
  }

  /// Build a single message bubble.
  Widget _buildMessageBubble(DmMessage message, int index) {
    final isOutgoing = message.isOutgoing;
    final alignment = isOutgoing
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isOutgoing
        ? VineTheme.vineGreen.withValues(alpha: 0.8)
        : VineTheme.cardBackground;
    const textColor = Colors.white;

    // Determine key for testing
    final key = isOutgoing
        ? Key('outgoing_message_$index')
        : Key('incoming_message_$index');

    // Build content based on message type
    final Widget contentWidget = message.type == DmMessageType.videoShare
        ? _buildVideoShareContent(message, textColor)
        : Text(
            message.content,
            style: const TextStyle(color: textColor, fontSize: 15),
          );

    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Container(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                contentWidget,
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(message.createdAt),
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build content for a video share message.
  Widget _buildVideoShareContent(DmMessage message, Color textColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Video indicator with icon
        InkWell(
          key: const Key('video_share_tap_target'),
          onTap: () => _handleVideoTap(message),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_circle_fill, color: Colors.white, size: 32),
                SizedBox(width: 8),
                Text(
                  'Shared Video',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(width: 4),
                Icon(Icons.chevron_right, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
        // Show caption if there's text content
        if (message.content.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            message.content,
            style: TextStyle(color: textColor, fontSize: 15),
          ),
        ],
      ],
    );
  }

  /// Handle tap on a video share to navigate to the video.
  void _handleVideoTap(DmMessage message) {
    Log.info(
      'Video share tapped: metadata=${message.metadata}',
      category: LogCategory.ui,
    );

    // Parse metadata to get video event ID
    if (message.metadata == null) {
      _showVideoError('No video information available');
      return;
    }

    String? videoEventId;
    try {
      final metadata = jsonDecode(message.metadata!) as Map<String, dynamic>;
      videoEventId = metadata['videoEventId'] as String?;
    } catch (e) {
      Log.warning(
        'Failed to parse video metadata: $e',
        category: LogCategory.ui,
      );
      _showVideoError('Invalid video information');
      return;
    }

    if (videoEventId == null) {
      _showVideoError('Video not found');
      return;
    }

    // Navigate to video detail screen (handles fetching from cache or relay)
    context.push('/video/$videoEventId');
  }

  /// Show an error message for video issues.
  void _showVideoError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VineTheme.likeRed,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Build the message input area.
  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: VineTheme.cardBackground,
        border: Border(top: BorderSide(color: Colors.grey[800]!)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey[500]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: Colors.grey[900],
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _messageController,
              builder: (context, value, child) {
                final hasText = value.text.trim().isNotEmpty;
                return IconButton(
                  icon: Icon(
                    Icons.send,
                    color: hasText ? VineTheme.vineGreen : Colors.grey[600],
                  ),
                  onPressed: hasText && !_isSending ? _sendMessage : null,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Format a timestamp for display.
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
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
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday $time';
    } else {
      return '${timestamp.day}/${timestamp.month} $time';
    }
  }
}
