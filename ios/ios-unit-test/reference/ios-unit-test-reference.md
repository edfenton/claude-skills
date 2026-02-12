# iOS Unit Test Reference

xcodebuild commands, simulator management, and common failure patterns.

---

## xcodebuild commands

### Discover schemes

```bash
xcodebuild -list -project MyApp.xcodeproj
xcodebuild -list -workspace MyApp.xcworkspace
```

### Run all tests

```bash
# Project
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test

# Workspace (with SPM or CocoaPods)
xcodebuild \
  -workspace MyApp.xcworkspace \
  -scheme MyApp \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Run specific test target

```bash
xcodebuild \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -only-testing:MyAppTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

### Run specific test class or method

```bash
# Single test class
xcodebuild test \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -only-testing:MyAppTests/HomeViewModelTests \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# Single test method
xcodebuild test \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -only-testing:MyAppTests/HomeViewModelTests/test_load_setsItemsFromStore \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Clean before testing

```bash
xcodebuild clean test \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

### Generate test results bundle

```bash
xcodebuild test \
  -project MyApp.xcodeproj \
  -scheme MyApp \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -resultBundlePath TestResults.xcresult
```

---

## Simulator management

### List available simulators

```bash
xcrun simctl list devices available
```

### Common destinations

```bash
# iPhone (latest)
-destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# iPhone specific iOS version
-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.0'

# iPad
-destination 'platform=iOS Simulator,name=iPad Pro (12.9-inch) (6th generation)'

# Any available simulator
-destination 'platform=iOS Simulator,id=auto'
```

**Note:** Simulator names change with Xcode versions. Use `xcrun simctl list devices available` to find available simulators. For CI, use dynamic UDID discovery instead of hardcoded names.

### Boot simulator manually (if needed)

```bash
xcrun simctl boot "iPhone 17 Pro"
```

### Reset simulator state

```bash
xcrun simctl erase "iPhone 17 Pro"
```

---

## Common failure patterns

### 1. Async test not awaited properly

**Symptom:** Test completes before async work finishes; assertion fails or passes incorrectly.

```swift
// ❌ Bad: doesn't wait
@Test func load_fetchesItems() {
    sut.load()
    #expect(!sut.items.isEmpty) // Fails—load hasn't completed
}

// ✅ Good: async test
@Test func load_fetchesItems() async {
    await sut.load()
    #expect(!sut.items.isEmpty)
}
```

### 2. MainActor isolation issues

**Symptom:** "Actor-isolated property cannot be accessed from non-isolated context"

```swift
// ❌ Bad: accessing @MainActor property from non-main context
@Test func something() {
    let value = sut.items // Error if sut is @MainActor
}

// ✅ Good: mark test as @MainActor
@Test @MainActor
func something() {
    let value = sut.items // OK
    #expect(!value.isEmpty)
}

// Or use async access
@Test func something() async {
    let value = await sut.items
    #expect(!value.isEmpty)
}
```

### 3. Mock not reset between tests

**Symptom:** Tests pass alone, fail when run together.

```swift
// ✅ Fresh state via init (structs, not classes)
struct HomeViewModelTests {
    let mockStore: InMemoryPersistenceStore
    let sut: HomeViewModel

    init() {
        mockStore = InMemoryPersistenceStore()
        sut = HomeViewModel(persistenceStore: mockStore)
    }
}
```

### 4. SwiftData context threading issues

**Symptom:** Crash or unexpected behavior with "illegal access" errors.

```swift
// ✅ Use in-memory configuration for tests
let config = ModelConfiguration(isStoredInMemoryOnly: true)
let container = try ModelContainer(for: ItemModel.self, configurations: config)

// ✅ Access context on correct actor
@Test @MainActor
func persistence() async throws {
    let context = container.mainContext
    // Use context here
}
```

### 5. UI test element not found

**Symptom:** `XCTAssertTrue(element.exists)` fails; element not in hierarchy.

```swift
// ❌ Bad: checking immediately
let button = app.buttons["Save"]
XCTAssertTrue(button.exists) // Might fail if view hasn't loaded

// ✅ Good: wait for element
let button = app.buttons["Save"]
XCTAssertTrue(button.waitForExistence(timeout: 5))
```

### 6. UI test timing issues

**Symptom:** Flaky tests that pass sometimes, fail others.

```swift
// ❌ Bad: arbitrary sleep
sleep(2)
XCTAssertTrue(label.exists)

// ✅ Good: wait for specific condition
let label = app.staticTexts["Welcome"]
XCTAssertTrue(label.waitForExistence(timeout: 5))

// ✅ Good: wait for element to have value
let expectation = expectation(for: NSPredicate(format: "label == %@", "Loaded"),
                               evaluatedWith: statusLabel)
wait(for: [expectation], timeout: 5)
```

### 7. Test depends on network

**Symptom:** Test fails on CI or without internet.

```swift
// ✅ Mock the API client
let mockClient = MockAPIClient()
mockClient.stubbedResponse = .success(testData)
sut = MyViewModel(apiClient: mockClient)
```

