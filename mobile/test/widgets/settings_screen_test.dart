// ABOUTME: Widget test for unified settings screen
// ABOUTME: Verifies settings navigation and UI structure

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/screens/settings_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';

@GenerateMocks([AuthService])
import 'settings_screen_test.mocks.dart';

void main() {
  group('SettingsScreen Tests', () {
    late MockAuthService mockAuthService;

    setUp(() {
      mockAuthService = MockAuthService();
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    testWidgets('Settings screen displays all sections', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify section headers (displayed as uppercase)
      expect(find.text('PROFILE'), findsOneWidget);
      expect(find.text('NETWORK'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Settings tiles display correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify profile settings
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Key Management'), findsOneWidget);

      // Verify network settings
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Relay Diagnostics'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);

      // CRITICAL: P2P Sync should be hidden for release
      expect(find.text('P2P Sync'), findsNothing);
      expect(find.text('Peer-to-peer synchronization settings'), findsNothing);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Settings tiles have proper icons', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Verify icons exist
      expect(find.byIcon(Icons.person), findsWidgets); // Edit Profile
      expect(find.byIcon(Icons.key), findsWidgets); // Key Management
      expect(find.byIcon(Icons.hub), findsWidgets); // Relays
      expect(
        find.byIcon(Icons.troubleshoot),
        findsWidgets,
      ); // Relay Diagnostics
      expect(find.byIcon(Icons.cloud_upload), findsWidgets); // Media Servers

      // CRITICAL: P2P Sync icon (Icons.sync) should be hidden for release
      expect(find.byIcon(Icons.sync), findsNothing);
      // TODO(any): Fix and re-enable these tests
    }, skip: true);

    testWidgets('Settings screen reorganizes dev and danger items', (
      tester,
    ) async {
      // Developer mode is disabled by default (EnvironmentService not initialized)
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentProfile).thenReturn(null);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Let async version loader settle (PackageInfo)
      await tester.pumpAndSettle();

      // Sanity check: authenticated sections and core network tiles render
      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Log Out'), findsOneWidget);
      expect(find.text('Relays'), findsOneWidget);
      expect(find.text('Media Servers'), findsOneWidget);

      Future<void> scrollUntilBuilt(Finder target) async {
        final listFinder = find.byType(ListView);
        for (var i = 0; i < 30 && target.evaluate().isEmpty; i++) {
          await tester.drag(listFinder, const Offset(0, -300));
          await tester.pump();
        }
      }

      // Dev options should be visible even when developer mode is off
      await scrollUntilBuilt(find.text('Developer Options'));
      expect(find.text('Developer Options'), findsOneWidget);

      // Destructive account actions should be moved to a bottom "Danger Zone"
      await scrollUntilBuilt(find.text('DANGER ZONE'));
      expect(find.text('DANGER ZONE'), findsOneWidget);

      await scrollUntilBuilt(find.text('Remove Keys from Device'));
      expect(find.text('Remove Keys from Device'), findsOneWidget);

      await scrollUntilBuilt(find.text('Delete Account and Data'));
      expect(find.text('Delete Account and Data'), findsOneWidget);

      // Ensure ordering: Danger Zone is below Support
      await scrollUntilBuilt(find.text('Save Logs'));
      final supportY = tester.getTopLeft(find.text('SUPPORT')).dy;

      await scrollUntilBuilt(find.text('DANGER ZONE'));
      final dangerY = tester.getTopLeft(find.text('DANGER ZONE')).dy;
      expect(dangerY, greaterThan(supportY));
    });

    testWidgets('App bar displays correctly', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      expect(find.text('Settings'), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, isNotNull);
    });
  });
}
