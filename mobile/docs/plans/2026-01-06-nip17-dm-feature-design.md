# NIP-17 Direct Messages Feature Design

## Overview

Add support for sending, receiving, and viewing encrypted direct messages using NIP-17 (gift-wrapped private messages). Extends the existing "send video to person" functionality into a full messaging experience.

## Protocol Summary

NIP-17 uses three-layer encryption for privacy:
1. **Kind 14** (rumor) - unsigned message content
2. **Kind 13** (seal) - signed and encrypted by sender
3. **Kind 1059** (gift wrap) - wrapped with ephemeral key for anonymity

Optional **kind 10050** specifies user's preferred DM relays (not required - defaults to normal relays).

## Existing Infrastructure

- `NIP17MessageService` - already handles sending gift-wrapped messages
- "Send video to person" feature already uses this service
- Relay infrastructure already in place

## New Components

### 1. NIP17InboxService

**Purpose**: Receive and decrypt incoming gift-wrapped messages.

**Location**: `lib/services/nip17_inbox_service.dart`

**Responsibilities**:
- Subscribe to kind 1059 events addressed to current user's pubkey
- Decrypt gift wrap → unseal → extract kind 14 rumor content
- Parse message content (text, video references, etc.)
- Emit stream of `IncomingMessage` objects
- Handle reconnection and missed messages

**Key methods**:
```dart
Stream<IncomingMessage> get incomingMessages;
Future<void> startListening();
Future<void> stopListening();
Future<List<IncomingMessage>> fetchHistory({DateTime? since});
```

### 2. DMRepository

**Purpose**: Local storage and state management for conversations.

**Location**: `lib/repositories/dm_repository.dart`

**Database tables** (Drift):

```dart
// Conversation metadata
class DmConversations extends Table {
  TextColumn get peerPubkey => text()();  // Other party's pubkey
  DateTimeColumn get lastMessageAt => dateTime()();
  IntColumn get unreadCount => integer().withDefault(const Constant(0))();
  TextColumn get lastMessagePreview => text().nullable()();

  @override
  Set<Column> get primaryKey => {peerPubkey};
}

// Individual messages
class DmMessages extends Table {
  TextColumn get id => text()();  // Event ID
  TextColumn get peerPubkey => text()();  // Conversation partner
  TextColumn get senderPubkey => text()();  // Who sent it
  TextColumn get content => text()();  // Decrypted content
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get isRead => boolean().withDefault(const Constant(false))();
  TextColumn get messageType => text().withDefault(const Constant('text'))();  // text, video
  TextColumn get metadata => text().nullable()();  // JSON for video refs, etc.

  @override
  Set<Column> get primaryKey => {id};
}
```

**Key methods**:
```dart
Stream<List<Conversation>> watchConversations();
Stream<List<DmMessage>> watchMessages(String peerPubkey);
Future<void> saveMessage(IncomingMessage message);
Future<void> markConversationRead(String peerPubkey);
Future<int> getUnreadCount();
```

### 3. DMProvider (Riverpod)

**Location**: `lib/providers/dm_provider.dart`

```dart
// Total unread count for badge
final unreadDmCountProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchUnreadCount();
});

// List of conversations
final conversationsProvider = StreamProvider<List<Conversation>>((ref) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchConversations();
});

// Messages for a specific conversation
final conversationMessagesProvider = StreamProvider.family<List<DmMessage>, String>((ref, peerPubkey) {
  final repo = ref.watch(dmRepositoryProvider);
  return repo.watchMessages(peerPubkey);
});
```

### 4. UI Screens

#### InboxScreen
**Location**: `lib/screens/inbox_screen.dart`

- List of conversations sorted by last message time
- Each row shows: avatar, display name, message preview, timestamp, unread badge
- Tap to open ConversationScreen
- Pull-to-refresh

#### ConversationScreen
**Location**: `lib/screens/conversation_screen.dart`

- Message thread with single user
- Minimal feed style (like video comments)
- Text messages displayed inline
- Shared videos displayed as tappable thumbnails
- Text input at bottom for composing
- Send button uses existing `NIP17MessageService`

### 5. Entry Points

1. **Notifications tab** - Add "Messages" as 6th tab
2. **Drawer menu** - Add "Messages" item with unread badge
3. **Profile screen** - Add "Message" button (for other users)
4. **Send video flow** - Already exists, opens conversation after send

## Message Types

### Text Message
```dart
class TextMessage {
  final String content;
}
```

### Video Share Message
```dart
class VideoShareMessage {
  final String? text;  // Optional caption
  final String videoEventId;  // Reference to kind 34236 event
  final String? videoUrl;  // Direct URL if available
}
```

Detected by presence of video reference tags in the kind 14 event.

## Relay Strategy

**Sending**:
1. Check recipient's kind 10050 for preferred relays
2. If found: send to their relays + our relays
3. If not found: send to our default relays (they'll receive on shared relays)

**Receiving**:
- Subscribe to kind 1059 on our normal relays
- No special inbox relay setup required by default
- Optional: user can configure dedicated DM relays in settings (publishes kind 10050)

## Read/Unread Tracking

- All local (no read receipts sent to sender)
- Messages marked read when conversation is opened
- Unread count shown as badge on Messages tab and drawer item
- Badge on individual conversation rows

## Implementation Order

1. **Database schema** - Add Drift tables for conversations and messages
2. **NIP17InboxService** - Receive and decrypt incoming messages
3. **DMRepository** - Local storage and queries
4. **Providers** - Riverpod providers for UI reactivity
5. **InboxScreen** - Conversation list UI
6. **ConversationScreen** - Message thread UI
7. **Entry points** - Add Messages tab, drawer item, profile button
8. **Polish** - Notifications, badges, edge cases

## Testing Strategy

- Unit tests for decryption logic
- Repository tests with mock database
- Widget tests for conversation UI
- Integration test for send/receive round-trip

## Future Considerations (Not in v1)

- Group DMs (NIP-17 supports this but adds complexity)
- Message reactions
- Read receipts (optional, privacy implications)
- Message deletion
- Media attachments beyond videos
- Push notifications for new DMs
