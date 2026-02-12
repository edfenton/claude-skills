# Shared Changelog Reference

Templates and scripts for changelog generation from conventional commits.

---

## Changelog Template

```markdown
# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.2.0] - 2025-01-24

### ✨ Features

- **auth:** add biometric login support (#42)
- **ui:** implement dark mode toggle (#39)

### 🐛 Bug Fixes

- **api:** handle network timeout gracefully (#38)
- **storage:** fix data corruption on app backgrounding (#35)

### ⚡ Performance

- **images:** lazy load off-screen images (#40)

### ⚠️ Breaking Changes

- **config:** `API_URL` environment variable renamed to `API_BASE_URL`

## [1.1.0] - 2025-01-10

### ✨ Features

- **auth:** add Sign in with Apple (#30)

### 🐛 Bug Fixes

- **ui:** fix keyboard overlap on login screen (#28)

## [1.0.0] - 2025-01-01

### 🎉 Initial Release

- Core authentication flow
- Home screen with item list
- Settings page
```

---

## Generation Script

```bash
#!/bin/bash
# scripts/generate-changelog.sh

set -e

VERSION="${1:-}"
FROM_TAG="${2:-$(git describe --tags --abbrev=0 2>/dev/null || echo '')}"
DRY_RUN="${3:-false}"

# Get commits since last tag (or all commits)
if [ -n "$FROM_TAG" ]; then
  COMMITS=$(git log "$FROM_TAG"..HEAD --pretty=format:"%H|%s|%b---END---" --reverse)
  echo "Generating changelog from $FROM_TAG to HEAD"
else
  COMMITS=$(git log --pretty=format:"%H|%s|%b---END---" --reverse)
  echo "Generating changelog from initial commit"
fi

# Initialize arrays for each type
declare -a FEATURES FIXES PERF DOCS REFACTOR TESTS BUILD BREAKING

# Parse commits
while IFS= read -r commit; do
  [ -z "$commit" ] && continue
  
  HASH=$(echo "$commit" | cut -d'|' -f1)
  SUBJECT=$(echo "$commit" | cut -d'|' -f2)
  BODY=$(echo "$commit" | cut -d'|' -f3 | sed 's/---END---$//')
  
  # Extract type and scope
  if [[ "$SUBJECT" =~ ^([a-z]+)(\(([a-z0-9-]+)\))?: ]]; then
    TYPE="${BASH_REMATCH[1]}"
    SCOPE="${BASH_REMATCH[3]}"
    MESSAGE="${SUBJECT#*: }"
    
    # Format entry
    if [ -n "$SCOPE" ]; then
      ENTRY="- **$SCOPE:** $MESSAGE"
    else
      ENTRY="- $MESSAGE"
    fi
    
    # Check for breaking changes
    if [[ "$BODY" == *"BREAKING CHANGE"* ]] || [[ "$SUBJECT" == *"!"* ]]; then
      BREAKING+=("$ENTRY")
    fi
    
    # Categorize
    case "$TYPE" in
      feat) FEATURES+=("$ENTRY") ;;
      fix) FIXES+=("$ENTRY") ;;
      perf) PERF+=("$ENTRY") ;;
      docs) DOCS+=("$ENTRY") ;;
      refactor) REFACTOR+=("$ENTRY") ;;
      test) TESTS+=("$ENTRY") ;;
      build|ci) BUILD+=("$ENTRY") ;;
    esac
  fi
done <<< "$COMMITS"

# Infer version if not provided
if [ -z "$VERSION" ]; then
  CURRENT_VERSION="${FROM_TAG:-0.0.0}"
  CURRENT_VERSION="${CURRENT_VERSION#v}"  # Remove 'v' prefix
  
  IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
  MAJOR="${MAJOR:-0}"
  MINOR="${MINOR:-0}"
  PATCH="${PATCH:-0}"
  
  if [ ${#BREAKING[@]} -gt 0 ]; then
    MAJOR=$((MAJOR + 1))
    MINOR=0
    PATCH=0
  elif [ ${#FEATURES[@]} -gt 0 ]; then
    MINOR=$((MINOR + 1))
    PATCH=0
  else
    PATCH=$((PATCH + 1))
  fi
  
  VERSION="$MAJOR.$MINOR.$PATCH"
  echo "Suggested version: $VERSION"
fi

# Generate changelog entry
DATE=$(date +%Y-%m-%d)
ENTRY="## [$VERSION] - $DATE"

if [ ${#BREAKING[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### ⚠️ Breaking Changes

$(printf '%s\n' "${BREAKING[@]}")"
fi

if [ ${#FEATURES[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### ✨ Features

$(printf '%s\n' "${FEATURES[@]}")"
fi

if [ ${#FIXES[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### 🐛 Bug Fixes

$(printf '%s\n' "${FIXES[@]}")"
fi

if [ ${#PERF[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### ⚡ Performance

$(printf '%s\n' "${PERF[@]}")"
fi

if [ ${#DOCS[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### 📚 Documentation

$(printf '%s\n' "${DOCS[@]}")"
fi

if [ ${#REFACTOR[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### ♻️ Refactoring

$(printf '%s\n' "${REFACTOR[@]}")"
fi

if [ ${#BUILD[@]} -gt 0 ]; then
  ENTRY="$ENTRY

### 🔧 Build & CI

$(printf '%s\n' "${BUILD[@]}")"
fi

echo ""
echo "=== Generated Changelog Entry ==="
echo "$ENTRY"
echo "================================="

if [ "$DRY_RUN" = "true" ]; then
  echo ""
  echo "(Dry run - no files modified)"
  exit 0
fi

# Update or create CHANGELOG.md
if [ -f "CHANGELOG.md" ]; then
  # Insert after "## [Unreleased]" or at top
  if grep -q "## \[Unreleased\]" CHANGELOG.md; then
    sed -i.bak "/## \[Unreleased\]/a\\
\\
$ENTRY" CHANGELOG.md
    rm CHANGELOG.md.bak
  else
    # Insert after header
    sed -i.bak "4a\\
\\
$ENTRY" CHANGELOG.md
    rm CHANGELOG.md.bak
  fi
else
  # Create new file
  cat > CHANGELOG.md << EOF
# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

$ENTRY
EOF
fi

echo ""
echo "✅ CHANGELOG.md updated with version $VERSION"
```

