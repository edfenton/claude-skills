# iOS Deps Reference

Swift Package Manager commands, common packages, and dependency management.

---

## SPM Commands

### Resolve dependencies

```bash
# Resolve and fetch packages
swift package resolve

# Update to latest compatible versions
swift package update

# Show dependency graph
swift package show-dependencies

# Show dependencies as JSON
swift package show-dependencies --format json
```

### Package.resolved

```bash
# Location (Xcode project)
<Project>.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved

# Location (Swift package)
Package.resolved
```

### Clean and reset

```bash
# Clean build artifacts
swift package clean

# Reset package cache
swift package reset

# Purge cache (nuclear option)
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build
swift package resolve
```

---

## Xcode Integration

### Add package via Xcode
1. File → Add Package Dependencies...
2. Enter package URL
3. Choose version rules
4. Select target(s)

### Update packages via Xcode
1. File → Packages → Update to Latest Package Versions

### Reset package caches via Xcode
1. File → Packages → Reset Package Caches

### Resolve versions via Xcode
1. File → Packages → Resolve Package Versions

---

## Version Rules

### Specifying versions

```swift
// Package.swift
dependencies: [
  // Exact version
  .package(url: "https://github.com/Alamofire/Alamofire.git", exact: "5.8.1"),

  // Up to next minor (recommended for stability)
  .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),

  // Up to next major
  .package(url: "https://github.com/Alamofire/Alamofire.git", .upToNextMajor(from: "5.0.0")),

  // Range
  .package(url: "https://github.com/Alamofire/Alamofire.git", "5.8.0"..<"6.0.0"),

  // Branch (for development only)
  .package(url: "https://github.com/Alamofire/Alamofire.git", branch: "main"),

  // Commit (for pinning)
  .package(url: "https://github.com/Alamofire/Alamofire.git", revision: "abc123"),
]
```

### Recommended strategy

| Environment | Strategy |
|-------------|----------|
| Development | `from:` (allow minor updates) |
| Production | `exact:` or `from:` with locked Package.resolved |
| CI | Always use Package.resolved |

---

## Common Packages

### Networking

```swift
// Alamofire - HTTP networking
.package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0")

// Moya - Network abstraction layer
.package(url: "https://github.com/Moya/Moya.git", from: "15.0.0")
```

### Images

```swift
// Kingfisher - Image downloading and caching
.package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0")

// SDWebImage - Image loading
.package(url: "https://github.com/SDWebImage/SDWebImage.git", from: "5.18.0")

// Nuke - Image loading (lightweight)
.package(url: "https://github.com/kean/Nuke.git", from: "12.0.0")
```

### Data

```swift
// SwiftyJSON - JSON parsing
.package(url: "https://github.com/SwiftyJSON/SwiftyJSON.git", from: "5.0.0")

// GRDB - SQLite toolkit
.package(url: "https://github.com/groue/GRDB.swift.git", from: "6.0.0")

// KeychainAccess - Keychain wrapper
.package(url: "https://github.com/kishikawakatsumi/KeychainAccess.git", from: "4.2.0")
```

### UI

```swift
// SnapKit - Auto Layout DSL
.package(url: "https://github.com/SnapKit/SnapKit.git", from: "5.6.0")

// Lottie - Animations
.package(url: "https://github.com/airbnb/lottie-ios.git", from: "4.3.0")
```

### Utilities

```swift
// swift-argument-parser - CLI argument parsing
.package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")

// swift-collections - Data structures
.package(url: "https://github.com/apple/swift-collections.git", from: "1.0.0")

// swift-algorithms - Sequence algorithms
.package(url: "https://github.com/apple/swift-algorithms.git", from: "1.0.0")
```

### Testing

```swift
// Quick - BDD testing framework
.package(url: "https://github.com/Quick/Quick.git", from: "7.0.0")

// Nimble - Matcher framework
.package(url: "https://github.com/Quick/Nimble.git", from: "13.0.0")

// OHHTTPStubs - Network stubbing
.package(url: "https://github.com/AliSoftware/OHHTTPStubs.git", from: "9.1.0")
```

