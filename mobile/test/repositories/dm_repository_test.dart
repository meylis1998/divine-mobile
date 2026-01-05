// ABOUTME: Unit tests for DMRepository
// ABOUTME: Tests message saving, conversation updates, and reactive streams

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:drift/drift.dart' hide isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/services/nip17_inbox_service.dart';

class MockNostrKeyManager extends Mock implements NostrKeyManager {}

class MockNIP17InboxService extends Mock implements NIP17InboxService {}

void main() {
  // Valid 64-character hex pubkeys for testing
  const testOwnerPubkey =
      'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
  const testPeerPubkey =
      'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
  const testPeerPubkey2 =
      'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';

  // Valid 64-character event IDs
  const testRumorId =
      'd1e2f3a4b5c6789012345678901234567890abcdef1234567890123456789012';
  const testGiftWrapId =
      'e2f3a4b5c6789012345678901234567890abcdef1234567890123456789012d1';
  const testRumorId2 =
      'f3a4b5c6789012345678901234567890abcdef1234567890123456789012e2f3';
  const testGiftWrapId2 =
      'a4b5c6789012345678901234567890abcdef1234567890123456789012e2f3a4';

  late AppDatabase database;
  late DmConversationsDao conversationsDao;
  late DmMessagesDao messagesDao;
  late MockNostrKeyManager mockKeyManager;
  late MockNIP17InboxService mockInboxService;
  late DMRepository repository;

  setUp(() async {
    // Create in-memory database for testing
    database = AppDatabase.test(NativeDatabase.memory());

    conversationsDao = database.dmConversationsDao;
    messagesDao = database.dmMessagesDao;

    mockKeyManager = MockNostrKeyManager();
    mockInboxService = MockNIP17InboxService();

    // Default key manager setup
    when(() => mockKeyManager.hasKeys).thenReturn(true);
    when(() => mockKeyManager.publicKey).thenReturn(testOwnerPubkey);

    // Default inbox service setup
    when(
      () => mockInboxService.incomingMessages,
    ).thenAnswer((_) => const Stream.empty());

    repository = DMRepository(
      conversationsDao: conversationsDao,
      messagesDao: messagesDao,
      keyManager: mockKeyManager,
      inboxService: mockInboxService,
    );
  });

  tearDown(() async {
    repository.dispose();
    await database.close();
  });

  group('DMRepository', () {
    group('saveIncomingMessage', () {
      test('saves message to database and creates conversation', () async {
        final incomingMessage = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Hello, world!',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );

        await repository.saveIncomingMessage(incomingMessage);

        // Verify message was saved
        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages, hasLength(1));
        expect(messages.first.rumorId, equals(testRumorId));
        expect(messages.first.content, equals('Hello, world!'));
        expect(messages.first.isOutgoing, isFalse);

        // Verify conversation was created/updated
        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation, isNotNull);
        expect(conversation!.unreadCount, equals(1));
        expect(conversation.lastMessagePreview, contains('Hello'));
      });

      test('increments unread count for incoming messages', () async {
        // Save first message
        final message1 = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'First message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message1);

        // Save second message
        final message2 = IncomingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          senderPubkey: testPeerPubkey,
          content: 'Second message',
          createdAt: DateTime.now().add(const Duration(seconds: 1)),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message2);

        // Verify unread count is 2
        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.unreadCount, equals(2));
      });

      test('updates conversation lastMessageAt with newer messages', () async {
        // Use timestamps with second precision since Drift stores seconds
        final earlierTime = DateTime.fromMillisecondsSinceEpoch(
          (DateTime.now().millisecondsSinceEpoch ~/ 1000) * 1000,
        );
        final laterTime = earlierTime.add(const Duration(minutes: 5));

        // Save earlier message
        final message1 = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Earlier message',
          createdAt: earlierTime,
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message1);

        // Save later message
        final message2 = IncomingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          senderPubkey: testPeerPubkey,
          content: 'Later message',
          createdAt: laterTime,
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message2);

        // Verify lastMessageAt is the later time (compare seconds since Drift
        // stores with second precision)
        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(
          conversation!.lastMessageAt.millisecondsSinceEpoch ~/ 1000,
          equals(laterTime.millisecondsSinceEpoch ~/ 1000),
        );
        expect(conversation.lastMessagePreview, contains('Later'));
      });

      test('handles video share message type', () async {
        final incomingMessage = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Check out this video!',
          createdAt: DateTime.now(),
          type: DmMessageType.videoShare,
          videoATag: '34236:$testPeerPubkey:video-d-tag',
        );

        await repository.saveIncomingMessage(incomingMessage);

        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages.first.messageType, equals('videoShare'));
        expect(messages.first.metadata, contains('videoATag'));
      });
    });

    group('saveOutgoingMessage', () {
      test('saves outgoing message without incrementing unread', () async {
        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: 'Hello from me!',
          createdAt: DateTime.now(),
        );

        // Verify message was saved as outgoing
        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages, hasLength(1));
        expect(messages.first.isOutgoing, isTrue);
        expect(messages.first.senderPubkey, equals(testOwnerPubkey));

        // Verify unread count is 0 (outgoing messages don't count)
        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.unreadCount, equals(0));
      });

      test('updates conversation with outgoing message preview', () async {
        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: 'My outgoing message',
          createdAt: DateTime.now(),
        );

        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.lastMessagePreview, contains('My outgoing'));
      });
    });

    group('markConversationRead', () {
      test('resets unread count to 0', () async {
        // Create conversation with unread messages
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Unread message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message);

        // Verify unread count is 1
        var conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.unreadCount, equals(1));

        // Mark as read
        await repository.markConversationRead(testPeerPubkey);

        // Verify unread count is now 0
        conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.unreadCount, equals(0));
      });

      test('marks individual messages as read', () async {
        // Create messages
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Unread message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message);

        // Verify message is unread
        var messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages.first.isRead, isFalse);

        // Mark conversation as read
        await repository.markConversationRead(testPeerPubkey);

        // Verify message is now read
        messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages.first.isRead, isTrue);
      });
    });

    group('watchConversations', () {
      test('emits conversation list sorted by lastMessageAt', () async {
        // Create two conversations at different times
        final earlierTime = DateTime.now();
        final laterTime = earlierTime.add(const Duration(minutes: 5));

        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: 'Earlier message',
          createdAt: earlierTime,
        );

        await repository.saveOutgoingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          recipientPubkey: testPeerPubkey2,
          content: 'Later message',
          createdAt: laterTime,
        );

        // Watch conversations
        final conversations = await repository.watchConversations().first;

        expect(conversations, hasLength(2));
        // First should be the more recent conversation
        expect(conversations.first.peerPubkey, equals(testPeerPubkey2));
        expect(conversations.last.peerPubkey, equals(testPeerPubkey));
      });

      test('emits updated list when new message arrives', () async {
        // Set up stream listener
        final conversationUpdates = <List<dynamic>>[];
        final subscription = repository.watchConversations().listen(
          conversationUpdates.add,
        );

        // Allow initial emission
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Save a message
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'New message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message);

        // Allow emission
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(conversationUpdates, isNotEmpty);
        // Last emission should contain the new conversation
        expect(
          conversationUpdates.last.any((c) => c.peerPubkey == testPeerPubkey),
          isTrue,
        );

        await subscription.cancel();
      });
    });

    group('watchMessages', () {
      test('emits messages for specific conversation', () async {
        // Create messages in two different conversations
        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: 'Message to peer 1',
          createdAt: DateTime.now(),
        );

        await repository.saveOutgoingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          recipientPubkey: testPeerPubkey2,
          content: 'Message to peer 2',
          createdAt: DateTime.now(),
        );

        // Watch messages for peer 1 only
        final messages = await repository.watchMessages(testPeerPubkey).first;

        expect(messages, hasLength(1));
        expect(messages.first.peerPubkey, equals(testPeerPubkey));
        expect(messages.first.content, equals('Message to peer 1'));
      });

      test('emits messages sorted by createdAt descending', () async {
        final earlierTime = DateTime.now();
        final laterTime = earlierTime.add(const Duration(minutes: 5));

        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: 'Earlier message',
          createdAt: earlierTime,
        );

        await repository.saveOutgoingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          recipientPubkey: testPeerPubkey,
          content: 'Later message',
          createdAt: laterTime,
        );

        final messages = await repository.watchMessages(testPeerPubkey).first;

        expect(messages, hasLength(2));
        // First should be most recent
        expect(messages.first.content, equals('Later message'));
        expect(messages.last.content, equals('Earlier message'));
      });
    });

    group('watchUnreadCount', () {
      test('emits total unread count across conversations', () async {
        // Create unread messages in two conversations
        final message1 = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Message 1',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message1);

        final message2 = IncomingMessage(
          rumorId: testRumorId2,
          giftWrapId: testGiftWrapId2,
          senderPubkey: testPeerPubkey2,
          content: 'Message 2',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message2);

        final unreadCount = await repository.watchUnreadCount().first;

        expect(unreadCount, equals(2));
      });

      test('updates when conversation is marked as read', () async {
        // Create unread message
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Unread message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        await repository.saveIncomingMessage(message);

        // Verify initial unread count
        var unreadCount = await repository.watchUnreadCount().first;
        expect(unreadCount, equals(1));

        // Mark as read
        await repository.markConversationRead(testPeerPubkey);

        // Verify updated unread count
        unreadCount = await repository.watchUnreadCount().first;
        expect(unreadCount, equals(0));
      });
    });

    group('startSync', () {
      test('listens to inbox service and saves incoming messages', () async {
        final messageController = StreamController<IncomingMessage>.broadcast();

        when(
          () => mockInboxService.incomingMessages,
        ).thenAnswer((_) => messageController.stream);

        // Start sync
        await repository.startSync();

        // Emit a message
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Synced message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        messageController.add(message);

        // Allow processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify message was saved
        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages, hasLength(1));
        expect(messages.first.content, equals('Synced message'));

        await messageController.close();
      });
    });

    group('stopSync', () {
      test('stops listening to inbox service', () async {
        final messageController = StreamController<IncomingMessage>.broadcast();

        when(
          () => mockInboxService.incomingMessages,
        ).thenAnswer((_) => messageController.stream);

        // Start and then stop sync
        await repository.startSync();
        repository.stopSync();

        // Emit a message after stopping
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Should not be saved',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );
        messageController.add(message);

        // Allow processing
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Verify message was NOT saved
        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages, isEmpty);

        await messageController.close();
      });
    });

    group('edge cases', () {
      test('handles missing keys gracefully', () async {
        when(() => mockKeyManager.hasKeys).thenReturn(false);
        when(() => mockKeyManager.publicKey).thenReturn(null);

        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Test',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );

        // Should throw StateError when no keys
        expect(() => repository.saveIncomingMessage(message), throwsStateError);
      });

      test('deduplicates messages with same rumorId', () async {
        final message = IncomingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          senderPubkey: testPeerPubkey,
          content: 'Original message',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );

        // Save the same message twice
        await repository.saveIncomingMessage(message);
        await repository.saveIncomingMessage(message);

        // Verify only one message exists
        final messages = await messagesDao.getMessagesForConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(messages, hasLength(1));

        // Verify unread count is only 1
        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );
        expect(conversation!.unreadCount, equals(1));
      });

      test('truncates long message preview', () async {
        final longContent = 'A' * 200; // 200 character message

        await repository.saveOutgoingMessage(
          rumorId: testRumorId,
          giftWrapId: testGiftWrapId,
          recipientPubkey: testPeerPubkey,
          content: longContent,
          createdAt: DateTime.now(),
        );

        final conversation = await conversationsDao.getConversation(
          ownerPubkey: testOwnerPubkey,
          peerPubkey: testPeerPubkey,
        );

        // Preview should be truncated
        expect(
          conversation!.lastMessagePreview!.length,
          lessThanOrEqualTo(100),
        );
      });
    });
  });
}
