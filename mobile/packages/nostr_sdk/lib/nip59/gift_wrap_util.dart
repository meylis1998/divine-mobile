// ABOUTME: Utility for handling NIP-59 gift wrapped events and NIP-17 private DMs.
// ABOUTME: Provides secure unwrapping with sender verification to prevent impersonation.

import 'dart:convert';
import 'dart:developer';
import 'dart:math' as math;

import '../client_utils/keys.dart';
import '../event.dart';
import '../event_kind.dart';
import '../nip44/nip44_v2.dart';
import '../nostr.dart';

class GiftWrapUtil {
  /// Unwraps a gift-wrapped event (kind 1059) to extract the inner rumor event.
  ///
  /// The unwrapping process follows NIP-59/NIP-17:
  /// 1. Decrypt gift wrap → get seal (kind 13)
  /// 2. Verify seal is properly signed
  /// 3. Decrypt seal → get rumor (e.g., kind 14 for DMs)
  /// 4. CRITICAL: Verify seal pubkey matches rumor pubkey (prevents impersonation)
  ///
  /// Returns null if decryption fails or sender verification fails.
  static Future<Event?> getRumorEvent(Nostr nostr, Event giftWrapEvent) async {
    // Step 1: Decrypt the gift wrap to get the seal
    final sealText = await nostr.nostrSigner.nip44Decrypt(
      giftWrapEvent.pubkey,
      giftWrapEvent.content,
    );
    if (sealText == null) {
      return null;
    }

    Event sealEvent;
    try {
      final sealJson = jsonDecode(sealText);
      sealEvent = Event.fromJson(sealJson);
    } on FormatException catch (e) {
      log('GiftWrap seal JSON decode failed: $e');
      return null;
    }

    // Step 2: Verify the seal is valid and properly signed
    if (!sealEvent.isValid || !sealEvent.isSigned) {
      log(
        'GiftWrap seal signature verification failed, '
        'gift wrap id: ${giftWrapEvent.id}, from: ${giftWrapEvent.pubkey}',
      );
      return null;
    }

    // Step 3: Decrypt the seal to get the rumor
    final rumorText = await nostr.nostrSigner.nip44Decrypt(
      sealEvent.pubkey,
      sealEvent.content,
    );
    if (rumorText == null) {
      return null;
    }

    Event rumorEvent;
    try {
      final rumorJson = jsonDecode(rumorText);
      rumorEvent = Event.fromJson(rumorJson);
    } on FormatException catch (e) {
      log('GiftWrap rumor JSON decode failed: $e');
      return null;
    }

    // Step 4: CRITICAL - Verify sender isn't impersonating (NIP-17 requirement)
    // "Clients MUST verify if pubkey of the kind:13 is the same pubkey on the
    // kind:14, otherwise any sender can impersonate others by simply changing
    // the pubkey on kind:14."
    if (sealEvent.pubkey != rumorEvent.pubkey) {
      log(
        'Sender impersonation attempt detected: seal pubkey does not match '
        'rumor pubkey. Seal pubkey: ${sealEvent.pubkey}, '
        'rumor pubkey: ${rumorEvent.pubkey}',
      );
      return null;
    }

    return rumorEvent;
  }

  static Future<Event?> getGiftWrapEvent(
    Nostr nostr,
    Event e,
    String receiverPublicKey,
  ) async {
    var giftEventCreatedAt =
        e.createdAt - math.Random().nextInt(60 * 60 * 24 * 2);
    var rumorEventMap = e.toJson();
    rumorEventMap.remove("sig");

    var sealEventContent = await nostr.nostrSigner.nip44Encrypt(
      receiverPublicKey,
      jsonEncode(rumorEventMap),
    );
    if (sealEventContent == null) {
      return null;
    }
    var sealEvent = Event(
      nostr.publicKey,
      EventKind.sealEventKind,
      [],
      sealEventContent,
    );
    await nostr.signEvent(sealEvent);

    var randomPrivateKey = generatePrivateKey();
    var randomPubkey = getPublicKey(randomPrivateKey);
    var randomKey = NIP44V2.shareSecret(randomPrivateKey, receiverPublicKey);
    var giftWrapEventContent = await NIP44V2.encrypt(
      jsonEncode(sealEvent.toJson()),
      randomKey,
    );
    var giftWrapEvent = Event(
      randomPubkey,
      EventKind.giftWrap,
      [
        ["p", receiverPublicKey],
      ],
      giftWrapEventContent,
      createdAt: giftEventCreatedAt,
    );
    giftWrapEvent.sign(randomPrivateKey);

    return giftWrapEvent;
  }
}
