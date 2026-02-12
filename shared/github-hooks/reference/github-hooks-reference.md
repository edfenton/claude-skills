# GitHub Hooks Reference

Local Git hook configurations for MERN, NEAN, and iOS projects.

---

## MERN Setup (Husky + lint-staged + pnpm)

### Install dependencies

```bash
pnpm add -D husky lint-staged @commitlint/cli @commitlint/config-conventional -w
```

### pnpm 10 compatibility

Add to root `package.json` to allow husky's install script:

```json
{
  "pnpm": {
    "onlyBuiltDependencies": ["husky"]
  }
}
```

### Initialize Husky

```bash
# Initialize husky
pnpm exec husky init

# This creates .husky/ directory and updates package.json
```

### Pre-commit hook

Husky v9+ hooks are plain shell scripts (no sourcing line needed):

```bash
# .husky/pre-commit
pnpm exec lint-staged

# Run secret scanning (if gitleaks installed)
if command -v gitleaks &> /dev/null; then
  gitleaks protect --staged --verbose
fi
```

### Commit-msg hook

```bash
# .husky/commit-msg
pnpm exec commitlint --edit $1
```

### Pre-push hook

```bash
# .husky/pre-push
echo "Running tests before push..."
pnpm test

echo "Running build..."
pnpm build
```

### lint-staged configuration

```json
// .lintstagedrc.json
{
  "*.{js,jsx,ts,tsx}": [
    "eslint --fix",
    "prettier --write"
  ],
  "*.{json,md,yml,yaml}": [
    "prettier --write"
  ],
  "*.css": [
    "prettier --write"
  ]
}
```

### Commitlint configuration

```json
// .commitlintrc.json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "build",
        "ci",
        "chore",
        "revert"
      ]
    ],
    "subject-case": [2, "always", "lower-case"],
    "header-max-length": [2, "always", 72],
    "body-max-line-length": [2, "always", 100]
  }
}
```

### Package.json updates

```json
{
  "scripts": {
    "prepare": "husky"
  },
  "lint-staged": {
    "*.{js,jsx,ts,tsx}": ["eslint --fix", "prettier --write"],
    "*.{json,md,yml,yaml}": ["prettier --write"]
  }
}
```

---

## NEAN Setup (Husky + lint-staged + npm/Nx)

### Install dependencies

```bash
npm install -D husky lint-staged @commitlint/cli @commitlint/config-conventional
```

### Initialize Husky

```bash
# Initialize husky
npx husky init

# This creates .husky/ directory and updates package.json
```

### Pre-commit hook

Husky v9+ hooks are plain shell scripts (no sourcing line needed):

```bash
# .husky/pre-commit
npx lint-staged

# Run secret scanning (if gitleaks installed)
if command -v gitleaks &> /dev/null; then
  gitleaks protect --staged --verbose
fi
```

### Commit-msg hook

```bash
# .husky/commit-msg
npx commitlint --edit $1
```

### Pre-push hook (Nx-optimized)

```bash
# .husky/pre-push
echo "Running affected tests before push..."
# Only test what's affected by your changes (much faster!)
npx nx affected --target=test --parallel=3

echo "Running affected build..."
npx nx affected --target=build --parallel=3
```

### lint-staged configuration (Nx-aware)

```json
// .lintstagedrc.json
{
  "*.{ts,tsx,js,jsx}": [
    "npx nx affected --target=lint --fix --files"
  ],
  "*.{json,md,yml,yaml,html,scss,css}": [
    "prettier --write"
  ]
}
```

**Alternative (simpler, but slower):**

```json
// .lintstagedrc.json
{
  "apps/**/*.{ts,tsx}": [
    "eslint --fix",
    "prettier --write"
  ],
  "libs/**/*.{ts,tsx}": [
    "eslint --fix",
    "prettier --write"
  ],
  "*.{json,md,yml,yaml}": [
    "prettier --write"
  ],
  "*.{html,scss,css}": [
    "prettier --write"
  ]
}
```

### Commitlint configuration

```json
// .commitlintrc.json
{
  "extends": ["@commitlint/config-conventional"],
  "rules": {
    "type-enum": [
      2,
      "always",
      [
        "feat",
        "fix",
        "docs",
        "style",
        "refactor",
        "perf",
        "test",
        "build",
        "ci",
        "chore",
        "revert"
      ]
    ],
    "scope-enum": [
      1,
      "always",
      [
        "api",
        "web",
        "shared",
        "auth",
        "database",
        "ui",
        "deps",
        "config"
      ]
    ],
    "subject-case": [2, "always", "lower-case"],
    "header-max-length": [2, "always", 72],
    "body-max-line-length": [2, "always", 100]
  }
}
```

