// ABOUTME: Service for receiving and decrypting NIP-17 gift-wrapped DMs.
// ABOUTME: Handles subscription to kind 1059 events, decryption, and message parsing.

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Message type for DM content
enum DmMessageType {
  /// Plain text message
  text,

  /// Video share - message contains a reference to a video event
  videoShare,
}

/// Represents a decrypted incoming DM message
class IncomingMessage {
  /// Creates an incoming message
  const IncomingMessage({
    required this.rumorId,
    required this.giftWrapId,
    required this.senderPubkey,
    required this.content,
    required this.createdAt,
    required this.type,
    this.videoATag,
    this.videoEventId,
  });

  /// Rumor event ID (inner event, used for deduplication)
  final String rumorId;

  /// Gift wrap event ID (outer event)
  final String giftWrapId;

  /// Pubkey of the message sender
  final String senderPubkey;

  /// Decrypted message content
  final String content;

  /// Message creation timestamp (from rumor's created_at)
  final DateTime createdAt;

  /// Type of message (text or video share)
  final DmMessageType type;

  /// Optional addressable video reference (e.g., "34236:pubkey:d-tag")
  final String? videoATag;

  /// Optional video event ID reference
  final String? videoEventId;

  @override
  String toString() {
    return 'IncomingMessage(rumorId: $rumorId, sender: $senderPubkey, '
        'type: $type, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content})';
  }
}

/// Service for receiving and processing NIP-17 encrypted direct messages.
///
/// This service:
/// - Subscribes to kind 1059 (gift wrap) events addressed to the current user
/// - Decrypts messages using GiftWrapUtil.getRumorEvent()
/// - Parses message content and detects video shares
/// - Deduplicates messages by rumor event ID
/// - Emits a stream of [IncomingMessage] objects
class NIP17InboxService {
  /// Creates a new inbox service
  NIP17InboxService({
    required NostrKeyManager keyManager,
    required NostrClient nostrClient,
  }) : _keyManager = keyManager,
       _nostrClient = nostrClient;

  final NostrKeyManager _keyManager;
  final NostrClient _nostrClient;

  /// Stream controller for incoming messages
  final _messageController = StreamController<IncomingMessage>.broadcast();

  /// Set of seen rumor IDs for deduplication
  final Set<String> _seenRumorIds = {};

  /// Subscription for gift wrap events
  StreamSubscription<Event>? _subscription;

  /// Nostr instance for decryption (lazily initialized)
  Nostr? _nostr;

  /// Whether the service is currently listening for messages
  bool get isListening => _subscription != null;

  /// Stream of incoming decrypted messages
  Stream<IncomingMessage> get incomingMessages => _messageController.stream;

