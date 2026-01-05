// ABOUTME: Data Access Object for NIP-17 DM message operations.
// ABOUTME: Manages decrypted message storage, retrieval, and read status.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'dm_messages_dao.g.dart';

/// DAO for managing DM messages.
///
/// This DAO handles storage and retrieval of decrypted NIP-17 private messages.
/// Messages are stored after decryption with the rumor event ID as the
/// primary identifier for deduplication and threading.
///
/// The composite primary key of (rumorId, ownerPubkey) ensures that:
/// 1. Duplicate messages (same rumor ID) are deduplicated
/// 2. Multi-account scenarios work correctly (same message may be received
///    by different accounts)
@DriftAccessor(tables: [DmMessages])
class DmMessagesDao extends DatabaseAccessor<AppDatabase>
    with _$DmMessagesDaoMixin {
  DmMessagesDao(super.attachedDatabase);

  /// Insert a new message, ignoring duplicates.
  ///
  /// Uses INSERT OR IGNORE to deduplicate based on (rumorId, ownerPubkey).
  /// This is called when processing incoming gift wrap events after decryption.
  Future<void> insertMessage({
    required String rumorId,
    required String giftWrapId,
    required String ownerPubkey,
    required String peerPubkey,
    required String senderPubkey,
    required String content,
    required DateTime createdAt,
    required bool isOutgoing,
    String messageType = 'text',
    String? metadata,
  }) async {
    await into(dmMessages).insert(
      DmMessagesCompanion.insert(
        rumorId: rumorId,
        giftWrapId: giftWrapId,
        ownerPubkey: ownerPubkey,
        peerPubkey: peerPubkey,
        senderPubkey: senderPubkey,
        content: content,
        createdAt: createdAt,
        isOutgoing: isOutgoing,
        messageType: Value(messageType),
        metadata: Value(metadata),
      ),
      mode: InsertMode.insertOrIgnore,
    );
  }

  /// Get messages for a specific conversation, sorted by time descending.
  ///
  /// Returns most recent messages first for typical chat UI display.
  Future<List<DmMessageRow>> getMessagesForConversation({
    required String ownerPubkey,
    required String peerPubkey,
    int? limit,
    int? offset,
  }) async {
    var query = select(dmMessages)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) & t.peerPubkey.equals(peerPubkey),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    if (limit != null) {
      query = query..limit(limit, offset: offset);
    }

    return query.get();
  }

  /// Watch messages for a conversation (reactive stream).
  ///
  /// Emits a new list whenever messages change. Returns most recent first.
  Stream<List<DmMessageRow>> watchMessagesForConversation({
    required String ownerPubkey,
    required String peerPubkey,
    int? limit,
  }) {
    var query = select(dmMessages)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) & t.peerPubkey.equals(peerPubkey),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    return query.watch();
  }

  /// Get a specific message by rumor ID.
  Future<DmMessageRow?> getMessage({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    final query = select(dmMessages)
      ..where(
        (t) => t.rumorId.equals(rumorId) & t.ownerPubkey.equals(ownerPubkey),
      );

    return query.getSingleOrNull();
  }

  /// Check if a message exists (for deduplication before processing).
  Future<bool> hasMessage({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    final query = select(dmMessages)
      ..where(
        (t) => t.rumorId.equals(rumorId) & t.ownerPubkey.equals(ownerPubkey),
      );

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Check if a gift wrap event has already been processed.
  Future<bool> hasGiftWrap(String giftWrapId) async {
    final query = select(dmMessages)
      ..where((t) => t.giftWrapId.equals(giftWrapId));

    final result = await query.getSingleOrNull();
    return result != null;
  }

  /// Mark a single message as read.
  Future<void> markAsRead({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    await (update(dmMessages)..where(
          (t) => t.rumorId.equals(rumorId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .write(const DmMessagesCompanion(isRead: Value(true)));
  }

  /// Mark all messages in a conversation as read.
  Future<int> markConversationMessagesAsRead({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    return (update(dmMessages)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.peerPubkey.equals(peerPubkey) &
              t.isRead.equals(false),
        ))
        .write(const DmMessagesCompanion(isRead: Value(true)));
  }

  /// Get unread message count for a specific conversation.
  ///
  /// Only counts incoming messages (outgoing messages are always "read").
  Future<int> getUnreadCountForConversation({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    final countExpr = dmMessages.rumorId.count();
    final query = selectOnly(dmMessages)
      ..where(
        dmMessages.ownerPubkey.equals(ownerPubkey) &
            dmMessages.peerPubkey.equals(peerPubkey) &
            dmMessages.isRead.equals(false) &
            dmMessages.isOutgoing.equals(false),
      )
      ..addColumns([countExpr]);

    final result = await query.getSingle();
    return result.read(countExpr) ?? 0;
  }

  /// Delete a specific message.
  Future<int> deleteMessage({
    required String rumorId,
    required String ownerPubkey,
  }) async {
    return (delete(dmMessages)..where(
          (t) => t.rumorId.equals(rumorId) & t.ownerPubkey.equals(ownerPubkey),
        ))
        .go();
  }

  /// Delete all messages for a specific conversation.
  Future<int> deleteMessagesForConversation({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    return (delete(dmMessages)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.peerPubkey.equals(peerPubkey),
        ))
        .go();
  }

  /// Delete all messages for an owner.
  ///
  /// Used when logging out or clearing user data.
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    return (delete(
      dmMessages,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Delete all messages (for testing or full reset).
  Future<int> deleteAll() async {
    return delete(dmMessages).go();
  }

  /// Get the most recent message for a conversation.
  ///
  /// Useful for updating conversation preview without fetching all messages.
  Future<DmMessageRow?> getMostRecentMessage({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    final query = select(dmMessages)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) & t.peerPubkey.equals(peerPubkey),
      )
      ..orderBy([(t) => OrderingTerm.desc(t.createdAt)])
      ..limit(1);

    return query.getSingleOrNull();
  }

  /// Batch insert multiple messages in a single transaction.
  ///
  /// Used during initial sync to efficiently store messages.
  /// Uses INSERT OR IGNORE to handle duplicates.
  Future<void> insertMessagesBatch(List<DmMessageRow> messages) async {
    if (messages.isEmpty) return;

    await batch((batch) {
      for (final msg in messages) {
        batch.insert(
          dmMessages,
          DmMessagesCompanion.insert(
            rumorId: msg.rumorId,
            giftWrapId: msg.giftWrapId,
            ownerPubkey: msg.ownerPubkey,
            peerPubkey: msg.peerPubkey,
            senderPubkey: msg.senderPubkey,
            content: msg.content,
            createdAt: msg.createdAt,
            isOutgoing: msg.isOutgoing,
            isRead: Value(msg.isRead),
            messageType: Value(msg.messageType),
            metadata: Value(msg.metadata),
          ),
          mode: InsertMode.insertOrIgnore,
        );
      }
    });
  }
}
