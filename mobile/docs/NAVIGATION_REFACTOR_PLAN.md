# Navigation Refactor Plan: Navigator 1.0 → go_router Migration

**Date**: 2026-01-08
**Status**: Planning Phase
**Goal**: Migrate all Navigator 1.0 API usage to go_router for consistency and maintainability

---

## Executive Summary

This document outlines a comprehensive plan to migrate OpenVine's navigation from a hybrid Navigator 1.0 + go_router approach to a pure go_router implementation. The migration will improve consistency, eliminate stack management complexity, and leverage go_router's declarative routing for all navigation scenarios.

### Current State
- **Primary routing**: go_router with ShellRoute architecture ✅
- **Modal/overlay navigation**: Navigator 1.0 API (~170 occurrences)
- **Fullscreen overlays**: Navigator 1.0 push (~12 occurrences)
- **Coordination complexity**: Manual clearing of Navigator stacks in `app_shell.dart`

### Target State
- **All navigation**: go_router declarative routes
- **Modals**: go_router dialog routes with proper typing
- **Overlays**: go_router's imperative push API
- **Zero Navigator 1.0**: Complete removal of `Navigator.of(context)` calls

---

## Navigation Architecture Analysis

### Current Architecture Strengths

1. **URL-Driven State Management** ⭐
   - Routes drive UI state, not internal variables
   - Deep linking works out of the box
   - Browser back button support (web)
   - Clean testability via URL inspection

2. **Per-Tab State Preservation** ⭐
   - 13 separate navigator keys for different tab/mode combinations
   - Users can switch tabs without losing scroll position
   - Last video index tracked per tab

3. **Type-Safe Routing** ⭐
   - `RouteContext` enum prevents invalid routes
   - Navigation extensions provide clean DSL
   - Compile-time route validation

4. **Reactive Navigation** ⭐
   - `pageContextProvider` parses URL reactively
   - Screens rebuild when route changes
   - Bidirectional URL ↔ UI sync (PageView)

### Current Architecture Weaknesses

1. **Hybrid Navigation Complexity** ⚠️
   - Two navigation systems to understand
   - Manual coordination in `app_shell.dart`
   - Stack corruption risk when mixing APIs

2. **Navigator 1.0 for Overlays** ⚠️
   - Modals don't update URL
   - Can't deep link to dialogs
   - No browser back button for modals
   - Testing requires mocking Navigator

3. **Route Stack Management** ⚠️
   - `navigator.canPop()` checks mixed with `context.canPop()`
   - `popUntil()` clears Navigator stack before GoRouter navigation
   - Complex back button logic in `app_shell.dart`

---

## Migration Categories

### Category 1: Modal Dialogs (Priority: HIGH)
**Occurrences**: ~100+
**Pattern**: `showDialog()` + `Navigator.of(context).pop()`

#### Current Implementation
```dart
// Delete confirmation dialog
showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Delete Video?'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text('Delete'),
      ),
    ],
  ),
);
```

#### Target Implementation
```dart
// Using go_router's declarative dialog routes
context.push<bool>('/dialogs/confirm-delete', extra: {
  'title': 'Delete Video?',
  'confirmText': 'Delete',
  'videoId': videoId,
});

// OR using go_router's imperative API
context.push<bool>(
  '/confirm',
  extra: ConfirmDialogData(
    title: 'Delete Video?',
    onConfirm: () => deleteVideo(),
  ),
);
```

#### Files Affected
- `lib/screens/comments/comment_options_modal.dart`
- `lib/screens/profile/user_profile_screen.dart`
- `lib/screens/camera/universal_camera_screen_pure.dart`
- `lib/widgets/dialogs/delete_confirmation_dialog.dart`
- `lib/widgets/dialogs/report_dialog.dart`
- `lib/widgets/video/video_actions_bar.dart`
- `lib/screens/settings/*.dart` (30+ dialogs)

---

### Category 2: Modal Bottom Sheets (Priority: HIGH)
**Occurrences**: ~50+
**Pattern**: `showModalBottomSheet()` + `Navigator.of(context).pop()`

#### Current Implementation
```dart
// Comments screen
static Future<void> show(BuildContext context, VideoEvent video) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsScreen(video: video),
  );
}
```

#### Target Implementation (Option A: Bottom Sheet Route)
```dart
// Define bottom sheet route in router
GoRoute(
  path: '/video/:videoId/comments',
  pageBuilder: (context, state) {
    final videoId = state.pathParameters['videoId']!;
    return CustomTransitionPage(
      child: CommentsScreen(videoId: videoId),
      transitionsBuilder: bottomSheetTransition,
    );
  },
),

// Usage
context.push('/video/$videoId/comments');
```

#### Target Implementation (Option B: Custom Page Builder)
```dart
// Create reusable bottom sheet page builder
class BottomSheetPage<T> extends Page<T> {
  final Widget child;

  const BottomSheetPage({required this.child});

  @override
  Route<T> createRoute(BuildContext context) {
    return ModalBottomSheetRoute<T>(
      builder: (_) => child,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      settings: this,
    );
  }
}

// Usage in router
context.push('/comments', extra: video);
```

