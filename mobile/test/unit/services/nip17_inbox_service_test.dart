// ABOUTME: Unit tests for NIP17InboxService - receiving encrypted DMs
// ABOUTME: Tests decryption, message type detection, and deduplication

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nip17_inbox_service.dart';

import 'nip17_inbox_service_test.mocks.dart';

@GenerateMocks([NostrKeyManager, NostrClient, Nostr])
void main() {
  group('NIP17InboxService', () {
    late NIP17InboxService service;
    late MockNostrKeyManager mockKeyManager;
    late MockNostrClient mockNostrClient;

    // Test keys - real format but test values
    const testPrivateKey =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const testPublicKey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const senderPubkey =
        'e771af0b05c8e95fcdf6feb3500544d2fb1ccd384788e9f490bb3ee28e8ed66f';

    setUp(() {
      mockKeyManager = MockNostrKeyManager();
      mockNostrClient = MockNostrClient();

      // Setup mock key manager
      when(mockKeyManager.hasKeys).thenReturn(true);
      when(mockKeyManager.privateKey).thenReturn(testPrivateKey);
      when(mockKeyManager.publicKey).thenReturn(testPublicKey);

      service = NIP17InboxService(
        keyManager: mockKeyManager,
        nostrClient: mockNostrClient,
      );
    });

    tearDown(() {
      service.dispose();
    });

    group('IncomingMessage', () {
      test('should create text message correctly', () {
        final message = IncomingMessage(
          rumorId:
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
          giftWrapId:
              'def456abc123def456abc123def456abc123def456abc123def456abc123def4',
          senderPubkey: senderPubkey,
          content: 'Hello, world!',
          createdAt: DateTime.now(),
          type: DmMessageType.text,
        );

        expect(message.type, equals(DmMessageType.text));
        expect(message.content, equals('Hello, world!'));
        expect(message.videoATag, isNull);
        expect(message.videoEventId, isNull);
      });

      test('should create video share message correctly', () {
        final message = IncomingMessage(
          rumorId:
              'abc123def456abc123def456abc123def456abc123def456abc123def456abc1',
          giftWrapId:
              'def456abc123def456abc123def456abc123def456abc123def456abc123def4',
          senderPubkey: senderPubkey,
          content: 'Check out this video!',
          createdAt: DateTime.now(),
          type: DmMessageType.videoShare,
          videoATag: '34236:$senderPubkey:my-video-dtag',
          videoEventId:
              'video123abc456video123abc456video123abc456video123abc456video12',
        );

        expect(message.type, equals(DmMessageType.videoShare));
        expect(message.videoATag, isNotNull);
        expect(message.videoEventId, isNotNull);
      });
    });

    group('Message Type Detection', () {
      test('should detect text message when no video tags present', () {
        // A rumor event with just text content
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
        ];

        final type = NIP17InboxService.detectMessageType(rumorTags);
        expect(type, equals(DmMessageType.text));
      });

      test('should detect video share when a tag references kind 34236', () {
        // A rumor event with a video reference via 'a' tag
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
          ['a', '34236:$senderPubkey:my-video-dtag'],
        ];

        final type = NIP17InboxService.detectMessageType(rumorTags);
        expect(type, equals(DmMessageType.videoShare));
      });

      test('should detect video share when e tag references video event', () {
        // A rumor event with a video reference via 'e' tag
        // Note: We can't always know if 'e' references a video without fetching,
        // but if there's an 'a' tag for 34236, we know it's a video share
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
          [
            'e',
            'video123abc456video123abc456video123abc456video123abc456video12',
          ],
          ['a', '34236:$senderPubkey:video-dtag'],
        ];

        final type = NIP17InboxService.detectMessageType(rumorTags);
        expect(type, equals(DmMessageType.videoShare));
      });

      test('should extract video a-tag correctly', () {
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
          ['a', '34236:$senderPubkey:my-video-dtag'],
        ];

        final aTag = NIP17InboxService.extractVideoATag(rumorTags);
        expect(aTag, equals('34236:$senderPubkey:my-video-dtag'));
      });

      test('should return null for video a-tag when not present', () {
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
        ];

        final aTag = NIP17InboxService.extractVideoATag(rumorTags);
        expect(aTag, isNull);
      });

      test('should extract video event ID from e tag', () {
        const videoEventId =
            'video123abc456video123abc456video123abc456video123abc456video12';
        final rumorTags = <List<String>>[
          ['p', testPublicKey],
          ['e', videoEventId],
        ];

        final eTag = NIP17InboxService.extractVideoEventId(rumorTags);
        expect(eTag, equals(videoEventId));
      });
    });

    group('Deduplication', () {
      test('should deduplicate messages by rumor ID', () async {
        // The service should track seen rumor IDs and not emit duplicates
        const rumorId =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abc1';

        // First occurrence should be accepted
        expect(service.hasSeenRumorId(rumorId), isFalse);
        service.markRumorIdSeen(rumorId);
        expect(service.hasSeenRumorId(rumorId), isTrue);

        // Second occurrence should be detected as duplicate
        expect(service.hasSeenRumorId(rumorId), isTrue);
      });

      test('should track multiple different rumor IDs', () async {
        const rumorId1 =
            'abc123def456abc123def456abc123def456abc123def456abc123def456abc1';
        const rumorId2 =
            'def456abc123def456abc123def456abc123def456abc123def456abc123def4';

        service.markRumorIdSeen(rumorId1);

        expect(service.hasSeenRumorId(rumorId1), isTrue);
        expect(service.hasSeenRumorId(rumorId2), isFalse);

        service.markRumorIdSeen(rumorId2);

        expect(service.hasSeenRumorId(rumorId1), isTrue);
        expect(service.hasSeenRumorId(rumorId2), isTrue);
      });
    });

    group('Subscription Management', () {
      test('should not start listening without keys', () async {
        when(mockKeyManager.hasKeys).thenReturn(false);

        await expectLater(
          () => service.startListening(),
          throwsA(isA<StateError>()),
        );
      });

      test('should create subscription filter for kind 1059 with p tag', () {
        // The filter should match kind 1059 (gift wrap) events
        // with a p tag matching the current user's pubkey
        final filter = service.createGiftWrapFilter();

        expect(filter.kinds, contains(EventKind.giftWrap));
        expect(filter.p, contains(testPublicKey));
      });

      test('should stop listening and clean up subscription', () async {
        // Setup a mock subscription
        final controller = StreamController<Event>.broadcast();
        when(
          mockNostrClient.subscribe(any),
        ).thenAnswer((_) => controller.stream);

        await service.startListening();
        expect(service.isListening, isTrue);

        await service.stopListening();
        expect(service.isListening, isFalse);

        await controller.close();
      });
    });

    group('Timestamp Handling', () {
      test('should use rumor created_at not gift wrap created_at', () {
        // NIP-17 specifies that gift wrap timestamps are randomized,
        // so we must use the rumor's created_at for ordering

        // Simulate a gift wrap with randomized timestamp (2 days ago)
        final giftWrapCreatedAt =
            DateTime.now()
                .subtract(const Duration(days: 2))
                .millisecondsSinceEpoch ~/
            1000;

        // Rumor has the actual message timestamp
        final rumorCreatedAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        // The service should extract and use rumorCreatedAt
        final messageTime = NIP17InboxService.rumorTimestampToDateTime(
          rumorCreatedAt,
        );

        // Verify the message time is close to now, not 2 days ago
        final now = DateTime.now();
        final diff = now.difference(messageTime).inSeconds.abs();
        expect(diff, lessThan(5)); // Within 5 seconds

        // Gift wrap time would be significantly different
        final giftWrapTime = DateTime.fromMillisecondsSinceEpoch(
          giftWrapCreatedAt * 1000,
        );
        final giftWrapDiff = now.difference(giftWrapTime).inHours.abs();
        expect(giftWrapDiff, greaterThan(40)); // More than 40 hours ago
      });
    });

    group('Stream Behavior', () {
      test('should emit incoming messages to stream', () async {
        // Setup mock subscription that emits events
        final controller = StreamController<Event>.broadcast();
        when(
          mockNostrClient.subscribe(any),
        ).thenAnswer((_) => controller.stream);

        await service.startListening();

        // The service should provide a stream of IncomingMessage objects
        expect(service.incomingMessages, isA<Stream<IncomingMessage>>());

        await controller.close();
      });

      test('should handle subscription errors gracefully', () async {
        final controller = StreamController<Event>.broadcast();
        when(
          mockNostrClient.subscribe(any),
        ).thenAnswer((_) => controller.stream);

        await service.startListening();

        // Add an error to the stream
        controller.addError(Exception('Test error'));

        // Service should continue running (not crash)
        expect(service.isListening, isTrue);

        await controller.close();
      });
    });

    group('Error Handling', () {
      test('should handle decryption failure gracefully', () async {
        // When decryption fails, the service should log and skip the message
        // rather than crashing or emitting incomplete data

        // Create a gift wrap event with valid pubkey format but invalid content
        // This simulates receiving a gift wrap that cannot be decrypted
        final invalidGiftWrapEvent = Event(
          // Valid 64-char hex pubkey (random ephemeral key)
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          EventKind.giftWrap,
          [
            ['p', testPublicKey],
          ],
          'invalid-encrypted-content-that-will-fail-decryption',
        );

        // The service should return null (not throw) when decryption fails
        final result = await service.processGiftWrapEvent(invalidGiftWrapEvent);
        expect(result, isNull);
      });

      test('should reject events that are not kind 1059', () async {
        // Only kind 1059 (gift wrap) events should be processed
        final nonGiftWrapEvent = Event(
          senderPubkey,
          EventKind.textNote, // Kind 1, not 1059
          [
            ['p', testPublicKey],
          ],
          'This is not a gift wrap',
        );

        final result = await service.processGiftWrapEvent(nonGiftWrapEvent);
        expect(result, isNull);
      });
    });
  });
}