  /// Start listening for incoming gift-wrapped messages
  ///
  /// Throws [StateError] if keys are not available.
  Future<void> startListening() async {
    if (!_keyManager.hasKeys || _keyManager.privateKey == null) {
      throw StateError('Cannot start listening without keys');
    }

    if (_subscription != null) {
      Log.debug(
        'NIP17InboxService already listening, ignoring start request',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      'Starting NIP17InboxService listener',
      category: LogCategory.system,
    );

    // Initialize Nostr instance for decryption
    _initNostr();

    // Create subscription filter
    final filter = createGiftWrapFilter();

    // Subscribe to gift wrap events
    final stream = _nostrClient.subscribe([filter]);

    _subscription = stream.listen(
      _handleGiftWrapEvent,
      onError: (Object error, StackTrace stackTrace) {
        Log.error(
          'Error in gift wrap subscription: $error',
          category: LogCategory.system,
          error: error,
          stackTrace: stackTrace,
        );
      },
      onDone: () {
        Log.debug(
          'Gift wrap subscription completed',
          category: LogCategory.system,
        );
      },
    );
  }

  /// Stop listening for messages
  Future<void> stopListening() async {
    await _subscription?.cancel();
    _subscription = null;
    Log.info(
      'Stopped NIP17InboxService listener',
      category: LogCategory.system,
    );
  }

  /// Fetch historical messages since a given timestamp
  ///
  /// Returns a list of decrypted messages from the past.
  Future<List<IncomingMessage>> fetchHistory({DateTime? since}) async {
    if (!_keyManager.hasKeys || _keyManager.privateKey == null) {
      throw StateError('Cannot fetch history without keys');
    }

    _initNostr();

    final sinceTimestamp = since?.millisecondsSinceEpoch ?? 0;
    final filter = Filter(
      kinds: const [EventKind.giftWrap],
      p: [_keyManager.publicKey!],
      since: sinceTimestamp ~/ 1000,
    );

    Log.info(
      'Fetching DM history since ${since ?? 'beginning'}',
      category: LogCategory.system,
    );

    final events = await _nostrClient.queryEvents([filter]);
    final messages = <IncomingMessage>[];

    for (final event in events) {
      final message = await processGiftWrapEvent(event);
      if (message != null) {
        messages.add(message);
      }
    }

    // Sort by created_at descending (most recent first)
    messages.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    Log.info(
      'Fetched ${messages.length} historical DM messages',
      category: LogCategory.system,
    );

    return messages;
  }

  /// Create filter for subscribing to gift wrap events
  Filter createGiftWrapFilter() {
    return Filter(
      kinds: const [EventKind.giftWrap],
      p: [_keyManager.publicKey!],
    );
  }

  /// Check if a rumor ID has already been seen
  bool hasSeenRumorId(String rumorId) {
    return _seenRumorIds.contains(rumorId);
  }

  /// Mark a rumor ID as seen
  void markRumorIdSeen(String rumorId) {
    _seenRumorIds.add(rumorId);
  }

  /// Process a gift wrap event and return the decrypted message
  ///
  /// Returns null if:
  /// - Event is not kind 1059
  /// - Decryption fails
  /// - Message is a duplicate (already seen rumor ID)
  Future<IncomingMessage?> processGiftWrapEvent(Event giftWrapEvent) async {
    // Verify it's a gift wrap event
    if (giftWrapEvent.kind != EventKind.giftWrap) {
      Log.debug(
        'Ignoring non-gift-wrap event kind ${giftWrapEvent.kind}',
        category: LogCategory.system,
      );
      return null;
    }

    if (_nostr == null) {
      Log.error(
        'Nostr instance not initialized for decryption',
        category: LogCategory.system,
      );
      return null;
    }

    try {
      // Decrypt the gift wrap to get the rumor event
      final rumorEvent = await GiftWrapUtil.getRumorEvent(
        _nostr!,
        giftWrapEvent,
      );

      if (rumorEvent == null) {
        Log.debug(
          'Failed to decrypt gift wrap event ${giftWrapEvent.id}',
          category: LogCategory.system,
        );
        return null;
      }

      // Check for duplicates
      if (hasSeenRumorId(rumorEvent.id)) {
        Log.debug(
          'Duplicate rumor ID ${rumorEvent.id}, skipping',
          category: LogCategory.system,
        );
        return null;
      }

      // Mark as seen
      markRumorIdSeen(rumorEvent.id);

      // Parse the rumor event tags
      final tags = _parseTags(rumorEvent.tags);

      // Detect message type
      final type = detectMessageType(tags);

      // Extract video references if present
      final videoATag = extractVideoATag(tags);
      final videoEventId = extractVideoEventId(tags);

      // Create the incoming message
      final message = IncomingMessage(
        rumorId: rumorEvent.id,
        giftWrapId: giftWrapEvent.id,
        senderPubkey: rumorEvent.pubkey,
        content: rumorEvent.content,
        createdAt: rumorTimestampToDateTime(rumorEvent.createdAt),
        type: type,
        videoATag: videoATag,
        videoEventId: videoEventId,
      );

      Log.debug(
        'Decrypted DM from ${rumorEvent.pubkey}: $type',
        category: LogCategory.system,
      );

      return message;
    } catch (e, stackTrace) {
      Log.error(
        'Error processing gift wrap event: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      return null;
    }
  }

  /// Handle an incoming gift wrap event from the subscription
  Future<void> _handleGiftWrapEvent(Event giftWrapEvent) async {
    final message = await processGiftWrapEvent(giftWrapEvent);
    if (message != null) {
      _messageController.add(message);
    }
  }

  /// Initialize the Nostr instance for decryption
  void _initNostr() {
    if (_nostr != null) return;

    final privateKey = _keyManager.privateKey!;
    final publicKey = _keyManager.publicKey!;

    final signer = LocalNostrSigner(privateKey);

    _nostr = Nostr(
      signer,
      publicKey,
      [], // Empty filters - not using for subscriptions
      _dummyRelayGenerator,
    );
  }

  /// Dummy relay generator - not used for decryption
  Relay _dummyRelayGenerator(String url) {
    throw UnimplementedError(
      'Relay generation not needed for decryption-only Nostr instance',
    );
  }

  /// Parse dynamic tags list to List<List<String>>
  List<List<String>> _parseTags(List<dynamic> dynamicTags) {
    return dynamicTags.map((tag) {
      if (tag is List) {
        return tag.map((e) => e.toString()).toList();
      }
      return <String>[];
    }).toList();
  }

  /// Detect the message type based on rumor event tags
  ///
  /// Returns [DmMessageType.videoShare] if the rumor has an 'a' tag
  /// referencing kind 34236 (video events).
  static DmMessageType detectMessageType(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isEmpty) continue;

      // Check for 'a' tag referencing kind 34236
      if (tag[0] == 'a' && tag.length > 1) {
        final aTagValue = tag[1];
        if (aTagValue.startsWith('34236:')) {
          return DmMessageType.videoShare;
        }
      }
    }

    return DmMessageType.text;
  }

  /// Extract video 'a' tag if present
  ///
  /// Returns the 'a' tag value (e.g., "34236:pubkey:d-tag") or null
  static String? extractVideoATag(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isEmpty) continue;

      if (tag[0] == 'a' && tag.length > 1) {
        final aTagValue = tag[1];
        if (aTagValue.startsWith('34236:')) {
          return aTagValue;
        }
      }
    }

    return null;
  }

  /// Extract video event ID from 'e' tag if present
  ///
  /// Returns the first 'e' tag value or null
  static String? extractVideoEventId(List<List<String>> tags) {
    for (final tag in tags) {
      if (tag.isEmpty) continue;

      if (tag[0] == 'e' && tag.length > 1) {
        return tag[1];
      }
    }

    return null;
  }

  /// Convert a Unix timestamp (seconds) to DateTime
  static DateTime rumorTimestampToDateTime(int timestamp) {
    return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
  }

  /// Dispose the service and clean up resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _messageController.close();
    _seenRumorIds.clear();
    _nostr = null;
  }
}