#### Files Affected
- `lib/screens/comments/comments_screen.dart`
- `lib/screens/share/share_menu.dart`
- `lib/screens/video/video_options_sheet.dart`
- `lib/widgets/video/age_verification_dialog.dart`
- `lib/screens/settings/blossom_server_settings_screen.dart`
- `lib/screens/clips/clip_library_screen.dart`

---

### Category 3: Fullscreen Overlay Pushes (Priority: MEDIUM)
**Occurrences**: ~12
**Pattern**: `Navigator.of(context).push(MaterialPageRoute(...))`

#### Current Implementation
```dart
// Push curated list feed
Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FullscreenVideoFeedScreen(
      source: CuratedListFeedSource(
        listId: listId,
        videos: videoIds,
      ),
      initialIndex: index,
    ),
  ),
);
```

#### Target Implementation
```dart
// Define route in router
GoRoute(
  path: '/list/:listId/feed',
  name: 'curatedListFeed',
  pageBuilder: (context, state) {
    final listId = state.pathParameters['listId']!;
    final initialIndex = int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;
    final extra = state.extra as CuratedListFeedData;

    return MaterialPage(
      child: FullscreenVideoFeedScreen(
        source: CuratedListFeedSource(
          listId: listId,
          videos: extra.videoIds,
        ),
        initialIndex: initialIndex,
      ),
    );
  },
),

// Usage with navigation extension
context.pushCuratedListFeed(listId, videoIds, index);
```

#### Files Affected
- `lib/widgets/video/video_feed_item.dart`
- `lib/screens/notifications/notifications_screen.dart`
- `lib/screens/activity/activity_screens.dart`
- `lib/screens/profile/profile_screen_router.dart`

---

### Category 4: Camera Screen Navigation (Priority: LOW)
**Occurrences**: 8
**Pattern**: Multiple `Navigator.of(context).pop()` calls in camera flow

#### Current Implementation
```dart
// Camera screen dismissal
void _handleCancel() {
  Navigator.of(context).pop();
}

void _handleSave() async {
  final result = await _processVideo();
  Navigator.of(context).pop(result);
}
```

#### Target Implementation
```dart
// Use go_router's pop with result
void _handleCancel() {
  context.pop(); // go_router automatically handles result type
}

void _handleSave() async {
  final result = await _processVideo();
  context.pop(result);
}
```

#### Files Affected
- `lib/screens/camera/universal_camera_screen_pure.dart`
- `lib/screens/camera/clip_manager_screen.dart`
- `lib/screens/camera/camera_screen.dart`

---

### Category 5: AppShell Navigation Coordination (Priority: HIGH)
**Occurrences**: 1 (but critical)
**Pattern**: Manual Navigator stack clearing before GoRouter navigation

#### Current Implementation
```dart
// app_shell.dart back button logic
void _handleBack(BuildContext context, WidgetRef ref) {
  // First check if GoRouter can pop
  if (context.canPop()) {
    context.pop();
    return;
  }

  // Check if we're in feed mode, go to grid mode
  final currentRoute = ref.read(pageContextProvider).valueOrNull;
  if (currentRoute?.videoIndex != null) {
    // Navigate to grid mode
    _navigateToGridMode(context, currentRoute);
    return;
  }

  // Navigate to previous tab from history
  final history = ref.read(tabHistoryProvider);
  if (history.length > 1) {
    final previousTab = history[history.length - 2];
    _navigateToPreviousTab(context, ref, previousTab);
    return;
  }

  // Fallback to home
  context.goHome();
}

void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  // Clear any pushed Navigator routes first
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }

  // Then navigate with GoRouter
  _navigateToTab(context, ref, index);
}
```

#### Target Implementation
```dart
// Simplified without Navigator 1.0
void _handleBack(BuildContext context, WidgetRef ref) {
  // Pure GoRouter stack management
  if (context.canPop()) {
    context.pop();
    return;
  }

  // Check if we're in feed mode, go to grid mode
  final currentRoute = ref.read(pageContextProvider).valueOrNull;
  if (currentRoute?.videoIndex != null) {
    _navigateToGridMode(context, currentRoute);
    return;
  }

  // Navigate to previous tab from history
  final history = ref.read(tabHistoryProvider);
  if (history.length > 1) {
    final previousTab = history[history.length - 2];
    _navigateToPreviousTab(context, ref, previousTab);
    return;
  }

  // Fallback to home
  context.goHome();
}

void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  // No need to clear Navigator stack - pure GoRouter
  _navigateToTab(context, ref, index);
}
```

**Note**: This change eliminates the coordination complexity entirely.

#### Files Affected
- `lib/router/app_shell.dart` (single critical file)

---

## Migration Strategy

### Phase 1: Foundation Setup (Week 1)
**Goal**: Prepare go_router infrastructure for modals and bottom sheets

1. **Create Custom Page Builders**
   - [ ] `DialogPage<T>` - Wraps dialogs in go_router pages
   - [ ] `BottomSheetPage<T>` - Wraps bottom sheets in go_router pages
   - [ ] `TransparentModalPage<T>` - For custom modal presentations

