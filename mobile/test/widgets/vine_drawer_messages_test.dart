// ABOUTME: Tests for Messages entry point in the VineDrawer.
// ABOUTME: Verifies Messages item is visible with unread badge when applicable.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/dm_providers.dart';
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
      when(mockAuthService.currentPublicKeyHex).thenReturn(
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2',
      );

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

      // Check that no badge with count "0" is shown
      expect(
        find.text('0'),
        findsNothing,
        reason: 'Badge should not show when count is 0',
      );
    });

    testWidgets('Tapping Messages navigates to InboxScreen', (tester) async {
      final scaffoldKey = GlobalKey<ScaffoldState>();
      var navigatedToMessages = false;

      // Create a GoRouter that tracks navigation to /messages
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              key: scaffoldKey,
              drawer: const VineDrawer(),
              body: const Center(child: Text('Test')),
            ),
          ),
          GoRoute(
            path: '/messages',
            builder: (context, state) {
              navigatedToMessages = true;
              // Return a simple page to verify navigation
              return const Scaffold(body: Text('Messages Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWith((ref) => mockAuthService),
            unreadDmCountProvider.overrideWith(
              (ref) => unreadCountController.stream,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
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

      // Verify navigation occurred to /messages route
      expect(
        navigatedToMessages,
        isTrue,
        reason: 'Should navigate to /messages when Messages is tapped',
      );
      expect(
        find.text('Messages Screen'),
        findsOneWidget,
        reason: 'Messages Screen should be visible after navigation',
      );
    });
  });
}
