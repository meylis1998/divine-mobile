// ABOUTME: Tests for NewConversationScreen - contact picker for starting DMs.
// ABOUTME: Verifies contact list display, search functionality, and user selection.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/repositories/follow_repository.dart';
import 'package:openvine/screens/new_conversation_screen.dart';
import 'package:openvine/services/user_profile_service.dart';

@GenerateMocks([FollowRepository, UserProfileService])
import 'new_conversation_screen_test.mocks.dart';

void main() {
  late MockFollowRepository mockFollowRepository;
  late MockUserProfileService mockUserProfileService;

  // Test pubkeys
  const testPubkey1 =
      'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
  const testPubkey2 =
      'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
  const testPubkey3 =
      'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';

  setUp(() {
    mockFollowRepository = MockFollowRepository();
    mockUserProfileService = MockUserProfileService();

    // Default setup - no following
    when(mockFollowRepository.followingPubkeys).thenReturn([]);

    // Default profile service behavior
    when(mockUserProfileService.getCachedProfile(any)).thenReturn(null);
    when(mockUserProfileService.hasProfile(any)).thenReturn(false);
    when(mockUserProfileService.shouldSkipProfileFetch(any)).thenReturn(false);

    // Default streaming search behavior - return empty stream that completes
    when(
      mockUserProfileService.searchUsersStream(any, limit: anyNamed('limit')),
    ).thenAnswer((_) {
      final controller = StreamController<UserProfile>();
      // Close immediately to signal completion
      controller.close();
      return controller.stream;
    });
  });

  // Helper to create test profiles with required fields
  UserProfile createTestProfile({
    required String pubkey,
    String? name,
    String? displayName,
  }) {
    return UserProfile(
      pubkey: pubkey,
      rawData: const <String, dynamic>{},
      createdAt: DateTime.now(),
      eventId: 'test-event-$pubkey',
      name: name,
      displayName: displayName,
    );
  }

  Widget buildTestWidget({
    List<String> followingPubkeys = const [],
    Map<String, UserProfile> profiles = const {},
  }) {
    when(mockFollowRepository.followingPubkeys).thenReturn(followingPubkeys);

    for (final entry in profiles.entries) {
      when(
        mockUserProfileService.getCachedProfile(entry.key),
      ).thenReturn(entry.value);
      when(mockUserProfileService.hasProfile(entry.key)).thenReturn(true);
    }

    return ProviderScope(
      overrides: [
        followRepositoryProvider.overrideWithValue(mockFollowRepository),
        userProfileServiceProvider.overrideWithValue(mockUserProfileService),
        // Override the profile fetch provider to return profiles synchronously
        fetchUserProfileProvider.overrideWith((ref, pubkey) {
          return profiles[pubkey];
        }),
      ],
      child: const MaterialApp(home: NewConversationScreen()),
    );
  }

  group('NewConversationScreen', () {
    testWidgets('displays screen with search field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Verify search field is present (title and back button are now in AppShell)
      expect(find.byKey(const Key('new_conversation_input')), findsOneWidget);
    });

    testWidgets('shows empty state when no contacts', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should show no contacts message
      expect(find.text('No contacts yet'), findsOneWidget);
      expect(
        find.text('Follow users to see them here,\nor search by name above'),
        findsOneWidget,
      );
    });

    testWidgets('shows followed users when available', (tester) async {
      final testProfile1 = createTestProfile(
        pubkey: testPubkey1,
        name: 'Alice',
        displayName: 'Alice Anderson',
      );
      final testProfile2 = createTestProfile(
        pubkey: testPubkey2,
        name: 'Bob',
        displayName: 'Bob Builder',
      );

      await tester.pumpWidget(
        buildTestWidget(
          followingPubkeys: [testPubkey1, testPubkey2],
          profiles: {testPubkey1: testProfile1, testPubkey2: testProfile2},
        ),
      );
      await tester.pumpAndSettle();

      // Should show section header
      expect(find.text('People you follow'), findsOneWidget);

      // Should show user names
      expect(find.text('Alice Anderson'), findsOneWidget);
      expect(find.text('Bob Builder'), findsOneWidget);
    });

    testWidgets('has paste button', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should have paste button
      expect(find.byIcon(Icons.paste), findsOneWidget);
    });

    testWidgets('has search icon in input field', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should have search icon
      expect(find.byIcon(Icons.search), findsOneWidget);
    });

    testWidgets('shows correct hint text', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Check hint text
      final textField = tester.widget<TextField>(
        find.byKey(const Key('new_conversation_input')),
      );
      expect(textField.decoration?.hintText, 'Search by name or paste npub...');
    });

    testWidgets('shows search results when typing', (tester) async {
      final testProfile = createTestProfile(
        pubkey: testPubkey1,
        name: 'Alice',
        displayName: 'Alice Anderson',
      );

      await tester.pumpWidget(
        buildTestWidget(
          followingPubkeys: [testPubkey1, testPubkey2, testPubkey3],
          profiles: {
            testPubkey1: testProfile,
            testPubkey2: createTestProfile(pubkey: testPubkey2, name: 'Bob'),
            testPubkey3: createTestProfile(
              pubkey: testPubkey3,
              name: 'Charlie',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Should show all followed users initially
      expect(find.text('Alice Anderson'), findsOneWidget);
      expect(find.text('Bob'), findsOneWidget);
      expect(find.text('Charlie'), findsOneWidget);

      // Type search query
      await tester.enterText(
        find.byKey(const Key('new_conversation_input')),
        'alice',
      );

      // Wait for debounce
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle();

      // Should only show Alice now
      expect(find.text('Alice Anderson'), findsOneWidget);
    });

    testWidgets('shows no results message when search has no matches', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildTestWidget(
          followingPubkeys: [testPubkey1],
          profiles: {
            testPubkey1: createTestProfile(
              pubkey: testPubkey1,
              name: 'Alice',
              displayName: 'Alice Anderson',
            ),
          },
        ),
      );
      await tester.pumpAndSettle();

      // Type search query that won't match
      await tester.enterText(
        find.byKey(const Key('new_conversation_input')),
        'xyz123nomatch',
      );

      // Wait for debounce timer to fire and stream to complete
      await tester.pump(const Duration(milliseconds: 350));
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      // Should show no results message
      expect(find.text('No users found for "xyz123nomatch"'), findsOneWidget);
    });

    testWidgets('shows npub format when profile not loaded', (tester) async {
      // Don't provide profile for this pubkey
      await tester.pumpWidget(
        buildTestWidget(followingPubkeys: [testPubkey1], profiles: const {}),
      );
      await tester.pumpAndSettle();

      // Should show npub format (truncated) not hex
      // The npub starts with "npub1" and we show first 12 + ... + last 8
      expect(find.textContaining('npub1'), findsOneWidget);
    });
  });
}
