# iOS Release Reference

App Store submission requirements, archive creation, and troubleshooting.

---

## Version Management

### Info.plist keys

```xml
<!-- Version shown to users (e.g., 1.2.0) -->
<key>CFBundleShortVersionString</key>
<string>$(MARKETING_VERSION)</string>

<!-- Build number (must increment each upload, e.g., 42) -->
<key>CFBundleVersion</key>
<string>$(CURRENT_PROJECT_VERSION)</string>
```

### Increment via xcconfig

```
// Config/Prod.xcconfig
MARKETING_VERSION = 1.2.0
CURRENT_PROJECT_VERSION = 42
```

### Increment via command line

```bash
# Get current values
/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "App/Info.plist"
/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "App/Info.plist"

# Set new values
agvtool new-marketing-version 1.2.0
agvtool new-version -all 42

# Or directly
/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString 1.2.0" "App/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion 42" "App/Info.plist"
```

---

## Privacy Manifest (iOS 17+)

### Required file

Create `PrivacyInfo.xcprivacy` in your app bundle:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>NSPrivacyTracking</key>
  <false/>
  <key>NSPrivacyTrackingDomains</key>
  <array/>
  <key>NSPrivacyCollectedDataTypes</key>
  <array>
    <!-- Add collected data types -->
  </array>
  <key>NSPrivacyAccessedAPITypes</key>
  <array>
    <!-- Required reason APIs -->
    <dict>
      <key>NSPrivacyAccessedAPIType</key>
      <string>NSPrivacyAccessedAPICategoryUserDefaults</string>
      <key>NSPrivacyAccessedAPITypeReasons</key>
      <array>
        <string>CA92.1</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
```

### Common required reason APIs

| API Category | Common Reason |
|--------------|---------------|
| UserDefaults | CA92.1 (app functionality) |
| File timestamp | C617.1 (app functionality) |
| System boot time | 35F9.1 (time calculations) |
| Disk space | E174.1 (download decisions) |

---

## Info.plist Requirements

### Required usage descriptions

```xml
<!-- Camera -->
<key>NSCameraUsageDescription</key>
<string>Take photos for your profile</string>

<!-- Photo Library -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Select photos to upload</string>

<!-- Location -->
<key>NSLocationWhenInUseUsageDescription</key>
<string>Find nearby stores</string>

<!-- Notifications -->
<key>NSUserNotificationsUsageDescription</key>
<string>Receive updates about your orders</string>

<!-- Face ID -->
<key>NSFaceIDUsageDescription</key>
<string>Securely unlock the app</string>

<!-- Contacts -->
<key>NSContactsUsageDescription</key>
<string>Find friends using the app</string>

<!-- Microphone -->
<key>NSMicrophoneUsageDescription</key>
<string>Record voice messages</string>
```

### App Transport Security

```xml
<!-- Only if needed - prefer HTTPS everywhere -->
<key>NSAppTransportSecurity</key>
<dict>
  <key>NSAllowsArbitraryLoads</key>
  <false/>
  <key>NSExceptionDomains</key>
  <dict>
    <key>legacy-api.example.com</key>
    <dict>
      <key>NSExceptionAllowsInsecureHTTPLoads</key>
      <true/>
      <key>NSExceptionRequiresForwardSecrecy</key>
      <false/>
    </dict>
  </dict>
</dict>
```

---

## App Icons

### Required sizes (App Store)

| Size | Purpose |
|------|---------|
| 1024x1024 | App Store (required, no alpha/transparency) |

### Asset catalog
- Use `AppIcon` asset catalog
- Let Xcode generate all sizes from 1024x1024
- Ensure no transparency (alpha channel)

### Validate icon

```bash
# Check for alpha channel
sips -g hasAlpha Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png
# Should show "hasAlpha: no"
```

---

## Archive Commands

### Create archive

```bash
# Clean first
xcodebuild clean -project MyApp.xcodeproj -scheme MyApp -configuration Release

# Archive
xcodebuild archive \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Release \
  -archivePath ./build/MyApp.xcarchive \
  -destination 'generic/platform=iOS'
```

### With workspace

```bash
xcodebuild archive \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Release \
  -archivePath ./build/MyApp.xcarchive \
  -destination 'generic/platform=iOS'
```

### Export for App Store

```bash
xcodebuild -exportArchive \
  -archivePath ./build/MyApp.xcarchive \
  -exportOptionsPlist ExportOptions.plist \
  -exportPath ./build/export
```

### ExportOptions.plist

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>
  <string>app-store-connect</string>
  <key>destination</key>
  <string>upload</string>
  <key>signingStyle</key>
  <string>automatic</string>
  <key>teamID</key>
  <string>YOUR_TEAM_ID</string>
  <key>uploadSymbols</key>
  <true/>
</dict>
</plist>
```

---

## Validation

### Validate archive

```bash
xcodebuild -validateArchive \
  -archivePath ./build/MyApp.xcarchive
```

### Validate IPA with altool (legacy)

```bash
xcrun altool --validate-app \
  -f ./build/export/MyApp.ipa \
  -t ios \
  -u "apple-id@example.com" \
  -p "@keychain:AC_PASSWORD"
```

### Upload with altool

```bash
xcrun altool --upload-app \
  -f ./build/export/MyApp.ipa \
  -t ios \
  -u "apple-id@example.com" \
  -p "@keychain:AC_PASSWORD"
```