2. **Extend Navigation Extensions**
   - [ ] Add dialog navigation helpers: `context.pushDialog()`, `context.showConfirmDialog()`
   - [ ] Add bottom sheet helpers: `context.pushBottomSheet()`
   - [ ] Add typed result handling: `context.popWithResult<T>()`

3. **Update Route Configuration**
   - [ ] Add dialog routes section in `app_router.dart`
   - [ ] Add modal routes section for bottom sheets
   - [ ] Configure transition builders for modals

4. **Create Migration Utilities**
   - [ ] `ModalMigrationHelper` - Helper functions for converting Navigator calls
   - [ ] Testing utilities for new modal routes

**Deliverables**:
- `lib/router/pages/dialog_page.dart`
- `lib/router/pages/bottom_sheet_page.dart`
- `lib/router/nav_extensions.dart` (updated)
- `lib/router/app_router.dart` (updated with modal routes)

---

### Phase 2: Modal Dialog Migration (Week 2-3)
**Goal**: Replace all `showDialog()` calls with go_router dialog routes

#### Step-by-Step Process

**Step 1: Identify Dialog Types**
Run analysis to categorize dialogs:
```bash
grep -r "showDialog" lib/ | wc -l  # Count total
grep -r "AlertDialog" lib/ | wc -l  # Count alert dialogs
grep -r "Dialog(" lib/ | wc -l     # Count custom dialogs
```

**Step 2: Create Common Dialog Routes**
Define reusable dialog routes for common patterns:

```dart
// In app_router.dart
final _dialogRoutes = [
  GoRoute(
    path: '/dialogs/confirm',
    name: 'confirmDialog',
    pageBuilder: (context, state) {
      final data = state.extra as ConfirmDialogData;
      return DialogPage(
        child: ConfirmationDialog(
          title: data.title,
          message: data.message,
          confirmText: data.confirmText,
          cancelText: data.cancelText,
        ),
      );
    },
  ),
  GoRoute(
    path: '/dialogs/input',
    name: 'inputDialog',
    pageBuilder: (context, state) {
      final data = state.extra as InputDialogData;
      return DialogPage(
        child: InputDialog(
          title: data.title,
          hintText: data.hintText,
          initialValue: data.initialValue,
        ),
      );
    },
  ),
  // ... more dialog routes
];
```

**Step 3: Migrate by Category**

1. **Confirmation Dialogs** (highest volume)
   - Delete confirmations
   - Logout confirmations
   - Discard changes confirmations
   - Block/report confirmations

2. **Input Dialogs**
   - Text input dialogs
   - Username/display name editing
   - Caption editing
   - Search input

3. **Custom Dialogs**
   - Age verification
   - Upload progress
   - Error messages
   - Info/help dialogs

**Step 4: Update Each File**

For each file:
```dart
// BEFORE
showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('Delete Video?'),
    content: Text('This action cannot be undone.'),
    actions: [
      TextButton(
        onPressed: () => Navigator.of(context).pop(false),
        child: Text('Cancel'),
      ),
      TextButton(
        onPressed: () => Navigator.of(context).pop(true),
        child: Text('Delete'),
      ),
    ],
  ),
);

// AFTER
final confirmed = await context.pushDialog<bool>(
  ConfirmDialogData(
    title: 'Delete Video?',
    message: 'This action cannot be undone.',
    confirmText: 'Delete',
    cancelText: 'Cancel',
  ),
);
```

**Step 5: Test Each Migration**
- Verify dialog displays correctly
- Verify return values work
- Verify back button behavior
- Verify nested navigation doesn't break

**Files to Migrate** (prioritized by usage frequency):
1. `lib/widgets/video/video_actions_bar.dart` (delete, report)
2. `lib/screens/settings/key_management_screen.dart` (delete key confirmations)
3. `lib/screens/settings/relay_settings_screen.dart` (delete relay)
4. `lib/screens/settings/notification_settings_screen.dart` (permission dialogs)
5. `lib/screens/profile/edit_profile_screen.dart` (discard changes)
6. `lib/screens/camera/universal_camera_screen_pure.dart` (discard recording)
7. `lib/screens/comments/comments_screen.dart` (delete comment)
8. `lib/screens/share/share_menu.dart` (share options)
9. `lib/widgets/dialogs/*` (30+ dialog widgets)

**Testing Checklist** (per file):
- [ ] Dialog appears correctly
- [ ] Cancel button dismisses dialog
- [ ] Confirm button returns correct value
- [ ] Back button/gesture dismisses dialog
- [ ] Dialog state is preserved on orientation change
- [ ] Multiple dialogs can stack (if needed)
- [ ] No Navigator 1.0 calls remain in file

---

### Phase 3: Bottom Sheet Migration (Week 4-5)
**Goal**: Replace all `showModalBottomSheet()` calls with go_router routes

#### Step-by-Step Process

**Step 1: Create Bottom Sheet Infrastructure**

