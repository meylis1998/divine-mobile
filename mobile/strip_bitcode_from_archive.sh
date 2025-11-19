#!/bin/bash
# Strip bitcode from Zendesk frameworks in the built app archive
# Run this script after building but BEFORE uploading to App Store

set -e

# Check if archive path is provided
if [ -z "$1" ]; then
    echo "Usage: $0 <path-to-xcarchive>"
    echo "Example: $0 ~/Library/Developer/Xcode/Archives/2025-11-18/Runner.xcarchive"
    exit 1
fi

ARCHIVE_PATH="$1"
FRAMEWORKS_PATH="${ARCHIVE_PATH}/Products/Applications/Runner.app/Frameworks"

if [ ! -d "$FRAMEWORKS_PATH" ]; then
    echo "Error: Frameworks directory not found at $FRAMEWORKS_PATH"
    exit 1
fi

echo "Stripping bitcode from Zendesk frameworks in archive..."

# List of Zendesk frameworks that contain bitcode
ZENDESK_FRAMEWORKS=(
    "CommonUISDK"
    "MessagingAPI"
    "MessagingSDK"
    "SDKConfigurations"
    "SupportProvidersSDK"
    "SupportSDK"
    "ZendeskCoreSDK"
)

for framework in "${ZENDESK_FRAMEWORKS[@]}"; do
    FRAMEWORK_BINARY="${FRAMEWORKS_PATH}/${framework}.framework/${framework}"

    if [ -f "$FRAMEWORK_BINARY" ]; then
        echo "Processing $framework..."

        # Check if it contains bitcode
        if xcrun bitcode_strip -v "$FRAMEWORK_BINARY" 2>&1 | grep -q "bitcode"; then
            echo "  Stripping bitcode from $framework"
            # Create backup
            cp "$FRAMEWORK_BINARY" "${FRAMEWORK_BINARY}.backup"
            # Strip bitcode
            xcrun bitcode_strip -r "$FRAMEWORK_BINARY" -o "$FRAMEWORK_BINARY"
            echo "  ✅ Bitcode stripped from $framework"
        else
            echo "  ℹ️  No bitcode found in $framework"
        fi
    else
        echo "  ⚠️  Framework binary not found: $FRAMEWORK_BINARY"
    fi
done

echo ""
echo "✅ Bitcode stripping complete!"
echo ""
echo "You can now upload this archive to App Store Connect:"
echo "  xcodebuild -exportArchive -archivePath \"$ARCHIVE_PATH\" ..."
