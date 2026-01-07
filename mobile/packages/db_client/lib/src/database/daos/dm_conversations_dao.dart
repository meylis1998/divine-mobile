// ABOUTME: Data Access Object for NIP-17 DM conversation operations.
// ABOUTME: Manages conversation metadata, unread counts, and mute status.

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart';

part 'dm_conversations_dao.g.dart';

/// DAO for managing DM conversation metadata.
///
/// This DAO handles storage and retrieval of conversation-level data for
/// NIP-17 private messages. Each conversation is identified by the composite
/// key of owner pubkey (current user) and peer pubkey (other party).
///
/// Supports multi-account scenarios where different users may have
/// separate conversation histories with the same peer.
@DriftAccessor(tables: [DmConversations])
class DmConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$DmConversationsDaoMixin {
  DmConversationsDao(super.attachedDatabase);

  /// Insert or update a conversation record.
  ///
  /// Called when a new message arrives or is sent to update the conversation
  /// metadata. The lastMessageAt and lastMessagePreview should reflect the
  /// most recent message.
  Future<void> upsertConversation({
    required String ownerPubkey,
    required String peerPubkey,
    required DateTime lastMessageAt,
    String? lastMessagePreview,
    int unreadCount = 0,
    bool isMuted = false,
  }) async {
    await into(dmConversations).insertOnConflictUpdate(
      DmConversationsCompanion.insert(
        ownerPubkey: ownerPubkey,
        peerPubkey: peerPubkey,
        lastMessageAt: lastMessageAt,
        lastMessagePreview: Value(lastMessagePreview),
        unreadCount: Value(unreadCount),
        isMuted: Value(isMuted),
      ),
    );
  }

  /// Get all conversations for an owner, sorted by most recent message.
  Future<List<DmConversationRow>> getAllConversations(
    String ownerPubkey,
  ) async {
    final query = select(dmConversations)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)]);

    return query.get();
  }

  /// Watch all conversations for an owner (reactive stream).
  ///
  /// Emits a new list whenever any conversation changes.
  Stream<List<DmConversationRow>> watchAllConversations(String ownerPubkey) {
    final query = select(dmConversations)
      ..where((t) => t.ownerPubkey.equals(ownerPubkey))
      ..orderBy([(t) => OrderingTerm.desc(t.lastMessageAt)]);

    return query.watch();
  }

  /// Get a specific conversation.
  Future<DmConversationRow?> getConversation({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    final query = select(dmConversations)
      ..where(
        (t) =>
            t.ownerPubkey.equals(ownerPubkey) & t.peerPubkey.equals(peerPubkey),
      );

    return query.getSingleOrNull();
  }

  /// Get total unread message count across all non-muted conversations.
  Future<int> getTotalUnreadCount(String ownerPubkey) async {
    final sumExpr = dmConversations.unreadCount.sum();
    final query = selectOnly(dmConversations)
      ..where(
        dmConversations.ownerPubkey.equals(ownerPubkey) &
            dmConversations.isMuted.equals(false),
      )
      ..addColumns([sumExpr]);

    final result = await query.getSingle();
    return result.read(sumExpr) ?? 0;
  }

  /// Watch total unread count (reactive stream).
  Stream<int> watchTotalUnreadCount(String ownerPubkey) {
    final sumExpr = dmConversations.unreadCount.sum();
    final query = selectOnly(dmConversations)
      ..where(
        dmConversations.ownerPubkey.equals(ownerPubkey) &
            dmConversations.isMuted.equals(false),
      )
      ..addColumns([sumExpr]);

    return query.watchSingle().map((row) => row.read(sumExpr) ?? 0);
  }

  /// Mark a conversation as read (set unread count to 0).
  Future<void> markConversationRead({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    await (update(dmConversations)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.peerPubkey.equals(peerPubkey),
        ))
        .write(const DmConversationsCompanion(unreadCount: Value(0)));
  }

  /// Increment unread count for a conversation.
  ///
  /// Called when a new incoming message arrives.
  Future<void> incrementUnreadCount({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    await customStatement(
      '''
      UPDATE dm_conversations
      SET unread_count = unread_count + 1
      WHERE owner_pubkey = ? AND peer_pubkey = ?
      ''',
      [ownerPubkey, peerPubkey],
    );
  }

  /// Set the muted status for a conversation.
  Future<void> setMuted({
    required String ownerPubkey,
    required String peerPubkey,
    required bool isMuted,
  }) async {
    await (update(dmConversations)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.peerPubkey.equals(peerPubkey),
        ))
        .write(DmConversationsCompanion(isMuted: Value(isMuted)));
  }

  /// Delete a specific conversation.
  Future<int> deleteConversation({
    required String ownerPubkey,
    required String peerPubkey,
  }) async {
    return (delete(dmConversations)..where(
          (t) =>
              t.ownerPubkey.equals(ownerPubkey) &
              t.peerPubkey.equals(peerPubkey),
        ))
        .go();
  }

  /// Delete all conversations for an owner.
  ///
  /// Used when logging out or clearing user data.
  Future<int> deleteAllForOwner(String ownerPubkey) async {
    return (delete(
      dmConversations,
    )..where((t) => t.ownerPubkey.equals(ownerPubkey))).go();
  }

  /// Delete all conversations (for testing or full reset).
  Future<int> deleteAll() async {
    return delete(dmConversations).go();
  }
}