```dart
// lib/router/pages/bottom_sheet_page.dart
class BottomSheetPage<T> extends Page<T> {
  final Widget child;
  final bool isScrollControlled;
  final Color? backgroundColor;

  const BottomSheetPage({
    required this.child,
    this.isScrollControlled = true,
    this.backgroundColor = Colors.transparent,
    super.key,
  });

  @override
  Route<T> createRoute(BuildContext context) {
    return ModalBottomSheetRoute<T>(
      builder: (_) => child,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      settings: this,
    );
  }
}
```

**Step 2: Define Bottom Sheet Routes**

```dart
// In app_router.dart
final _bottomSheetRoutes = [
  GoRoute(
    path: '/video/:videoId/comments',
    name: 'videoComments',
    pageBuilder: (context, state) {
      final videoId = state.pathParameters['videoId']!;
      final video = state.extra as VideoEvent;
      return BottomSheetPage(
        child: CommentsScreen(video: video),
      );
    },
  ),
  GoRoute(
    path: '/share',
    name: 'shareMenu',
    pageBuilder: (context, state) {
      final data = state.extra as ShareMenuData;
      return BottomSheetPage(
        child: ShareMenu(
          url: data.url,
          videoId: data.videoId,
        ),
      );
    },
  ),
  GoRoute(
    path: '/video/:videoId/options',
    name: 'videoOptions',
    pageBuilder: (context, state) {
      final video = state.extra as VideoEvent;
      return BottomSheetPage(
        child: VideoOptionsSheet(video: video),
      );
    },
  ),
];
```

**Step 3: Add Navigation Extensions**

```dart
// In nav_extensions.dart
extension BottomSheetNavigation on BuildContext {
  Future<void> pushComments(VideoEvent video) {
    return push('/video/${video.id}/comments', extra: video);
  }

  Future<void> pushShareMenu(String url, String videoId) {
    return push('/share', extra: ShareMenuData(url: url, videoId: videoId));
  }

  Future<void> pushVideoOptions(VideoEvent video) {
    return push('/video/${video.id}/options', extra: video);
  }
}
```

**Step 4: Migrate Each Bottom Sheet**

For each file:
```dart
// BEFORE
static Future<void> show(BuildContext context, VideoEvent video) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CommentsScreen(video: video),
  );
}

// Usage
CommentsScreen.show(context, video);

// AFTER
// Remove static show method entirely
// Usage
context.pushComments(video);
```

**Files to Migrate**:
1. `lib/screens/comments/comments_screen.dart` ⭐ (HIGH TRAFFIC)
2. `lib/screens/share/share_menu.dart` ⭐ (HIGH TRAFFIC)
3. `lib/screens/video/video_options_sheet.dart`
4. `lib/screens/comments/comment_options_modal.dart`
5. `lib/widgets/video/age_verification_dialog.dart`
6. `lib/screens/settings/blossom_server_settings_screen.dart`
7. `lib/screens/clips/clip_library_screen.dart`
8. `lib/widgets/overlays/upload_progress_overlay.dart`

**Testing Checklist** (per bottom sheet):
- [ ] Sheet slides up with correct animation
- [ ] Scroll behavior works (if `isScrollControlled`)
- [ ] Dragging down dismisses sheet
- [ ] Back button dismisses sheet
- [ ] Tap outside dismisses sheet
- [ ] Sheet appears above bottom nav bar
- [ ] URL updates when sheet opens
- [ ] Deep links to sheet work (e.g., `/video/123/comments`)

---

### Phase 4: Fullscreen Overlay Migration (Week 6)
**Goal**: Replace `Navigator.push(MaterialPageRoute(...))` with go_router routes

#### Step-by-Step Process

**Step 1: Define Missing Overlay Routes**

These routes already exist in go_router but are pushed with Navigator 1.0:
- Curated list feed
- User list people screen
- Profile view (some cases)

Ensure these have proper route definitions:

```dart
// Already exists but verify
GoRoute(
  path: '/list/:listId/feed',
  name: 'curatedListFeed',
  pageBuilder: (context, state) {
    final listId = state.pathParameters['listId']!;
    final extra = state.extra as CuratedListFeedData?;
    final initialIndex = int.tryParse(state.uri.queryParameters['index'] ?? '0') ?? 0;

    return MaterialPage(
      child: FullscreenVideoFeedScreen(
        source: CuratedListFeedSource(
          listId: listId,
          videos: extra?.videoIds ?? [],
        ),
        initialIndex: initialIndex,
        contextTitle: extra?.listName ?? 'Curated List',
      ),
    );
  },
),
```

**Step 2: Replace Navigator.push Calls**

Search and replace pattern:
```bash
# Find all Navigator.push calls
grep -r "Navigator.of(context).push" lib/

# Find MaterialPageRoute usage
grep -r "MaterialPageRoute" lib/
```

For each occurrence:
```dart
// BEFORE
Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => FullscreenVideoFeedScreen(
      source: CuratedListFeedSource(listId: listId, videos: videoIds),
      initialIndex: index,
    ),
  ),
);

// AFTER
context.pushCuratedListFeed(
  listId: listId,
  videoIds: videoIds,
  initialIndex: index,
  listName: listName,
);
```

**Files to Migrate**:
1. `lib/widgets/video/video_feed_item.dart`
2. `lib/screens/notifications/notifications_screen.dart`
3. `lib/screens/activity/activity_screens.dart`
4. `lib/screens/profile/profile_screen_router.dart`

