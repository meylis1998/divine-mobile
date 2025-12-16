// ABOUTME: Unit tests for FollowingListNotifier provider
// ABOUTME: Tests branching logic, service calls, error handling, and refresh

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/following_list_notifier.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/state/social_state.dart';

class MockAuthService extends Mock implements AuthService {}

class MockSocialService extends Mock implements SocialService {}

class Listener<T> extends Mock {
  void call(T? previous, T next);
}

void main() {
  /// Creates a valid 64-character hex pubkey for testing
  String validPubkey(String suffix) {
    final hexSuffix = suffix.codeUnits
        .map((c) => c.toRadixString(16).padLeft(2, '0'))
        .join();
    return hexSuffix.padLeft(64, '0');
  }

  group('FollowingListNotifier', () {
    late MockAuthService mockAuthService;
    late MockSocialService mockSocialService;

    setUp(() {
      mockAuthService = MockAuthService();
      mockSocialService = MockSocialService();
    });

    ProviderContainer makeContainer() {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          socialServiceProvider.overrideWithValue(mockSocialService),
        ],
      );
      addTearDown(container.dispose);
      return container;
    }

    // For "other user" tests - we can properly test these by mocking services
    group('other user path', () {
      test('fetches following list from socialService', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUserPubkey = validPubkey('other_user');
        final expectedFollowing = [
          validPubkey('friend1'),
          validPubkey('friend2'),
        ];

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);
        when(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).thenAnswer((_) => Stream.value(expectedFollowing));

        final container = makeContainer();
        final result = await container.read(
          followingListProvider(otherUserPubkey).future,
        );

        expect(result, equals(expectedFollowing));
        verify(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).called(1);
      });

      test('returns empty list when user follows no one', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUserPubkey = validPubkey('other_user');

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);
        when(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).thenAnswer((_) => Stream.value([]));

        final container = makeContainer();
        final result = await container.read(
          followingListProvider(otherUserPubkey).future,
        );

        expect(result, isEmpty);
      });

      test('propagates stream errors', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUserPubkey = validPubkey('other_user');

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);
        when(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).thenAnswer((_) => Stream.error(Exception('Network error')));

        final container = makeContainer();

        // Keep provider alive during async assertion
        final subscription = container.listen(
          followingListProvider(otherUserPubkey),
          (_, __) {},
        );

        await expectLater(
          container.read(followingListProvider(otherUserPubkey).future),
          throwsA(isA<Exception>()),
        );

        subscription.close();
      });

      test('throws StateError on empty stream', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUserPubkey = validPubkey('other_user');

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);
        when(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).thenAnswer((_) => const Stream.empty());

        final container = makeContainer();

        await expectLater(
          container.read(followingListProvider(otherUserPubkey).future),
          throwsA(isA<StateError>()),
        );
      });

      test('unauthenticated user always takes other user path', () async {
        final targetPubkey = validPubkey('some_user');

        // No current user (unauthenticated)
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);
        when(
          () => mockSocialService.getFollowingListForUser(targetPubkey),
        ).thenAnswer((_) => Stream.value([]));

        final container = makeContainer();
        await container.read(followingListProvider(targetPubkey).future);

        // Should call socialService since null != any pubkey
        verify(
          () => mockSocialService.getFollowingListForUser(targetPubkey),
        ).called(1);
      });
    });

    group('refresh', () {
      late MockAuthService mockAuthService;
      late MockSocialService mockSocialService;

      setUp(() {
        mockAuthService = MockAuthService();
        mockSocialService = MockSocialService();
      });

      test('invalidates and refetches data', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUserPubkey = validPubkey('other_user');
        final firstResult = [validPubkey('friend1')];
        final secondResult = [validPubkey('friend1'), validPubkey('friend2')];

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);

        var callCount = 0;
        when(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).thenAnswer((_) {
          callCount++;
          return Stream.value(callCount == 1 ? firstResult : secondResult);
        });

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            socialServiceProvider.overrideWithValue(mockSocialService),
          ],
        );
        addTearDown(container.dispose);

        // Initial fetch
        final result1 = await container.read(
          followingListProvider(otherUserPubkey).future,
        );
        expect(result1, equals(firstResult));

        // Refresh
        await container
            .read(followingListProvider(otherUserPubkey).notifier)
            .refresh();

        // Should have new data
        final result2 = await container.read(
          followingListProvider(otherUserPubkey).future,
        );
        expect(result2, equals(secondResult));

        verify(
          () => mockSocialService.getFollowingListForUser(otherUserPubkey),
        ).called(2);
      });
    });

    group('family provider isolation', () {
      late MockAuthService mockAuthService;
      late MockSocialService mockSocialService;

      setUp(() {
        mockAuthService = MockAuthService();
        mockSocialService = MockSocialService();
      });

      test('different pubkeys have independent state', () async {
        final currentUserPubkey = validPubkey('current_user');
        final otherUser1 = validPubkey('other_user_1');
        final otherUser2 = validPubkey('other_user_2');
        final following1 = [validPubkey('a')];
        final following2 = [validPubkey('b'), validPubkey('c')];

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);
        when(
          () => mockSocialService.getFollowingListForUser(otherUser1),
        ).thenAnswer((_) => Stream.value(following1));
        when(
          () => mockSocialService.getFollowingListForUser(otherUser2),
        ).thenAnswer((_) => Stream.value(following2));

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            socialServiceProvider.overrideWithValue(mockSocialService),
          ],
        );
        addTearDown(container.dispose);

        final result1 = await container.read(
          followingListProvider(otherUser1).future,
        );
        final result2 = await container.read(
          followingListProvider(otherUser2).future,
        );

        expect(result1, equals(following1));
        expect(result2, equals(following2));
      });
    });

    group('current user path', () {
      // NOTE: The current user path (lines 18-21) reads from socialProvider,
      // which has complex initialization side effects that make it difficult
      // to test in isolation without integration tests.
      //
      // TODO: Refactor SocialNotifier to separate concerns and enable proper
      // unit testing of providers that depend on it.

      late MockAuthService mockAuthService;
      late MockSocialService mockSocialService;

      setUp(() {
        mockAuthService = MockAuthService();
        mockSocialService = MockSocialService();
      });

      test(
        'does NOT call socialService when pubkey matches current user',
        () async {
          final currentUserPubkey = validPubkey('current_user');
          final followingList = [validPubkey('friend1')];

          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(currentUserPubkey);

          final container = ProviderContainer(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              socialServiceProvider.overrideWithValue(mockSocialService),
              // Override socialProvider to return a known state
              // This is the minimal override needed to test the branching logic
              socialProvider.overrideWith(
                () => _FakeSocialNotifier(followingPubkeys: followingList),
              ),
            ],
          );
          addTearDown(container.dispose);

          final result = await container.read(
            followingListProvider(currentUserPubkey).future,
          );

          // Verify the current user path was taken (reads from socialProvider)
          expect(result, equals(followingList));
          // Verify the other user path was NOT taken
          verifyNever(
            () => mockSocialService.getFollowingListForUser(any<String>()),
          );
        },
      );

      test('returns empty list for current user with no following', () async {
        final currentUserPubkey = validPubkey('current_user');

        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(currentUserPubkey);

        final container = ProviderContainer(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            socialServiceProvider.overrideWithValue(mockSocialService),
            socialProvider.overrideWith(
              () => _FakeSocialNotifier(followingPubkeys: []),
            ),
          ],
        );
        addTearDown(container.dispose);

        final result = await container.read(
          followingListProvider(currentUserPubkey).future,
        );

        expect(result, isEmpty);
        verifyNever(
          () => mockSocialService.getFollowingListForUser(any<String>()),
        );
      });
    });
  });
}

/// TODO: This should be removed once SocialNotifier is refactored to be
/// more testable.
class _FakeSocialNotifier extends SocialNotifier {
  _FakeSocialNotifier({required List<String> followingPubkeys})
    : _state = SocialState.initial.copyWith(
        followingPubkeys: followingPubkeys,
        isInitialized: true,
      );

  final SocialState _state;

  @override
  SocialState build() => _state;
}
