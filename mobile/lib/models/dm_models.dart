// ABOUTME: Domain models for NIP-17 DM conversations and messages.
// ABOUTME: Represents decrypted DM data for UI display and business logic.

import 'package:db_client/db_client.dart';
import 'package:openvine/services/nip17_inbox_service.dart';

/// Represents a DM conversation with another user.
///
/// This is a domain model that abstracts the database representation
/// and provides a clean interface for the UI layer.
class Conversation {
  /// Creates a conversation.
  const Conversation({
    required this.peerPubkey,
    required this.lastMessageAt,
    required this.unreadCount,
    this.lastMessagePreview,
    this.isMuted = false,
  });

  /// Create a Conversation from a database row.
  factory Conversation.fromDrift(DmConversationRow row) {
    return Conversation(
      peerPubkey: row.peerPubkey,
      lastMessageAt: row.lastMessageAt,
      unreadCount: row.unreadCount,
      lastMessagePreview: row.lastMessagePreview,
      isMuted: row.isMuted,
    );
  }

  /// The pubkey of the conversation partner.
  final String peerPubkey;

  /// Timestamp of the most recent message.
  final DateTime lastMessageAt;

  /// Number of unread messages in this conversation.
  final int unreadCount;

  /// Preview text of the most recent message.
  final String? lastMessagePreview;

  /// Whether notifications are muted for this conversation.
  final bool isMuted;

  /// Whether this conversation has unread messages.
  bool get hasUnread => unreadCount > 0;

  /// Create a copy with updated fields.
  Conversation copyWith({
    String? peerPubkey,
    DateTime? lastMessageAt,
    int? unreadCount,
    String? lastMessagePreview,
    bool? isMuted,
  }) {
    return Conversation(
      peerPubkey: peerPubkey ?? this.peerPubkey,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      isMuted: isMuted ?? this.isMuted,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Conversation &&
        other.peerPubkey == peerPubkey &&
        other.lastMessageAt == lastMessageAt &&
        other.unreadCount == unreadCount &&
        other.lastMessagePreview == lastMessagePreview &&
        other.isMuted == isMuted;
  }

  @override
  int get hashCode {
    return Object.hash(
      peerPubkey,
      lastMessageAt,
      unreadCount,
      lastMessagePreview,
      isMuted,
    );
  }

  @override
  String toString() {
    return 'Conversation(peer: $peerPubkey, unread: $unreadCount, '
        'lastMessage: $lastMessageAt)';
  }
}

/// Represents a single DM message.
///
/// This is a domain model that abstracts the database representation
/// and provides a clean interface for the UI layer.
class DmMessage {
  /// Creates a DM message.
  const DmMessage({
    required this.rumorId,
    required this.giftWrapId,
    required this.peerPubkey,
    required this.senderPubkey,
    required this.content,
    required this.createdAt,
    required this.isOutgoing,
    this.isRead = false,
    this.type = DmMessageType.text,
    this.metadata,
  });

  /// Create a DmMessage from a database row.
  factory DmMessage.fromDrift(DmMessageRow row) {
    return DmMessage(
      rumorId: row.rumorId,
      giftWrapId: row.giftWrapId,
      peerPubkey: row.peerPubkey,
      senderPubkey: row.senderPubkey,
      content: row.content,
      createdAt: row.createdAt,
      isRead: row.isRead,
      type: _parseMessageType(row.messageType),
      metadata: row.metadata,
      isOutgoing: row.isOutgoing,
    );
  }

  /// Create a DmMessage from an IncomingMessage.
  factory DmMessage.fromIncoming(IncomingMessage incoming) {
    return DmMessage(
      rumorId: incoming.rumorId,
      giftWrapId: incoming.giftWrapId,
      peerPubkey: incoming.senderPubkey,
      senderPubkey: incoming.senderPubkey,
      content: incoming.content,
      createdAt: incoming.createdAt,
      isRead: false,
      type: incoming.type,
      metadata: _buildMetadata(incoming),
      isOutgoing: false,
    );
  }

  /// Rumor event ID (inner event, used for deduplication).
  final String rumorId;

  /// Gift wrap event ID (outer event).
  final String giftWrapId;

  /// Pubkey of the conversation partner.
  final String peerPubkey;

  /// Pubkey of the message sender.
  final String senderPubkey;

  /// Decrypted message content.
  final String content;

  /// Message creation timestamp.
  final DateTime createdAt;

  /// Whether the message has been read.
  final bool isRead;

  /// Type of message (text or video share).
  final DmMessageType type;

  /// JSON metadata for rich content (video refs, etc.).
  final String? metadata;

  /// Whether this is an outgoing message from the current user.
  final bool isOutgoing;

  /// Parse message type from string.
  static DmMessageType _parseMessageType(String typeStr) {
    switch (typeStr) {
      case 'videoShare':
        return DmMessageType.videoShare;
      case 'text':
      default:
        return DmMessageType.text;
    }
  }

  /// Build metadata JSON string from incoming message.
  static String? _buildMetadata(IncomingMessage incoming) {
    if (incoming.videoATag == null && incoming.videoEventId == null) {
      return null;
    }

    final parts = <String>[];
    if (incoming.videoATag != null) {
      parts.add('"videoATag":"${incoming.videoATag}"');
    }
    if (incoming.videoEventId != null) {
      parts.add('"videoEventId":"${incoming.videoEventId}"');
    }
    return '{${parts.join(',')}}';
  }

  /// Convert message type to string for database storage.
  String get typeString {
    switch (type) {
      case DmMessageType.text:
        return 'text';
      case DmMessageType.videoShare:
        return 'videoShare';
    }
  }

  /// Create a copy with updated fields.
  DmMessage copyWith({
    String? rumorId,
    String? giftWrapId,
    String? peerPubkey,
    String? senderPubkey,
    String? content,
    DateTime? createdAt,
    bool? isRead,
    DmMessageType? type,
    String? metadata,
    bool? isOutgoing,
  }) {
    return DmMessage(
      rumorId: rumorId ?? this.rumorId,
      giftWrapId: giftWrapId ?? this.giftWrapId,
      peerPubkey: peerPubkey ?? this.peerPubkey,
      senderPubkey: senderPubkey ?? this.senderPubkey,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      type: type ?? this.type,
      metadata: metadata ?? this.metadata,
      isOutgoing: isOutgoing ?? this.isOutgoing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DmMessage &&
        other.rumorId == rumorId &&
        other.giftWrapId == giftWrapId;
  }

  @override
  int get hashCode => Object.hash(rumorId, giftWrapId);

  @override
  String toString() {
    return 'DmMessage(rumorId: $rumorId, sender: $senderPubkey, '
        'type: $type, outgoing: $isOutgoing)';
  }
}
