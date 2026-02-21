# GitHub Secure Reference

Complete configurations for repository security (MERN, NEAN, iOS).

---

## Dependabot Configuration

> **Note:** Replace `your-username` with the actual GitHub username.
> Detect automatically: `GH_USER=$(gh api user -q .login)`

### MERN (pnpm)

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "America/New_York"
    open-pull-requests-limit: 10
    reviewers:
      - "your-username"
    labels:
      - "dependencies"
      - "automated"
    commit-message:
      prefix: "chore(deps)"
    ignore:
      - dependency-name: "zod"
        update-types: ["version-update:semver-major"]
      - dependency-name: "@types/node"
        update-types: ["version-update:semver-major"]
    groups:
      production-dependencies:
        dependency-type: "production"
        update-types:
          - "minor"
          - "patch"
      development-dependencies:
        dependency-type: "development"
        update-types:
          - "minor"
          - "patch"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"
    commit-message:
      prefix: "chore(ci)"
    groups:
      github-actions:
        patterns:
          - "*"
```

### NEAN (npm/Nx)

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
      time: "06:00"
      timezone: "America/New_York"
    open-pull-requests-limit: 10
    reviewers:
      - "your-username"
    labels:
      - "dependencies"
      - "automated"
    commit-message:
      prefix: "chore(deps)"
    groups:
      # Group Angular packages together
      angular:
        patterns:
          - "@angular/*"
          - "@angular-devkit/*"
          - "zone.js"
        update-types:
          - "minor"
          - "patch"
      # Group NestJS packages together
      nestjs:
        patterns:
          - "@nestjs/*"
        update-types:
          - "minor"
          - "patch"
      # Group Nx packages together
      nx:
        patterns:
          - "@nx/*"
          - "nx"
        update-types:
          - "minor"
          - "patch"
      # Group TypeORM and database
      database:
        patterns:
          - "typeorm"
          - "pg"
          - "@types/pg"
        update-types:
          - "minor"
          - "patch"
      # Group testing tools
      testing:
        patterns:
          - "jest"
          - "@types/jest"
          - "ts-jest"
          - "@playwright/*"
        update-types:
          - "minor"
          - "patch"
      # Other production dependencies
      production-dependencies:
        dependency-type: "production"
        exclude-patterns:
          - "@angular/*"
          - "@nestjs/*"
          - "@nx/*"
          - "typeorm"
        update-types:
          - "minor"
          - "patch"
      # Other dev dependencies
      development-dependencies:
        dependency-type: "development"
        exclude-patterns:
          - "@angular/*"
          - "@nestjs/*"
          - "@nx/*"
          - "jest"
          - "@playwright/*"
        update-types:
          - "minor"
          - "patch"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"
    commit-message:
      prefix: "chore(ci)"

  # Docker base images
  - package-ecosystem: "docker"
    directory: "/docker"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "docker"
    commit-message:
      prefix: "chore(docker)"
```

### iOS (Swift)

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "swift"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "swift"
    commit-message:
      prefix: "chore(deps)"

  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    labels:
      - "dependencies"
      - "github-actions"
    commit-message:
      prefix: "chore(ci)"
```

---

## CODEOWNERS

> **Note:** Replace `your-username` with the actual GitHub username.
> Detect automatically: `GH_USER=$(gh api user -q .login)`

### MERN

```
# .github/CODEOWNERS
# Default owners for everything
* @your-username

# Security-sensitive files require review
.github/workflows/ @your-username
.github/dependabot.yml @your-username
.github/CODEOWNERS @your-username

# Infrastructure
docker-compose*.yml @your-username
Dockerfile* @your-username

# API routes require backend review (src/app when --src-dir is used)
apps/web/src/app/api/ @your-username

# Shared schemas affect multiple consumers
packages/shared/ @your-username
```

### NEAN

```
# .github/CODEOWNERS
# Default owners for everything
* @your-username

# Security-sensitive files require review
.github/workflows/ @your-username
.github/dependabot.yml @your-username
.github/CODEOWNERS @your-username

# Infrastructure
docker/ @your-username
docker-compose*.yml @your-username
Dockerfile* @your-username
nx.json @your-username