### Package.json updates

```json
{
  "scripts": {
    "prepare": "husky",
    "lint": "nx run-many --target=lint --all",
    "test": "nx run-many --target=test --all",
    "build": "nx run-many --target=build --all"
  }
}
```

### Nx-specific optimizations

The NEAN setup uses Nx's affected commands which:
- Only lint/test projects affected by your changes
- Use computation caching (instant if nothing changed)
- Run in parallel for speed

```bash
# Example: only runs tests for projects affected by staged files
npx nx affected --target=test --base=HEAD~1

# With parallel execution
npx nx affected --target=test --parallel=3
```

---

## iOS Setup (Direct Git Hooks)

### Hook directory setup

```bash
# Create hooks directory
mkdir -p .githooks

# Configure git to use custom hooks directory
git config core.hooksPath .githooks
```

### Pre-commit hook

```bash
#!/bin/bash
# .githooks/pre-commit

set -e

echo "Running pre-commit checks..."

# Get staged Swift files
STAGED_SWIFT_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' || true)

if [ -n "$STAGED_SWIFT_FILES" ]; then
  echo "Checking Swift files..."

  # Run SwiftLint on staged files
  if command -v swiftlint &> /dev/null; then
    echo "$STAGED_SWIFT_FILES" | xargs swiftlint lint --strict --quiet
    if [ $? -ne 0 ]; then
      echo "SwiftLint found errors. Please fix them before committing."
      exit 1
    fi
    echo "  SwiftLint passed"
  else
    echo "  SwiftLint not installed, skipping..."
  fi

  # Run SwiftFormat on staged files
  if command -v swiftformat &> /dev/null; then
    echo "$STAGED_SWIFT_FILES" | xargs swiftformat --lint --quiet
    if [ $? -ne 0 ]; then
      echo "SwiftFormat found formatting issues."
      echo "Run 'swiftformat .' to fix them."
      exit 1
    fi
    echo "  SwiftFormat passed"
  else
    echo "  SwiftFormat not installed, skipping..."
  fi
fi

# Secret scanning
if command -v gitleaks &> /dev/null; then
  echo "Scanning for secrets..."
  gitleaks protect --staged --verbose
  if [ $? -ne 0 ]; then
    echo "Secrets detected! Remove them before committing."
    exit 1
  fi
  echo "  No secrets found"
else
  echo "  gitleaks not installed, skipping secret scan..."
fi

echo "Pre-commit checks passed!"
```

### Commit-msg hook

```bash
#!/bin/bash
# .githooks/commit-msg

set -e

COMMIT_MSG_FILE=$1
COMMIT_MSG=$(cat "$COMMIT_MSG_FILE")

# Conventional commit regex
PATTERN="^(feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert)(\([a-z0-9-]+\))?: .{1,50}"

if ! echo "$COMMIT_MSG" | grep -qE "$PATTERN"; then
  echo "Invalid commit message format!"
  echo ""
  echo "Expected format: <type>(<scope>): <subject>"
  echo ""
  echo "Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert"
  echo ""
  echo "Examples:"
  echo "  feat(auth): add biometric login"
  echo "  fix(api): handle network timeout"
  echo "  docs: update README"
  echo ""
  echo "Your message: $COMMIT_MSG"
  exit 1
fi

# Check message length
FIRST_LINE=$(echo "$COMMIT_MSG" | head -n 1)
if [ ${#FIRST_LINE} -gt 72 ]; then
  echo "Commit message first line too long (${#FIRST_LINE} > 72 chars)"
  exit 1
fi

echo "Commit message format valid"
```

### Pre-push hook

```bash
#!/bin/bash
# .githooks/pre-push

set -e

echo "Running tests before push..."

# Detect project type
if [ -f "Package.swift" ] || [ -d "*.xcodeproj" ] || [ -d "*.xcworkspace" ]; then
  # iOS project
  SCHEME=$(xcodebuild -list -json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin)['project']['schemes'][0])" 2>/dev/null || echo "App")

  xcodebuild test \
    -scheme "$SCHEME" \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    -quiet

  if [ $? -ne 0 ]; then
    echo "Tests failed! Push aborted."
    exit 1
  fi
else
  echo "Could not detect project type, skipping tests..."
fi

echo "All tests passed!"
```

