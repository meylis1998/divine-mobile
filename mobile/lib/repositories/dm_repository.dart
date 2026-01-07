// ABOUTME: Repository for managing NIP-17 DM conversations and messages.
// ABOUTME: Bridges inbox service and database, provides reactive streams for UI.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/services/nip17_inbox_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Maximum length for message preview in conversations.
const int _maxPreviewLength = 100;

/// Callback type for message notification creation.
typedef MessageNotificationCallback =
    Future<void> Function({
      required String senderPubkey,
      required String messagePreview,
      required String messageId,
    });

/// Repository for managing DM conversations and messages.
///
/// This repository:
/// - Bridges the [NIP17InboxService] and database DAOs
/// - Provides reactive streams for UI consumption
/// - Manages conversation metadata (unread counts, previews)
/// - Handles read/unread state
class DMRepository {
  /// Creates a DMRepository.
  DMRepository({
    required DmConversationsDao conversationsDao,
    required DmMessagesDao messagesDao,
    required NostrKeyManager keyManager,
    required NIP17InboxService inboxService,
    MessageNotificationCallback? onMessageReceived,
  }) : _conversationsDao = conversationsDao,
       _messagesDao = messagesDao,
       _keyManager = keyManager,
       _inboxService = inboxService,
       _onMessageReceived = onMessageReceived;

  final DmConversationsDao _conversationsDao;
  final DmMessagesDao _messagesDao;
  final NostrKeyManager _keyManager;
  final NIP17InboxService _inboxService;
  final MessageNotificationCallback? _onMessageReceived;

  /// Subscription for incoming messages from inbox service.
  StreamSubscription<IncomingMessage>? _inboxSubscription;

  /// Set of rumor IDs we've already processed (for deduplication).
  final Set<String> _processedRumorIds = {};

  /// Get the current user's pubkey.
  ///
  /// Throws [StateError] if keys are not available.
  String get _ownerPubkey {
    if (!_keyManager.hasKeys || _keyManager.publicKey == null) {
      throw StateError('Cannot access DM repository without keys');
    }
    return _keyManager.publicKey!;
  }

  /// Watch all conversations for the current user.
  ///
  /// Returns a stream of [Conversation] objects sorted by most recent message.
  Stream<List<Conversation>> watchConversations() {
    return _conversationsDao
        .watchAllConversations(_ownerPubkey)
        .map((rows) => rows.map(Conversation.fromDrift).toList());
  }

  /// Watch messages for a specific conversation.
  ///
  /// Returns a stream of [DmMessage] objects sorted by creation time
  /// (most recent first).
  Stream<List<DmMessage>> watchMessages(String peerPubkey) {
    return _messagesDao
        .watchMessagesForConversation(
          ownerPubkey: _ownerPubkey,
          peerPubkey: peerPubkey,
        )
        .map((rows) => rows.map(DmMessage.fromDrift).toList());
  }

  /// Watch total unread message count across all non-muted conversations.
  Stream<int> watchUnreadCount() {
    return _conversationsDao.watchTotalUnreadCount(_ownerPubkey);
  }

  /// Mark a conversation as read.
  ///
  /// Sets unread count to 0 and marks all messages in the conversation as read.
  Future<void> markConversationRead(String peerPubkey) async {
    final ownerPubkey = _ownerPubkey;

    // Mark conversation as read
    await _conversationsDao.markConversationRead(
      ownerPubkey: ownerPubkey,
      peerPubkey: peerPubkey,
    );

    // Mark all messages in conversation as read
    await _messagesDao.markConversationMessagesAsRead(
      ownerPubkey: ownerPubkey,
      peerPubkey: peerPubkey,
    );

    Log.debug(
      'Marked conversation with $peerPubkey as read',
      category: LogCategory.system,
    );
  }

