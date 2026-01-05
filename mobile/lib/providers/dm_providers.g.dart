// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'dm_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for NIP17InboxService instance.
///
/// Creates an inbox service for receiving and decrypting NIP-17 gift-wrapped DMs.
/// Requires [NostrKeyManager] and [NostrClient] dependencies.

@ProviderFor(nip17InboxService)
const nip17InboxServiceProvider = Nip17InboxServiceProvider._();

/// Provider for NIP17InboxService instance.
///
/// Creates an inbox service for receiving and decrypting NIP-17 gift-wrapped DMs.
/// Requires [NostrKeyManager] and [NostrClient] dependencies.

final class Nip17InboxServiceProvider
    extends
        $FunctionalProvider<
          NIP17InboxService,
          NIP17InboxService,
          NIP17InboxService
        >
    with $Provider<NIP17InboxService> {
  /// Provider for NIP17InboxService instance.
  ///
  /// Creates an inbox service for receiving and decrypting NIP-17 gift-wrapped DMs.
  /// Requires [NostrKeyManager] and [NostrClient] dependencies.
  const Nip17InboxServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip17InboxServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip17InboxServiceHash();

  @$internal
  @override
  $ProviderElement<NIP17InboxService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NIP17InboxService create(Ref ref) {
    return nip17InboxService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NIP17InboxService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NIP17InboxService>(value),
    );
  }
}

String _$nip17InboxServiceHash() => r'a3ae5f83436d03e06386d24b317717f4e22ce4c9';

/// Provider for DMRepository instance.
///
/// Creates a repository that bridges the inbox service and database.
/// Starts syncing incoming messages automatically.

@ProviderFor(dmRepository)
const dmRepositoryProvider = DmRepositoryProvider._();

/// Provider for DMRepository instance.
///
/// Creates a repository that bridges the inbox service and database.
/// Starts syncing incoming messages automatically.

final class DmRepositoryProvider
    extends $FunctionalProvider<DMRepository, DMRepository, DMRepository>
    with $Provider<DMRepository> {
  /// Provider for DMRepository instance.
  ///
  /// Creates a repository that bridges the inbox service and database.
  /// Starts syncing incoming messages automatically.
  const DmRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmRepositoryHash();

  @$internal
  @override
  $ProviderElement<DMRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DMRepository create(Ref ref) {
    return dmRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DMRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DMRepository>(value),
    );
  }
}

String _$dmRepositoryHash() => r'6af19e6e4aecc6f58d18983aad73af9d27946ac9';

/// Provider for total unread DM count across all conversations.
///
/// Used for displaying badge counts in the UI (e.g., DM tab badge).
/// Returns a stream that updates reactively when messages are read/received.

@ProviderFor(unreadDmCount)
const unreadDmCountProvider = UnreadDmCountProvider._();

/// Provider for total unread DM count across all conversations.
///
/// Used for displaying badge counts in the UI (e.g., DM tab badge).
/// Returns a stream that updates reactively when messages are read/received.

final class UnreadDmCountProvider
    extends $FunctionalProvider<AsyncValue<int>, int, Stream<int>>
    with $FutureModifier<int>, $StreamProvider<int> {
  /// Provider for total unread DM count across all conversations.
  ///
  /// Used for displaying badge counts in the UI (e.g., DM tab badge).
  /// Returns a stream that updates reactively when messages are read/received.
  const UnreadDmCountProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'unreadDmCountProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$unreadDmCountHash();

  @$internal
  @override
  $StreamProviderElement<int> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<int> create(Ref ref) {
    return unreadDmCount(ref);
  }
}

String _$unreadDmCountHash() => r'87fc6918840201f86e82eac031bdf716f4eb59da';

/// Provider for the list of all DM conversations.
///
/// Returns a stream of [Conversation] objects sorted by most recent message.
/// Used for the conversations list screen.

@ProviderFor(dmConversations)
const dmConversationsProvider = DmConversationsProvider._();

/// Provider for the list of all DM conversations.
///
/// Returns a stream of [Conversation] objects sorted by most recent message.
/// Used for the conversations list screen.

