# iOS scaffold templates

These templates are copied into new iOS repos created by the ios-scaffold skill.

## Local prerequisites
- Xcode
- Homebrew
- swiftformat + swiftlint:
  - brew install swiftformat swiftlint

## Scripts
- scripts/format.sh
- scripts/lint.sh

## CI
GitHub Actions workflow enforces:
- SwiftFormat (must be clean)
- SwiftLint (strict)
- Build/tests once an Xcode project exists