  /// Save an incoming message from the inbox service.
  ///
  /// This method:
  /// 1. Saves the message to the database
  /// 2. Updates or creates the conversation
  /// 3. Increments the unread count
  Future<void> saveIncomingMessage(IncomingMessage message) async {
    final ownerPubkey = _ownerPubkey;

    // Check for duplicates
    if (_processedRumorIds.contains(message.rumorId)) {
      Log.debug(
        'Skipping duplicate message: ${message.rumorId}',
        category: LogCategory.system,
      );
      return;
    }

    // Check if message already exists in database
    final existingMessage = await _messagesDao.hasMessage(
      rumorId: message.rumorId,
      ownerPubkey: ownerPubkey,
    );

    if (existingMessage) {
      Log.debug(
        'Message already exists in database: ${message.rumorId}',
        category: LogCategory.system,
      );
      _processedRumorIds.add(message.rumorId);
      return;
    }

    // Convert to domain model
    final dmMessage = DmMessage.fromIncoming(message);

    // Save message
    await _messagesDao.insertMessage(
      rumorId: dmMessage.rumorId,
      giftWrapId: dmMessage.giftWrapId,
      ownerPubkey: ownerPubkey,
      peerPubkey: dmMessage.peerPubkey,
      senderPubkey: dmMessage.senderPubkey,
      content: dmMessage.content,
      createdAt: dmMessage.createdAt,
      isOutgoing: false,
      messageType: dmMessage.typeString,
      metadata: dmMessage.metadata,
    );

    // Get current conversation state
    final existingConversation = await _conversationsDao.getConversation(
      ownerPubkey: ownerPubkey,
      peerPubkey: dmMessage.peerPubkey,
    );

    // Calculate new unread count
    final newUnreadCount = (existingConversation?.unreadCount ?? 0) + 1;

    // Update conversation
    await _conversationsDao.upsertConversation(
      ownerPubkey: ownerPubkey,
      peerPubkey: dmMessage.peerPubkey,
      lastMessageAt: dmMessage.createdAt,
      lastMessagePreview: _truncatePreview(dmMessage.content),
      unreadCount: newUnreadCount,
      isMuted: existingConversation?.isMuted ?? false,
    );

    // Track processed rumor ID
    _processedRumorIds.add(message.rumorId);

    Log.debug(
      'Saved incoming message from ${dmMessage.senderPubkey}',
      category: LogCategory.system,
    );

    // Create notification for the new message
    if (_onMessageReceived != null) {
      try {
        await _onMessageReceived(
          senderPubkey: dmMessage.senderPubkey,
          messagePreview: _truncatePreview(dmMessage.content),
          messageId: dmMessage.rumorId,
        );
      } catch (e) {
        Log.warning(
          'Failed to create message notification: $e',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save an outgoing message after it has been sent.
  ///
  /// This method:
  /// 1. Saves the message to the database with isOutgoing=true
  /// 2. Updates or creates the conversation (without incrementing unread)
  Future<void> saveOutgoingMessage({
    required String rumorId,
    required String giftWrapId,
    required String recipientPubkey,
    required String content,
    required DateTime createdAt,
    DmMessageType type = DmMessageType.text,
    String? metadata,
  }) async {
    final ownerPubkey = _ownerPubkey;

    // Convert message type to string
    final typeString = switch (type) {
      DmMessageType.text => 'text',
      DmMessageType.videoShare => 'videoShare',
    };

    // Save message
    await _messagesDao.insertMessage(
      rumorId: rumorId,
      giftWrapId: giftWrapId,
      ownerPubkey: ownerPubkey,
      peerPubkey: recipientPubkey,
      senderPubkey: ownerPubkey,
      content: content,
      createdAt: createdAt,
      isOutgoing: true,
      messageType: typeString,
      metadata: metadata,
    );

    // Get current conversation state
    final existingConversation = await _conversationsDao.getConversation(
      ownerPubkey: ownerPubkey,
      peerPubkey: recipientPubkey,
    );

    // Update conversation (keep existing unread count, don't increment for
    // outgoing)
    await _conversationsDao.upsertConversation(
      ownerPubkey: ownerPubkey,
      peerPubkey: recipientPubkey,
      lastMessageAt: createdAt,
      lastMessagePreview: _truncatePreview(content),
      unreadCount: existingConversation?.unreadCount ?? 0,
      isMuted: existingConversation?.isMuted ?? false,
    );

    Log.debug(
      'Saved outgoing message to $recipientPubkey',
      category: LogCategory.system,
    );
  }

  /// Start listening to the inbox service for incoming messages.
  ///
  /// Messages received from the inbox service are automatically saved
  /// to the database.
  Future<void> startSync() async {
    if (_inboxSubscription != null) {
      Log.debug(
        'DMRepository sync already running',
        category: LogCategory.system,
      );
      return;
    }

    Log.info('Starting DMRepository sync', category: LogCategory.system);

    _inboxSubscription = _inboxService.incomingMessages.listen(
      (message) async {
        try {
          await saveIncomingMessage(message);
        } catch (e, stackTrace) {
          Log.error(
            'Error saving incoming message: $e',
            category: LogCategory.system,
            error: e,
            stackTrace: stackTrace,
          );
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'Error in inbox subscription: $error',
          category: LogCategory.system,
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
  }

  /// Stop listening to the inbox service.
  void stopSync() {
    _inboxSubscription?.cancel();
    _inboxSubscription = null;

    Log.info('Stopped DMRepository sync', category: LogCategory.system);
  }

  /// Dispose the repository and release resources.
  void dispose() {
    stopSync();
    _processedRumorIds.clear();
  }

  /// Truncate message content for preview display.
  String _truncatePreview(String content) {
    if (content.length <= _maxPreviewLength) {
      return content;
    }
    return '${content.substring(0, _maxPreviewLength - 3)}...';
  }
}