---

## Using Standard Tools

### Option 1: standard-version (Node.js)

```bash
# Install
pnpm add -D standard-version

# Generate changelog and bump version
npx standard-version

# First release
npx standard-version --first-release

# Specific version
npx standard-version --release-as 1.2.0

# Dry run
npx standard-version --dry-run
```

Configuration:

```json
// .versionrc.json
{
  "types": [
    {"type": "feat", "section": "✨ Features"},
    {"type": "fix", "section": "🐛 Bug Fixes"},
    {"type": "perf", "section": "⚡ Performance"},
    {"type": "docs", "section": "📚 Documentation"},
    {"type": "refactor", "section": "♻️ Refactoring", "hidden": false},
    {"type": "test", "section": "🧪 Tests", "hidden": true},
    {"type": "build", "section": "🔧 Build", "hidden": true},
    {"type": "ci", "hidden": true},
    {"type": "chore", "hidden": true}
  ],
  "commitUrlFormat": "https://github.com/{{owner}}/{{repository}}/commit/{{hash}}",
  "compareUrlFormat": "https://github.com/{{owner}}/{{repository}}/compare/{{previousTag}}...{{currentTag}}"
}
```

### Option 2: git-cliff (Rust, faster)

```bash
# Install
brew install git-cliff

# Generate changelog
git cliff -o CHANGELOG.md

# Since last tag
git cliff --latest -o CHANGELOG.md

# Specific range
git cliff v1.0.0..HEAD -o CHANGELOG.md
```

Configuration:

```toml
# cliff.toml
[changelog]
header = """
# Changelog\n
"""
body = """
{% if version %}\
    ## [{{ version }}] - {{ timestamp | date(format="%Y-%m-%d") }}
{% else %}\
    ## [Unreleased]
{% endif %}\
{% for group, commits in commits | group_by(attribute="group") %}
    ### {{ group | upper_first }}
    {% for commit in commits %}
        - {% if commit.scope %}**{{ commit.scope }}:** {% endif %}{{ commit.message }}\
    {% endfor %}
{% endfor %}\n
"""
footer = ""
trim = true

[git]
conventional_commits = true
filter_unconventional = true
commit_parsers = [
    { message = "^feat", group = "✨ Features" },
    { message = "^fix", group = "🐛 Bug Fixes" },
    { message = "^perf", group = "⚡ Performance" },
    { message = "^doc", group = "📚 Documentation" },
    { message = "^refactor", group = "♻️ Refactoring" },
    { message = "^test", group = "🧪 Tests", skip = true },
    { message = "^chore", skip = true },
]
```

---

## GitHub Release Integration

```bash
#!/bin/bash
# scripts/release.sh

set -e

VERSION="$1"

if [ -z "$VERSION" ]; then
  echo "Usage: ./scripts/release.sh <version>"
  exit 1
fi

# Generate changelog
./scripts/generate-changelog.sh "$VERSION"

# Commit changelog
git add CHANGELOG.md
git commit -m "chore(release): $VERSION"

# Create tag
git tag -a "v$VERSION" -m "Release $VERSION"

# Push
git push origin main --tags

# Create GitHub release with changelog
CHANGELOG_SECTION=$(awk "/## \[$VERSION\]/,/## \[/" CHANGELOG.md | head -n -1)

gh release create "v$VERSION" \
  --title "v$VERSION" \
  --notes "$CHANGELOG_SECTION"

echo "✅ Released v$VERSION"
```

---

## CI Automation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    branches: [main]
    paths-ignore:
      - 'CHANGELOG.md'
      - '*.md'

jobs:
  release:
    runs-on: ubuntu-latest
    if: "!contains(github.event.head_commit.message, 'chore(release)')"
    steps:
      - uses: actions/checkout@v6
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Setup Node
        uses: actions/setup-node@v6
        with:
          node-version: '22'

      - name: Generate Changelog
        run: npx standard-version

      - name: Push Changes
        run: |
          git push --follow-tags origin main

      - name: Create GitHub Release
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
        run: |
          VERSION=$(git describe --tags --abbrev=0)
          gh release create "$VERSION" --generate-notes
```

---

## Commit Message Examples

Good commits for changelog:

```bash
# Feature with scope
git commit -m "feat(auth): add biometric login support"

# Fix with issue reference
git commit -m "fix(api): handle network timeout (#38)"

# Breaking change
git commit -m "feat(config)!: rename API_URL to API_BASE_URL

BREAKING CHANGE: Environment variable API_URL has been renamed to API_BASE_URL.
Update your .env files accordingly."

# Performance improvement
git commit -m "perf(images): lazy load off-screen images"
```