### Using notarytool (modern)

```bash
# Store credentials
xcrun notarytool store-credentials "AC_CREDENTIALS" \
  --apple-id "apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "@keychain:AC_PASSWORD"

# Validate
xcrun notarytool submit ./build/export/MyApp.ipa \
  --keychain-profile "AC_CREDENTIALS" \
  --wait
```

---

## Pre-Release Checklist Script

```bash
#!/bin/bash
# scripts/pre-release-check.sh

set -e

echo "🚀 Running pre-release checklist..."

FAILED=0

# Version check
echo ""
echo "📋 Version & Build"
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "App/Info.plist" 2>/dev/null || echo "NOT_FOUND")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "App/Info.plist" 2>/dev/null || echo "NOT_FOUND")
echo "  Version: $VERSION"
echo "  Build: $BUILD"

# Build check
echo ""
echo "🏗️ Build (Release)"
if xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration Release -destination 'generic/platform=iOS' build 2>/dev/null; then
  echo "  ✅ Build succeeded"
else
  echo "  ❌ Build failed"
  FAILED=1
fi

# Test check
echo ""
echo "🧪 Tests"
if xcodebuild -project MyApp.xcodeproj -scheme MyApp -destination 'platform=iOS Simulator,name=iPhone 15' test 2>/dev/null; then
  echo "  ✅ Tests passed"
else
  echo "  ❌ Tests failed"
  FAILED=1
fi

# Lint check
echo ""
echo "🔍 SwiftLint"
if ./scripts/lint.sh 2>/dev/null; then
  echo "  ✅ No lint errors"
else
  echo "  ❌ Lint errors found"
  FAILED=1
fi

# App icon check
echo ""
echo "🎨 App Icon"
ICON_PATH="Assets.xcassets/AppIcon.appiconset/icon_1024x1024.png"
if [ -f "$ICON_PATH" ]; then
  HAS_ALPHA=$(sips -g hasAlpha "$ICON_PATH" 2>/dev/null | grep -c "yes" || echo "0")
  if [ "$HAS_ALPHA" = "0" ]; then
    echo "  ✅ 1024x1024 icon present (no alpha)"
  else
    echo "  ❌ Icon has alpha channel (not allowed)"
    FAILED=1
  fi
else
  echo "  ❌ 1024x1024 icon missing"
  FAILED=1
fi

# Privacy manifest check
echo ""
echo "🔒 Privacy Manifest"
if [ -f "PrivacyInfo.xcprivacy" ]; then
  echo "  ✅ PrivacyInfo.xcprivacy present"
else
  echo "  ⚠️ PrivacyInfo.xcprivacy missing (required for iOS 17+)"
fi

# Summary
echo ""
echo "================================"
if [ $FAILED -eq 0 ]; then
  echo "✅ All checks passed!"
  echo ""
  echo "Next steps:"
  echo "1. Archive: xcodebuild archive ..."
  echo "2. Validate: xcodebuild -validateArchive ..."
  echo "3. Upload via Xcode or altool"
else
  echo "❌ Some checks failed. Fix issues before release."
  exit 1
fi
```

---

## App Store Connect Checklist

### Required metadata
- [ ] App name
- [ ] Subtitle (30 chars)
- [ ] Description (4000 chars max)
- [ ] Keywords (100 chars total, comma-separated)
- [ ] Privacy policy URL
- [ ] Support URL
- [ ] Marketing URL (optional)
- [ ] Category (primary + optional secondary)

### Screenshots
| Device | Sizes required |
|--------|----------------|
| iPhone 6.9" | 1320 x 2868 or 1290 x 2796 |
| iPhone 6.7" | 1290 x 2796 |
| iPhone 6.5" | 1284 x 2778 or 1242 x 2688 |
| iPhone 5.5" | 1242 x 2208 |
| iPad Pro 13" | 2064 x 2752 |
| iPad Pro 12.9" | 2048 x 2732 |

### Age rating
Complete questionnaire covering:
- Violence
- Sexual content
- Profanity
- Drugs/alcohol
- Gambling
- Horror
- User-generated content

### App Review Information
- Contact info (name, phone, email)
- Demo account credentials (if applicable)
- Notes for reviewer

---

## Common Rejection Reasons

### 1. Metadata
- Missing privacy policy
- Placeholder text in screenshots
- Misleading screenshots

### 2. Functionality
- Crashes during review
- Login required but no demo account
- Feature doesn't work as described

### 3. Design
- Non-standard UI patterns
- Broken on certain devices
- Missing iPad support (if Universal)

### 4. Privacy
- Collecting data without disclosure
- Missing usage descriptions
- Privacy manifest incomplete

### 5. Legal
- Copyright infringement
- Trademark issues
- Gambling without license

---

## Troubleshooting

### "Missing compliance" on upload
Add to Info.plist:
```xml
<key>ITSAppUsesNonExemptEncryption</key>
<false/>
```

### Code signing issues
```bash
# List available certificates
security find-identity -v -p codesigning

# List provisioning profiles
ls ~/Library/MobileDevice/Provisioning\ Profiles/
```

### Binary rejected for bitcode
Disable bitcode (deprecated in Xcode 14+):
```
Build Settings → Enable Bitcode → No
```

### Upload stuck
```bash
# Check Transporter logs
~/Library/Logs/Transporter/

# Use Transporter app instead of xcodebuild
# Or try from different network
```