**Testing Checklist**:
- [ ] Screen pushes with correct transition
- [ ] Back button returns to previous screen
- [ ] URL updates correctly
- [ ] Deep linking works
- [ ] State is preserved when navigating away and back

---

### Phase 5: Camera Screen Simplification (Week 7)
**Goal**: Replace all `Navigator.of(context).pop()` in camera with `context.pop()`

#### Step-by-Step Process

This is the simplest migration - pure find/replace:

```dart
// Find all occurrences in camera files
grep -r "Navigator.of(context).pop" lib/screens/camera/

// Replace each one
// BEFORE
Navigator.of(context).pop();
Navigator.of(context).pop(result);

// AFTER
context.pop();
context.pop(result);
```

**Files to Migrate**:
1. `lib/screens/camera/universal_camera_screen_pure.dart`
2. `lib/screens/camera/clip_manager_screen.dart`
3. `lib/screens/camera/camera_screen.dart`

**Testing Checklist**:
- [ ] Cancel button dismisses camera
- [ ] Save button returns video result
- [ ] Back button/gesture dismisses camera
- [ ] Navigation after camera works correctly

---

### Phase 6: AppShell Cleanup (Week 7)
**Goal**: Remove all Navigator 1.0 coordination logic

#### Step-by-Step Process

**Step 1: Remove Navigator Stack Clearing**

```dart
// BEFORE - app_shell.dart
void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.popUntil((route) => route.isFirst);
  }
  _navigateToTab(context, ref, index);
}

// AFTER
void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  _navigateToTab(context, ref, index);
}
```

**Step 2: Simplify Back Button Logic**

```dart
// BEFORE
void _handleBack(BuildContext context, WidgetRef ref) {
  // Complex logic mixing Navigator and GoRouter
}

// AFTER
void _handleBack(BuildContext context, WidgetRef ref) {
  // Pure GoRouter logic only
  if (context.canPop()) {
    context.pop();
    return;
  }

  final currentRoute = ref.read(pageContextProvider).valueOrNull;
  if (currentRoute?.videoIndex != null) {
    _navigateToGridMode(context, currentRoute);
    return;
  }

  final history = ref.read(tabHistoryProvider);
  if (history.length > 1) {
    final previousTab = history[history.length - 2];
    _navigateToPreviousTab(context, ref, previousTab);
    return;
  }

  context.goHome();
}
```

**Step 3: Remove Navigator Imports**

```dart
// Remove unnecessary imports
// import 'package:flutter/material.dart' (Navigator)
// Keep only GoRouter imports
import 'package:go_router/go_router.dart';
```

**Files to Update**:
1. `lib/router/app_shell.dart` ⭐ (CRITICAL)

**Testing Checklist**:
- [ ] Tab switching works correctly
- [ ] Back button behavior unchanged
- [ ] No stack corruption
- [ ] Modal overlays don't interfere with tab navigation
- [ ] Deep links work correctly

---

### Phase 7: Global Search & Cleanup (Week 8)
**Goal**: Find and eliminate any remaining Navigator 1.0 usage

#### Step-by-Step Process

**Step 1: Comprehensive Search**

```bash
# Find all Navigator references
grep -r "Navigator\." lib/ | grep -v "NavigatorObserver"

# Find all .pop() calls
grep -r "\.pop()" lib/

# Find all .push calls
grep -r "\.push(" lib/

# Find MaterialPageRoute
grep -r "MaterialPageRoute" lib/

# Find CupertinoPageRoute
grep -r "CupertinoPageRoute" lib/
```

**Step 2: Review Each Occurrence**

For each remaining usage:
1. Determine if it's legitimate (e.g., in tests, commented code)
2. If not, migrate to go_router equivalent
3. Document any intentional Navigator 1.0 usage (if any)

**Step 3: Update Tests**

Migrate test mocks from Navigator to GoRouter:
```dart
// BEFORE - in test files
testWidgets('pops on back button', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.tap(find.byType(BackButton));
  expect(find.byType(MyScreen), findsNothing);
});

// AFTER
testWidgets('pops on back button', (tester) async {
  final router = createTestRouter();
  await tester.pumpWidget(MyApp(router: router));
  await tester.tap(find.byType(BackButton));
  expect(router.location, equals('/previous-route'));
});
```

**Step 4: Update Documentation**

Update these files to reflect pure go_router navigation:
- `mobile/.claude/CLAUDE.md` - Update navigation section
- `mobile/docs/NAVIGATION_ARCHITECTURE.md` - Create comprehensive guide
- `README.md` - Update navigation description

**Step 5: Final Verification**

Run comprehensive checks:
```bash
# Ensure no Navigator.of(context) remains
grep -r "Navigator.of(context)" lib/ && echo "FOUND NAVIGATOR USAGE" || echo "CLEAN"

# Ensure no MaterialPageRoute remains
grep -r "MaterialPageRoute" lib/ && echo "FOUND MATERIAL PAGE ROUTE" || echo "CLEAN"

# Run all tests
flutter test

# Run integration tests
flutter test integration_test/
```

