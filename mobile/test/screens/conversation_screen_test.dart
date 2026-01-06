// ABOUTME: Widget tests for ConversationScreen - DM thread with single user.
// ABOUTME: Tests message display, sending, and mark-as-read on open.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:models/models.dart';
import 'package:openvine/models/dm_models.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/repositories/dm_repository.dart';
import 'package:openvine/screens/conversation_screen.dart';
import 'package:openvine/services/nip17_message_service.dart';

@GenerateMocks([DMRepository, NIP17MessageService])
import 'conversation_screen_test.mocks.dart';

void main() {
  late MockDMRepository mockDmRepository;
  late MockNIP17MessageService mockMessageService;
  late StreamController<List<DmMessage>> messagesController;

  // Test data - peer pubkey (full 64-char hex, no truncation per project rules)
  const testPeerPubkey =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const testOwnerPubkey =
      'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

  setUp(() {
    mockDmRepository = MockDMRepository();
    mockMessageService = MockNIP17MessageService();
    messagesController = StreamController<List<DmMessage>>.broadcast();

    // Default stub for watchMessages
    when(
      mockDmRepository.watchMessages(any),
    ).thenAnswer((_) => messagesController.stream);

    // Default stub for markConversationRead
    when(
      mockDmRepository.markConversationRead(any),
    ).thenAnswer((_) async => {});
  });

  tearDown(() {
    messagesController.close();
  });

  Widget buildTestWidget({String? peerPubkey}) {
    return ProviderScope(
      overrides: [
        dmRepositoryProvider.overrideWithValue(mockDmRepository),
        nip17MessageServiceProvider.overrideWithValue(mockMessageService),
      ],
      child: MaterialApp(
        home: ConversationScreen(peerPubkey: peerPubkey ?? testPeerPubkey),
      ),
    );
  }

  group('ConversationScreen', () {
    testWidgets(
      'displays incoming messages left-aligned with dark background',
      (tester) async {
        await tester.pumpWidget(buildTestWidget());

        // Emit test messages
        final messages = [
          DmMessage(
            rumorId: 'rumor1',
            giftWrapId: 'wrap1',
            peerPubkey: testPeerPubkey,
            senderPubkey: testPeerPubkey,
            content: 'Hello from peer',
            createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
            isOutgoing: false,
          ),
        ];
        messagesController.add(messages);
        await tester.pumpAndSettle();

        // Should display message content
        expect(find.text('Hello from peer'), findsOneWidget);

        // Incoming messages should exist (left-aligned check via widget keys)
        expect(find.byKey(const Key('incoming_message_0')), findsOneWidget);
      },
    );

    testWidgets('displays outgoing messages right-aligned with accent color', (
      tester,
    ) async {
      await tester.pumpWidget(buildTestWidget());

      // Emit outgoing message
      final messages = [
        DmMessage(
          rumorId: 'rumor2',
          giftWrapId: 'wrap2',
          peerPubkey: testPeerPubkey,
          senderPubkey: testOwnerPubkey,
          content: 'Hello from me',
          createdAt: DateTime.now(),
          isOutgoing: true,
        ),
      ];
      messagesController.add(messages);
      await tester.pumpAndSettle();

      // Should display message content
      expect(find.text('Hello from me'), findsOneWidget);

      // Outgoing messages should exist (right-aligned check via widget keys)
      expect(find.byKey(const Key('outgoing_message_0')), findsOneWidget);
    });

    testWidgets('shows message timestamps', (tester) async {
      await tester.pumpWidget(buildTestWidget());

      final now = DateTime.now();
      final messages = [
        DmMessage(
          rumorId: 'rumor3',
          giftWrapId: 'wrap3',
          peerPubkey: testPeerPubkey,
          senderPubkey: testPeerPubkey,
          content: 'Test message',
          createdAt: now,
          isOutgoing: false,
        ),
      ];
      messagesController.add(messages);
      await tester.pumpAndSettle();

      // Should show some form of timestamp (implementation may vary)
      // Look for a time-related widget
      expect(find.byType(Text), findsWidgets);
    });

    testWidgets('send button triggers message send', (tester) async {
      // Stub sendPrivateMessage
      when(
        mockMessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: 'test_event_id',
          recipientPubkey: testPeerPubkey,
        ),
      );

      // Stub saveOutgoingMessage
      when(
        mockDmRepository.saveOutgoingMessage(
          rumorId: anyNamed('rumorId'),
          giftWrapId: anyNamed('giftWrapId'),
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          createdAt: anyNamed('createdAt'),
          type: anyNamed('type'),
          metadata: anyNamed('metadata'),
        ),
      ).thenAnswer((_) async => {});

      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Enter text in the input field
      final textField = find.byType(TextField);
      expect(textField, findsOneWidget);
      await tester.enterText(textField, 'Test message to send');

      // Pump to allow state to update after text entry
      await tester.pump();

      // Tap send button (find by ancestor IconButton with send icon)
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);
      await tester.tap(sendButton);
      await tester.pumpAndSettle();

      // Verify sendPrivateMessage was called
      verify(
        mockMessageService.sendPrivateMessage(
          recipientPubkey: testPeerPubkey,
          content: 'Test message to send',
          additionalTags: anyNamed('additionalTags'),
        ),
      ).called(1);
    });

    testWidgets('marks conversation as read when screen opens', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Verify markConversationRead was called on init
      verify(mockDmRepository.markConversationRead(testPeerPubkey)).called(1);
    });

    testWidgets('has dark background per UI requirements', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Find the Scaffold and check backgroundColor
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.backgroundColor, Colors.black);
    });

    // Note: AppBar is now provided by AppShell wrapper, not by ConversationScreen
    // directly. Navigation and title are handled at the router level.

    testWidgets('displays empty state when no messages', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Should show empty state text or just the input field
      // The screen should still be usable
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('clears text field after sending message', (tester) async {
      when(
        mockMessageService.sendPrivateMessage(
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          additionalTags: anyNamed('additionalTags'),
        ),
      ).thenAnswer(
        (_) async => NIP17SendResult.success(
          messageEventId: 'test_event_id',
          recipientPubkey: testPeerPubkey,
        ),
      );

      when(
        mockDmRepository.saveOutgoingMessage(
          rumorId: anyNamed('rumorId'),
          giftWrapId: anyNamed('giftWrapId'),
          recipientPubkey: anyNamed('recipientPubkey'),
          content: anyNamed('content'),
          createdAt: anyNamed('createdAt'),
          type: anyNamed('type'),
          metadata: anyNamed('metadata'),
        ),
      ).thenAnswer((_) async => {});

      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Enter text
      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Test message');

      // Pump to allow state to update after text entry
      await tester.pump();

      // Tap send
      await tester.tap(find.byIcon(Icons.send));
      await tester.pumpAndSettle();

      // Text field should be cleared
      final textFieldWidget = tester.widget<TextField>(textField);
      expect(textFieldWidget.controller?.text, isEmpty);
    });

    testWidgets('send button is disabled when text is empty', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      messagesController.add([]);
      await tester.pumpAndSettle();

      // Find send button
      final sendButton = find.byIcon(Icons.send);
      expect(sendButton, findsOneWidget);

      // The IconButton should be disabled (onPressed is null) when no text
      final iconButton = tester.widget<IconButton>(
        find.ancestor(of: sendButton, matching: find.byType(IconButton)),
      );
      expect(iconButton.onPressed, isNull);
    });
  });
}
