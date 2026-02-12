# iOS Code Review Reference

Checklists and common issues. Use alongside ios-std, ios-nfr, and ios-sec skills.

---

## Automated gates

### SwiftLint

```bash
# Run lint
swiftlint lint --strict

# Auto-fix where possible
swiftlint lint --fix
```

### SwiftFormat

```bash
# Check only (no changes)
swiftformat . --lint

# Apply formatting
swiftformat .
```

### Common SwiftLint issues

| Rule                    | Issue              | Fix                                    |
| ----------------------- | ------------------ | -------------------------------------- |
| `force_cast`            | Force cast (`as!`) | Use optional cast with guard           |
| `force_unwrap`          | Force unwrap (`!`) | Use optional binding or nil coalescing |
| `line_length`           | Line too long      | Break into multiple lines              |
| `function_body_length`  | Function too long  | Extract helper methods                 |
| `cyclomatic_complexity` | Too complex        | Simplify or decompose                  |

---

## Standards review checklist (ios-std)

### Project structure

- [ ] Features in `Features/<Name>/` with View + ViewModel
- [ ] Shared UI in `UIComponents/`
- [ ] Services in `Services/` (Persistence, Notifications, Network, Config)
- [ ] One primary type per file

### SwiftUI

- [ ] Views contain no business logic
- [ ] State ownership correct (`@StateObject` vs `@ObservedObject`)
- [ ] No side effects in `body`
- [ ] Subviews extracted when files grow large

### MVVM

- [ ] ViewModels marked `@MainActor`
- [ ] State exposed via `@Published`
- [ ] Intents as methods (`load()`, `didTapSave()`)
- [ ] Dependencies injected via initializer
- [ ] No direct SwiftData/CoreData access in ViewModels

### Concurrency

- [ ] async/await used (not completion handlers)
- [ ] `@MainActor` on UI-facing code
- [ ] Cancellation handled in long-running operations
- [ ] No unstructured `Task.detached` without justification

### Naming

- [ ] Types: PascalCase
- [ ] Functions/vars: camelCase
- [ ] Feature folders: PascalCase

---

## NFR review checklist (ios-nfr)

### Performance

- [ ] No main thread blocking
- [ ] Lists use lazy loading where appropriate
- [ ] Images sized/cached appropriately
- [ ] No tight polling loops

### Accessibility

- [ ] Interactive elements have accessibility labels
- [ ] Dynamic Type doesn't break layouts
- [ ] Tap targets ≥ 44pt
- [ ] Color not sole indicator of meaning

### Offline correctness

- [ ] Local persistence is source of truth
- [ ] Schema changes have migration plan
- [ ] Storage growth bounded (cleanup strategy)

### App Store readiness

- [ ] Permission strings present and accurate
- [ ] Entitlements documented
- [ ] No private API usage

---

## Security review checklist (ios-sec)

### Data storage

- [ ] Secrets in Keychain, not UserDefaults
- [ ] Sensitive files excluded from backup
- [ ] Data at rest encrypted where appropriate

### Network

- [ ] ATS enabled (no exceptions without justification)
- [ ] Certificate pinning for sensitive endpoints
- [ ] No hardcoded credentials

### Input validation

- [ ] Deep link parameters validated before use
- [ ] Notification payloads treated as untrusted
- [ ] WebView content sanitized if used

### Logging

- [ ] os.Logger used with privacy levels
- [ ] No PII, tokens, or credentials logged
- [ ] Sensitive data marked `.private`

---

## Common issues by category

### Security (must-fix)

**Secret in UserDefaults**

```swift
// ❌ Bad
UserDefaults.standard.set(apiToken, forKey: "token")

// ✅ Good
try KeychainManager.save(key: "token", data: apiToken.data(using: .utf8)!)
```

**ATS exception without justification**

```xml
<!-- ❌ Bad: blanket exception -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <true/>
</dict>

<!-- ✅ Good: specific exception with reason -->
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSExceptionDomains</key>
    <dict>
        <key>legacy-api.example.com</key>
        <dict>
            <key>NSExceptionAllowsInsecureHTTPLoads</key>
            <true/>
            <!-- Required for legacy API until migration in Q3 -->
        </dict>
    </dict>
</dict>
```

**Unvalidated deep link**

```swift
// ❌ Bad
func handle(url: URL) {
    let id = url.pathComponents[1]
    navigateToItem(id: id) // No validation
}

// ✅ Good
func handle(url: URL) {
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
          let host = components.host,
          allowedHosts.contains(host),
          let id = components.queryItems?.first(where: { $0.name == "id" })?.value,
          id.allSatisfy({ $0.isLetter || $0.isNumber }) else {
        return
    }
    navigateToItem(id: id)
}
```