# API - requires backend review
apps/api/ @your-username

# Auth and security modules - require careful review
libs/api/auth/ @your-username
libs/api/common/src/guards/ @your-username
libs/api/common/src/filters/ @your-username

# Database - entities and migrations require review
libs/api/database/ @your-username

# Shared types affect both frontend and backend
libs/shared/ @your-username

# Angular app core
apps/web/src/app/app.config.ts @your-username
apps/web/src/app/app.routes.ts @your-username
```

### iOS

```
# .github/CODEOWNERS
* @your-username

.github/workflows/ @your-username
.github/CODEOWNERS @your-username

*.xcodeproj @your-username
*.xcworkspace @your-username
*.xcconfig @your-username

App/Sources/Services/ @your-username
Config/ @your-username
```

---

## Security Policy

> **Note:** Replace `security@example.com` with `$GH_USER@users.noreply.github.com` or the repo owner's email.
> Detect automatically: `GH_USER=$(gh api user -q .login)`

```markdown
<!-- .github/SECURITY.md -->
# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| latest  | :white_check_mark: |
| < latest| :x:                |

## Reporting a Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report them via email to: security@example.com

Include:
- Type of vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

You should receive a response within 48 hours. If the issue is confirmed, we will:
1. Work on a fix
2. Release a patch
3. Credit you in the release notes (unless you prefer anonymity)

## Security Measures

This repository employs:
- Branch protection (no direct pushes to main)
- Required code reviews
- Automated dependency updates (Dependabot)
- Secret scanning
- CodeQL analysis
```

---

## Pull Request Template

```markdown
<!-- .github/pull_request_template.md -->
## Description
<!-- What does this PR do? -->

## Type of Change
- [ ] Bug fix (non-breaking change fixing an issue)
- [ ] New feature (non-breaking change adding functionality)
- [ ] Breaking change (fix or feature causing existing functionality to change)
- [ ] Documentation update
- [ ] Refactoring (no functional changes)
- [ ] Dependencies update

## Checklist
- [ ] I have read the contributing guidelines
- [ ] My code follows the project's style guidelines
- [ ] I have added tests covering my changes
- [ ] All new and existing tests pass
- [ ] I have updated documentation as needed
- [ ] My changes generate no new warnings
- [ ] I have checked for security implications

## Security Considerations
<!-- Does this PR have security implications? If so, describe them. -->
- [ ] This PR has no security implications
- [ ] This PR has been reviewed for security concerns

## Screenshots (if applicable)
<!-- Add screenshots for UI changes -->

## Related Issues
<!-- Link related issues: Fixes #123, Relates to #456 -->
```

---

## CI Workflows

> **For MERN projects**, these files are provided as templates in `mern-scaffold/templates/.github/`. The code blocks below are reference for customization and for NEAN/iOS platforms.

### MERN CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
    paths-ignore:
      - "**.md"
      - "docs/**"
      - ".github/dependabot.yml"
      - "LICENSE"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-test-build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6

      # No version specified - reads from packageManager in package.json
      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "pnpm"

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Format check
        run: pnpm format

      - name: Type check
        run: pnpm typecheck

      - name: Test
        run: pnpm test

      - name: Build
        run: pnpm build

      - name: Upload build artifact
        uses: actions/upload-artifact@v4
        with:
          name: next-build
          path: apps/web/.next
          retention-days: 1

  e2e:
    runs-on: ubuntu-latest
    needs: lint-test-build

    env:
      CI: true
      MONGODB_URI: mongodb://localhost:27017/test

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017
        options: >-
          --health-cmd "mongosh --eval 'db.runCommand({ping:1})'"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v6

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "pnpm"

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Cache Playwright browsers
        uses: actions/cache@v4
        id: playwright-cache
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ runner.os }}-${{ hashFiles('pnpm-lock.yaml') }}

      - name: Install Playwright browsers
        if: steps.playwright-cache.outputs.cache-hit != 'true'
        run: pnpm --filter web exec playwright install --with-deps chromium

      - name: Install Playwright system deps
        if: steps.playwright-cache.outputs.cache-hit == 'true'
        run: pnpm --filter web exec playwright install-deps chromium

      # Turbo filters env vars — write .env.local so Next.js sees MONGODB_URI
      - name: Create env file for Next.js
        run: echo "MONGODB_URI=$MONGODB_URI" > apps/web/.env.local

      - name: Download build artifact
        uses: actions/download-artifact@v4
        with:
          name: next-build
          path: apps/web/.next

      - name: Run E2E tests
        run: pnpm test:e2e
```

