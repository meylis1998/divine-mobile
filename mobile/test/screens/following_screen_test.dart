// ABOUTME: Widget tests for FollowingScreen UI states and styling
// ABOUTME: Tests loading, data, and empty states; AppBar and Scaffold styling

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/following_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/theme/vine_theme.dart';

class MockAuthService extends Mock implements AuthService {}

class MockSocialService extends Mock implements SocialService {}

class MockUserProfileService extends Mock implements UserProfileService {}

void main() {
  // Helper to create valid hex pubkeys (64 hex characters)
  String validPubkey(String suffix) {
    final hexSuffix = suffix.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join();
    return hexSuffix.padLeft(64, '0');
  }

  late MockAuthService mockAuthService;
  late MockSocialService mockSocialService;
  late MockUserProfileService mockUserProfileService;

  setUp(() {
    mockAuthService = MockAuthService();
    mockSocialService = MockSocialService();
    mockUserProfileService = MockUserProfileService();
  });

  /// Creates test widget with mocked services.
  /// The real FollowingListNotifier runs and fetches data from mocked services.
  Widget createTestWidget({
    required String pubkey,
    required List<String> followingList,
    String displayName = 'Test User',
  }) {
    // Configure auth service - viewing another user's following list
    final currentUserPubkey = validPubkey('current_user');
    when(() => mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);
    when(() => mockAuthService.isAuthenticated).thenReturn(true);

    // Configure social service to return following list
    when(() => mockSocialService.getFollowingListForUser(pubkey))
        .thenAnswer((_) => Stream.value(followingList));

    // Configure social service for isFollowing checks (used by UserProfileTile)
    when(() => mockSocialService.isFollowing(any())).thenReturn(false);

    // Configure user profile service for UserProfileTile
    when(() => mockUserProfileService.getCachedProfile(any())).thenReturn(null);
    when(() => mockUserProfileService.fetchProfile(any()))
        .thenAnswer((_) async => null);

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        socialServiceProvider.overrideWithValue(mockSocialService),
        userProfileServiceProvider.overrideWithValue(mockUserProfileService),
      ],
      child: MaterialApp(
        home: FollowingScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }

  group('FollowingScreen', () {
    group('loading state', () {
      testWidgets('displays loading indicator while fetching', (tester) async {
        final pubkey = validPubkey('test');

        // Configure auth service
        final currentUserPubkey = validPubkey('current_user');
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(currentUserPubkey);

        // Use a Completer that never completes to simulate perpetual loading
        final neverCompletes = Completer<List<String>>();
        when(() => mockSocialService.getFollowingListForUser(pubkey))
            .thenAnswer((_) => Stream.fromFuture(neverCompletes.future));

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              socialServiceProvider.overrideWithValue(mockSocialService),
            ],
            child: MaterialApp(
              home: FollowingScreen(pubkey: pubkey, displayName: 'Test User'),
            ),
          ),
        );

        // Single pump shows loading state before stream emits
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('data state', () {
      testWidgets('displays following list when data available', (tester) async {
        final pubkey = validPubkey('test');
        final following = [
          validPubkey('following1'),
          validPubkey('following2'),
          validPubkey('following3'),
        ];

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: following),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
      });

      testWidgets('shows empty state when following list is empty', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: []),
        );
        await tester.pumpAndSettle();

        expect(find.text('Not following anyone yet'), findsOneWidget);
        expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
        expect(find.byType(ListView), findsNothing);
      });
    });

    group('AppBar', () {
      testWidgets('displays correct title with display name', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(
            pubkey: pubkey,
            followingList: [],
            displayName: 'Alice',
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text("Alice's Following"), findsOneWidget);
      });

      testWidgets('has vineGreen background color', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: []),
        );
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.backgroundColor, VineTheme.vineGreen);
      });

      testWidgets('has white foreground color', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: []),
        );
        await tester.pumpAndSettle();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        expect(appBar.foregroundColor, Colors.white);
      });

      testWidgets('has back button', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: []),
        );
        await tester.pumpAndSettle();

        expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      });
    });

    group('Scaffold', () {
      testWidgets('has dark (black) background', (tester) async {
        final pubkey = validPubkey('test');

        await tester.pumpWidget(
          createTestWidget(pubkey: pubkey, followingList: []),
        );
        await tester.pumpAndSettle();

        final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
        expect(scaffold.backgroundColor, Colors.black);
      });
    });
  });
}