---

## Check for Updates Script

```bash
#!/bin/bash
# scripts/check-deps.sh

set -e

echo "📦 Checking Swift package dependencies..."

# Parse Package.resolved and check for updates
# This is a simplified version - in practice, you'd query the package registry

if [ -f "Package.resolved" ]; then
  echo "Found Package.resolved"
  cat Package.resolved | grep -E '"(identity|version)"' | paste - - | while read line; do
    echo "$line"
  done
else
  RESOLVED_PATH=$(find . -name "Package.resolved" -path "*xcshareddata*" | head -1)
  if [ -n "$RESOLVED_PATH" ]; then
    echo "Found: $RESOLVED_PATH"
    cat "$RESOLVED_PATH" | grep -E '"(identity|version)"' | paste - -
  else
    echo "No Package.resolved found"
  fi
fi

echo ""
echo "To update packages, run: swift package update"
```

---

## Safe Update Script

```bash
#!/bin/bash
# scripts/safe-update-deps.sh

set -e

echo "📦 Starting safe dependency update..."

# Store current state
cp Package.resolved Package.resolved.backup 2>/dev/null || true

# Update packages
echo "🔄 Updating packages..."
swift package update

# Build
echo "🏗️ Building..."
if ! xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' build 2>/dev/null; then
  echo "❌ Build failed, rolling back..."
  mv Package.resolved.backup Package.resolved 2>/dev/null || true
  swift package resolve
  exit 1
fi

# Test
echo "🧪 Running tests..."
if ! xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' test 2>/dev/null; then
  echo "❌ Tests failed, rolling back..."
  mv Package.resolved.backup Package.resolved 2>/dev/null || true
  swift package resolve
  exit 1
fi

# Clean up backup
rm Package.resolved.backup 2>/dev/null || true

echo "✅ Update successful!"
echo ""
echo "Run 'git diff Package.resolved' to review changes"
```

---

## Package.swift Example

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
  name: "MyApp",
  platforms: [
    .iOS(.v17),
  ],
  products: [
    .library(name: "MyApp", targets: ["MyApp"]),
  ],
  dependencies: [
    .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.8.0"),
    .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0"),
  ],
  targets: [
    .target(
      name: "MyApp",
      dependencies: [
        "Alamofire",
        "Kingfisher",
      ]
    ),
    .testTarget(
      name: "MyAppTests",
      dependencies: ["MyApp"]
    ),
  ]
)
```

---

## Xcode Project Dependencies

For Xcode projects (not Swift packages), dependencies are managed in:
- Project Navigator → Project → Package Dependencies

Add programmatically by editing the `.xcodeproj/project.pbxproj` file (not recommended) or use:

```bash
# Use xcodebuild to resolve
xcodebuild -resolvePackageDependencies -project MyApp.xcodeproj

# Or with workspace
xcodebuild -resolvePackageDependencies -workspace MyApp.xcworkspace -scheme MyApp
```

---

## Troubleshooting

### Package resolution fails

```bash
# Clear derived data
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reset package cache
swift package reset
swift package resolve
```

### Xcode doesn't see package updates

```bash
# Close Xcode, then:
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf ~/Library/Developer/Xcode/DerivedData

# Reopen Xcode
```

### Conflicting dependencies

```bash
# Show dependency graph to identify conflicts
swift package show-dependencies --format json | python3 -m json.tool

# Or visual tree
swift package show-dependencies
```

### Binary framework issues

```bash
# Clear all caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/org.swift.swiftpm
rm -rf .build

# Re-resolve
swift package resolve
```

---

## Security Resources

### Check for vulnerabilities
- GitHub Security Advisories: Check package repos for security tabs
- Swift Package Index: https://swiftpackageindex.com/
- No official SPM audit tool exists (unlike npm audit)

### Manual audit checklist
- [ ] Check package's GitHub security advisories
- [ ] Review recent commits for security fixes
- [ ] Check issue tracker for vulnerability reports
- [ ] Verify maintainer activity (abandoned packages = risk)
- [ ] Review package permissions (network, files, etc.)
