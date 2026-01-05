// ABOUTME: Riverpod providers for NIP-17 DM state management.
// ABOUTME: Provides reactive streams for conversations, messages, and unread counts.

import 'package:db_client/db_client.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/services/nip17_inbox_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'dm_providers.g.dart';

/// Provider for NIP17InboxService instance.
///
/// Creates an inbox service for receiving and decrypting NIP-17 gift-wrapped DMs.
/// Requires [NostrKeyManager] and [NostrClient] dependencies.
@Riverpod(keepAlive: true)
NIP17InboxService nip17InboxService(Ref ref) {
  final keyManager = ref.watch(nostrKeyManagerProvider);
  final nostrClient = ref.watch(nostrServiceProvider);

  final service = NIP17InboxService(
    keyManager: keyManager,
    nostrClient: nostrClient,
  );

  ref.onDispose(() {
    service.dispose();
  });

  return service;
}

/// Provider for DMRepository instance.
///
/// Creates a repository that bridges the inbox service and database.
/// Starts syncing incoming messages automatically.
@Riverpod(keepAlive: true)
DMRepository dmRepository(Ref ref) {
  final db = ref.watch(databaseProvider);
  final keyManager = ref.watch(nostrKeyManagerProvider);
  final inboxService = ref.watch(nip17InboxServiceProvider);

  final repository = DMRepository(
    conversationsDao: db.dmConversationsDao,
    messagesDao: db.dmMessagesDao,
    keyManager: keyManager,
    inboxService: inboxService,
  );

  // Start syncing incoming messages
  repository.startSync();

  Log.info(
    'DMRepository created and sync started',
    category: LogCategory.system,
  );

  ref.onDispose(() {
    repository.dispose();
    Log.info('DMRepository disposed', category: LogCategory.system);
  });

  return repository;
}

/// Provider for total unread DM count across all conversations.
///
/// Used for displaying badge counts in the UI (e.g., DM tab badge).
/// Returns a stream that updates reactively when messages are read/received.
@riverpod
Stream<int> unreadDmCount(Ref ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchUnreadCount();
}

/// Provider for the list of all DM conversations.
///
/// Returns a stream of [Conversation] objects sorted by most recent message.
/// Used for the conversations list screen.
@riverpod
Stream<List<Conversation>> dmConversations(Ref ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchConversations();
}

/// Family provider for messages in a specific conversation.
///
/// Takes a [peerPubkey] parameter to identify the conversation partner.
/// Returns a stream of [DmMessage] objects sorted by creation time.
@riverpod
Stream<List<DmMessage>> conversationMessages(Ref ref, String peerPubkey) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchMessages(peerPubkey);
}