### NEAN CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
    paths-ignore:
      - "**.md"
      - "docs/**"
      - ".github/dependabot.yml"
      - "LICENSE"
  workflow_dispatch:

permissions:
  contents: read

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-test-build:
    name: Lint, Test & Build
    runs-on: ubuntu-latest

    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_USER: postgres
          POSTGRES_PASSWORD: postgres
          POSTGRES_DB: test
        ports:
          - 5432:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

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

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npx nx affected --target=lint --parallel=3

      - name: Test
        run: npx nx affected --target=test --parallel=3 --coverage
        env:
          DATABASE_HOST: localhost
          DATABASE_PORT: 5432
          DATABASE_USERNAME: postgres
          DATABASE_PASSWORD: postgres
          DATABASE_NAME: test

      - name: Build
        run: npx nx affected --target=build --parallel=3

  e2e:
    name: E2E Tests
    runs-on: ubuntu-latest
    needs: lint-test-build
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

      - name: Install dependencies
        run: npm ci

      - name: Cache Playwright browsers
        uses: actions/cache@v4
        id: playwright-cache
        with:
          path: ~/.cache/ms-playwright
          key: playwright-${{ runner.os }}-${{ hashFiles('package-lock.json') }}

      - name: Install Playwright
        if: steps.playwright-cache.outputs.cache-hit != 'true'
        run: npx playwright install --with-deps

      - name: Install Playwright system deps
        if: steps.playwright-cache.outputs.cache-hit == 'true'
        run: npx playwright install-deps

      - name: E2E Tests
        run: npx nx affected --target=e2e --parallel=1
```

### iOS CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  pull_request:
    branches: [main]
    paths-ignore:
      - "**.md"
      - "docs/**"
      - ".github/dependabot.yml"
      - "LICENSE"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  build-and-test:
    name: Build & Test
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v6

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.4.app

      - name: Build
        run: |
          xcodebuild build \
            -scheme App \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO

      - name: Test
        run: |
          xcodebuild test \
            -scheme App \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -configuration Debug \
            CODE_SIGNING_ALLOWED=NO
```

---

## Security Workflow

```yaml
# .github/workflows/security.yml
name: Security

on:
  pull_request:
    branches: [main]
  schedule:
    - cron: "0 6 * * 1"
  workflow_dispatch:

permissions:
  actions: read          # Required for CodeQL v3+ telemetry
  contents: read
  security-events: write
  pull-requests: read

jobs:
  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    # Note: CodeQL is free for public repos only. Private repos need GitHub Advanced Security.
    steps:
      - uses: actions/checkout@v6

      - name: Initialize CodeQL
        uses: github/codeql-action/init@v3
        with:
          languages: javascript-typescript

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3
        with:
          category: "/language:javascript-typescript"

  dependency-review:
    name: Dependency Review
    runs-on: ubuntu-latest
    if: github.event_name == 'pull_request'
    steps:
      - uses: actions/checkout@v6

      - name: Dependency Review
        uses: actions/dependency-review-action@v4
        with:
          fail-on-severity: high
          deny-licenses: GPL-3.0, AGPL-3.0

  secrets:
    name: Secret Scanning
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      - name: TruffleHog Secret Scan
        uses: trufflesecurity/trufflehog@v3.93.3
        with:
          extra_args: --only-verified
```

---

## PR Validation Workflow

