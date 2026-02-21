#!/usr/bin/env bash
# optimize-ci.sh — Reduce GitHub Actions usage for existing projects.
#
# Run from any project root that has .github/workflows/ci.yml.
# Changes are left uncommitted so you can review before committing.
#
# What it does:
#   1. Removes push-to-main triggers from ci.yml and security.yml
#   2. Adds paths-ignore to ci.yml (skip CI for docs-only PRs)
#   3. Adds workflow_dispatch to security.yml if missing
#   4. Adds Playwright browser caching if e2e job exists
#   5. Prints a summary of changes made

set -euo pipefail

CI_FILE=".github/workflows/ci.yml"
SEC_FILE=".github/workflows/security.yml"
CHANGES=0

info()  { printf "  %s\n" "$1"; }
ok()    { printf "  [done] %s\n" "$1"; CHANGES=$((CHANGES + 1)); }
skip()  { printf "  [skip] %s\n" "$1"; }

echo "=== GitHub Actions Cost Optimizer ==="
echo ""

# ── ci.yml ────────────────────────────────────────────────────────────────────

if [ -f "$CI_FILE" ]; then
  echo "Processing $CI_FILE ..."

  # 1. Remove push trigger for main
  if grep -qE '^\s*push:' "$CI_FILE"; then
    # Remove the push: block (push: line + branches: [main] line)
    sed -i.bak '/^  push:/,/branches: \[main\]/d' "$CI_FILE"
    rm -f "$CI_FILE.bak"
    ok "Removed push-to-main trigger"
  else
    skip "No push trigger found"
  fi

  # 2. Add paths-ignore if missing
  if ! grep -q 'paths-ignore' "$CI_FILE"; then
    # Insert paths-ignore after "branches: [main]" under pull_request
    sed -i.bak '/pull_request:/,/branches: \[main\]/{
      /branches: \[main\]/a\
\    paths-ignore:\
\      - "**.md"\
\      - "docs/**"\
\      - ".github/dependabot.yml"\
\      - "LICENSE"
    }' "$CI_FILE"
    rm -f "$CI_FILE.bak"
    ok "Added paths-ignore for docs-only PRs"
  else
    skip "paths-ignore already present"
  fi

  # 3. Add Playwright caching if e2e job exists and cache not present
  if grep -q 'e2e:' "$CI_FILE" && ! grep -q 'playwright-cache' "$CI_FILE"; then
    # Insert cache steps before the "Install Playwright" step
    sed -i.bak '/- name: Install Playwright browsers/{
      i\
\      - name: Cache Playwright browsers\
\        uses: actions/cache@v4\
\        id: playwright-cache\
\        with:\
\          path: ~/.cache/ms-playwright\
\          key: playwright-${{ runner.os }}-${{ hashFiles('"'"'pnpm-lock.yaml'"'"', '"'"'package-lock.json'"'"') }}\
\
    }' "$CI_FILE"
    rm -f "$CI_FILE.bak"
    ok "Added Playwright browser caching"
  elif grep -q 'playwright-cache' "$CI_FILE"; then
    skip "Playwright caching already present"
  else
    skip "No e2e job found"
  fi

  echo ""
else
  echo "No $CI_FILE found, skipping CI optimizations."
  echo ""
fi

# ── security.yml ──────────────────────────────────────────────────────────────

if [ -f "$SEC_FILE" ]; then
  echo "Processing $SEC_FILE ..."

  # 1. Remove push trigger for main
  if grep -qE '^\s*push:' "$SEC_FILE"; then
    sed -i.bak '/^  push:/,/branches: \[main\]/d' "$SEC_FILE"
    rm -f "$SEC_FILE.bak"
    ok "Removed push-to-main trigger"
  else
    skip "No push trigger found"
  fi

  # 2. Add workflow_dispatch if missing
  if ! grep -q 'workflow_dispatch' "$SEC_FILE"; then
    sed -i.bak '/^on:/,/^[^ ]/{
      /^[^ ]/i\
\  workflow_dispatch:
    }' "$SEC_FILE"
    rm -f "$SEC_FILE.bak"
    ok "Added workflow_dispatch trigger"
  else
    skip "workflow_dispatch already present"
  fi

  echo ""
else
  echo "No $SEC_FILE found, skipping security optimizations."
  echo ""
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo "=== Summary ==="
if [ "$CHANGES" -gt 0 ]; then
  echo "  $CHANGES change(s) applied. Files left uncommitted for review."
  echo ""
  echo "  Review with:  git diff"
  echo "  Commit with:  git add .github/workflows/ && git commit -m 'ci: reduce GitHub Actions usage'"
else
  echo "  No changes needed — workflows are already optimized."
fi
