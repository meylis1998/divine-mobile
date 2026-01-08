# OpenVine Navigation Architecture

**Last Updated**: 2026-01-08
**Status**: Current Implementation

---

## Table of Contents

1. [Overview](#overview)
2. [Router Configuration](#router-configuration)
3. [Navigation Patterns](#navigation-patterns)
4. [URL Structure](#url-structure)
5. [State Management](#state-management)
6. [Navigation Extensions](#navigation-extensions)
7. [Common Flows](#common-flows)
8. [Testing](#testing)
9. [Best Practices](#best-practices)

---

## Overview

OpenVine uses a **hybrid navigation architecture** combining:
- **go_router** (primary) - For declarative, URL-driven navigation
- **Navigator 1.0** (selective) - For modals, dialogs, and temporary overlays

### Key Features

- **URL as Source of Truth**: Routes drive UI state, not internal state variables
- **Per-Tab Navigation Stacks**: 13 separate navigator keys preserve state across tabs
- **ShellRoute Architecture**: Bottom navigation bar persists across main tabs
- **Deep Linking**: Full support for web URLs and app links
- **Reactive Navigation**: Riverpod providers watch URL changes

---

## Router Configuration

### Main Router Provider

**Location**: `lib/router/app_router.dart`

```dart
@riverpod
GoRouter goRouter(GoRouterRef ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/home/0',
    debugLogDiagnostics: true,
    refreshListenable: authStateNotifier,
    redirect: _globalRedirect,
    routes: _routes,
    observers: [VideoStopNavigatorObserver()],
  );
}
```

### Navigator Keys

The router maintains separate navigator keys for state preservation:

```dart
// Root navigator
final _rootKey = GlobalKey<NavigatorState>();

// Tab navigators (maintain scroll position per tab)
final _homeKey = GlobalKey<NavigatorState>();
final _exploreGridKey = GlobalKey<NavigatorState>();
final _exploreFeedKey = GlobalKey<NavigatorState>();
final _notificationsKey = GlobalKey<NavigatorState>();
final _searchEmptyKey = GlobalKey<NavigatorState>();
final _searchGridKey = GlobalKey<NavigatorState>();
final _searchFeedKey = GlobalKey<NavigatorState>();
final _hashtagGridKey = GlobalKey<NavigatorState>();
final _hashtagFeedKey = GlobalKey<NavigatorState>();
final _profileGridKey = GlobalKey<NavigatorState>();
final _profileFeedKey = GlobalKey<NavigatorState>();
final _likedVideosGridKey = GlobalKey<NavigatorState>();
final _likedVideosFeedKey = GlobalKey<NavigatorState>();
```

### Route Structure

#### Shell Routes (With Bottom Navigation)

Routes that maintain the bottom navigation bar:

```dart
ShellRoute(
  navigatorKey: _shellKey,
  builder: (context, state, child) => AppShell(child: child),
  routes: [
    // Home feed
    GoRoute(path: '/home/:index', ...),

    // Explore (grid + feed)
    GoRoute(path: '/explore', ...),
    GoRoute(path: '/explore/:index', ...),

    // Notifications
    GoRoute(path: '/notifications/:index', ...),

    // Profile (grid + feed)
    GoRoute(path: '/profile/:npub', ...),
    GoRoute(path: '/profile/:npub/:index', ...),

    // Liked videos
    GoRoute(path: '/liked-videos', ...),
    GoRoute(path: '/liked-videos/:index', ...),

    // Search
    GoRoute(path: '/search', ...),
    GoRoute(path: '/search/:searchTerm', ...),
    GoRoute(path: '/search/:searchTerm/:index', ...),

    // Hashtag
    GoRoute(path: '/hashtag/:tag', ...),
    GoRoute(path: '/hashtag/:tag/:index', ...),

    // Curated lists
    GoRoute(path: '/list/:listId', ...),
  ],
),
```

#### Non-Shell Routes (Fullscreen)

Routes that hide the bottom navigation:

```dart
// Onboarding
GoRoute(path: '/welcome', ...),
GoRoute(path: '/import-key', ...),

// Camera
GoRoute(path: '/camera', ...),
GoRoute(path: '/clip-manager', ...),

// Settings
GoRoute(path: '/settings', ...),
GoRoute(path: '/relay-settings', ...),
GoRoute(path: '/blossom-settings', ...),
GoRoute(path: '/notification-settings', ...),
GoRoute(path: '/key-management', ...),
GoRoute(path: '/safety-settings', ...),
GoRoute(path: '/developer-options', ...),

// Profile editing
GoRoute(path: '/edit-profile', ...),
GoRoute(path: '/setup-profile', ...),

// Video management
GoRoute(path: '/drafts', ...),
GoRoute(path: '/clips', ...),
GoRoute(path: '/edit-video', ...),

// Social
GoRoute(path: '/followers/:pubkey', ...),
GoRoute(path: '/following/:pubkey', ...),

// Deep links
GoRoute(path: '/video/:id', ...),
GoRoute(path: '/sound/:id', ...),

// Overlay routes
GoRoute(path: '/video-feed', ...),
GoRoute(path: '/profile-view/:npub', ...),
```

### Redirect Logic

The router implements automatic redirects based on app state:

```dart
FutureOr<String?> _globalRedirect(BuildContext context, GoRouterState state) {
  // 1. Check TOS acceptance
  final tosAccepted = ref.read(tosAcceptedProvider);
  if (!tosAccepted && state.uri.path != '/welcome') {
    return '/welcome';
  }

  // 2. Check if user has following list (first launch)
  final hasFollowing = ref.read(hasFollowingProvider);
  if (!hasFollowing && state.uri.path.startsWith('/home')) {
    return '/explore'; // Show explore instead of empty home
  }

  // 3. Allow navigation
  return null;
}
```

---

## Navigation Patterns

### Declarative Navigation (go_router)

Used for tab switching and main navigation:

```dart
// Navigate to a tab (updates URL)
context.goHome();         // /home/0
context.goExplore();      // /explore
context.goNotifications(); // /notifications/0
context.goProfile(npub);  // /profile/:npub

// Navigate with video index
context.goHome(5);        // /home/5 (video at index 5)
context.goExplore(10);    // /explore/10
```

### Imperative Navigation (go_router)

Used for pushing overlay routes:

```dart
// Push fullscreen routes
context.pushCamera();
context.pushSettings();
context.pushProfile(npub);
context.pushVideoFeed(source, index, title);
context.pushOtherProfile(npub);

// Push with result
final result = await context.pushCamera();
if (result != null) {
  // Handle uploaded video
}
```

### Modal Navigation (Navigator 1.0 - To Be Migrated)

Currently used for dialogs and bottom sheets:

```dart
// Show dialog
final confirmed = await showDialog<bool>(
  context: context,
  builder: (context) => AlertDialog(...),
);

// Show bottom sheet
await showModalBottomSheet(
  context: context,
  builder: (context) => CommentsScreen(video: video),
);

// Dismiss
Navigator.of(context).pop(result);
```

**Note**: These will be migrated to go_router in the future.

---

## URL Structure

### URL Patterns

| Route | URL | Description |
|-------|-----|-------------|
| Home | `/home/:index` | Home feed at video index |
| Explore Grid | `/explore` | Explore in grid mode |
| Explore Feed | `/explore/:index` | Explore feed at video index |
| Notifications | `/notifications/:index` | Notifications feed |
| Profile Grid | `/profile/:npub` | User profile in grid mode |
| Profile Feed | `/profile/:npub/:index` | User profile feed |
| Liked Videos Grid | `/liked-videos` | Liked videos in grid mode |
| Liked Videos Feed | `/liked-videos/:index` | Liked videos feed |
| Search Empty | `/search` | Empty search screen |
| Search Grid | `/search/:term` | Search results in grid mode |
| Search Feed | `/search/:term/:index` | Search results feed |
| Hashtag Grid | `/hashtag/:tag` | Hashtag videos in grid mode |
| Hashtag Feed | `/hashtag/:tag/:index` | Hashtag videos feed |
| Curated List | `/list/:listId` | NIP-51 curated video list |
| Video Detail | `/video/:id` | Single video view (deep link) |
| Sound Detail | `/sound/:id` | Audio track detail for reuse |
| Camera | `/camera` | Video recording |
| Settings | `/settings` | Settings screen |
| Profile View | `/profile-view/:npub` | Other user's profile |

### URL Parameters

- **`:index`** - Video position in feed (0-based integer)
- **`:npub`** - Nostr public key in npub format
- **`:tag`** - Hashtag name (without #)
- **`:term`** - Search query
- **`:listId`** - NIP-51 list identifier
- **`:id`** - Video event ID
- **`:videoId`** - Video identifier

### URL Examples

```
/home/0                           # Home feed, first video
/explore/25                       # Explore feed, video at index 25
/profile/npub1abc.../10           # User profile, video at index 10
/hashtag/nostr/5                  # #nostr hashtag, video at index 5
/search/bitcoin                   # Search for "bitcoin" (grid mode)
/search/bitcoin/3                 # Search results, video at index 3
/video/abc123                     # Deep link to specific video
/profile-view/npub1xyz...         # View other user's profile
```

---

## State Management

### Page Context Provider

Parses the current URL into structured data:

**Location**: `lib/router/page_context_provider.dart`

```dart
@riverpod
Stream<RouteContext> pageContext(PageContextRef ref) async* {
  final locations = ref.watch(routerLocationStreamProvider);
  await for (final location in locations) {
    final context = parseRoute(location);
    yield context;
  }
}
```

### Route Context

Structured representation of current route:

```dart
class RouteContext {
  final RouteType type;      // home, explore, profile, etc.
  final int? videoIndex;     // Position in video feed
  final String? npub;        // User identifier
  final String? hashtag;     // Hashtag filter
  final String? searchTerm;  // Search query
  final String? listId;      // Curated list ID
  final String? soundId;     // Audio track ID
}
```

### Route Types

**Location**: `lib/router/route_utils.dart`

```dart
enum RouteType {
  home,
  explore,
  notifications,
  profile,
  likedVideos,
  hashtag,
  search,
  camera,
  clipManager,
  editVideo,
  settings,
  relaySettings,
  blossomSettings,
  notificationSettings,
  keyManagement,
  safetySettings,
  developerOptions,
  editProfile,
  setupProfile,
  drafts,
  clips,
  followers,
  following,
  videoDetail,
  videoFeed,
  profileView,
  curatedList,
  sound,
  welcome,
  importKey,
  unknown,
}
```

### Tab History Provider

Tracks tab navigation history for back button:

**Location**: `lib/router/tab_history_provider.dart`

```dart
@riverpod
class TabHistory extends _$TabHistory {
  @override
  List<int> build() => [0]; // Start with home tab

  void push(int tabIndex) {
    // Add tab to history, remove duplicates
    state = [...state.where((t) => t != tabIndex), tabIndex];
  }

  int? getPrevious() {
    return state.length > 1 ? state[state.length - 2] : null;
  }
}
```

### Last Tab Position Provider

Remembers last video index per tab:

**Location**: `lib/router/last_tab_position_provider.dart`

```dart
@riverpod
class LastTabPosition extends _$LastTabPosition {
  @override
  Map<int, int?> build() => {};

  void updatePosition(int tabIndex, int? videoIndex) {
    state = {...state, tabIndex: videoIndex};
  }

  int? getPosition(int tabIndex) => state[tabIndex];
}
```

---

## Navigation Extensions

### Core Extensions

**Location**: `lib/router/nav_extensions.dart`

#### Tab Navigation

```dart
// Navigate to tabs (declarative - updates URL)
context.goHome([int? index]);
context.goExplore([int? index]);
context.goNotifications([int? index]);
context.goProfile(String identifier, [int? index]);
context.goProfileGrid(String identifier);
context.goMyProfile();
context.goHashtag(String tag, [int? index]);
context.goLikedVideos([int? index]);
context.goSearch([String? term, int? index]);
```

#### Overlay Navigation

```dart
// Push fullscreen overlays (imperative - adds to stack)
context.pushCamera();
context.pushSettings();
context.pushComments(VideoEvent video);
context.pushProfile(String identifier, [int? index]);
context.pushProfileGrid(String identifier);
context.pushFollowing(String pubkey, String displayName);
context.pushFollowers(String pubkey, String displayName);
context.pushVideoFeed(VideoFeedSource source, int initialIndex, String contextTitle);
context.pushOtherProfile(String identifier);
context.pushCuratedList(String listId, String listName, List<String> videoIds, String authorPubkey);
```

### Extension Implementation Pattern

```dart
extension NavigationExtensions on BuildContext {
  // Declarative navigation (updates URL)
  void goHome([int? index]) {
    if (index != null) {
      go('/home/$index');
    } else {
      go('/home/0');
    }
  }

  // Imperative navigation (pushes on stack)
  Future<T?> pushCamera<T>() {
    return push<T>('/camera');
  }

  // Navigation with complex data
  Future<void> pushVideoFeed(
    VideoFeedSource source,
    int initialIndex,
    String contextTitle,
  ) {
    return push(
      '/video-feed',
      extra: {
        'source': source,
        'initialIndex': initialIndex,
        'contextTitle': contextTitle,
      },
    );
  }
}
```

---

## Common Flows

### Flow 1: Home → Video → Comments → Back

```dart
// 1. User on home tab
// URL: /home/0

// 2. User swipes to video at index 5
// URL: /home/5 (automatic via PageView sync)

// 3. User taps comments button
context.pushComments(video);
// URL: /home/5 (comments are overlay, don't affect URL)

// 4. User dismisses comments
Navigator.of(context).pop();
// URL: /home/5 (back to video)

// 5. User taps back button
context.pop();
// URL: /home (back to grid mode)
```

### Flow 2: Explore → Video → Profile → Back

```dart
// 1. User on explore grid
// URL: /explore

// 2. User taps video thumbnail
context.goExplore(10);
// URL: /explore/10

// 3. User taps user avatar
context.pushOtherProfile(userNpub);
// URL: /explore/10 (profile pushed on top)
// Stack: [/explore/10, /profile-view/npub1...]

// 4. User taps back button
context.pop();
// URL: /explore/10 (back to video)
// Stack: [/explore/10]

// 5. User taps back button again
context.pop();
// URL: /explore (back to grid)
// Stack: []
```

### Flow 3: Tab Switching with Position Restoration

```dart
// 1. User on home feed at video 5
// URL: /home/5

// 2. User taps explore tab
_handleTabTap(context, ref, 1);
// - Stores position 5 for home tab
// - Retrieves last position for explore tab (e.g., 15)
// - Navigates to /explore/15
// URL: /explore/15

// 3. User taps home tab
_handleTabTap(context, ref, 0);
// - Retrieves stored position for home tab (5)
// - Navigates back to /home/5
// URL: /home/5 (restored position)
```

### Flow 4: Deep Link Handling

```dart
// 1. User clicks link: https://divine.video/video/abc123
// App launches or switches to foreground

// 2. GoRouter matches route
// URL: /video/abc123

// 3. VideoDetailScreen loads
// - Fetches video event by ID
// - Displays video player

// 4. User taps back button
context.pop();
// URL: /home/0 (default fallback)
```

### Flow 5: Camera → Preview → Upload

```dart
// 1. User taps camera button
context.pushCamera();
// URL: /camera

// 2. User records video and saves
// Camera screen processes video
final result = await _processVideo();

// 3. Camera pops with result
context.pop(result);
// URL: /home/0 (returns to previous screen)

// 4. Caller receives result
if (result != null) {
  await _uploadVideo(result);
}
```

---

## Router-Driven Screens

Several screens follow a **router-driven architecture** where the URL is the single source of truth:

### HomeScreenRouter

**Location**: `lib/screens/home/home_screen_router.dart`

- **Pattern**: PageView syncs bidirectionally with URL
- **State Source**: `pageContextProvider` (parsed from URL)
- **Sync Logic**:
  - URL change → jump PageController to index
  - Page swipe → update URL to new index
- **No Internal State**: No `currentIndex` variable, only URL

```dart
class HomeScreenRouter extends ConsumerStatefulWidget {
  @override
  ConsumerState<HomeScreenRouter> createState() => _HomeScreenRouterState();
}

class _HomeScreenRouterState extends ConsumerState<HomeScreenRouter> {
  late PageController _pageController;

  @override
  Widget build(BuildContext context) {
    // Watch URL for changes
    ref.listen(pageContextProvider, (previous, next) {
      if (next.videoIndex != null) {
        _pageController.jumpToPage(next.videoIndex!);
      }
    });

    return PageView.builder(
      controller: _pageController,
      onPageChanged: (index) {
        // Update URL when user swipes
        context.goHome(index);
      },
      itemBuilder: (context, index) => VideoFeedItem(...),
    );
  }
}
```

### Other Router-Driven Screens

- **ExploreScreenRouter** - Same pattern for explore feed
- **ProfileScreenRouter** - Profile video feed
- **HashtagScreenRouter** - Hashtag video feed
- **LikedVideosScreenRouter** - Liked videos feed

**Benefits**:
- URL is always accurate
- Deep linking works automatically
- Browser back button works (web)
- No state synchronization bugs
- Easy to test (just check URL)

---

## AppShell & Bottom Navigation

**Location**: `lib/router/app_shell.dart`

### Features

1. **Dynamic Header Title**
   - Home: "diVine"
   - Explore: "Explore" (tappable → navigate to /explore)
   - Notifications: "Notifications"
   - Profile: User's display name
   - Hashtag: "#hashtag" (tappable → navigate to /hashtag/:tag)

2. **Smart Back Button**
   - Pops GoRouter stack if routes available
   - Navigates from feed → grid mode for current tab
   - Returns to previous tab from history
   - Falls back to home tab
   - **Current**: Clears Navigator.push routes before GoRouter navigation

3. **Tab Tap Handling**
   - Restores last video position for each tab
   - Updates tab history for back button
   - **Current**: Clears Navigator stack before tab switch

4. **Hamburger Menu**
   - Shows when no back button is needed
   - Opens VineDrawer with navigation options

### Tab Mapping

```dart
int _getTabIndexForRoute(RouteContext? route) {
  if (route == null) return -1;

  switch (route.type) {
    case RouteType.home:
      return 0;
    case RouteType.explore:
      return 1;
    case RouteType.notifications:
      return 2;
    case RouteType.profile when route.npub == myNpub:
      return 3;
    default:
      return -1; // Not a main tab
  }
}
```

---

## Testing

### Unit Tests

**Test Files**:
- `test/router/app_router_test.dart` - Router configuration tests
- `test/router/nav_extensions_test.dart` - Navigation extension tests
- `test/router/route_utils_test.dart` - URL parsing/building tests
- `test/router/page_context_provider_test.dart` - Route context tests

**Example Test**:
```dart
testWidgets('navigates to explore when button tapped', (tester) async {
  final router = createTestRouter(initialLocation: '/home/0');

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  // Tap explore tab
  await tester.tap(find.byIcon(Icons.explore));
  await tester.pumpAndSettle();

  // Verify navigation
  expect(router.location, equals('/explore'));
  expect(find.text('Explore'), findsOneWidget);
});
```

### Widget Tests

**Pattern**: Test navigation by verifying URL changes

```dart
testWidgets('video swipe updates URL', (tester) async {
  final router = createTestRouter(initialLocation: '/home/0');

  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp.router(routerConfig: router),
    ),
  );

  // Initial state
  expect(router.location, equals('/home/0'));

  // Swipe to next video
  await tester.drag(find.byType(PageView), const Offset(0, -300));
  await tester.pumpAndSettle();

  // Verify URL updated
  expect(router.location, equals('/home/1'));
});
```

### Integration Tests

**Test File**: `test/integration/navigation_flow_test.dart`

```dart
void main() {
  testWidgets('complete navigation flow', (tester) async {
    await tester.pumpWidget(MyApp());

    // 1. Start on home
    expect(find.text('diVine'), findsOneWidget);

    // 2. Navigate to explore
    await tester.tap(find.byIcon(Icons.explore));
    await tester.pumpAndSettle();
    expect(find.text('Explore'), findsOneWidget);

    // 3. Tap video
    await tester.tap(find.byType(VideoThumbnail).first);
    await tester.pumpAndSettle();

    // 4. Open comments
    await tester.tap(find.byIcon(Icons.comment));
    await tester.pumpAndSettle();
    expect(find.text('Comments'), findsOneWidget);

    // 5. Back to video
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Comments'), findsNothing);

    // 6. Back to explore
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(ExploreScreen), findsOneWidget);
  });
}
```

---

## Best Practices

### DO: Use Declarative Navigation for Tabs

```dart
// ✅ Good: Updates URL, supports deep linking
context.goExplore(index);

// ❌ Bad: Imperative, no URL update
setState(() => _currentTab = 1);
```

### DO: Use Navigation Extensions

```dart
// ✅ Good: Type-safe, clean API
context.pushProfile(userNpub);

// ❌ Bad: Error-prone string manipulation
context.push('/profile/$userNpub');
```

### DO: Parse URL for State

```dart
// ✅ Good: URL is source of truth
final route = ref.watch(pageContextProvider).valueOrNull;
final videoIndex = route?.videoIndex ?? 0;

// ❌ Bad: Internal state variable
int _currentVideoIndex = 0;
```

### DO: Test Navigation by URL

```dart
// ✅ Good: Verifiable
await context.goExplore(5);
expect(router.location, equals('/explore/5'));

// ❌ Bad: Implementation detail
expect(_pageController.page, equals(5));
```

### DON'T: Mix Navigation APIs in Same Flow

```dart
// ❌ Bad: Mixing go_router and Navigator
context.push('/profile');
Navigator.of(context).push(...); // Stack corruption risk

// ✅ Good: Consistent API
context.push('/profile');
context.push('/video-feed');
```

### DON'T: Store Navigation State Locally

```dart
// ❌ Bad: State out of sync with URL
int _currentTab = 0;
void _handleTap(int index) {
  setState(() => _currentTab = index);
}

// ✅ Good: Derive from URL
final route = ref.watch(pageContextProvider).valueOrNull;
final currentTab = _getTabIndexForRoute(route);
```

### DON'T: Use Raw go_router API

```dart
// ❌ Bad: No type safety, string typos
context.go('/profle/npub1abc'); // Typo!

// ✅ Good: Extension catches typos at compile time
context.goProfile('npub1abc');
```

---

## Migration Guide

For information on migrating to a pure go_router architecture (removing Navigator 1.0), see:

**[NAVIGATION_REFACTOR_PLAN.md](./NAVIGATION_REFACTOR_PLAN.md)**

This guide includes:
- Migration strategy for dialogs and bottom sheets
- Code examples for each pattern
- Testing approach
- Timeline and risk assessment

---

## Additional Resources

### Related Files

- `lib/router/app_router.dart` - Main router configuration
- `lib/router/app_shell.dart` - Shell with bottom navigation
- `lib/router/nav_extensions.dart` - Navigation DSL
- `lib/router/route_utils.dart` - URL parsing utilities
- `lib/router/page_context_provider.dart` - Route context provider
- `lib/router/tab_history_provider.dart` - Tab history tracking
- `lib/router/last_tab_position_provider.dart` - Position preservation

### Documentation

- [go_router Package](https://pub.dev/packages/go_router)
- [go_router Documentation](https://docs.flutter.dev/development/ui/navigation/url-strategies)
- [Riverpod Navigation](https://riverpod.dev/docs/concepts/providers#passing-ref-as-an-argument)

### Architecture Decisions

For context on why certain navigation patterns were chosen, see:
- [ADR: URL-Driven Navigation](./adr/001-url-driven-navigation.md) (if exists)
- [ADR: Per-Tab State Preservation](./adr/002-per-tab-state.md) (if exists)

---

**Document Status**: Current Implementation
**Last Reviewed**: 2026-01-08
**Next Review**: After Navigator 1.0 Migration
