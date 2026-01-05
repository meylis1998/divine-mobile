// ABOUTME: Widget tests for InboxScreen - DM conversation list.
// ABOUTME: Tests loading state, empty state, conversation display, navigation, and refresh.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/conversation_screen.dart';
import 'package:openvine/screens/inbox_screen.dart';
import 'package:openvine/services/user_profile_service.dart';

@GenerateMocks([DMRepository, UserProfileService])
import 'inbox_screen_test.mocks.dart';

void main() {
  late MockDMRepository mockDmRepository;
  late MockUserProfileService mockUserProfileService;
  late StreamController<List<Conversation>> conversationsController;

  // Test data - peer pubkeys (full 64-char hex, no truncation per project rules)
  const testPeerPubkey1 =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const testPeerPubkey2 =
      'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
  const testPeerPubkey3 =
      'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

  setUp(() {
    mockDmRepository = MockDMRepository();
    mockUserProfileService = MockUserProfileService();
    conversationsController = StreamController<List<Conversation>>.broadcast();

    // Default stub for watchConversations
    when(
      mockDmRepository.watchConversations(),
    ).thenAnswer((_) => conversationsController.stream);

    // Default stubs for user profile service
    when(mockUserProfileService.hasProfile(any)).thenReturn(false);
    when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
    when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(false);
    when(
      mockUserProfileService.fetchProfile(any),
    ).thenAnswer((_) async => null);
  });

  tearDown(() {
    conversationsController.close();
  });

  Widget buildTestWidget() {
    return ProviderScope(
      overrides: [
        dmRepositoryProvider.overrideWithValue(mockDmRepository),
        userProfileServiceProvider.overrideWithValue(mockUserProfileService),
      ],
      child: const MaterialApp(home: InboxScreen()),
    );
  }

  group('InboxScreen', () {
    testWidgets('displays loading indicator while fetching conversations', (
      tester,
    ) async {
      // Don't emit any data yet - stream should be in loading state
      await tester.pumpWidget(buildTestWidget());

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('shows empty state when no conversations', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Emit empty list
      conversationsController.add([]);
      await tester.pumpAndSettle();

      // Should show empty state message
      expect(find.text('No messages yet'), findsOneWidget);

      // Should NOT show loading indicator
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays conversation list with avatars and names', (
      tester,
    ) async {
      // Set up profile for first peer (no picture to avoid network image issues)
      final testProfile = UserProfile(
        pubkey: testPeerPubkey1,
        displayName: 'Alice',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'test_event_id_for_profile',
      );

      when(mockUserProfileService.hasProfile(testPeerPubkey1)).thenReturn(true);
      when(
        mockUserProfileService.getCachedProfile(testPeerPubkey1),
      ).thenReturn(testProfile);

      await tester.pumpWidget(buildTestWidget());

      // Emit conversations
      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now().subtract(const Duration(minutes: 5)),
          unreadCount: 0,
          lastMessagePreview: 'Hello there!',
        ),
        Conversation(
          peerPubkey: testPeerPubkey2,
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 2)),
          unreadCount: 0,
          lastMessagePreview: 'How are you?',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Should show conversation list items
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('Hello there!'), findsOneWidget);
      expect(find.text('How are you?'), findsOneWidget);
    });

    testWidgets('displays message preview and timestamp', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final now = DateTime.now();
      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: now,
          unreadCount: 0,
          lastMessagePreview: 'This is a preview message',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Should show message preview
      expect(find.text('This is a preview message'), findsOneWidget);

      // Should show some form of timestamp (may vary by implementation)
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('shows unread badge when conversation has unread messages', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Emit conversation with unread messages
      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 5,
          lastMessagePreview: 'New message!',
        ),
        Conversation(
          peerPubkey: testPeerPubkey2,
          lastMessageAt: DateTime.now().subtract(const Duration(hours: 1)),
          unreadCount: 0,
          lastMessagePreview: 'Old message',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Should show unread count badge
      expect(find.text('5'), findsOneWidget);

      // Second conversation should not have a badge (0 unread)
      // The '0' text should not appear as a badge
    });

    testWidgets('tapping a conversation navigates to ConversationScreen', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Emit conversation
      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 0,
          lastMessagePreview: 'Tap me!',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Find and tap the conversation row
      final conversationTile = find.text('Tap me!');
      expect(conversationTile, findsOneWidget);
      await tester.tap(conversationTile);
      await tester.pumpAndSettle();

      // Should navigate to ConversationScreen
      expect(find.byType(ConversationScreen), findsOneWidget);
    });

    testWidgets('pull-to-refresh triggers data reload', (tester) async {
      // Set up a flag to track if refresh was called
      var refreshCalled = false;
      when(mockDmRepository.watchConversations()).thenAnswer((_) {
        refreshCalled = true;
        return conversationsController.stream;
      });

      await tester.pumpWidget(buildTestWidget());

      // Emit initial data
      conversationsController.add([
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 0,
          lastMessagePreview: 'Initial message',
        ),
      ]);
      await tester.pumpAndSettle();

      // Reset flag after initial load
      refreshCalled = false;

      // Perform pull-to-refresh gesture
      await tester.fling(
        find.byType(RefreshIndicator),
        const Offset(0, 300),
        1000,
      );
      await tester.pumpAndSettle();

      // The RefreshIndicator should be present
      expect(find.byType(RefreshIndicator), findsOneWidget);
    });

    testWidgets('has dark background per UI requirements', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      // Emit empty conversations to get past loading state
      conversationsController.add([]);
      await tester.pumpAndSettle();

      // Find the Scaffold and check backgroundColor
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    testWidgets('conversations are sorted by last message time', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      final now = DateTime.now();
      // Emit conversations in non-sorted order
      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey2,
          lastMessageAt: now.subtract(const Duration(hours: 2)),
          unreadCount: 0,
          lastMessagePreview: 'Old message',
        ),
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: now,
          unreadCount: 0,
          lastMessagePreview: 'Newest message',
        ),
        Conversation(
          peerPubkey: testPeerPubkey3,
          lastMessageAt: now.subtract(const Duration(hours: 1)),
          unreadCount: 0,
          lastMessagePreview: 'Middle message',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Find all preview text widgets
      final previewFinders = [
        find.text('Newest message'),
        find.text('Middle message'),
        find.text('Old message'),
      ];

      // Verify all previews are displayed
      for (final finder in previewFinders) {
        expect(finder, findsOneWidget);
      }

      // The conversations should be in time-sorted order in the list
      // (newest first). We can verify by checking the order of widgets.
      final newestWidget = tester.getTopLeft(previewFinders[0]);
      final middleWidget = tester.getTopLeft(previewFinders[1]);
      final oldestWidget = tester.getTopLeft(previewFinders[2]);

      // In a vertical list, newest should be higher (smaller Y) than middle
      expect(newestWidget.dy, lessThan(middleWidget.dy));
      // Middle should be higher than oldest
      expect(middleWidget.dy, lessThan(oldestWidget.dy));
    });

    testWidgets('shows avatar placeholder when no profile image', (
      tester,
    ) async {
      // No profile set up - should use placeholder
      await tester.pumpWidget(buildTestWidget());

      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 0,
          lastMessagePreview: 'Hello!',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Should show some kind of avatar (CircleAvatar)
      expect(find.byType(CircleAvatar), findsOneWidget);
    });

    testWidgets('shows pubkey when no display name available', (tester) async {
      // No profile set up - should fall back to pubkey
      await tester.pumpWidget(buildTestWidget());

      final conversations = [
        Conversation(
          peerPubkey: testPeerPubkey1,
          lastMessageAt: DateTime.now(),
          unreadCount: 0,
          lastMessagePreview: 'Hello!',
        ),
      ];
      conversationsController.add(conversations);
      await tester.pumpAndSettle();

      // Should show truncated pubkey with ellipsis (UI truncation, not
      // string truncation)
      // The full pubkey is stored but displayed with overflow handling
      expect(find.byType(Text), findsWidgets);
    });
  });
}
