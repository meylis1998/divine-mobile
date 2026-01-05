// ABOUTME: Unit tests for DmConversationsDao with conversation management.
// ABOUTME: Tests upsert, retrieval, unread counts, mute status, and cleanup.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;
  late DmConversationsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkeys for testing
  const ownerPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  const peerPubkey1 =
      'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';
  const peerPubkey2 =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const otherOwnerPubkey =
      'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dm_conv_dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.dmConversationsDao;
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

  group('DmConversationsDao', () {
    group('upsertConversation', () {
      test('inserts new conversation', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
          lastMessagePreview: 'Hello there!',
        );

        final results = await dao.getAllConversations(ownerPubkey);
        expect(results, hasLength(1));
        expect(results.first.ownerPubkey, equals(ownerPubkey));
        expect(results.first.peerPubkey, equals(peerPubkey1));
        expect(results.first.lastMessagePreview, equals('Hello there!'));
        expect(results.first.unreadCount, equals(0));
        expect(results.first.isMuted, isFalse);
      });

      test('updates existing conversation with same key', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
          lastMessagePreview: 'First message',
        );

        final later = now.add(const Duration(minutes: 5));
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: later,
          lastMessagePreview: 'Updated message',
          unreadCount: 3,
        );

        final results = await dao.getAllConversations(ownerPubkey);
        expect(results, hasLength(1));
        expect(results.first.lastMessagePreview, equals('Updated message'));
        expect(results.first.unreadCount, equals(3));
      });

      test('handles null optional fields', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
        );

        final results = await dao.getAllConversations(ownerPubkey);
        expect(results.first.lastMessagePreview, isNull);
      });
    });

    group('getAllConversations', () {
      test(
        'returns conversations sorted by lastMessageAt descending',
        () async {
          final now = DateTime.now();
          await dao.upsertConversation(
            ownerPubkey: ownerPubkey,
            peerPubkey: peerPubkey1,
            lastMessageAt: now,
          );
          await dao.upsertConversation(
            ownerPubkey: ownerPubkey,
            peerPubkey: peerPubkey2,
            lastMessageAt: now.add(const Duration(hours: 1)),
          );

          final results = await dao.getAllConversations(ownerPubkey);
          expect(results[0].peerPubkey, equals(peerPubkey2));
          expect(results[1].peerPubkey, equals(peerPubkey1));
        },
      );

      test('filters by owner pubkey', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
        );
        await dao.upsertConversation(
          ownerPubkey: otherOwnerPubkey,
          peerPubkey: peerPubkey2,
          lastMessageAt: now,
        );

        final results = await dao.getAllConversations(ownerPubkey);
        expect(results, hasLength(1));
        expect(results.first.peerPubkey, equals(peerPubkey1));
      });

      test('returns empty list when no conversations exist', () async {
        final results = await dao.getAllConversations(ownerPubkey);
        expect(results, isEmpty);
      });
    });

    group('getConversation', () {
      test('returns conversation when it exists', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
          lastMessagePreview: 'Test message',
        );

        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        expect(result, isNotNull);
        expect(result!.peerPubkey, equals(peerPubkey1));
      });

      test('returns null when conversation does not exist', () async {
        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        expect(result, isNull);
      });
    });

    group('getTotalUnreadCount', () {
      test('returns sum of unread counts for owner', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
          unreadCount: 5,
        );
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
          lastMessageAt: now,
          unreadCount: 3,
        );

        final count = await dao.getTotalUnreadCount(ownerPubkey);
        expect(count, equals(8));
      });

      test('excludes muted conversations from unread count', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
          unreadCount: 5,
        );
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
          lastMessageAt: now,
          unreadCount: 3,
          isMuted: true,
        );

        final count = await dao.getTotalUnreadCount(ownerPubkey);
        expect(count, equals(5));
      });

      test('returns 0 when no conversations', () async {
        final count = await dao.getTotalUnreadCount(ownerPubkey);
        expect(count, equals(0));
      });
    });

    group('markConversationRead', () {
      test('sets unread count to 0', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 5,
        );

        await dao.markConversationRead(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(result!.unreadCount, equals(0));
      });
    });

    group('incrementUnreadCount', () {
      test('increments unread count by 1', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 2,
        );

        await dao.incrementUnreadCount(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(result!.unreadCount, equals(3));
      });
    });

    group('setMuted', () {
      test('mutes conversation', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
        );

        await dao.setMuted(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          isMuted: true,
        );

        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(result!.isMuted, isTrue);
      });

      test('unmutes conversation', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
          isMuted: true,
        );

        await dao.setMuted(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          isMuted: false,
        );

        final result = await dao.getConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(result!.isMuted, isFalse);
      });
    });

    group('deleteConversation', () {
      test('deletes conversation by key', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
        );

        final deleted = await dao.deleteConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );

        expect(deleted, equals(1));
        final results = await dao.getAllConversations(ownerPubkey);
        expect(results, isEmpty);
      });

      test('returns 0 for non-existent conversation', () async {
        final deleted = await dao.deleteConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
        );
        expect(deleted, equals(0));
      });
    });

    group('deleteAllForOwner', () {
      test('deletes all conversations for owner', () async {
        final now = DateTime.now();
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
        );
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey2,
          lastMessageAt: now,
        );
        await dao.upsertConversation(
          ownerPubkey: otherOwnerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: now,
        );

        final deleted = await dao.deleteAllForOwner(ownerPubkey);

        expect(deleted, equals(2));
        final ownerResults = await dao.getAllConversations(ownerPubkey);
        expect(ownerResults, isEmpty);
        final otherResults = await dao.getAllConversations(otherOwnerPubkey);
        expect(otherResults, hasLength(1));
      });
    });

    group('watchAllConversations', () {
      test('emits initial list', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
        );

        final stream = dao.watchAllConversations(ownerPubkey);
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results.first.peerPubkey, equals(peerPubkey1));
      });
    });

    group('watchTotalUnreadCount', () {
      test('emits initial count', () async {
        await dao.upsertConversation(
          ownerPubkey: ownerPubkey,
          peerPubkey: peerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 5,
        );

        final stream = dao.watchTotalUnreadCount(ownerPubkey);
        final count = await stream.first;

        expect(count, equals(5));
      });
    });
  });
}
