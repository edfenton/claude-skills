# Shared README Reference

Templates and examples for generating project README files.

---

## MERN README Template

```markdown
# Project Name

[![CI](https://github.com/username/repo/workflows/CI/badge.svg)](https://github.com/username/repo/actions)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Brief description of what this project does and who it's for.

## Features

- ✅ Feature one
- ✅ Feature two
- ✅ Feature three
- 🚧 Upcoming feature (in progress)

## Tech Stack

- **Framework:** Next.js (App Router)
- **Language:** TypeScript
- **Database:** MongoDB with Mongoose
- **Auth:** NextAuth.js
- **Styling:** Tailwind CSS
- **Testing:** Vitest + Playwright

## Prerequisites

- Node.js 22+
- pnpm 9+
- MongoDB (local or Atlas)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/username/repo.git
cd repo

# Install dependencies
pnpm install

# Set up environment variables
cp .env.example .env
# Edit .env with your values

# Start development server
pnpm dev
```

Open [http://localhost:3000](http://localhost:3000) to view the app.

## Environment Variables

See [.env.example](.env.example) for all required variables.

Key variables:
| Variable | Description |
|----------|-------------|
| `MONGODB_URI` | MongoDB connection string |
| `NEXTAUTH_SECRET` | Auth secret (32+ chars) |
| `NEXTAUTH_URL` | Application URL |

## Development

```bash
# Start development server
pnpm dev

# Run tests
pnpm test

# Run tests in watch mode
pnpm test:watch

# Run linting
pnpm lint

# Format code
pnpm format

# Build for production
pnpm build
```

## Project Structure

```
├── apps/
│   └── web/                 # Next.js application
│       ├── app/             # App Router pages and API routes
│       ├── src/
│       │   ├── components/  # React components
│       │   ├── lib/         # Utilities and helpers
│       │   └── server/      # Server-side code
│       └── e2e/             # Playwright tests
├── packages/
│   └── shared/              # Shared schemas and utilities
└── docs/                    # Documentation
```

## API Documentation

API documentation is available at `/api/docs` when running in development mode.

See [API.md](docs/API.md) for detailed endpoint documentation.

## Deployment

### Vercel (Recommended)

[![Deploy with Vercel](https://vercel.com/button)](https://vercel.com/new/clone?repository-url=https://github.com/username/repo)

### Docker

```bash
docker build -t myapp .
docker run -p 3000:3000 --env-file .env.production myapp
```

See [Deployment Guide](docs/deployment.md) for detailed instructions.

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and development process.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Next.js](https://nextjs.org/)
- [Tailwind CSS](https://tailwindcss.com/)
- [MongoDB](https://www.mongodb.com/)
```

---

## iOS README Template

```markdown
# App Name

[![CI](https://github.com/username/repo/workflows/CI/badge.svg)](https://github.com/username/repo/actions)
[![Platform](https://img.shields.io/badge/platform-iOS%2017+-blue.svg)](https://developer.apple.com/ios/)
[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org/)

Brief description of what this app does.

## Features

- ✅ Feature one
- ✅ Feature two
- ✅ Feature three
- 🚧 Upcoming feature (in progress)

## Screenshots

| Home | Detail | Settings |
|------|--------|----------|
| ![Home](docs/screenshots/home.png) | ![Detail](docs/screenshots/detail.png) | ![Settings](docs/screenshots/settings.png) |

## Tech Stack

- **UI:** SwiftUI
- **Architecture:** MVVM
- **Persistence:** SwiftData
- **Concurrency:** Swift async/await
- **Minimum iOS:** 17.0

## Prerequisites

- macOS 14.0+
- Xcode 15.4+
- iOS 17.0+ simulator or device

## Quick Start

```bash
# Clone the repository
git clone https://github.com/username/repo.git
cd repo

# Install development tools
brew install swiftlint swiftformat

# Open in Xcode
open App.xcodeproj
```

Select a simulator and press `Cmd+R` to build and run.

## Development

### Build & Run

```bash
# Build (command line)
xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' build

# Run tests
xcodebuild -scheme App -destination 'platform=iOS Simulator,name=iPhone 15' test

# Or use Xcode: Cmd+B (build), Cmd+R (run), Cmd+U (test)
```

### Code Quality

```bash
# Run linting
./scripts/lint.sh

# Format code
./scripts/format.sh
```

### Environment Configuration

The app uses xcconfig files for environment-specific settings:

| Config | Purpose |
|--------|---------|
| `NonProd.xcconfig` | Development/staging |
| `Prod.xcconfig` | Production |

To switch environments, change the build configuration in Xcode.

## Project Structure

```
├── App/
│   └── Sources/
│       ├── AppEntry/        # App entry point
│       ├── Features/        # Feature modules
│       │   └── Home/        # Example feature
│       ├── UIComponents/    # Reusable UI components
│       ├── Models/          # Data models
│       ├── Services/        # Business logic services
│       └── Infrastructure/  # DI, utilities
├── Tests/
│   ├── UnitTests/           # Unit tests
│   └── UITests/             # UI tests
├── Config/                  # xcconfig files
└── Docs/                    # Documentation
```

## Architecture

This app follows MVVM (Model-View-ViewModel):

- **Views:** SwiftUI views, minimal logic
- **ViewModels:** `@MainActor` classes, `@Published` state, intent methods
- **Models:** Domain models and SwiftData models
- **Services:** Business logic, persistence, networking

See [Architecture Decision Records](docs/adr/) for detailed design decisions.

## Testing

```bash
# Run all tests
xcodebuild test -scheme App -destination 'platform=iOS Simulator,name=iPhone 15'

# Run unit tests only
xcodebuild test -scheme AppTests -destination 'platform=iOS Simulator,name=iPhone 15'
```

Test coverage target: 80% for ViewModels and Services.

## Release

See [Release Guide](docs/release.md) for App Store submission instructions.

### Build for TestFlight

1. Update version in Xcode (or `Config/Base.xcconfig`)
2. Archive: Product → Archive
3. Upload to App Store Connect

## Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feat/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feat/amazing-feature`)
5. Open a Pull Request

Please ensure:
- All tests pass
- No SwiftLint errors
- Code is formatted with SwiftFormat

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [Apple SwiftUI](https://developer.apple.com/swiftui/)
- [SwiftLint](https://github.com/realm/SwiftLint)
```

---

## Minimal README Template

```markdown
# Project Name

Brief description.

## Quick Start

```bash
# Install
pnpm install  # or: open App.xcodeproj

# Run
pnpm dev      # or: Cmd+R in Xcode
```

## Development

```bash
pnpm test     # Run tests
pnpm lint     # Run linting
pnpm build    # Build for production
```

## License

MIT
```

---

## Badge Templates

### GitHub Actions CI

```markdown
[![CI](https://github.com/USERNAME/REPO/workflows/CI/badge.svg)](https://github.com/USERNAME/REPO/actions)
```

### Code Coverage (Codecov)

```markdown
[![codecov](https://codecov.io/gh/USERNAME/REPO/branch/main/graph/badge.svg)](https://codecov.io/gh/USERNAME/REPO)
```

### License

```markdown
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![License: Apache 2.0](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
```

### Platform

```markdown
[![Platform](https://img.shields.io/badge/platform-iOS%2017+-blue.svg)](https://developer.apple.com/ios/)
[![Node](https://img.shields.io/badge/node-22+-green.svg)](https://nodejs.org/)
```

### Version

```markdown
[![npm version](https://img.shields.io/npm/v/PACKAGE.svg)](https://www.npmjs.com/package/PACKAGE)
[![App Store](https://img.shields.io/itunes/v/APP_ID.svg)](https://apps.apple.com/app/idAPP_ID)
```

---

## Generation Script

```bash
#!/bin/bash
# scripts/generate-readme.sh

set -e

PLATFORM="${1:-auto}"
MINIMAL="${2:-false}"

# Auto-detect platform
if [ "$PLATFORM" = "auto" ]; then
  if [ -f "package.json" ]; then
    PLATFORM="mern"
  elif [ -d "*.xcodeproj" ] || [ -f "Package.swift" ]; then
    PLATFORM="ios"
  else
    echo "Could not detect platform. Specify: mern or ios"
    exit 1
  fi
fi

echo "Generating README for $PLATFORM platform..."

# Extract project info
if [ "$PLATFORM" = "mern" ]; then
  NAME=$(node -p "require('./package.json').name" 2>/dev/null || echo "Project")
  DESCRIPTION=$(node -p "require('./package.json').description" 2>/dev/null || echo "")
  VERSION=$(node -p "require('./package.json').version" 2>/dev/null || echo "1.0.0")
else
  # iOS - extract from xcodeproj or Info.plist
  NAME=$(basename *.xcodeproj .xcodeproj 2>/dev/null || echo "App")
  DESCRIPTION=""
fi

# Generate based on template
# ... (apply template with extracted values)

echo "✅ README.md generated"
```

---

## README Checklist

Before publishing, verify:

- [ ] Project name and description are clear
- [ ] Prerequisites list all required tools with versions
- [ ] Quick start works on a fresh clone
- [ ] All code blocks are copy-paste ready
- [ ] Links work (no broken links)
- [ ] Screenshots are current (if included)
- [ ] License file exists and matches badge
- [ ] Contact/contribution info is current

---

## Tips for Good READMEs

1. **Lead with value** — What does this do? Why should I care?
2. **Quick start first** — Get users running in < 5 minutes
3. **Copy-paste ready** — Code blocks should work as-is
4. **Scannable structure** — Use headings, lists, tables
5. **Keep it current** — Update when things change
6. **Link to details** — Don't repeat docs, link to them
7. **Include visuals** — Screenshots, diagrams, badges
8. **Test your setup steps** — Clone fresh and follow them