**PII in logs**

```swift
// ❌ Bad
logger.info("User logged in: \(user.email)")

// ✅ Good
logger.info("User logged in: \(user.email, privacy: .private)")
```

### Standards (should-fix)

**Business logic in View**

```swift
// ❌ Bad
struct HomeView: View {
    @State private var items: [Item] = []

    var body: some View {
        List(items) { item in
            Text(item.name)
        }
        .task {
            // Business logic in view
            let data = try? await URLSession.shared.data(from: apiURL)
            items = try? JSONDecoder().decode([Item].self, from: data)
        }
    }
}

// ✅ Good
struct HomeView: View {
    @StateObject private var viewModel: HomeViewModel

    var body: some View {
        List(viewModel.items) { item in
            Text(item.name)
        }
        .task {
            await viewModel.load()
        }
    }
}
```

**Wrong state wrapper**

```swift
// ❌ Bad: StateObject for injected dependency
struct ChildView: View {
    @StateObject var viewModel: SharedViewModel // Wrong if passed from parent
}

// ✅ Good: ObservedObject for injected dependency
struct ChildView: View {
    @ObservedObject var viewModel: SharedViewModel
}
```

**ViewModel accessing SwiftData directly**

```swift
// ❌ Bad
@MainActor
class HomeViewModel: ObservableObject {
    @Published var items: [Item] = []

    func load(context: ModelContext) {
        let models = try? context.fetch(FetchDescriptor<ItemModel>())
        items = models?.map { $0.toDomain() } ?? []
    }
}

// ✅ Good
@MainActor
class HomeViewModel: ObservableObject {
    @Published var items: [Item] = []
    private let store: PersistenceStore

    init(store: PersistenceStore) {
        self.store = store
    }

    func load() async {
        items = (try? await store.fetchItems()) ?? []
    }
}
```

### NFR (should-fix)

**Missing accessibility label**

```swift
// ❌ Bad
Button(action: toggleFavorite) {
    Image(systemName: "heart.fill")
}

// ✅ Good
Button(action: toggleFavorite) {
    Image(systemName: "heart.fill")
}
.accessibilityLabel("Remove from favorites")
```

**Force unwrap**

```swift
// ❌ Bad
let url = URL(string: urlString)!
let data = try! JSONEncoder().encode(item)

// ✅ Good
guard let url = URL(string: urlString) else {
    throw AppError.invalidURL
}
let data = try JSONEncoder().encode(item)
```

**Dynamic Type broken**

```swift
// ❌ Bad: fixed height breaks with larger text
Text(title)
    .frame(height: 44)

// ✅ Good: minimum height allows growth
Text(title)
    .frame(minHeight: 44)
```

---

## Report template

```
## Code Review Results

### Automated Gates
| Check | Status |
|-------|--------|
| SwiftLint | ❌ Fail (5 warnings, 2 errors) |
| SwiftFormat | ✅ Pass |

### Policy Review
| Category | Must-fix | Should-fix | Nice-to-have |
|----------|----------|------------|--------------|
| Security | 2 | 0 | 0 |
| Standards | 0 | 3 | 1 |
| NFR | 0 | 2 | 2 |

### Must-fix Issues

#### [sec] API token stored in UserDefaults
**File:** `Services/Config/CredentialManager.swift:34`
**Issue:** Sensitive token stored in UserDefaults instead of Keychain
**Fix:** Use KeychainManager.save() instead

#### [sec] Unvalidated deep link parameter
**File:** `Infrastructure/DeepLinkHandler.swift:22`
**Issue:** Path component used directly without validation
**Fix:** Validate against allowlist and sanitize input

### Should-fix Issues

#### [std] Business logic in View
**File:** `Features/Home/HomeView.swift:45`
**Issue:** Network call and data parsing in .task modifier
**Fix:** Move to HomeViewModel.load()

...
```

---

## Quick reference

| Task          | Command                                             |
| ------------- | --------------------------------------------------- |
| Run SwiftLint | `swiftlint lint --strict`                           |
| Auto-fix lint | `swiftlint lint --fix`                              |
| Check format  | `swiftformat . --lint`                              |
| Apply format  | `swiftformat .`                                     |
| Build         | `xcodebuild build -scheme MyApp -destination '...'` |
| Test          | `xcodebuild test -scheme MyApp -destination '...'`  |