```yaml
# .github/workflows/pr-check.yml
name: PR Check

on:
  pull_request:
    types: [opened, synchronize, reopened, edited]

permissions:
  contents: read
  pull-requests: write

jobs:
  validate:
    name: Validate PR
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0

      # Check PR size
      - name: Check PR Size
        uses: codelytv/pr-size-labeler@v1
        with:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          xs_label: 'size/xs'
          xs_max_size: 10
          s_label: 'size/s'
          s_max_size: 100
          m_label: 'size/m'
          m_max_size: 500
          l_label: 'size/l'
          l_max_size: 1000
          xl_label: 'size/xl'
          fail_if_xl: false
          message_if_xl: >
            This PR is quite large. Consider breaking it into smaller PRs
            for easier review.

      # Check commit messages (conventional commits)
      - name: Check Commits
        uses: wagoid/commitlint-github-action@v6
        with:
          configFile: .commitlintrc.json
        continue-on-error: true  # Warning only

      # Check for fixup/squash commits
      - name: Check for WIP
        run: |
          if git log --oneline origin/main..HEAD | grep -iE '(fixup|squash|wip|todo)'; then
            echo "::warning::Found fixup/squash/WIP commits. Please clean up before merging."
          fi
```

---

## Dependabot Auto-Merge Workflow

Auto-approves and merges Dependabot PRs for minor/patch updates after CI passes. Major version bumps are left for manual review.

```yaml
# .github/workflows/dependabot-auto-merge.yml
name: Dependabot Auto-Merge

on: pull_request

permissions:
  contents: write
  pull-requests: write

jobs:
  auto-merge:
    runs-on: ubuntu-latest
    if: github.actor == 'dependabot[bot]'
    steps:
      - name: Fetch Dependabot metadata
        id: metadata
        uses: dependabot/fetch-metadata@v2
        with:
          github-token: "${{ secrets.GITHUB_TOKEN }}"

      - name: Auto-approve minor/patch updates
        if: steps.metadata.outputs.update-type != 'version-update:semver-major'
        run: gh pr review --approve "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}

      - name: Enable auto-merge
        if: steps.metadata.outputs.update-type != 'version-update:semver-major'
        run: gh pr merge --auto --squash "$PR_URL"
        env:
          PR_URL: ${{ github.event.pull_request.html_url }}
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Repository Settings via gh CLI

```bash
#!/bin/bash
# scripts/setup-repo-settings.sh

set -e

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "Configuring repository settings for $REPO"

# Core settings: squash-only, auto-cleanup, disable wiki
gh api --method PATCH -H "Accept: application/vnd.github+json" \
  "/repos/$REPO" \
  -F delete_branch_on_merge=true \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F has_wiki=false \
  -F allow_auto_merge=true

# Disable forking for private org-owned repos (not available on user-owned repos)
VISIBILITY=$(gh repo view "$REPO" --json visibility -q .visibility)
OWNER_TYPE=$(gh api "/repos/$REPO" --jq '.owner.type')
if [ "$VISIBILITY" = "PRIVATE" ] && [ "$OWNER_TYPE" = "Organization" ]; then
  gh api --method PATCH -H "Accept: application/vnd.github+json" \
    "/repos/$REPO" \
    -F allow_forking=false
  echo "✓ Forking disabled (private org repo)"
fi

# Allow GitHub Actions to approve PRs (needed for dependabot-auto-merge)
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/actions/permissions/workflow" \
  -F can_approve_pull_request_reviews=true \
  -F default_workflow_permissions=read

echo "✓ Repository settings configured"
echo "  - Delete branch on merge: true"
echo "  - Squash merge only (merge commit + rebase disabled)"
echo "  - Wiki disabled"
echo "  - Auto-merge enabled"
echo "  - Actions can approve PRs: true"
```

---

## Branch Protection via gh CLI

### MERN/NEAN Script

```bash
#!/bin/bash
# scripts/setup-branch-protection.sh

set -e

BRANCH="${1:-main}"
REVIEWERS="${2:-1}"
REPO="${3:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
PLATFORM="${4:-mern}"  # mern, nean, or ios

echo "Setting up branch protection for $REPO:$BRANCH ($PLATFORM)"

# Determine required status checks based on platform
# Note: GitHub uses job "name:" (not YAML key) as the status check context
if [ "$PLATFORM" = "nean" ]; then
  STATUS_CONTEXTS='["Lint, Test & Build"]'