---

## Testing Strategy

### Unit Tests

**New Test Files to Create**:
1. `test/router/dialog_page_test.dart` - Test DialogPage builder
2. `test/router/bottom_sheet_page_test.dart` - Test BottomSheetPage builder
3. `test/router/modal_routes_test.dart` - Test modal route definitions

**Existing Test Files to Update**:
1. `test/router/app_router_test.dart` - Add modal route tests
2. `test/router/nav_extensions_test.dart` - Test new navigation extensions
3. All widget tests that mock Navigator

### Widget Tests

For each migrated screen:
```dart
testWidgets('shows confirmation dialog and returns result', (tester) async {
  final router = createTestRouter(initialLocation: '/');

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(
        routerConfig: router,
      ),
    ),
  );

  // Trigger dialog
  await tester.tap(find.byType(DeleteButton));
  await tester.pumpAndSettle();

  // Verify dialog is visible
  expect(find.text('Delete Video?'), findsOneWidget);
  expect(router.location, contains('/dialogs/confirm'));

  // Tap confirm
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();

  // Verify dialog closed
  expect(find.text('Delete Video?'), findsNothing);
  expect(router.location, equals('/'));
});
```

### Integration Tests

Create comprehensive integration test:
```dart
// test/integration/navigation_flow_test.dart
void main() {
  testWidgets('complete navigation flow', (tester) async {
    await tester.pumpWidget(MyApp());

    // Navigate through tabs
    await tester.tap(find.byIcon(Icons.explore));
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);

    // Open video
    await tester.tap(find.byType(VideoThumbnail).first);
    await tester.pumpAndSettle();

    // Open comments bottom sheet
    await tester.tap(find.byIcon(Icons.comment));
    await tester.pumpAndSettle();
    expect(find.text('Comments'), findsOneWidget);

    // Close comments
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Comments'), findsNothing);

    // Back to explore
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreScreen), findsOneWidget);
  });
}
```

### Manual Testing Checklist

For each phase, manually test:
- [ ] Happy path navigation works
- [ ] Back button behavior correct
- [ ] Deep links work
- [ ] Browser back button (web)
- [ ] Android back gesture
- [ ] iOS swipe back gesture
- [ ] Orientation changes don't break navigation
- [ ] Multi-window support (iPad, desktop)
- [ ] Rapid navigation doesn't cause crashes

---

## Migration Checklist

### Pre-Migration
- [ ] Backup current codebase (git commit)
- [ ] Run all tests and ensure passing
- [ ] Document current test coverage
- [ ] Create feature branch: `feat/navigation-refactor`

### Phase 1: Foundation Setup
- [ ] Create DialogPage class
- [ ] Create BottomSheetPage class
- [ ] Add dialog navigation extensions
- [ ] Add bottom sheet navigation extensions
- [ ] Update app_router.dart with modal routes
- [ ] Create migration helper utilities
- [ ] Write tests for new infrastructure
- [ ] Review and merge foundation

### Phase 2: Modal Dialog Migration
- [ ] Analyze and categorize all dialogs
- [ ] Define common dialog routes
- [ ] Migrate confirmation dialogs (highest volume)
- [ ] Migrate input dialogs
- [ ] Migrate custom dialogs
- [ ] Update tests for migrated dialogs
- [ ] Manual testing of dialog flows
- [ ] Review and merge dialog migration

### Phase 3: Bottom Sheet Migration
- [ ] Create bottom sheet infrastructure
- [ ] Define bottom sheet routes
- [ ] Add bottom sheet navigation extensions
- [ ] Migrate CommentsScreen (high traffic)
- [ ] Migrate ShareMenu (high traffic)
- [ ] Migrate remaining bottom sheets
- [ ] Update tests for migrated bottom sheets
- [ ] Manual testing of bottom sheet flows
- [ ] Review and merge bottom sheet migration

### Phase 4: Fullscreen Overlay Migration
- [ ] Verify overlay routes exist
- [ ] Replace Navigator.push in video_feed_item.dart
- [ ] Replace Navigator.push in notifications
- [ ] Replace Navigator.push in activity screens
- [ ] Replace Navigator.push in profile screens
- [ ] Update tests for overlay routes
- [ ] Manual testing of overlay flows
- [ ] Review and merge overlay migration

### Phase 5: Camera Screen Simplification
- [ ] Replace Navigator.pop in camera screens
- [ ] Replace Navigator.pop in clip manager
- [ ] Update camera tests
- [ ] Manual testing of camera flows
- [ ] Review and merge camera migration

### Phase 6: AppShell Cleanup
- [ ] Remove Navigator stack clearing logic
- [ ] Simplify back button logic
- [ ] Remove Navigator imports
- [ ] Update app_shell tests
- [ ] Comprehensive manual testing of tab navigation
- [ ] Review and merge app_shell migration

### Phase 7: Global Cleanup
- [ ] Run global search for Navigator usage
- [ ] Migrate any remaining Navigator calls
- [ ] Update test mocks
- [ ] Update documentation
- [ ] Run full test suite
- [ ] Run integration tests
- [ ] Final manual testing
- [ ] Review and merge cleanup

