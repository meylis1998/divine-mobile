# Navigator.of(context) → go_router Migration Plan

**Date**: 2026-01-09
**Status**: Ready for Implementation
**Branch**: `refactor/navigation`
**Scope**: Replace all `Navigator.of(context)` calls with go_router equivalents

---

## Overview

This plan focuses **only** on replacing `Navigator.of(context)` API calls with their go_router equivalents. It does **not** cover modal dialogs (`showDialog`) or bottom sheets (`showModalBottomSheet`) - those remain unchanged for now.

### Summary of Changes

| Pattern | Count | go_router Equivalent |
|---------|-------|---------------------|
| `Navigator.of(context).pop()` | 62 | `context.pop()` |
| `Navigator.of(context).push()` | 8 | `context.push()` |
| `Navigator.of(context).popUntil()` | 4 | Custom handling |
| `Navigator.pop(context)` | 21 | `context.pop()` |
| **Total** | **95** | |

---

## Category 1: Simple Pop Migrations

### Pattern
```dart
// BEFORE
Navigator.of(context).pop();
Navigator.of(context).pop(result);
Navigator.pop(context);
Navigator.pop(context, result);

// AFTER
context.pop();
context.pop(result);
```

### Files to Update

#### Void Pops (no return value)

| File | Line(s) | Notes |
|------|---------|-------|
| `lib/widgets/text_overlay/text_overlay_editor.dart` | 101 | Simple close |
| `lib/widgets/profile/profile_block_confirmation_dialog.dart` | 88 | Dialog close |
| `lib/screens/hashtag_feed_screen.dart` | 267 | Back navigation |
| `lib/screens/discover_lists_screen.dart` | 347 | Back navigation |
| `lib/screens/sounds_screen.dart` | 102 | Back navigation |
| `lib/screens/settings_screen.dart` | 540, 547, 607, 618 | Various closes |
| `lib/screens/clip_library_screen.dart` | 262, 277, 304 | Various closes |
| `lib/screens/test_camera_screen.dart` | 146 | Camera dismiss |
| `lib/screens/sound_detail_screen.dart` | 156 | Back navigation |
| `lib/widgets/video_feed_item/video_feed_item.dart` | 1349 | Action close |
| `lib/screens/pure/universal_camera_screen_pure.dart` | 756, 808, 830, 1349, 2207, 2212 | Camera flow |
| `lib/screens/pure/video_metadata_screen_pure.dart` | 123, 654 | Form dismiss |
| `lib/screens/video_editor_screen.dart` | 276, 316 | Editor close |
| `lib/widgets/share_video_menu.dart` | 1285 | Menu close |
| `lib/screens/pure/search_screen_pure.dart` | 445 | Back navigation |
| `lib/screens/user_list_people_screen.dart` | 39 | Back navigation |
| `lib/widgets/proofmode_badge_row.dart` | 154 | Dialog close |
| `lib/screens/clip_manager_screen.dart` | 430 | Screen close |

#### Pops with Return Values

| File | Line(s) | Return Type | Notes |
|------|---------|-------------|-------|
| `lib/screens/profile_screen_router.dart` | 304, 308 | `bool` | Confirm actions |
| `lib/screens/other_profile_screen.dart` | 207, 211 | `bool` | Confirm actions |
| `lib/screens/settings_screen.dart` | 461, 465, 495, 499 | `bool` | Confirm dialogs |
| `lib/screens/developer_options_screen.dart` | 102, 109 | `bool` | Confirm dialog |
| `lib/screens/pure/video_metadata_screen_pure.dart` | 1319, 1323, 1804, 1811 | `bool` | Confirm dialogs |
| `lib/widgets/share_video_menu.dart` | 2598, 2602 | `bool` | Delete confirm |
| `lib/widgets/reserved_username_request_dialog.dart` | 162, 168 | void | Form close |

#### Navigator.pop(context) Pattern

