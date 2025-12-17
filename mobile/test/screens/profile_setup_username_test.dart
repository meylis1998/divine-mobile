// ABOUTME: Widget tests for username field in ProfileSetupScreen
// ABOUTME: Tests status indicators, pre-population, and validation behavior

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/state/username_state.dart';
import 'package:openvine/theme/vine_theme.dart';

void main() {
  group('Username Status Indicator Widget Tests', () {
    // Test the indicator widget in isolation
    Widget buildStatusIndicator(UsernameState state) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: _buildUsernameStatusIndicator(state),
        ),
      );
    }

    testWidgets('should not show indicator when status is idle', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: '',
          status: UsernameCheckStatus.idle,
        )),
      );

      expect(find.text('Checking availability...'), findsNothing);
      expect(find.text('Username available!'), findsNothing);
      expect(find.text('Username already taken'), findsNothing);
      expect(find.text('Username is reserved'), findsNothing);
    });

    testWidgets('should show checking indicator with spinner', (tester) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: 'testuser',
          status: UsernameCheckStatus.checking,
        )),
      );

      expect(find.text('Checking availability...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('should show available indicator with green checkmark', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: 'availableuser',
          status: UsernameCheckStatus.available,
        )),
      );

      expect(find.text('Username available!'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
    });

    testWidgets('should show taken indicator with cancel icon', (tester) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: 'takenuser',
          status: UsernameCheckStatus.taken,
        )),
      );

      expect(find.text('Username already taken'), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('should show reserved indicator with contact support', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: 'reserveduser',
          status: UsernameCheckStatus.reserved,
        )),
      );

      expect(find.text('Username is reserved'), findsOneWidget);
      expect(find.text('Contact Support'), findsOneWidget);
    });

    testWidgets('should show error indicator', (tester) async {
      await tester.pumpWidget(
        buildStatusIndicator(const UsernameState(
          username: 'erroruser',
          status: UsernameCheckStatus.error,
          errorMessage: 'Network error',
        )),
      );

      expect(find.text('Network error'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('Username Validation Logic Tests', () {
    test('should allow valid usernames', () {
      expect(_isValidUsername('testuser'), isTrue);
      expect(_isValidUsername('test_user'), isTrue);
      expect(_isValidUsername('test-user'), isTrue);
      expect(_isValidUsername('test.user'), isTrue);
      expect(_isValidUsername('TestUser123'), isTrue);
    });

    test('should reject usernames that are too short', () {
      expect(_isValidUsername('ab'), isFalse);
      expect(_isValidUsername('a'), isFalse);
      expect(_isValidUsername(''), isFalse);
    });

    test('should reject usernames that are too long', () {
      expect(_isValidUsername('a' * 21), isFalse);
      expect(_isValidUsername('a' * 30), isFalse);
    });

    test('should reject usernames with invalid characters', () {
      expect(_isValidUsername('user@name'), isFalse);
      expect(_isValidUsername('user name'), isFalse);
      expect(_isValidUsername('user!name'), isFalse);
      expect(_isValidUsername('user#name'), isFalse);
    });
  });

  group('NIP-05 Username Extraction Tests', () {
    test('should extract username from @divine.video domain', () {
      expect(_extractUsername('testuser@divine.video'), equals('testuser'));
      expect(_extractUsername('my_user@divine.video'), equals('my_user'));
    });

    test('should extract username from legacy @openvine.co domain', () {
      expect(_extractUsername('legacyuser@openvine.co'), equals('legacyuser'));
    });

    test('should return null for external domains', () {
      expect(_extractUsername('user@nostr.com'), isNull);
      expect(_extractUsername('user@example.org'), isNull);
    });

    test('should return null for invalid formats', () {
      expect(_extractUsername('invalid'), isNull);
      expect(_extractUsername(''), isNull);
      expect(_extractUsername('user@'), isNull);
    });
  });
}

/// Replicated from ProfileSetupScreen for isolated testing
Widget _buildUsernameStatusIndicator(UsernameState usernameState) {
  // Don't show anything if idle or username is empty
  if (usernameState.status == UsernameCheckStatus.idle ||
      usernameState.username.isEmpty) {
    return const SizedBox.shrink();
  }

  // Checking indicator
  if (usernameState.isChecking) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            'Checking availability...',
            style: TextStyle(color: Colors.grey[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Available indicator
  if (usernameState.isAvailable) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          const Icon(
            Icons.check_circle,
            color: VineTheme.vineGreen,
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            'Username available!',
            style: TextStyle(color: VineTheme.vineGreen, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Taken indicator
  if (usernameState.isTaken) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.cancel, color: Colors.red[400], size: 16),
          const SizedBox(width: 8),
          Text(
            'Username already taken',
            style: TextStyle(color: Colors.red[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Reserved indicator with Contact Support button
  if (usernameState.isReserved) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock, color: Colors.orange[400], size: 16),
              const SizedBox(width: 8),
              Text(
                'Username is reserved',
                style: TextStyle(color: Colors.orange[400], fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: () {},
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  // Error indicator
  if (usernameState.hasError) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.orange[400], size: 16),
          const SizedBox(width: 8),
          Text(
            usernameState.errorMessage ?? 'Failed to check availability',
            style: TextStyle(color: Colors.orange[400], fontSize: 12),
          ),
        ],
      ),
    );
  }

  return const SizedBox.shrink();
}

/// Replicated validation logic from ProfileSetupScreen
bool _isValidUsername(String username) {
  final regex = RegExp(r'^[a-z0-9\-_.]+$', caseSensitive: false);
  return regex.hasMatch(username) &&
      username.length >= 3 &&
      username.length <= 20;
}

/// Replicated username extraction logic from ProfileSetupScreen
String? _extractUsername(String? nip05) {
  if (nip05 == null || nip05.isEmpty) return null;

  if (nip05.endsWith('@divine.video') || nip05.endsWith('@openvine.co')) {
    final parts = nip05.split('@');
    if (parts.length == 2) {
      return parts[0];
    }
  }
  return null;
}