### 8. Keychain access in tests

**Symptom:** Keychain operations fail in test environment.

```swift
// ✅ Use a test double for keychain operations
protocol SecureStorage {
    func save(key: String, data: Data) throws
    func load(key: String) throws -> Data?
    func delete(key: String) throws
}

// In tests
class MockSecureStorage: SecureStorage {
    var storage: [String: Data] = [:]

    func save(key: String, data: Data) throws {
        storage[key] = data
    }

    func load(key: String) throws -> Data? {
        storage[key]
    }

    func delete(key: String) throws {
        storage.removeValue(forKey: key)
    }
}
```

---

## Debugging tips

### View test output in real-time

```bash
xcodebuild test ... 2>&1 | tee test_output.log
```

### Parse xcresult bundle

```bash
# Summary
xcrun xcresulttool get --path TestResults.xcresult --format json

# Specific test failures
xcrun xcresulttool get --path TestResults.xcresult --id <test-id>
```

### Run tests in Xcode for debugging

1. Open project in Xcode
2. Product → Test (⌘U)
3. Use breakpoints in test code
4. Check Test Navigator (⌘6) for results

### Print debug info in tests

```swift
func test_something() async {
    await sut.load()

    // Debug output
    print("Items count: \(sut.items.count)")
    print("Items: \(sut.items)")

    XCTAssertEqual(sut.items.count, 3)
}
```

---

## Test organization

### Recommended structure

```
MyAppTests/
  Features/
    Home/
      HomeViewModelTests.swift
    Settings/
      SettingsViewModelTests.swift
  Services/
    Persistence/
      SwiftDataStoreTests.swift
    Notifications/
      NotificationRouterTests.swift
  Mocks/
    MockPersistenceStore.swift
    MockAPIClient.swift
    MockNotificationService.swift
  Helpers/
    TestFixtures.swift
    TestHelpers.swift

MyAppUITests/
  Features/
    HomeUITests.swift
    SettingsUITests.swift
  Helpers/
    XCUIApplication+Launch.swift
```

### Test naming convention

```swift
@Test func <method>_<condition>_<expected>() {
    // ...
}

// Examples
@Test func load_whenStoreEmpty_setsEmptyItems()
@Test func load_whenStoreHasItems_setsItems()
@Test func didTapSave_withValidItem_savesToStore()
@Test func didTapDelete_removesItemFromList()
```

---

## Report template

```
## Test Results

**Command:**
```

xcodebuild -project MyApp.xcodeproj -scheme MyApp -configuration NonProd \
 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test

```

**Summary:** 45 passed, 3 failed, 0 skipped

### Failures

#### MyAppTests/HomeViewModelTests

**Test:** test_load_setsItemsFromStore
**Error:**
```

Expectation failed: ([] == [Item(...)]) is false

```
**Location:** HomeViewModelTests.swift:42
**Likely cause:** Async load not awaited; test completes before items populated

#### MyAppTests/SwiftDataStoreTests

**Test:** test_save_persistsItem
**Error:**
```

Actor-isolated property 'mainContext' can not be referenced from a non-isolated context

```
**Location:** SwiftDataStoreTests.swift:28
**Likely cause:** Test method needs @MainActor annotation

#### MyAppUITests/HomeUITests

**Test:** test_addItem_showsInList
**Error:**
```

Failed to find element: staticText["New Item"]

```
**Location:** HomeUITests.swift:55
**Likely cause:** Need waitForExistence instead of immediate assertion
```

---

## Swift Testing gotchas

### Foundation import required
Swift Testing does not re-export Foundation. If your tests use `Date`, `UUID`, `Data`, etc., add `import Foundation` explicitly.

### Parameterized tests with @Test(arguments:)
Use `@Test(arguments:)` instead of loops for parameterized tests:

```swift
// ❌ Bad: loop inside test
@Test func allTypes_succeed() {
    for type in ["a", "b", "c"] {
        #expect(parse(type) != nil)
    }
}

// ✅ Good: parameterized test
@Test(arguments: ["a", "b", "c"])
func type_succeeds(type: String) {
    #expect(parse(type) != nil)
}
```

### struct, not class
Swift Testing uses structs (not XCTestCase classes). Use `init()` for setup instead of `setUp()`.

### No implicitly unwrapped optionals needed
With structs and `init()`, use `let` properties instead of `var ... !`.

---

## Quick reference

| Task                | Command                                                 |
| ------------------- | ------------------------------------------------------- |
| List schemes        | `xcodebuild -list -project MyApp.xcodeproj`             |
| Run all tests       | `xcodebuild test -scheme MyApp -destination '...'`      |
| Run one test file   | `-only-testing:MyAppTests/HomeViewModelTests`           |
| Run one test method | `-only-testing:MyAppTests/HomeViewModelTests/test_load` |
| List simulators     | `xcrun simctl list devices available`                   |
| Reset simulator     | `xcrun simctl erase "iPhone 17 Pro"`                    |
| Save results        | `-resultBundlePath TestResults.xcresult`                |
