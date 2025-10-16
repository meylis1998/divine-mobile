# PR-B: Delete 3 Zombie Files Depending on Removed VideoManager

## Summary
Deletes 3 files with 0 imports that are fully disabled and depend on the deleted `IVideoManager` interface.

## Files Deleted
1. **`lib/services/nostr_video_bridge.dart`** (396 lines)
2. **`lib/services/video_performance_monitor.dart`** (881 lines)
3. **`lib/widgets/video_preview_tile.dart`** (269 lines)

**Total:** 1,546 lines of dead code removed, 15 TODOs eliminated

## Proof of Delete Safety

### Zero Imports
```bash
$ rg -n "import.*nostr_video_bridge" lib/ test/
# No results

$ rg -n "import.*video_performance_monitor" lib/ test/
# No results

$ rg -n "import.*video_preview_tile" lib/ test/
# No results
```

### Zero Class References
```bash
$ rg -n "NostrVideoBridge|VideoPerformanceMonitor|VideoPreviewTile" lib/ test/
# No results
```

### Analysis Clean
```bash
$ flutter analyze
Analyzing mobile...

   info • 'ActiveVideoNotifier' is deprecated and shouldn't be used (2 unrelated deprecation warnings)

2 issues found. (ran in 3.4s)
```

## Why These Files Were Dead

### 1. nostr_video_bridge.dart
- Constructor 100% commented out (lines 27-36)
- All fields set to `null` (lines 41-43)
- Has placeholder constructor `NostrVideoBridge.disabled()`
- Depends on deleted `IVideoManager`
- 6 TODOs: "Restore when needed" / "Remove or refactor"

### 2. video_performance_monitor.dart
- Main class 100% commented out (lines 17-619)
- Entire `VideoPerformanceMonitor` wrapped in `/* ... */` block
- Depends on deleted `IVideoManager`
- Only data classes remain (unused)
- 5 TODOs: "Restore when VideoPerformanceMonitor/IVideoManager available"

### 3. video_preview_tile.dart
- Core logic disabled (lines 98-134 commented out)
- Controller creation always returns `null` (line 170)
- Widget immediately sets `_hasError = true` (line 100)
- Depends on deleted VideoManager providers
- 4 TODOs: "Restore when VideoManager available"

## Architecture Context
These files are fossils from the pre-Riverpod VideoManager refactor:
- The `IVideoManager` interface was deleted during the migration to Riverpod-based video management
- The new architecture uses `VideoPageView` + `ActiveVideoProvider` instead
- These bridge/adapter classes have no path to restoration (architecture has fundamentally changed)

## Verification Steps
1. ✅ Deleted files with `git rm`
2. ✅ Checked for barrel exports (none found)
3. ✅ `flutter clean && flutter pub get` (success)
4. ✅ `flutter analyze` (2 unrelated deprecation warnings, 0 errors)
5. ✅ `dart run build_runner build -d` (success, 139 outputs generated)
6. ✅ `rg` for class names (0 references)

## Impact
- **Code reduction:** -1,546 lines
- **TODO reduction:** -15 zombie TODOs
- **Compilation:** No changes (files had 0 imports)
- **Tests:** No changes (files had 0 references)
- **Risk:** Zero (files were fully disabled stubs)
