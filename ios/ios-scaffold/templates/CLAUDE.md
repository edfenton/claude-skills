# Repo context for Claude Code (iOS)

## Stack

- Platform: iOS (Swift + SwiftUI)
- Devices: iPhone + iPad
- Architecture: MVVM with service boundaries
- Persistence: offline-first via `PersistenceStore` protocol
- Notifications: push plumbing included (compiles without APNs membership)
- Environments: non-prod + prod via xcconfig

## Project structure

```
Features/           # Feature modules (View + ViewModel)
UIComponents/       # Shared UI primitives
Services/
  Persistence/      # PersistenceStore + SwiftDataStore
  Notifications/    # Push handling (stubbed until signing)
  Network/          # API client
  Config/           # Environment
Infrastructure/     # Router, composition root
```

## Commands

```bash
./scripts/format.sh    # SwiftFormat
./scripts/lint.sh      # SwiftLint
```

Tests: via xcodebuild or Xcode (see `Docs/build-and-run.md`)
CI: GitHub Actions enforces format, lint, build, tests

## TDD (Test-Driven Development)

**All new features and bug fixes must follow TDD:**

1. **Red** — Write failing tests first
   - Derive test cases from acceptance criteria
   - Run tests via Xcode or `xcodebuild test` to confirm failure
   - Do NOT write implementation code yet

2. **Green** — Implement minimum code to pass
   - Write only enough code to make tests pass
   - Run tests after each change

3. **Refactor** — Clean up while tests stay green
   - Improve code quality without changing behavior
   - Run tests to confirm no regressions

### Test locations

| Source | Test |
|--------|------|
| `Features/Foo/FooViewModel.swift` | `Tests/Features/Foo/FooViewModelTests.swift` |
| `Services/Bar/BarService.swift` | `Tests/Services/Bar/BarServiceTests.swift` |

### What to test

- **ViewModels:** State changes, user action handling, async operations
- **Services:** Protocol conformance, error handling, edge cases
- **Models:** Validation, computed properties, codable conformance

## Skills

**Always-on:** ios-sec, ios-nfr, ios-std, ios-styleguide, retro-create

**Manual invocation:**

- `/ios-kit` — project setup
- `/ios-stack` — stack decisions reference
- `/ios-scaffold` — scaffold new features
- `/ios-unit-test` — run tests and fix failures
- `/ios-code-review` — review against policies
- `/ios-design-review` — visual review

## Notes

- If `.xcodeproj` missing, follow `Docs/build-and-run.md`