| File | Line(s) | Notes |
|------|---------|-------|
| `lib/widgets/text_overlay/text_overlay_editor.dart` | 184 | Close editor |
| `lib/widgets/delete_account_dialog.dart` | 47, 152, 265, 319 | Dialog steps |
| `lib/features/feature_flags/screens/feature_flag_screen.dart` | 162, 166, 198, 213, 248 | Dialog closes |
| `lib/screens/profile_screen_router.dart` | 125, 138 | Menu returns |
| `lib/screens/relay_settings_screen.dart` | 122, 712, 716, 849, 856 | Various |
| `lib/screens/pure/video_metadata_screen_pure.dart` | 1754 | Close |
| `lib/screens/notification_settings_screen.dart` | 59 | Back |
| `lib/screens/comments/comments_screen.dart` | 116 | Header close |
| `lib/screens/key_management_screen.dart` | 454 | Dialog close |
| `lib/screens/blossom_settings_screen.dart` | 108, 167, 209 | Various |
| `lib/services/share_service.dart` | 170, 181, 193 | Share actions |

---

## Category 2: Push Migrations

### Pattern
```dart
// BEFORE
Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => SomeScreen(args),
  ),
);

// AFTER
context.push('/route-path', extra: args);
// OR use existing nav extension:
context.pushSomeScreen(args);
```

### Files to Update

| File | Line | Current Push | Migration |
|------|------|--------------|-----------|
| `lib/widgets/video_feed_item/video_feed_item.dart` | 956 | `CuratedListFeedScreen` | `context.pushCuratedList(...)` (exists) |
| `lib/screens/activity_screens.dart` | 333 | Activity detail | Create route or use existing |
| `lib/screens/pure/universal_camera_screen_pure.dart` | 1344 | Sound picker | Create route |
| `lib/screens/explore_screen.dart` | 437, 672 | Detail views | Use existing routes |
| `lib/screens/notifications_screen.dart` | 328 | Notification detail | Use existing routes |
| `lib/screens/video_editor_screen.dart` | 303, 403 | Sound picker, metadata | Create routes |
| `lib/screens/clip_manager_screen.dart` | 658 | Export/publish | Create route |

### Required Route Additions

Some pushes require new go_router routes:

```dart
// Sound picker modal - add to app_router.dart
GoRoute(
  path: '/sound-picker',
  name: 'sound-picker',
  builder: (_, state) {
    final onSelect = state.extra as void Function(AudioEvent)?;
    return SoundPickerModal(onSoundSelected: onSelect);
  },
),
```

---

## Category 3: PopUntil Migrations (CRITICAL)

### Current Usage

```dart
// app_shell.dart:121 and 203
final navigator = Navigator.of(context);
if (navigator.canPop()) {
  navigator.popUntil((route) => route.isFirst);
}
```

### Problem

This code exists because some screens are pushed via `Navigator.push()` instead of go_router. The shell needs to clear these before switching tabs.

### Solution

**Step 1**: First migrate all `Navigator.push()` calls in Category 2 to go_router.

**Step 2**: Once all pushes use go_router, the `popUntil` becomes unnecessary because go_router manages the entire stack.

**Step 3**: Replace with simpler logic:

```dart
// AFTER - when all pushes use go_router
void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
  // go_router handles stack - no manual clearing needed
  switch (tabIndex) {
    case 0:
      context.goHome(lastIndex ?? 0);
      break;
    // ... etc
  }
}
```

### profile_setup_screen.dart PopUntil

```dart
// Lines 1187 and 1238
Navigator.of(context).popUntil((route) => route.isFirst);
```

**Migration**: Replace with `context.go('/home/0')` or appropriate destination route. The `go` method replaces the entire stack.

---

## Implementation Order

### Phase 1: Simple Pops (Low Risk)
**Goal**: Replace all `Navigator.of(context).pop()` and `Navigator.pop(context)` with `context.pop()`

1. Start with files that have fewest changes (1-2 pops)
2. Move to files with multiple pops
3. Test each file after migration

### Phase 2: Push Migrations (Medium Risk)
**Goal**: Replace all `Navigator.of(context).push()` with go_router navigation

1. Ensure routes exist in `app_router.dart`
2. Add any missing routes
3. Replace push calls with `context.push()` or nav extensions
4. Test navigation flows