elif [ "$PLATFORM" = "ios" ]; then
  STATUS_CONTEXTS='["Build & Test"]'
else
  # MERN default (no name: set, so YAML key is used)
  STATUS_CONTEXTS='["lint-test-build"]'
fi

# Build review requirements (null if 0 reviewers for ralph-mode/solo-dev)
if [ "$REVIEWERS" -eq 0 ]; then
  REVIEW_CONFIG="null"
  ENFORCE_ADMINS="true"
else
  REVIEW_CONFIG='{
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": '"$REVIEWERS"'
  }'
  ENFORCE_ADMINS="false"
fi

# Apply branch protection rules using --input for complex JSON
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": $STATUS_CONTEXTS
  },
  "enforce_admins": $ENFORCE_ADMINS,
  "required_pull_request_reviews": $REVIEW_CONFIG,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo "Branch protection applied to $BRANCH"
```

### Ralph Mode Script

For fully autonomous Ralph operation:

```bash
#!/bin/bash
# scripts/setup-ralph-mode.sh
# Configures repo for autonomous Ralph / solo-dev operation

set -e

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"

echo "Configuring $REPO for Ralph automation..."

# 1. Repository settings: squash-only, auto-cleanup, disable wiki, auto-merge
echo "Applying repository settings..."
gh api --method PATCH -H "Accept: application/vnd.github+json" \
  "/repos/$REPO" \
  -F delete_branch_on_merge=true \
  -F allow_squash_merge=true \
  -F allow_merge_commit=false \
  -F allow_rebase_merge=false \
  -F has_wiki=false \
  -F allow_auto_merge=true

# Disable forking for private org-owned repos (not available on user-owned repos)
VISIBILITY=$(gh repo view "$REPO" --json visibility -q .visibility)
OWNER_TYPE=$(gh api "/repos/$REPO" --jq '.owner.type')
if [ "$VISIBILITY" = "PRIVATE" ] && [ "$OWNER_TYPE" = "Organization" ]; then
  gh api --method PATCH -H "Accept: application/vnd.github+json" \
    "/repos/$REPO" -F allow_forking=false
fi

echo "✓ Repository settings configured"

# 2. Set branch protection with 0 required reviewers, enforce_admins true
echo "Setting branch protection (0 reviewers, CI required, admins enforced)..."

# Detect platform for status checks
# Note: GitHub uses job "name:" (not YAML key) as the status check context
if [ -f "nx.json" ]; then
  STATUS_CONTEXTS='["Lint, Test & Build"]'
elif [ -f "Package.swift" ]; then
  STATUS_CONTEXTS='["Build & Test"]'
else
  # MERN default (no name: set, so YAML key is used)
  STATUS_CONTEXTS='["lint-test-build"]'
fi

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": true,
    "contexts": $STATUS_CONTEXTS
  },
  "enforce_admins": true,
  "required_pull_request_reviews": null,
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}
EOF

echo "✓ Branch protection configured"

# 3. Enable security features
echo "Enabling security features..."
gh api --method PUT "/repos/$REPO/vulnerability-alerts" 2>/dev/null || true
gh api --method PUT "/repos/$REPO/automated-security-fixes" 2>/dev/null || true

echo "✓ Security features enabled"

echo ""
echo "Repository ready for Ralph automation!"
echo ""
echo "Ralph workflow:"
echo "  1. ./scripts/ralph/ralph.sh 10"
echo "  2. PRs auto-merge when CI passes"
echo "  3. No manual intervention needed"
```

---

## Enable Repository Security Features

```bash
#!/bin/bash
# scripts/enable-security-features.sh

set -e

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"

echo "🔒 Enabling security features for $REPO"

# Enable vulnerability alerts (Dependabot alerts)
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/vulnerability-alerts"

echo "✅ Dependabot alerts enabled"

# Enable automated security fixes (Dependabot security updates)
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/automated-security-fixes"

echo "✅ Dependabot security updates enabled"