### Post-Migration
- [ ] Run full regression testing
- [ ] Update CLAUDE.md with new navigation patterns
- [ ] Create NAVIGATION_ARCHITECTURE.md guide
- [ ] Performance testing (navigation speed)
- [ ] Memory leak testing
- [ ] Deploy to staging environment
- [ ] QA testing on all platforms
- [ ] Deploy to production
- [ ] Monitor crash reports

---

## Risk Assessment

### High Risk Areas

1. **Comments Bottom Sheet** ⚠️⚠️⚠️
   - **Risk**: Highest traffic feature, used in every video
   - **Mitigation**: Migrate early, thorough testing, feature flag
   - **Rollback**: Keep old implementation as fallback

2. **AppShell Tab Navigation** ⚠️⚠️⚠️
   - **Risk**: Core navigation logic, affects all screens
   - **Mitigation**: Migrate last, comprehensive testing, staged rollout
   - **Rollback**: Git revert capability

3. **Camera Flow** ⚠️⚠️
   - **Risk**: Complex state management with recording
   - **Mitigation**: Thorough testing on all platforms
   - **Rollback**: Separate feature branch

### Medium Risk Areas

1. **Share Menu** ⚠️⚠️
   - **Risk**: High usage, platform-specific behavior
   - **Mitigation**: Test on iOS, Android, Web
   - **Rollback**: Easy to revert

2. **Profile Navigation** ⚠️⚠️
   - **Risk**: Multiple navigation paths (grid→feed, profile→videos)
   - **Mitigation**: Integration tests for all paths
   - **Rollback**: Isolated changes

3. **Dialog Confirmations** ⚠️
   - **Risk**: Many variations, easy to miss edge cases
   - **Mitigation**: Systematic migration, checklist
   - **Rollback**: Per-file rollback possible

### Low Risk Areas

1. **Settings Screens** ⚠️
   - **Risk**: Lower traffic, isolated changes
   - **Mitigation**: Standard testing
   - **Rollback**: Easy

2. **Search Navigation** ⚠️
   - **Risk**: Well-defined flows
   - **Mitigation**: Unit tests sufficient
   - **Rollback**: Easy

---

## Code Examples

### Example 1: Confirmation Dialog Migration

**Before**:
```dart
// lib/widgets/video/video_actions_bar.dart
Future<void> _handleDelete(BuildContext context, VideoEvent video) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Delete Video?'),
      content: const Text('This action cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await _deleteVideo(video);
  }
}
```

**After**:
```dart
// lib/widgets/video/video_actions_bar.dart
Future<void> _handleDelete(BuildContext context, VideoEvent video) async {
  final confirmed = await context.pushDialog<bool>(
    ConfirmDialogData(
      title: 'Delete Video?',
      message: 'This action cannot be undone.',
      confirmText: 'Delete',
      cancelText: 'Cancel',
      confirmStyle: ConfirmDialogStyle.destructive,
    ),
  );

  if (confirmed == true) {
    await _deleteVideo(video);
  }
}

// lib/router/nav_extensions.dart (new extension)
extension DialogNavigation on BuildContext {
  Future<T?> pushDialog<T>(Object data) {
    return push<T>('/dialogs/confirm', extra: data);
  }
}

// lib/router/app_router.dart (new route)
GoRoute(
  path: '/dialogs/confirm',
  name: 'confirmDialog',
  pageBuilder: (context, state) {
    final data = state.extra as ConfirmDialogData;
    return DialogPage<bool>(
      child: ConfirmationDialog(data: data),
    );
  },
),
```

### Example 2: Bottom Sheet Migration

**Before**:
```dart
// lib/screens/comments/comments_screen.dart
class CommentsScreen extends StatelessWidget {
  const CommentsScreen({required this.video, super.key});

  final VideoEvent video;

  static Future<void> show(BuildContext context, VideoEvent video) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommentsScreen(video: video),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // ... comments UI
    );
  }
}

// Usage in video_feed_item.dart
ElevatedButton(
  onPressed: () => CommentsScreen.show(context, video),
  child: Text('Comments'),
)
```

**After**:
```dart
// lib/screens/comments/comments_screen.dart
class CommentsScreen extends StatelessWidget {
  const CommentsScreen({required this.video, super.key});

  final VideoEvent video;

  // Removed static show method

  @override
  Widget build(BuildContext context) {
    return Container(
      // ... comments UI (unchanged)
    );
  }
}

// lib/router/nav_extensions.dart (new extension)
extension CommentsNavigation on BuildContext {
  Future<void> pushComments(VideoEvent video) {
    return push('/video/${video.id}/comments', extra: video);
  }
}

// lib/router/app_router.dart (new route)
GoRoute(
  path: '/video/:videoId/comments',
  name: 'videoComments',
  pageBuilder: (context, state) {
    final video = state.extra as VideoEvent;
    return BottomSheetPage(
      child: CommentsScreen(video: video),
    );
  },
),

// Usage in video_feed_item.dart
ElevatedButton(
  onPressed: () => context.pushComments(video),
  child: Text('Comments'),
)
```

### Example 3: AppShell Cleanup

