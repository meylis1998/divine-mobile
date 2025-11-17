#!/bin/bash
# Helper script to refactor NostrService from embedded relay to direct RelayPool

echo "🔄 Refactoring NostrService to use direct RelayPool connections..."
echo "This will:"
echo "  1. Remove all embedded relay references"
echo "  2. Replace with nostr_sdk RelayPool"
echo "  3. Update all subscription/publishing methods"
echo ""
echo "Backup created at: mobile/lib/services/nostr_service.dart.backup"

cd "$(dirname "$0")"

# Create backup
cp lib/services/nostr_service.dart lib/services/nostr_service.dart.backup

echo "✅ Backup created"
echo "Now applying refactor..."
