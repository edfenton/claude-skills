# Build and run

## Local prerequisites
- Xcode installed
- Homebrew installed
- brew install swiftformat swiftlint

## If the Xcode project was not created automatically by the scaffold
1. Open Xcode
2. Create a new iOS App (SwiftUI)
3. Set the project name to your app name
4. Save it at the repository root
5. Add existing source folders under App/Sources to the target (File Inspector -> Target Membership)
6. Add Unit and UI test targets if not created automatically
7. Wire xcconfig files:
   - In Build Settings, set the configuration files:
     - Debug (NonProd) -> Config/NonProd.xcconfig
     - Release (Prod)  -> Config/Prod.xcconfig
8. Update the CI workflow with the correct scheme/project if needed

## Common commands (after project exists)
- Build:
  - xcodebuild -project <YourApp>.xcodeproj -scheme <YourScheme> -configuration NonProd build
- Unit tests:
  - xcodebuild -project <YourApp>.xcodeproj -scheme <YourScheme> -configuration NonProd test
