# NEAN Deps Reference

Dependency management commands, strategies, and common issues.

---

## Commands

### Check outdated

```bash
# All packages
npm outdated

# JSON output for parsing
npm outdated --json

# Long format with details
npm outdated --long
```

### Security audit

```bash
# Run audit
npm audit

# JSON output
npm audit --json

# Fix automatically (where possible)
npm audit fix

# Production only
npm audit --omit=dev
```

### Update packages

```bash
# Update all (patch + minor within semver)
npm update

# Update specific package
npm update @nestjs/core

# Update to latest (including major) — use npm-check-updates
npx npm-check-updates -u
npm install

# Check what would be updated
npx npm-check-updates
```

---

## Safe Update Script

```bash
#!/bin/bash
# scripts/safe-update.sh

set -e

echo "Starting safe dependency update..."

# Store current state
LOCKFILE_HASH=$(md5 -q package-lock.json 2>/dev/null || md5sum package-lock.json | cut -d' ' -f1)

# Update patch and minor versions
echo "Updating dependencies..."
npm update

# Check if anything changed
NEW_HASH=$(md5 -q package-lock.json 2>/dev/null || md5sum package-lock.json | cut -d' ' -f1)
if [ "$LOCKFILE_HASH" = "$NEW_HASH" ]; then
  echo "No updates available"
  exit 0
fi

# Run tests
echo "Running tests..."
if ! npx nx run-many --target=test; then
  echo "Tests failed, rolling back..."
  git checkout package-lock.json
  npm install
  exit 1
fi

# Run build
echo "Running build..."
if ! npx nx run-many --target=build; then
  echo "Build failed, rolling back..."
  git checkout package-lock.json
  npm install
  exit 1
fi

# Run lint
echo "Running lint..."
if ! npm run lint; then
  echo "Lint warnings after update"
fi

echo "Update successful!"
echo ""
echo "Changed packages:"
npm outdated 2>/dev/null || true

echo ""
echo "Run 'git diff package-lock.json' to review changes"
echo "Run 'git add package-lock.json && git commit -m \"chore: update dependencies\"' to commit"
```

---

## Dependency Categories

### Critical (update immediately)
- Security vulnerabilities (high/critical)
- Packages with known exploits
- Auth-related packages (`@nestjs/passport`, `passport-jwt`, `bcrypt`)

### High priority
- Framework packages (`@nestjs/*`, `@angular/*`)
- Database drivers (`typeorm`, `pg`)
- Build tools (TypeScript, ESLint)
- Nx workspace packages (`@nx/*`)

### Normal priority
- UI libraries (PrimeNG, `primeflex`, `primeicons`)
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
npm ls <package>

# Override peer deps (use sparingly)
# package.json
{
  "overrides": {
    "rxjs": "^7.8.0"
  }
}

# Force install (last resort)
npm install --legacy-peer-deps
```

### Lockfile conflicts

```bash
# Regenerate lockfile
rm package-lock.json
npm install

# Or resolve conflicts
git checkout --theirs package-lock.json
npm install
```

### Nx workspace dependency issues

```bash
# Check Nx dependency graph
npx nx graph

# Reset Nx cache
npx nx reset

# Update Nx workspace packages together
npx nx migrate latest
npx nx migrate --run-migrations
```

---

## Major Update Checklist

### Before updating

- [ ] Read changelog for breaking changes
- [ ] Check GitHub issues for known problems
- [ ] Review migration guide (if available)
- [ ] Ensure tests have good coverage
- [ ] Create a branch for the update

### Angular updates

```bash
# Use Angular CLI for updates (handles migrations)
npx ng update @angular/core @angular/cli

# Check for additional updates
npx ng update

# Update Angular CDK and Material (if used)
npx ng update @angular/cdk
```

### NestJS updates

```bash
# Update all NestJS packages together
npm update @nestjs/core @nestjs/common @nestjs/platform-express @nestjs/testing @nestjs/typeorm @nestjs/swagger @nestjs/passport @nestjs/jwt @nestjs/throttler

# Check migration guide
# https://docs.nestjs.com/migration-guide
```

### Nx updates

```bash
# Use Nx migrate for workspace updates
npx nx migrate latest

# Run generated migrations
npx nx migrate --run-migrations

# Clean up
rm migrations.json
```

### TypeScript updates

```bash
# Update TypeScript
npm update typescript -D

# Update type definitions
npm update @types/node -D

# Check for new strict options
# tsconfig.json may need updates
```

### ESLint updates

```bash
# Major ESLint updates often change config format
# ESLint 9 uses flat config (eslint.config.mjs)

# Update ESLint and plugins together
npm update eslint eslint-plugin-* @typescript-eslint/* @angular-eslint/* -D
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
| jsonwebtoken | Algorithm confusion | Update to 9.0.0+ |

### Moderate (2)
| Package | Vulnerability | Fix |
|---------|---------------|-----|
| ... | ... | ... |

## Recommended Updates

### Immediate (security)
- jsonwebtoken: 8.5.1 -> 9.0.2

### This sprint (patch/minor)
- @nestjs/core: 10.3.0 -> 10.3.5
- @angular/core: 17.1.0 -> 17.1.3
- typeorm: 0.3.19 -> 0.3.20

### Next sprint (major, needs review)
- @angular/core: 17.x -> 18.x
  - Breaking: Control flow syntax, signal-based components
  - Migration: https://angular.dev/update-guide
- eslint: 8.x -> 9.x
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
      "matchPackagePatterns": ["^@nestjs/"],
      "groupName": "nestjs"
    },
    {
      "matchPackagePatterns": ["^@angular/"],
      "groupName": "angular"
    },
    {
      "matchPackagePatterns": ["^@nx/", "^nx$"],
      "groupName": "nx"
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
      nestjs:
        patterns:
          - "@nestjs/*"
      angular:
        patterns:
          - "@angular/*"
      nx:
        patterns:
          - "@nx/*"
          - "nx"
      typescript:
        patterns:
          - "typescript"
          - "@types/*"
      eslint:
        patterns:
          - "eslint*"
          - "@typescript-eslint/*"
          - "@angular-eslint/*"
      testing:
        patterns:
          - "jest"
          - "@types/jest"
          - "ts-jest"
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
    "@nestjs/core": "10.3.5",
    "@angular/core": "17.1.3",

    // Allow patch for stable packages
    "typeorm": "~0.3.20",
    "pg": "~8.11.3",

    // Allow minor for well-maintained packages
    "rxjs": "^7.8.0",
    "class-validator": "^0.14.0"
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