### Installation script

```bash
#!/bin/bash
# scripts/install-hooks.sh

set -e

echo "Installing Git hooks..."

# Set hooks path
git config core.hooksPath .githooks

# Make hooks executable
chmod +x .githooks/*

echo "Git hooks installed!"
echo ""
echo "Hooks will now run automatically on:"
echo "  - pre-commit: lint, format, secret scan"
echo "  - commit-msg: validate commit format"
echo "  - pre-push: run tests"
echo ""
echo "To bypass hooks (not recommended):"
echo "  git commit --no-verify"
echo "  git push --no-verify"
```

---

## Gitleaks Configuration

### Installation

```bash
# macOS
brew install gitleaks

# Linux
# Download from https://github.com/gitleaks/gitleaks/releases
```

### Configuration file

```toml
# .gitleaks.toml
title = "Gitleaks Config"

[allowlist]
description = "Allowlisted files and patterns"
paths = [
  '''\.gitleaks\.toml$''',
  '''\.env\.example$''',
  '''package-lock\.json$''',
  '''pnpm-lock\.yaml$''',
]

# Custom rules
[[rules]]
id = "custom-api-key"
description = "Custom API Key"
regex = '''(?i)api[_-]?key\s*[=:]\s*['"]?([a-zA-Z0-9]{32,})['"]?'''
secretGroup = 1

# Allowlist specific patterns
[[rules.allowlist]]
regexes = [
  '''EXAMPLE_API_KEY''',
  '''your-api-key-here''',
]
```

### Test gitleaks

```bash
# Scan entire repo
gitleaks detect -v

# Scan only staged files
gitleaks protect --staged -v

# Generate baseline (to ignore existing issues)
gitleaks detect --baseline-path .gitleaks-baseline.json
```

---

## Bypassing Hooks

Sometimes you need to bypass hooks (e.g., emergency fixes):

```bash
# Skip pre-commit and commit-msg
git commit --no-verify -m "emergency: fix production outage"

# Skip pre-push
git push --no-verify

# Note: Document why hooks were bypassed
```

---

## Troubleshooting

### Husky hooks not running

```bash
# Reinstall husky
rm -rf .husky
npx husky init  # or pnpm exec husky init

# Verify prepare script exists
cat package.json | grep prepare
```

### Permission denied

```bash
# Make hooks executable
chmod +x .husky/*
# or
chmod +x .githooks/*
```

### Git hooks path not set

```bash
# Verify hooks path
git config core.hooksPath

# Set manually
git config core.hooksPath .githooks
```

### lint-staged not finding files

```bash
# Debug lint-staged
npx lint-staged --debug

# Check git status
git status
git diff --cached --name-only
```

### Nx affected not detecting changes

```bash
# Check what Nx thinks is affected
npx nx affected:graph

# Force run all
npx nx run-many --target=test --all
```

---

## CI Integration

Ensure CI runs the same checks as hooks:

### MERN CI

```yaml
# .github/workflows/ci.yml
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      - name: Setup pnpm
        uses: pnpm/action-setup@v4

      - name: Setup Node
        uses: actions/setup-node@v6
        with:
          node-version: '22'
          cache: 'pnpm'

      - run: pnpm install --frozen-lockfile
      - run: pnpm lint
      - run: pnpm prettier --check .

      - name: Commitlint
        uses: wagoid/commitlint-github-action@v6
        if: github.event_name == 'pull_request'
```

### NEAN CI

```yaml
# .github/workflows/ci.yml
jobs:
  lint-test-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: Derive Nx SHAs
        uses: nrwl/nx-set-shas@v4

      - name: Setup Node
        uses: actions/setup-node@v6
        with:
          node-version: '22'
          cache: 'npm'

      - run: npm ci

      - name: Lint
        run: npx nx affected --target=lint --parallel=3

      - name: Test
        run: npx nx affected --target=test --parallel=3

      - name: Build
        run: npx nx affected --target=build --parallel=3

      - name: Commitlint
        uses: wagoid/commitlint-github-action@v6
        if: github.event_name == 'pull_request'
```

This ensures PRs fail if contributors bypass local hooks.
