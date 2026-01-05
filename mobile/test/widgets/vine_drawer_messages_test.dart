// ABOUTME: Tests for Messages entry point in the VineDrawer.
// ABOUTME: Verifies Messages item is visible with unread badge when applicable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/dm_providers.dart';
import 'package:openvine/screens/inbox_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/vine_drawer.dart';

import 'vine_drawer_messages_test.mocks.dart';

@GenerateMocks([AuthService])
void main() {
  group('VineDrawer Messages Entry Point', () {
    late MockAuthService mockAuthService;
    late StreamController<int> unreadCountController;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(
        mockAuthService.currentPublicKeyHex,
      ).thenReturn('test_pubkey_' + '0' * 54);

      unreadCountController = StreamController<int>();
    });

    tearDown(() {
      unreadCountController.close();
    });

    testWidgets('Messages item is visible in drawer', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            unreadDmCountProvider.overrideWith(
              (ref) => unreadCountController.stream,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Open the drawer
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify Messages item is present
      expect(
        find.text('Messages'),
        findsOneWidget,
        reason: 'Messages menu item should be visible in drawer',
      );

      // Verify it has the chat icon
      expect(
        find.byIcon(Icons.chat_bubble_outline),
        findsOneWidget,
        reason: 'Messages item should have chat bubble icon',
      );
    });

    testWidgets('Messages item shows unread badge when count > 0', (
      tester,
    ) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            unreadDmCountProvider.overrideWith(
              (ref) => unreadCountController.stream,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Emit unread count before opening drawer
      unreadCountController.add(5);
      await tester.pump();

      // Open the drawer
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Verify badge is shown with count
      expect(
        find.text('5'),
        findsOneWidget,
        reason: 'Unread badge should show count of 5',
      );
    });

    testWidgets('Messages item shows no badge when unread count is 0', (
      tester,
    ) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            unreadDmCountProvider.overrideWith(
              (ref) => unreadCountController.stream,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
        ),
      );

      // Emit zero unread count
      unreadCountController.add(0);
      await tester.pump();

      // Open the drawer
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Find the Messages item key to scope badge search
      final messagesItemFinder = find.byKey(const Key('drawer-messages-item'));
      expect(messagesItemFinder, findsOneWidget);

      // There should be no badge container within the Messages item
      // The badge container has a specific decoration
      final badgeFinder = find.descendant(
        of: messagesItemFinder,
        matching: find.byType(Container),
      );

      // Check that no badge with count "0" is shown
      expect(
        find.text('0'),
        findsNothing,
        reason: 'Badge should not show when count is 0',
      );
    });

    testWidgets('Tapping Messages navigates to InboxScreen', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();
      var navigatedToInbox = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            unreadDmCountProvider.overrideWith(
              (ref) => unreadCountController.stream,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
            onGenerateRoute: (settings) {
              // Catch navigation to InboxScreen
              return MaterialPageRoute<void>(
                builder: (context) {
                  if (settings.name == '/inbox' ||
                      settings.arguments is InboxScreen) {
                    navigatedToInbox = true;
                  }
                  return const Scaffold(body: Text('Navigation Target'));
                },
              );
            },
          ),
        ),
      );

      // Emit initial count
      unreadCountController.add(0);
      await tester.pump();

      // Open the drawer
      scaffoldKey.currentState!.openDrawer();
      await tester.pumpAndSettle();

      // Tap the Messages item
      await tester.tap(find.text('Messages'));
      await tester.pumpAndSettle();

      // Verify navigation occurred (drawer closed + InboxScreen pushed)
      // We check by looking for InboxScreen in the widget tree
      expect(
        find.byType(InboxScreen),
        findsOneWidget,
        reason: 'Should navigate to InboxScreen when Messages is tapped',
      );
    });
  });
}
