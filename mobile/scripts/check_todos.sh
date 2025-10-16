#!/usr/bin/env bash
# ABOUTME: CI script to enforce TODO format with issue IDs
# ABOUTME: Fails if any TODO in lib/ lacks issue link (format: // TODO(#123): text)

set -euo pipefail

echo "🔍 Checking TODO format in lib/ directory..."

# Check for bare TODOs without issue IDs
# Allowed: // TODO(#123): text or // TODO(gh-123): text
# Disallowed: // TODO: text or // TODO text
if rg -n --glob 'lib/**/*.dart' -e '//\s*TODO(?!\(#\d+\)|\(gh-\d+\))' ; then
  echo ""
  echo "❌ Found TODOs without issue IDs in lib/"
  echo ""
  echo "Fix: Add issue reference in format:"
  echo "  // TODO(#123): description"
  echo "  // TODO(gh-123): description"
  echo ""
  echo "If this is a note (not actionable work), rewrite as:"
  echo "  // Note: description"
  echo ""
  exit 1
fi

echo "✅ TODO format check passed - all TODOs have issue links"
