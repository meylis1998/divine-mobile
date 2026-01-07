// ABOUTME: Tests for DM providers - verifies Riverpod providers for NIP-17 DM state.
// ABOUTME: Tests stream emissions from conversation, message, and unread count providers.

import 'dart:async';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: implementation_imports
import 'package:riverpod/src/framework.dart' show ProviderListenable;
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/services/nip17_inbox_service.dart';
import 'package:path/path.dart' as p;

@GenerateMocks([NostrClient, NostrKeyManager, NIP17InboxService])
import 'dm_providers_test.mocks.dart';

/// Helper to wait for async value to have data.
Future<T> waitForAsyncData<T>(
  ProviderContainer container,
  dynamic provider, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final completer = Completer<T>();

  final subscription = container.listen(
    provider as ProviderListenable<AsyncValue<T>>,
    (prev, next) {
      if (next is AsyncData<T> && !completer.isCompleted) {
        completer.complete(next.value);
      } else if (next is AsyncError<T> && !completer.isCompleted) {
        completer.completeError(next.error, next.stackTrace);
      }
    },
    fireImmediately: true,
  );

  try {
    return await completer.future.timeout(timeout);
  } finally {
    subscription.close();
  }
}

void main() {
  group('DM Providers', () {
    late ProviderContainer container;
    late AppDatabase testDb;
    late String testDbPath;
    late MockNostrClient mockNostrClient;
    late MockNostrKeyManager mockKeyManager;
    late MockNIP17InboxService mockInboxService;

    setUp(() async {
      // Create test database
      testDbPath = p.join(
        Directory.systemTemp.path,
        'dm_providers_test_${DateTime.now().millisecondsSinceEpoch}.db',
      );
      testDb = AppDatabase.test(NativeDatabase(File(testDbPath)));

      // Create mocks
      mockNostrClient = MockNostrClient();
      mockKeyManager = MockNostrKeyManager();
      mockInboxService = MockNIP17InboxService();

      // Configure mock key manager
      when(mockKeyManager.hasKeys).thenReturn(true);
      when(mockKeyManager.publicKey).thenReturn(
        'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab',
      );
      when(mockKeyManager.privateKey).thenReturn(
        'test_privkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890a',
      );

      // Configure mock inbox service
      when(
        mockInboxService.incomingMessages,
      ).thenAnswer((_) => const Stream<IncomingMessage>.empty());
      when(mockInboxService.isListening).thenReturn(false);

      // Create container with overrides
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(testDb),
          nostrKeyManagerProvider.overrideWithValue(mockKeyManager),
          nostrServiceProvider.overrideWithValue(mockNostrClient),
          nip17InboxServiceProvider.overrideWithValue(mockInboxService),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await testDb.close();

      final file = File(testDbPath);
      if (await file.exists()) {
        await file.delete();
      }
    });

    group('dmRepositoryProvider', () {
      test('creates DMRepository instance', () {
        final repo = container.read(dmRepositoryProvider);

        expect(repo, isA<DMRepository>());
      });

      test('returns same instance on multiple reads (keepAlive)', () {
        final repo1 = container.read(dmRepositoryProvider);
        final repo2 = container.read(dmRepositoryProvider);

        expect(identical(repo1, repo2), isTrue);
      });
    });

    group('unreadDmCountProvider', () {
      test('emits stream of unread counts', () async {
        // Insert test conversation with unread messages
        final ownerPubkey =
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
        final peerPubkey =
            'peer_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890a';

        await testDb.dmConversationsDao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey,
          lastMessageAt: DateTime.now(),
          lastMessagePreview: 'Test message',
          unreadCount: 5,
          isMuted: false,
        );

        // Wait for stream provider to emit data
        final count = await waitForAsyncData<int>(
          container,
          unreadDmCountProvider,
        );
        expect(count, equals(5));
      });

      test('emits 0 for no conversations', () async {
        final count = await waitForAsyncData<int>(
          container,
          unreadDmCountProvider,
        );
        expect(count, equals(0));
      });
    });

    group('dmConversationsProvider', () {
      test('emits stream of conversations', () async {
        // Insert test conversation
        final ownerPubkey =
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
        final peerPubkey =
            'peer_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890a';

        await testDb.dmConversationsDao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey,
          lastMessageAt: DateTime.now(),
          lastMessagePreview: 'Hello!',
          unreadCount: 2,
          isMuted: false,
        );

        // Wait for stream provider to emit data
        final conversations = await waitForAsyncData<List<Conversation>>(
          container,
          dmConversationsProvider,
        );
        expect(conversations, hasLength(1));
        expect(conversations.first.peerPubkey, equals(peerPubkey));
        expect(conversations.first.unreadCount, equals(2));
        expect(conversations.first.lastMessagePreview, equals('Hello!'));
      });

      test('emits empty list for no conversations', () async {
        final conversations = await waitForAsyncData<List<Conversation>>(
          container,
          dmConversationsProvider,
        );
        expect(conversations, isEmpty);
      });
    });

    group('conversationMessagesProvider', () {
      test('emits stream of messages for a specific peer', () async {
        // Insert test message
        final ownerPubkey =
            'test_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab';
        final peerPubkey =
            'peer_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef1234567890a';

        await testDb.dmMessagesDao.insertMessage(
          rumorId:
              'rumor_123456789012345678901234567890123456789012345678901234567890',
          giftWrapId:
              'giftwrap_12345678901234567890123456789012345678901234567890123456789',
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey,
          senderPubkey: peerPubkey,
          content: 'Test message content',
          createdAt: DateTime.now(),
          isOutgoing: false,
          messageType: 'text',
          metadata: null,
        );

        // Wait for family provider to emit data
        final messages = await waitForAsyncData<List<DmMessage>>(
          container,
          conversationMessagesProvider(peerPubkey),
        );
        expect(messages, hasLength(1));
        expect(messages.first.content, equals('Test message content'));
        expect(messages.first.senderPubkey, equals(peerPubkey));
        expect(messages.first.isOutgoing, isFalse);
      });

      test('emits empty list for peer with no messages', () async {
        final unknownPeer =
            'unknown_pubkey_234567890abcdef1234567890abcdef1234567890abcdef123456';
        final messages = await waitForAsyncData<List<DmMessage>>(
          container,
          conversationMessagesProvider(unknownPeer),
        );
        expect(messages, isEmpty);
      });

      test('different peers return different provider instances (family)', () {
        final peer1 =
            'peer1_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef12345678';
        final peer2 =
            'peer2_pubkey_1234567890abcdef1234567890abcdef1234567890abcdef12345678';

        final provider1 = conversationMessagesProvider(peer1);
        final provider2 = conversationMessagesProvider(peer2);

        // Should be different provider instances due to different arguments
        expect(provider1 == provider2, isFalse);
      });
    });

    group('nip17InboxServiceProvider', () {
      test('creates NIP17InboxService instance', () {
        final service = container.read(nip17InboxServiceProvider);
        expect(service, isA<NIP17InboxService>());
      });
    });
  });
}
