# OpenVine Codebase Cleanup Plan

## Executive Summary

The OpenVine codebase shows signs of rapid development with significant technical debt:
- **690 analyzer issues** requiring immediate attention
- **Critical security bypass** in CSAM detection
- **3,720+ lines of duplicate code** in profile screens alone
- **60+ test files** using timing hacks instead of proper async patterns
- **Major social features** are placeholder implementations

## Critical Issues (Fix Immediately)

### 1. Security: Re-enable CSAM Detection
**File**: `backend/src/handlers/nip96-upload.ts:122`
**Issue**: CSAM scanner is bypassed in production
**Action**: Remove try-catch that allows uploads to proceed on scanner failure
**Time**: 2 hours

### 2. Remove Deprecated Key Storage Service
**File**: `mobile/lib/services/key_storage_service.dart`
**Issue**: Contains known security vulnerabilities
**Action**: Delete file after confirming no dependencies
**Time**: 1 hour

### 3. Profile Screen Duplication (3,720 lines)
**Files**: 
- `mobile/lib/screens/profile_screen.dart` (2,573 lines)
- `mobile/lib/screens/profile_screen_scrollable.dart` (1,147 lines)
**Action**: Merge into single configurable component
**Time**: 1 day

## High Priority (Next Sprint)

### 4. Replace Future.delayed in 60+ Test Files
**Issue**: Tests use timing hacks violating async best practices
**Action**: 
- Create test utilities using Completer/StreamController patterns
- Update all test files to use proper async patterns
**Time**: 3 days

### 5. Complete Video Feed Architecture Consolidation
**Files to consolidate**:
- `video_feed_provider.dart` vs `video_feed_provider_v2.dart`
- `video_player_widget.dart` vs `video_playback_widget.dart`
- Multiple video managers and controllers
**Action**: Choose one implementation, remove others
**Time**: 2 days

### 6. Implement Core Social Features
**Current state**: All using placeholders
**Features needed**:
- Like system (NIP-25 reactions)
- Follow system (NIP-02 contact lists)
- Comments (Kind 1 text notes)
**Time**: 1 week

### 7. Fix 690 Analyzer Issues
**Categories**:
- Unused imports and variables
- Constructor argument mismatches
- Missing required parameters
**Action**: Run `dart fix --apply` then manual cleanup
**Time**: 1 day

## Medium Priority (Technical Debt)

### 8. Complete Riverpod Migration
**Current**: Mixed Provider/Riverpod usage
**Action**: 
- Update `main.dart` to use Riverpod exclusively
- Convert remaining ChangeNotifierProviders
- Remove Provider package dependency
**Time**: 3 days

### 9. Break Down Oversized Files
**Files > 1000 lines**:
- `video_feed_item.dart` (1,568 lines)
- `profile_setup_screen.dart` (1,337 lines)
**Action**: Extract widgets, split by responsibility
**Time**: 2 days

### 10. Platform Service Consolidation
**Issue**: Separate implementations for web, mobile, macOS
**Action**: Create factory pattern with single interface
**Time**: 2 days

### 11. Remove Debug Logging
**Issue**: Production code contains extensive debug logs
**Action**: Gate behind debug flags or remove
**Time**: 4 hours

## Implementation Order

### Week 1: Critical Security & Major Duplications
1. Fix CSAM detection bypass (Day 1)
2. Remove deprecated key storage (Day 1)
3. Start profile screen consolidation (Days 2-3)
4. Fix analyzer issues (Day 4)
5. Remove debug logging (Day 5)

### Week 2: Architecture Consolidation
1. Video feed provider consolidation (Days 1-2)
2. Video player widget unification (Day 3)
3. Platform service factory pattern (Days 4-5)

### Week 3: Test Suite Cleanup
1. Create async test utilities (Day 1)
2. Update test files to remove Future.delayed (Days 2-5)

### Week 4: State Management & Social Features
1. Complete Riverpod migration (Days 1-3)
2. Begin social features implementation (Days 4-5)

### Week 5-6: Social Features & File Cleanup
1. Complete social features (Week 5)
2. Break down oversized files (Week 6)

## Cleanup Metrics

### Before Cleanup
- Analyzer Issues: 690
- Duplicate Lines: ~5,000+
- Test Timing Hacks: 60+ files
- Oversized Files: 8
- Mixed State Management: Yes
- Security Issues: 2 critical

### Target After Cleanup
- Analyzer Issues: 0
- Duplicate Lines: <500
- Test Timing Hacks: 0
- Oversized Files: 0
- Mixed State Management: No (Riverpod only)
- Security Issues: 0

## File Removal List

### Immediate Removal
1. `mobile/lib/services/key_storage_service.dart` (security risk)
2. `mobile/lib/screens/profile_screen.dart` (after merging)
3. `mobile/lib/providers/video_feed_provider.dart` (keep v2)
4. `mobile/lib/widgets/video_player_widget.dart` (use playback variant)
5. All `.backup` files in project directories

### After Migration
1. Provider package dependency (after Riverpod migration)
2. VideoEventBridge import references
3. Legacy API endpoint configurations

## Testing Strategy

### Pre-Cleanup
1. Run full test suite, document baseline
2. Create integration tests for critical paths
3. Document current behavior of ambiguous features

### During Cleanup
1. Run tests after each major change
2. Use `flutter analyze` after each file modification
3. Test on all platforms after consolidation

### Post-Cleanup
1. Full regression testing
2. Performance benchmarking
3. Memory leak detection

## Risk Mitigation

### Backup Strategy
1. Create feature branch for each major cleanup task
2. Tag current state before starting
3. Keep original files in `old_files/` temporarily

### Rollback Plan
1. Each cleanup phase in separate PR
2. Feature flags for new implementations
3. Parallel running of old/new code where possible

## Success Criteria

1. **Zero analyzer warnings**
2. **All tests passing without timing hacks**
3. **No duplicate implementations**
4. **Single state management pattern**
5. **All security issues resolved**
6. **Core social features functional**
7. **Performance improvement of 20%+**

## Notes

- The V2 files appear to be the newer, cleaner implementations and should be kept
- The Riverpod migration is partially complete but needs finishing
- Social features are the biggest functional gap
- Test suite quality is good but implementation needs fixing
- Security issues are limited but critical

This plan provides a systematic approach to cleaning up the codebase while maintaining functionality and reducing risk through incremental changes.