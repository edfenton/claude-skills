# MERN Deps Reference

Dependency management commands, strategies, and common issues.

---

## Commands

### Check outdated

```bash
# All packages
pnpm outdated

# Specific workspace
pnpm outdated --filter=web

# JSON output for parsing
pnpm outdated --json
```

### Security audit

```bash
# Run audit
pnpm audit

# JSON output
pnpm audit --json

# Fix automatically (where possible)
pnpm audit fix

# Production only
pnpm audit --prod
```

### Update packages

```bash
# Interactive update
pnpm update --interactive

# Update all (patch + minor)
pnpm update

# Update specific package
pnpm update zod

# Update to latest (including major)
pnpm update --latest

# Update in specific workspace
pnpm update --filter=web
```

---

## Safe Update Script

```bash
#!/bin/bash
# scripts/safe-update.sh

set -e

echo "📦 Starting safe dependency update..."

# Store current state
LOCKFILE_HASH=$(md5sum pnpm-lock.yaml | cut -d' ' -f1)

# Update patch and minor versions
echo "🔄 Updating dependencies..."
pnpm update

# Check if anything changed
NEW_HASH=$(md5sum pnpm-lock.yaml | cut -d' ' -f1)
if [ "$LOCKFILE_HASH" = "$NEW_HASH" ]; then
  echo "✅ No updates available"
  exit 0
fi

# Run tests
echo "🧪 Running tests..."
if ! pnpm test; then
  echo "❌ Tests failed, rolling back..."
  git checkout pnpm-lock.yaml
  pnpm install
  exit 1
fi

# Run build
echo "🏗️ Running build..."
if ! pnpm build; then
  echo "❌ Build failed, rolling back..."
  git checkout pnpm-lock.yaml
  pnpm install
  exit 1
fi

# Run lint
echo "🔍 Running lint..."
if ! pnpm lint; then
  echo "⚠️ Lint warnings after update"
fi

echo "✅ Update successful!"
echo ""
echo "Changed packages:"
pnpm outdated 2>/dev/null || true

echo ""
echo "Run 'git diff pnpm-lock.yaml' to review changes"
echo "Run 'git add pnpm-lock.yaml && git commit -m \"chore: update dependencies\"' to commit"
```

---

## Dependency Categories

### Critical (update immediately)
- Security vulnerabilities (high/critical)
- Packages with known exploits
- Auth-related packages

### High priority
- Framework packages (Next.js, React)
- Database drivers (Mongoose)
- Build tools (TypeScript, ESLint)

### Normal priority
- UI libraries
- Utility packages
- Type definitions

### Low priority
- Dev-only tools
- Optional enhancements
- Cosmetic packages

---

## Common Issues

### Peer dependency conflicts

```bash
# Check peer deps
pnpm why <package>

# Override peer deps (use sparingly)
# package.json
{
  "pnpm": {
    "peerDependencyRules": {
      "allowedVersions": {
        "react": "18"
      }
    }
  }
}
```

### Lockfile conflicts

```bash
# Regenerate lockfile
rm pnpm-lock.yaml
pnpm install

# Or resolve conflicts
git checkout --theirs pnpm-lock.yaml
pnpm install
```

### Workspace dependency issues

```bash
# Update workspace package reference
# In apps/web/package.json
{
  "dependencies": {
    "@repo/shared": "workspace:*"
  }
}

# Force workspace resolution
pnpm install --force
```

---

## Major Update Checklist

### Before updating

- [ ] Read changelog for breaking changes
- [ ] Check GitHub issues for known problems
- [ ] Review migration guide (if available)
- [ ] Ensure tests have good coverage
- [ ] Create a branch for the update

### Framework updates (Next.js)

```bash
# Check Next.js upgrade guide
# https://nextjs.org/docs/app/building-your-application/upgrading

# Update Next.js and React together
pnpm update next react react-dom --filter=web

# Run codemod if available
npx @next/codemod@latest <transform> <path>
```

### TypeScript updates

```bash
# Update TypeScript
pnpm update typescript -D

# Update type definitions
pnpm update @types/node @types/react @types/react-dom -D --filter=web

# Check for new strict options
# tsconfig.json may need updates
```

### ESLint updates

```bash
# Major ESLint updates often change config format
# ESLint 9 uses flat config (eslint.config.mjs)

# Update ESLint and plugins together
pnpm update eslint eslint-plugin-* @typescript-eslint/* -D
```

---

## Audit Report Template

```
# Dependency Audit Report
Date: YYYY-MM-DD

## Summary
- Total packages: X
- Outdated packages: Y
- Security issues: Z

## Security Issues

### Critical (0)
None

### High (1)
| Package | Vulnerability | Fix |
|---------|---------------|-----|
| lodash | Prototype Pollution | Update to 4.17.21+ |

### Moderate (2)
| Package | Vulnerability | Fix |
|---------|---------------|-----|
| ... | ... | ... |

## Recommended Updates

### Immediate (security)
- lodash: 4.17.19 → 4.17.21

### This sprint (patch/minor)
- next: 14.1.0 → 14.2.1
- zod: 3.22.4 → 3.22.5
- mongoose: 8.0.1 → 8.0.3

### Next sprint (major, needs review)
- eslint: 8.56.0 → 9.0.0
  - Breaking: Flat config required
  - Migration: https://eslint.org/docs/latest/use/configure/migration-guide

## Action Items
1. [ ] Fix critical/high vulnerabilities immediately
2. [ ] Update patch/minor versions this week
3. [ ] Schedule major updates for next sprint
```

---

## Renovate/Dependabot Config

### Renovate

```json
// renovate.json
{
  "$schema": "https://docs.renovatebot.com/renovate-schema.json",
  "extends": ["config:base"],
  "packageRules": [
    {
      "matchUpdateTypes": ["patch", "minor"],
      "automerge": true,
      "automergeType": "pr"
    },
    {
      "matchUpdateTypes": ["major"],
      "automerge": false,
      "labels": ["major-update"]
    },
    {
      "matchPackagePatterns": ["^@types/"],
      "automerge": true,
      "groupName": "type definitions"
    },
    {
      "matchPackagePatterns": ["eslint"],
      "groupName": "eslint"
    }
  ],
  "schedule": ["before 6am on monday"]
}
```

### Dependabot

```yaml
# .github/dependabot.yml
version: 2
updates:
  - package-ecosystem: "npm"
    directory: "/"
    schedule:
      interval: "weekly"
      day: "monday"
    open-pull-requests-limit: 10
    groups:
      typescript:
        patterns:
          - "typescript"
          - "@types/*"
      eslint:
        patterns:
          - "eslint*"
          - "@typescript-eslint/*"
      testing:
        patterns:
          - "vitest"
          - "@testing-library/*"
          - "playwright"
```

---

## Version Pinning Strategy

```json
// package.json
{
  "dependencies": {
    // Pin exact for critical packages
    "next": "14.2.1",
    "react": "18.2.0",
    
    // Allow patch for stable packages
    "zod": "~3.22.4",
    
    // Allow minor for well-maintained packages
    "mongoose": "^8.0.0"
  },
  "devDependencies": {
    // More flexible for dev tools
    "typescript": "^5.0.0",
    "eslint": "^8.0.0"
  }
}
```

Symbols:
- `1.2.3` — Exact version
- `~1.2.3` — Patch updates (1.2.x)
- `^1.2.3` — Minor updates (1.x.x)
- `*` — Any version (avoid)