final class DmConversationsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<Conversation>>,
          List<Conversation>,
          Stream<List<Conversation>>
        >
    with
        $FutureModifier<List<Conversation>>,
        $StreamProvider<List<Conversation>> {
  /// Provider for the list of all DM conversations.
  ///
  /// Returns a stream of [Conversation] objects sorted by most recent message.
  /// Used for the conversations list screen.
  const DmConversationsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'dmConversationsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$dmConversationsHash();

  @$internal
  @override
  $StreamProviderElement<List<Conversation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<Conversation>> create(Ref ref) {
    return dmConversations(ref);
  }
}

String _$dmConversationsHash() => r'2b6efe6e5481abaeec6d1e5a38d53325683a9024';

/// Family provider for messages in a specific conversation.
///
/// Takes a [peerPubkey] parameter to identify the conversation partner.
/// Returns a stream of [DmMessage] objects sorted by creation time.

@ProviderFor(conversationMessages)
const conversationMessagesProvider = ConversationMessagesFamily._();

/// Family provider for messages in a specific conversation.
///
/// Takes a [peerPubkey] parameter to identify the conversation partner.
/// Returns a stream of [DmMessage] objects sorted by creation time.

final class ConversationMessagesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DmMessage>>,
          List<DmMessage>,
          Stream<List<DmMessage>>
        >
    with $FutureModifier<List<DmMessage>>, $StreamProvider<List<DmMessage>> {
  /// Family provider for messages in a specific conversation.
  ///
  /// Takes a [peerPubkey] parameter to identify the conversation partner.
  /// Returns a stream of [DmMessage] objects sorted by creation time.
  const ConversationMessagesProvider._({
    required ConversationMessagesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'conversationMessagesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$conversationMessagesHash();

  @override
  String toString() {
    return r'conversationMessagesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<DmMessage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DmMessage>> create(Ref ref) {
    final argument = this.argument as String;
    return conversationMessages(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ConversationMessagesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$conversationMessagesHash() =>
    r'20bee742773652df9e2f5b07e3c0cd086517f039';

/// Family provider for messages in a specific conversation.
///
/// Takes a [peerPubkey] parameter to identify the conversation partner.
/// Returns a stream of [DmMessage] objects sorted by creation time.

final class ConversationMessagesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<DmMessage>>, String> {
  const ConversationMessagesFamily._()
    : super(
        retry: null,
        name: r'conversationMessagesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Family provider for messages in a specific conversation.
  ///
  /// Takes a [peerPubkey] parameter to identify the conversation partner.
  /// Returns a stream of [DmMessage] objects sorted by creation time.

  ConversationMessagesProvider call(String peerPubkey) =>
      ConversationMessagesProvider._(argument: peerPubkey, from: this);

  @override
  String toString() => r'conversationMessagesProvider';
}

/// Provider for NIP17MessageService instance.
///
/// Creates a message service for sending encrypted NIP-17 gift-wrapped DMs.
/// Requires [NostrKeyManager] and [NostrClient] dependencies.

@ProviderFor(nip17MessageService)
const nip17MessageServiceProvider = Nip17MessageServiceProvider._();

/// Provider for NIP17MessageService instance.
///
/// Creates a message service for sending encrypted NIP-17 gift-wrapped DMs.
/// Requires [NostrKeyManager] and [NostrClient] dependencies.

final class Nip17MessageServiceProvider
    extends
        $FunctionalProvider<
          NIP17MessageService,
          NIP17MessageService,
          NIP17MessageService
        >
    with $Provider<NIP17MessageService> {
  /// Provider for NIP17MessageService instance.
  ///
  /// Creates a message service for sending encrypted NIP-17 gift-wrapped DMs.
  /// Requires [NostrKeyManager] and [NostrClient] dependencies.
  const Nip17MessageServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nip17MessageServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nip17MessageServiceHash();

  @$internal
  @override
  $ProviderElement<NIP17MessageService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  NIP17MessageService create(Ref ref) {
    return nip17MessageService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NIP17MessageService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NIP17MessageService>(value),
    );
  }
}

String _$nip17MessageServiceHash() =>
    r'370a4e40b2233c915f86977f4c89d4b1cadbd920';