# Enable secret scanning (requires GHAS for private repos — will 422 on Pro)
# Free for public repos; skips gracefully if unavailable
gh api \
  --method PATCH \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO" \
  --input - <<SECEOF 2>/dev/null && echo "✅ Secret scanning enabled" || echo "⚠️  Secret scanning not available (requires GHAS or public repo)"
{
  "security_and_analysis": {
    "secret_scanning": {"status": "enabled"},
    "secret_scanning_push_protection": {"status": "enabled"}
  }
}
SECEOF

echo ""
echo "🎉 Security features enabled for $REPO"
```

---

## Verification Checklist

After running the setup, verify:

### Repository Settings
- [ ] Dependabot alerts enabled
- [ ] Dependabot security updates enabled
- [ ] Secret scanning enabled
- [ ] Push protection enabled (if available)
- [ ] Delete branch on merge enabled
- [ ] Squash merge only (merge commit + rebase disabled)
- [ ] Wiki disabled
- [ ] Forking disabled (private repos only)
- [ ] Auto-merge enabled

### Branch Protection
- [ ] Require pull request before merging
- [ ] Require approvals (N reviewers, or null for solo-dev/ralph-mode)
- [ ] Dismiss stale reviews (when reviewers > 0)
- [ ] Require status checks (use job **name** not id, e.g., `Lint, Test & Build` not `lint-test-build`)
- [ ] Require branches up to date
- [ ] Require linear history
- [ ] Enforce admins (true when reviewers = 0; false when reviewers > 0)
- [ ] Required conversation resolution
- [ ] Block force pushes
- [ ] Block deletions

### Workflows
- [ ] CI workflow runs on PRs
- [ ] CodeQL analysis runs
- [ ] Dependency review runs on PRs
- [ ] PR validation runs

### Files
- [ ] `.github/dependabot.yml` exists
- [ ] `.github/CODEOWNERS` exists (with correct paths for platform)
- [ ] `.github/SECURITY.md` exists
- [ ] `.github/pull_request_template.md` exists

---

## Automated Verification

```bash
#!/bin/bash
# scripts/verify-github-secure.sh
# Verifies all github-secure settings are correctly applied

set -e

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"
PASS=0
FAIL=0

check() {
  local label="$1" actual="$2" expected="$3"
  if [ "$actual" = "$expected" ]; then
    echo "  PASS  $label"
    PASS=$((PASS + 1))
  else
    echo "  FAIL  $label (expected: $expected, got: $actual)"
    FAIL=$((FAIL + 1))
  fi
}

echo "Verifying repository settings..."
REPO_JSON=$(gh api "/repos/$REPO")
check "delete_branch_on_merge" "$(echo "$REPO_JSON" | jq -r .delete_branch_on_merge)" "true"
check "allow_squash_merge" "$(echo "$REPO_JSON" | jq -r .allow_squash_merge)" "true"
check "allow_merge_commit" "$(echo "$REPO_JSON" | jq -r .allow_merge_commit)" "false"
check "allow_rebase_merge" "$(echo "$REPO_JSON" | jq -r .allow_rebase_merge)" "false"
check "has_wiki" "$(echo "$REPO_JSON" | jq -r .has_wiki)" "false"
check "allow_auto_merge" "$(echo "$REPO_JSON" | jq -r .allow_auto_merge)" "true"

echo ""
echo "Verifying branch protection..."
BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection")
check "enforce_admins" "$(echo "$BP_JSON" | jq -r .enforce_admins.enabled)" "true"
check "required_linear_history" "$(echo "$BP_JSON" | jq -r .required_linear_history.enabled)" "true"
check "allow_force_pushes" "$(echo "$BP_JSON" | jq -r .allow_force_pushes.enabled)" "false"
check "allow_deletions" "$(echo "$BP_JSON" | jq -r .allow_deletions.enabled)" "false"
check "required_conversation_resolution" "$(echo "$BP_JSON" | jq -r .required_conversation_resolution.enabled)" "true"
check "status_checks_strict" "$(echo "$BP_JSON" | jq -r .required_status_checks.strict)" "true"

echo ""
echo "Verifying workflow files..."
for f in .github/workflows/*.yml; do
  if grep -q "^permissions:" "$f"; then
    check "$f has permissions block" "true" "true"
  else
    check "$f has permissions block" "false" "true"
  fi
done

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
```