**Before**:
```dart
// lib/router/app_shell.dart
void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  // Get the shell navigator and clear any pushed routes
  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    // Pop all routes back to the shell
    navigator.popUntil((route) => route.isFirst);
  }

  // Then navigate with GoRouter
  final lastPosition = ref.read(lastTabPositionProvider)[index];
  switch (index) {
    case 0:
      context.goHome(lastPosition);
      break;
    case 1:
      context.goExplore(lastPosition);
      break;
    case 2:
      context.goNotifications(lastPosition ?? 0);
      break;
    case 3:
      final myNpub = ref.read(authStateProvider).valueOrNull?.npub;
      if (myNpub != null) {
        context.goProfile(myNpub, lastPosition);
      }
      break;
  }
}
```

**After**:
```dart
// lib/router/app_shell.dart
void _handleTabTap(BuildContext context, WidgetRef ref, int index) {
  // No need to clear Navigator stack - pure GoRouter
  final lastPosition = ref.read(lastTabPositionProvider)[index];
  switch (index) {
    case 0:
      context.goHome(lastPosition);
      break;
    case 1:
      context.goExplore(lastPosition);
      break;
    case 2:
      context.goNotifications(lastPosition ?? 0);
      break;
    case 3:
      final myNpub = ref.read(authStateProvider).valueOrNull?.npub;
      if (myNpub != null) {
        context.goProfile(myNpub, lastPosition);
      }
      break;
  }
}
```

---

## Benefits of Migration

### 1. Consistency ✅
- **Single navigation API**: All navigation uses go_router
- **Predictable behavior**: No mixing of navigation systems
- **Easier onboarding**: Developers learn one API

### 2. URL-Driven Everything ✅
- **Deep linking**: Can deep link to any modal/dialog
- **Browser support**: Back button works for all overlays (web)
- **Testability**: Can verify navigation by checking URL

### 3. Simplified Stack Management ✅
- **No coordination**: go_router manages single stack
- **No corruption risk**: Can't accidentally break stack
- **Less code**: Remove Navigator clearing logic

### 4. Better Testing ✅
- **Declarative**: Test navigation by checking routes
- **Mockable**: Easy to mock router in tests
- **Integration**: End-to-end navigation tests

### 5. Developer Experience ✅
- **Type safety**: Typed routes with code generation
- **Extensions**: Clean DSL for navigation
- **Debugging**: go_router has excellent logging

### 6. Performance ✅
- **Optimized**: go_router optimized for Flutter
- **Lazy loading**: Routes loaded on demand
- **Memory**: Better memory management

---

## Timeline

**Total Estimated Time**: 8 weeks (with buffer)

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| Phase 1: Foundation | 1 week | Custom pages, extensions, routes |
| Phase 2: Modal Dialogs | 2 weeks | All dialogs migrated |
| Phase 3: Bottom Sheets | 2 weeks | All bottom sheets migrated |
| Phase 4: Fullscreen Overlays | 1 week | All overlays migrated |
| Phase 5: Camera Screen | 0.5 weeks | Camera navigation simplified |
| Phase 6: AppShell Cleanup | 0.5 weeks | Stack management removed |
| Phase 7: Global Cleanup | 1 week | Documentation, testing |

**Buffer**: 2 weeks for unexpected issues

---

## Success Metrics

### Code Metrics
- [ ] Zero `Navigator.of(context)` calls in production code
- [ ] Zero `MaterialPageRoute` usage
- [ ] All navigation uses go_router
- [ ] Test coverage maintained or improved
- [ ] No increase in crash rate

### Performance Metrics
- [ ] Navigation speed unchanged or faster
- [ ] Memory usage unchanged or lower
- [ ] App startup time unchanged
- [ ] Frame drops during navigation <= current

### Quality Metrics
- [ ] All tests passing
- [ ] No navigation-related bugs in production
- [ ] Code review approval
- [ ] QA sign-off
- [ ] No user complaints about navigation

---

## Rollback Plan

### Immediate Rollback (< 1 hour)
If critical issues found in production:
1. Revert merge commit: `git revert <commit-hash>`
2. Deploy previous version
3. Monitor crash reports

### Partial Rollback (< 4 hours)
If specific feature broken:
1. Identify problematic file
2. Revert specific changes: `git checkout <commit> -- <file>`
3. Test fix locally
4. Deploy hotfix

### Feature Flag Rollback
For high-risk features (comments, camera):
1. Add feature flag: `useGoRouterModals`
2. Keep old Navigator code behind flag
3. Toggle flag if issues found
4. Remove flag after stability confirmed

---

## Conclusion

This migration will modernize OpenVine's navigation architecture, eliminate hybrid complexity, and provide a solid foundation for future features. The phased approach minimizes risk while delivering incremental value.

**Next Steps**:
1. Review this plan with team
2. Get approval for timeline
3. Create feature branch
4. Begin Phase 1: Foundation Setup

**Questions?** Contact the navigation team or file an issue in the project tracker.

---

**Document Version**: 1.0
**Last Updated**: 2026-01-08
**Authors**: Claude Code Navigation Analysis
**Status**: Approved for Implementation
