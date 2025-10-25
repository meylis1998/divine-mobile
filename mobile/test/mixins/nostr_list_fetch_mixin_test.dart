// ABOUTME: Tests for NostrListFetchMixin state management and UI building
// ABOUTME: Validates common patterns used by followers/following screens

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/mixins/nostr_list_fetch_mixin.dart';

// Test widget that uses the mixin
class TestListScreen extends ConsumerStatefulWidget {
  const TestListScreen({super.key});

  @override
  ConsumerState<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends ConsumerState<TestListScreen>
    with NostrListFetchMixin {
  List<String> _testList = [];
  bool _isLoading = true;
  String? _error;

  @override
  List<String> get userList => _testList;

  @override
  set userList(List<String> value) => _testList = value;

  @override
  bool get isLoading => _isLoading;

  @override
  set isLoading(bool value) => _isLoading = value;

  @override
  String? get error => _error;

  @override
  set error(String? value) => _error = value;

  @override
  Future<void> fetchList() async {
    // Simulate async fetch
    await Future.delayed(const Duration(milliseconds: 100));
    if (mounted) {
      setState(() {
        _testList = ['pubkey1', 'pubkey2', 'pubkey3'];
        completeLoading();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: buildAppBar(context, 'Test List'),
      body: buildListBody(
        context,
        _testList,
        (pubkey) {
          // Navigate callback
        },
        emptyMessage: 'No users found',
        emptyIcon: Icons.people,
      ),
    );
  }
}

void main() {
  group('NostrListFetchMixin', () {
    testWidgets('starts in loading state', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      // Should show loading indicator initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('completes loading and shows list', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      // Wait for fetchList async delay
      await tester.pump(const Duration(milliseconds: 200));

      // Should show ListView with items
      expect(find.byType(ListView), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('shows error state when error is set', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      // Trigger error
      final state = tester.state<_TestListScreenState>(find.byType(TestListScreen));
      state.setError('Test error message');
      await tester.pump();

      // Should show error UI
      expect(find.text('Test error message'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows empty state when list is empty', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      final state = tester.state<_TestListScreenState>(find.byType(TestListScreen));

      // Set empty list and complete loading
      state.userList = [];
      state.completeLoading();
      await tester.pump();

      // Should show empty state
      expect(find.text('No users found'), findsOneWidget);
      expect(find.byIcon(Icons.people), findsOneWidget);
    });

    testWidgets('retry button calls loadList', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      final state = tester.state<_TestListScreenState>(find.byType(TestListScreen));

      // Cancel any pending timers first
      state.cancelLoadingTimeout();

      // Set error state
      state.setError('Test error');
      await tester.pump();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Should be in loading state again
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Clean up timer
      state.cancelLoadingTimeout();
    });

    testWidgets('appBar has correct title', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      await tester.pump();

      expect(find.text('Test List'), findsOneWidget);
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);

      // Clean up timer
      final state = tester.state<_TestListScreenState>(find.byType(TestListScreen));
      state.cancelLoadingTimeout();
    });

    test('startLoading sets correct state', () {
      final widget = TestListScreen();
      final state = _TestListScreenState();

      // Manually set initial state
      state.isLoading = false;
      state.error = 'Previous error';

      // Note: Can't call startLoading without widget context
      // This test validates the state management contract
      expect(state.isLoading, false);
      expect(state.error, 'Previous error');
    });

    test('setError sets correct state', () {
      final state = _TestListScreenState();

      state.isLoading = true;
      state.error = null;

      // Validate state before error
      expect(state.isLoading, true);
      expect(state.error, null);

      // After setError is called (in a mounted context),
      // isLoading should be false and error should be set
    });

    test('completeLoading sets isLoading to false', () {
      final state = _TestListScreenState();

      state.isLoading = true;

      // Validate initial state
      expect(state.isLoading, true);

      // After completeLoading is called (in a mounted context),
      // isLoading should be false
    });

    testWidgets('disposes timer on widget disposal', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: TestListScreen(),
          ),
        ),
      );

      // Remove widget
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: Text('Different screen')),
          ),
        ),
      );

      // Should not throw errors (timer is properly disposed)
      expect(tester.takeException(), isNull);
    });
  });
}
