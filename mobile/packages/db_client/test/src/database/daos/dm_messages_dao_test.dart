// ABOUTME: Unit tests for DmMessagesDao with message storage and retrieval.
// ABOUTME: Tests insert, deduplication, read status, and pagination.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DmMessagesDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkeys for testing
  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const peerPubkey1 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const peerPubkey2 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  /// Valid 64-char hex event IDs for testing
  const rumorId1 =
      '1111111111111111111111111111111111111111111111111111111111111111';
  const rumorId2 =
      '2222222222222222222222222222222222222222222222222222222222222222';
  const rumorId3 =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const giftWrapId1 =
      'gggg111111111111111111111111111111111111111111111111111111111111';
  const giftWrapId2 =
      'gggg222222222222222222222222222222222222222222222222222222222222';
  const giftWrapId3 =
      'gggg333333333333333333333333333333333333333333333333333333333333';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dm_msg_dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.dmMessagesDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('DmMessagesDao', () {
    group('insertMessage', () {
      test('inserts new message', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Hello!',
          createdAt: now,
          isOutgoing: false,
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results, hasLength(1));
        expect(results.first.rumorId, equals(rumorId1));
        expect(results.first.content, equals('Hello!'));
        expect(results.first.isOutgoing, isFalse);
        expect(results.first.isRead, isFalse);
        expect(results.first.messageType, equals('text'));
      });

      test('deduplicates by rumorId and ownerPubkey', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Original message',
          createdAt: now,
          isOutgoing: false,
        );

        // Attempt to insert duplicate
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Duplicate message',
          createdAt: now.add(const Duration(minutes: 1)),
          isOutgoing: false,
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results, hasLength(1));
        // Should keep the original
        expect(results.first.content, equals('Original message'));
      });

      test('handles optional metadata field', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: ownerPubkey,
          content: 'Check out this video',
          createdAt: DateTime.now(),
          isOutgoing: true,
          messageType: 'video',
          metadata: '{"videoId": "abc123", "thumbnailUrl": "https://..."}',
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results.first.messageType, equals('video'));
        expect(results.first.metadata, contains('videoId'));
      });
    });

    group('getMessagesForConversation', () {
      test('returns messages sorted by createdAt descending', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'First',
          createdAt: now,
          isOutgoing: false,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: ownerPubkey,
          content: 'Second',
          createdAt: now.add(const Duration(minutes: 1)),
          isOutgoing: true,
        );
        await dao.insertMessage(
          rumorId: rumorId3,
          giftWrapId: giftWrapId3,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Third',
          createdAt: now.add(const Duration(minutes: 2)),
          isOutgoing: false,
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results[0].content, equals('Third'));
        expect(results[1].content, equals('Second'));
        expect(results[2].content, equals('First'));
      });

      test('filters by peer pubkey', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'From peer 1',
          createdAt: now,
          isOutgoing: false,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
          senderPubkey: peerPubkey2,
          content: 'From peer 2',
          createdAt: now,
          isOutgoing: false,
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results, hasLength(1));
        expect(results.first.content, equals('From peer 1'));
      });

      test('respects limit parameter', () async {
        final now = DateTime.now();
        for (var i = 0; i < 5; i++) {
          await dao.insertMessage(
            rumorId:
                'rumor$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i',
            giftWrapId:
                'giftwrap$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i$i',
            ownerPubkey: ownerPubkey,
            peerPubkey: peerPubkey1,
            senderPubkey: peerPubkey1,
            content: 'Message $i',
            createdAt: now.add(Duration(minutes: i)),
            isOutgoing: false,
          );
        }

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          limit: 3,
        );
        expect(results, hasLength(3));
      });

      test('returns empty list when no messages exist', () async {
        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results, isEmpty);
      });
    });

    group('getMessage', () {
      test('returns message when it exists', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Test message',
          createdAt: DateTime.now(),
          isOutgoing: false,
        );

        final result = await dao.getMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );

        expect(result, isNotNull);
        expect(result!.content, equals('Test message'));
      });

      test('returns null when message does not exist', () async {
        final result = await dao.getMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );

        expect(result, isNull);
      });
    });

    group('hasMessage', () {
      test('returns true when message exists', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Test',
          createdAt: DateTime.now(),
          isOutgoing: false,
        );

        final exists = await dao.hasMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );
        expect(exists, isTrue);
      });

      test('returns false when message does not exist', () async {
        final exists = await dao.hasMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );
        expect(exists, isFalse);
      });
    });

    group('markAsRead', () {
      test('marks message as read', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Test',
          createdAt: DateTime.now(),
          isOutgoing: false,
        );

        await dao.markAsRead(rumorId: rumorId1, ownerPubkey: ownerPubkey);

        final result = await dao.getMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );
        expect(result!.isRead, isTrue);
      });
    });

    group('markConversationMessagesAsRead', () {
      test('marks all messages in conversation as read', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'First',
          createdAt: now,
          isOutgoing: false,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Second',
          createdAt: now.add(const Duration(minutes: 1)),
          isOutgoing: false,
        );

        await dao.markConversationMessagesAsRead(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results.every((m) => m.isRead), isTrue);
      });
    });

    group('getUnreadCountForConversation', () {
      test('returns count of unread messages', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Unread 1',
          createdAt: now,
          isOutgoing: false,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Unread 2',
          createdAt: now.add(const Duration(minutes: 1)),
          isOutgoing: false,
        );

        await dao.markAsRead(rumorId: rumorId1, ownerPubkey: ownerPubkey);

        final count = await dao.getUnreadCountForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(count, equals(1));
      });

      test('excludes outgoing messages from unread count', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: ownerPubkey,
          content: 'Outgoing',
          createdAt: now,
          isOutgoing: true,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Incoming',
          createdAt: now.add(const Duration(minutes: 1)),
          isOutgoing: false,
        );

        final count = await dao.getUnreadCountForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(count, equals(1));
      });
    });

    group('deleteMessage', () {
      test('deletes message by key', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Test',
          createdAt: DateTime.now(),
          isOutgoing: false,
        );

        final deleted = await dao.deleteMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );

        expect(deleted, equals(1));
        final result = await dao.getMessage(
          rumorId: rumorId1,
          ownerPubkey: ownerPubkey,
        );
        expect(result, isNull);
      });
    });

    group('deleteMessagesForConversation', () {
      test('deletes all messages for conversation', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Conv 1',
          createdAt: now,
          isOutgoing: false,
        );
        await dao.insertMessage(
          rumorId: rumorId2,
          giftWrapId: giftWrapId2,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
          senderPubkey: peerPubkey2,
          content: 'Conv 2',
          createdAt: now,
          isOutgoing: false,
        );

        final deleted = await dao.deleteMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        expect(deleted, equals(1));
        final conv1 = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(conv1, isEmpty);
        final conv2 = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
        );
        expect(conv2, hasLength(1));
      });
    });

    group('deleteAllForOwner', () {
      test('deletes all messages for owner', () async {
        final now = DateTime.now();
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Owner 1',
          createdAt: now,
          isOutgoing: false,
        );

        final deleted = await dao.deleteAllForOwner(ownerPubkey);

        expect(deleted, equals(1));
        final results = await dao.getMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(results, isEmpty);
      });
    });

    group('watchMessagesForConversation', () {
      test('emits initial list', () async {
        await dao.insertMessage(
          rumorId: rumorId1,
          giftWrapId: giftWrapId1,
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          senderPubkey: peerPubkey1,
          content: 'Test',
          createdAt: DateTime.now(),
          isOutgoing: false,
        );

        final stream = dao.watchMessagesForConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results.first.content, equals('Test'));
      });
    });
  });
}
