// ABOUTME: Tests for GiftWrapUtil NIP-59/NIP-17 gift wrap decryption and sender verification.
// ABOUTME: Validates that sender impersonation attempts are detected and rejected.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

void main() {
  group('GiftWrapUtil Tests', () {
    late String senderPrivateKey;
    late String senderPublicKey;
    late String receiverPrivateKey;
    late String receiverPublicKey;
    late String attackerPrivateKey;
    late String attackerPublicKey;
    late LocalNostrSigner receiverSigner;

    setUp(() {
      // Generate test keys
      senderPrivateKey = generatePrivateKey();
      senderPublicKey = getPublicKey(senderPrivateKey);
      receiverPrivateKey = generatePrivateKey();
      receiverPublicKey = getPublicKey(receiverPrivateKey);
      attackerPrivateKey = generatePrivateKey();
      attackerPublicKey = getPublicKey(attackerPrivateKey);
      receiverSigner = LocalNostrSigner(receiverPrivateKey);
    });

    test(
      'getRumorEvent returns null when seal pubkey does not match rumor pubkey (impersonation attempt)',
      () async {
        // Create a rumor (kind 14 DM) with the SENDER's pubkey
        final rumorEvent = Event(
          senderPublicKey,
          EventKind.privateDirectMessage,
          [
            ['p', receiverPublicKey],
          ],
          'Hello, this is a private message',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        // Create a SEAL with the ATTACKER's key (not matching the rumor)
        // This simulates an impersonation attack where the attacker
        // wraps someone else's rumor in their own seal
        final attackerSigner = LocalNostrSigner(attackerPrivateKey);

        // Encrypt the rumor content with attacker's key to receiver
        final rumorJson = rumorEvent.toJson();
        rumorJson.remove('sig'); // Rumors should not be signed per NIP-17
        final encryptedRumor = await attackerSigner.nip44Encrypt(
          receiverPublicKey,
          jsonEncode(rumorJson),
        );

        // Create seal event with ATTACKER's pubkey
        final sealEvent = Event(
          attackerPublicKey, // Attacker's pubkey, NOT sender's
          EventKind.sealEventKind,
          [],
          encryptedRumor!,
        );
        sealEvent.sign(attackerPrivateKey);

        // Create gift wrap with random key
        final wrapPrivateKey = generatePrivateKey();
        final wrapPublicKey = getPublicKey(wrapPrivateKey);
        final encryptedSeal = await LocalNostrSigner(
          wrapPrivateKey,
        ).nip44Encrypt(receiverPublicKey, jsonEncode(sealEvent.toJson()));

        final giftWrapEvent = Event(wrapPublicKey, EventKind.giftWrap, [
          ['p', receiverPublicKey],
        ], encryptedSeal!);
        giftWrapEvent.sign(wrapPrivateKey);

        // Create Nostr instance for receiver to decrypt
        final nostr = _createTestNostr(receiverSigner, receiverPublicKey);

        // The impersonation should be detected and null returned
        final result = await GiftWrapUtil.getRumorEvent(nostr, giftWrapEvent);

        // CRITICAL: This should return null because seal pubkey (attacker)
        // does not match rumor pubkey (sender)
        expect(
          result,
          isNull,
          reason:
              'Impersonation attempt should be rejected - seal pubkey does not match rumor pubkey',
        );
      },
    );

    test(
      'getRumorEvent returns rumor when seal pubkey matches rumor pubkey (legitimate message)',
      () async {
        // Create a rumor (kind 14 DM) with the sender's pubkey
        final rumorEvent = Event(
          senderPublicKey,
          EventKind.privateDirectMessage,
          [
            ['p', receiverPublicKey],
          ],
          'Hello, this is a legitimate private message',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );

        // Create the SEAL with the SENDER's key (matching the rumor)
        final senderSigner = LocalNostrSigner(senderPrivateKey);

        // Encrypt the rumor content with sender's key to receiver
        final rumorJson = rumorEvent.toJson();
        rumorJson.remove('sig'); // Rumors should not be signed per NIP-17
        final encryptedRumor = await senderSigner.nip44Encrypt(
          receiverPublicKey,
          jsonEncode(rumorJson),
        );

        // Create seal event with SENDER's pubkey
        final sealEvent = Event(
          senderPublicKey, // Same as rumor pubkey - legitimate
          EventKind.sealEventKind,
          [],
          encryptedRumor!,
        );
        sealEvent.sign(senderPrivateKey);

        // Create gift wrap with random key
        final wrapPrivateKey = generatePrivateKey();
        final wrapPublicKey = getPublicKey(wrapPrivateKey);
        final encryptedSeal = await LocalNostrSigner(
          wrapPrivateKey,
        ).nip44Encrypt(receiverPublicKey, jsonEncode(sealEvent.toJson()));

        final giftWrapEvent = Event(wrapPublicKey, EventKind.giftWrap, [
          ['p', receiverPublicKey],
        ], encryptedSeal!);
        giftWrapEvent.sign(wrapPrivateKey);

        // Create Nostr instance for receiver to decrypt
        final nostr = _createTestNostr(receiverSigner, receiverPublicKey);

        // The legitimate message should be returned
        final result = await GiftWrapUtil.getRumorEvent(nostr, giftWrapEvent);

        expect(result, isNotNull, reason: 'Legitimate message should decrypt');
        expect(result!.pubkey, equals(senderPublicKey));
        expect(
          result.content,
          equals('Hello, this is a legitimate private message'),
        );
        expect(result.kind, equals(EventKind.privateDirectMessage));
      },
    );
  });
}

/// Creates a minimal Nostr instance for testing gift wrap decryption.
/// This bypasses relay pool functionality since we only need the signer.
Nostr _createTestNostr(NostrSigner signer, String publicKey) {
  return Nostr(
    signer,
    publicKey,
    [], // No event filters needed for this test
    (url) => throw UnimplementedError('Relay not needed for this test'),
  );
}
