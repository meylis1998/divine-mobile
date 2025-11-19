# Bitcode Stripping for Zendesk Frameworks

Apple deprecated bitcode in Xcode 14+, but Zendesk's iOS frameworks still contain embedded bitcode, which causes App Store validation failures.

## The Problem

When uploading to App Store Connect, you'll get these errors:
```
Invalid Executable. The executable 'Runner.app/Frameworks/CommonUISDK.framework/CommonUISDK' contains bitcode.
Invalid Executable. The executable 'Runner.app/Frameworks/MessagingAPI.framework/MessagingAPI' contains bitcode.
...and 5 more similar errors
```

## Solution: Add Xcode Build Phase

You need to add a "Run Script" build phase to strip bitcode during the build process.

### Steps:

1. **Open Xcode project:**
   ```bash
   cd ios
   open Runner.xcworkspace
   ```

2. **Select the Runner target** in the project navigator

3. **Go to Build Phases tab**

4. **Click the "+" button** and select "New Run Script Phase"

5. **Drag the new phase** to run AFTER "Embed Frameworks"

6. **Name it:** "Strip Bitcode from Zendesk Frameworks"

7. **Paste this script:**
   ```bash
   # Strip bitcode from Zendesk frameworks
   "${SRCROOT}/strip_bitcode.sh"
   ```

8. **Save and build**

The script `strip_bitcode.sh` is already in the `ios/` directory and will automatically strip bitcode from all Zendesk frameworks during every build.

## Alternative: Manual Stripping After Build

If you can't modify the Xcode project, you can manually strip bitcode from an existing archive:

```bash
# After building the archive in Xcode, run:
./strip_bitcode_from_archive.sh ~/Library/Developer/Xcode/Archives/YYYY-MM-DD/Runner.xcarchive
```

Then upload the modified archive to App Store Connect.

## Affected Frameworks

- CommonUISDK
- MessagingAPI
- MessagingSDK
- SDKConfigurations
- SupportProvidersSDK
- SupportSDK
- ZendeskCoreSDK

## Verification

After building, you can verify bitcode was stripped:

```bash
# Check if a framework contains bitcode
otool -arch arm64 -l path/to/Framework | grep __LLVM

# If output is empty, bitcode was successfully stripped
```