### Phase 3: PopUntil Removal (High Risk)
**Goal**: Remove Navigator stack coordination from app_shell.dart

1. **Prerequisite**: All Phase 2 pushes must be complete
2. Remove `popUntil` calls from `app_shell.dart`
3. Replace `popUntil` in `profile_setup_screen.dart` with `context.go()`
4. Extensive testing of tab navigation

---

## Migration Examples

### Example 1: Simple Pop

**File**: `lib/screens/sounds_screen.dart:102`

```dart
// BEFORE
IconButton(
  onPressed: () => Navigator.of(context).pop(),
  icon: const Icon(Icons.arrow_back),
)

// AFTER
IconButton(
  onPressed: () => context.pop(),
  icon: const Icon(Icons.arrow_back),
)
```

### Example 2: Pop with Return Value

**File**: `lib/screens/settings_screen.dart:461-465`

```dart
// BEFORE
TextButton(
  onPressed: () => Navigator.of(context).pop(false),
  child: const Text('Cancel'),
),
TextButton(
  onPressed: () => Navigator.of(context).pop(true),
  child: const Text('Confirm'),
),

// AFTER
TextButton(
  onPressed: () => context.pop(false),
  child: const Text('Cancel'),
),
TextButton(
  onPressed: () => context.pop(true),
  child: const Text('Confirm'),
),
```

### Example 3: Push Migration

**File**: `lib/widgets/video_feed_item/video_feed_item.dart:956`

```dart
// BEFORE
Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => CuratedListFeedScreen(
      listId: listId,
      listName: listName,
      videoIds: videoIds,
      authorPubkey: authorPubkey,
    ),
  ),
);

// AFTER (using existing nav extension)
context.pushCuratedList(
  listId: listId,
  listName: listName,
  videoIds: videoIds,
  authorPubkey: authorPubkey,
);
```

### Example 4: PopUntil Replacement

**File**: `lib/screens/profile_setup_screen.dart:1187`

```dart
// BEFORE
Navigator.of(context).popUntil((route) => route.isFirst);

// AFTER - navigate to specific destination
context.go('/home/0');  // or context.go('/explore') depending on flow
```

---

## Verification

After migration, run:

```bash
# Should return 0 for production code (excluding app_router.dart ShellRoute usage)
grep -r "Navigator.of(context)" lib/ --include="*.dart" | grep -v "app_router.dart" | grep -v "test" | wc -l

# Should return 0
grep -r "Navigator.pop(context" lib/ --include="*.dart" | grep -v "test" | wc -l

# Should return only app_router.dart ShellRoute usage
grep -r "MaterialPageRoute" lib/ --include="*.dart" | grep -v "test"
```

---

## Files Summary (Sorted by Change Count)

| File | Changes | Priority |
|------|---------|----------|
| `universal_camera_screen_pure.dart` | 7 | HIGH |
| `video_metadata_screen_pure.dart` | 6 | HIGH |
| `share_video_menu.dart` | 4 | HIGH |
| `settings_screen.dart` | 8 | HIGH |
| `feature_flag_screen.dart` | 5 | MEDIUM |
| `delete_account_dialog.dart` | 4 | MEDIUM |
| `relay_settings_screen.dart` | 5 | MEDIUM |
| `clip_library_screen.dart` | 3 | MEDIUM |
| `blossom_settings_screen.dart` | 3 | MEDIUM |
| `profile_screen_router.dart` | 4 | HIGH |
| `app_shell.dart` | 2 | CRITICAL |
| `profile_setup_screen.dart` | 2 | HIGH |
| All other files | 1-2 each | LOW |

---

## Testing Checklist

For each migrated file:

- [ ] Navigation works as before
- [ ] Return values are correctly passed (for pops with results)
- [ ] Back button/gesture works
- [ ] No regressions in related flows
- [ ] Widget tests still pass (update mocks if needed)

---

## Next Steps

1. **Start with Phase 1** - Simple pop migrations (lowest risk)
2. Pick a file with few changes as the first target
3. Create PR with batch of related changes
4. Test thoroughly before moving to next phase

Would you like me to start implementing changes for a specific file?
