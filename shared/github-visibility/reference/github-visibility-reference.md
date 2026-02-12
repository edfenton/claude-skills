# GitHub Visibility Reference

Complete templates and scripts for toggling repository visibility between private and public.

---

## MIT LICENSE Template

> **Placeholders:** Replace `{YEAR}` with current year and `{FULLNAME}` with GitHub username.
> Detect automatically: `GH_USER=$(gh api user -q .login)` and `YEAR=$(date +%Y)`

```
MIT License

Copyright (c) {YEAR} {FULLNAME}

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## Close External PRs Workflow

```yaml
# .github/workflows/close-external-prs.yml
name: Close External PRs

on:
  pull_request_target:
    types: [opened]

permissions:
  pull-requests: write

jobs:
  close-external:
    name: Close External PR
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          script: |
            const pr = context.payload.pull_request;
            const repoOwner = context.repo.owner;

            // Close if PR is from a fork or author is not the repo owner
            const isFork = pr.head.repo.fork || pr.head.repo.full_name !== pr.base.repo.full_name;
            const isOwner = pr.user.login === repoOwner;

            if (isFork || !isOwner) {
              await github.rest.issues.createComment({
                owner: context.repo.owner,
                repo: context.repo.repo,
                issue_number: pr.number,
                body: 'Thank you for your interest! This repository is not accepting external contributions. Feel free to fork and modify for your own use.'
              });

              await github.rest.pulls.update({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: pr.number,
                state: 'closed'
              });

              core.info(`Closed external PR #${pr.number} from ${pr.user.login}`);
            }
```

---

## CodeQL Conditional Pattern

### Adding condition (going private)

When going private, add the `if` condition to the CodeQL job so it only runs on public repos (avoids failures without GHAS license):

```yaml
jobs:
  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    if: github.repository_visibility == 'public'
    steps:
      # ... existing steps unchanged
```

### Removing condition (going public)

When going public, remove the `if` condition so CodeQL runs unconditionally:

```yaml
jobs:
  codeql:
    name: CodeQL Analysis
    runs-on: ubuntu-latest
    # No 'if' condition — runs on all events
    steps:
      # ... existing steps unchanged
```

### Script to patch security.yml

```bash
#!/bin/bash
# Patch security.yml CodeQL job for visibility change
# Usage: patch_codeql <public|private>

SECURITY_YML=".github/workflows/security.yml"
TARGET="$1"

if [ ! -f "$SECURITY_YML" ]; then
  echo "No security.yml found. Skipping CodeQL adjustments."
  exit 0
fi

if [ "$TARGET" = "private" ]; then
  # Add visibility condition to CodeQL job
  # Match the codeql job line and add the if condition after runs-on
  if grep -q "if: github.repository_visibility == 'public'" "$SECURITY_YML"; then
    echo "CodeQL already has visibility condition. No changes needed."
  else
    # Insert the condition after the runs-on line in the codeql job
    sed -i.bak '/^  codeql:/,/^  [a-z]/ {
      /runs-on:.*$/a\
    if: github.repository_visibility == '"'"'public'"'"'
    }' "$SECURITY_YML" && rm -f "$SECURITY_YML.bak"
    echo "Added visibility condition to CodeQL job."
  fi

elif [ "$TARGET" = "public" ]; then
  # Remove visibility condition from CodeQL job
  if grep -q "if: github.repository_visibility == 'public'" "$SECURITY_YML"; then
    sed -i.bak "/if: github.repository_visibility == 'public'/d" "$SECURITY_YML" && rm -f "$SECURITY_YML.bak"
    echo "Removed visibility condition from CodeQL job."
  else
    echo "CodeQL has no visibility condition. No changes needed."
  fi
fi
```

**Preferred approach:** Rather than fragile sed patching, read the file, locate the `codeql:` job block, and use the Edit tool to add/remove the `if:` line. The sed script above is a fallback.

---

## Branch Protection Read-Modify-Write Scripts

### Read current branch protection

```bash
#!/bin/bash
# Read current branch protection config
# Returns JSON that can be modified and written back

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"

BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)

if [ $? -ne 0 ]; then
  echo "No branch protection found for $BRANCH"
  exit 1
fi

echo "$BP_JSON"
```

### Add push restrictions (going public)

```bash
#!/bin/bash
# Add push restrictions so only the owner can push directly
# Uses read-modify-write: reads current config, adds restrictions, writes back

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"
GH_USER="${3:-$(gh api user -q .login)}"

# Read current protection
BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "No branch protection found. Skipping push restrictions."
  exit 0
fi

# Extract current settings to preserve them
STRICT=$(echo "$BP_JSON" | jq -r '.required_status_checks.strict // true')
CONTEXTS=$(echo "$BP_JSON" | jq -c '.required_status_checks.contexts // []')
ENFORCE_ADMINS=$(echo "$BP_JSON" | jq -r '.enforce_admins.enabled // false')
LINEAR=$(echo "$BP_JSON" | jq -r '.required_linear_history.enabled // false')
FORCE_PUSH=$(echo "$BP_JSON" | jq -r '.allow_force_pushes.enabled // false')
DELETIONS=$(echo "$BP_JSON" | jq -r '.allow_deletions.enabled // false')
CONVERSATION=$(echo "$BP_JSON" | jq -r '.required_conversation_resolution.enabled // false')

# Extract review settings (preserve if they exist)
HAS_REVIEWS=$(echo "$BP_JSON" | jq 'has("required_pull_request_reviews")')
if [ "$HAS_REVIEWS" = "true" ] && [ "$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews')" != "null" ]; then
  DISMISS_STALE=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
  CODEOWNER=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
  REVIEW_COUNT=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
  REVIEW_CONFIG="{
    \"dismiss_stale_reviews\": $DISMISS_STALE,
    \"require_code_owner_reviews\": $CODEOWNER,
    \"required_approving_review_count\": $REVIEW_COUNT
  }"
else
  REVIEW_CONFIG="null"
fi

# Write back with push restrictions added
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": $STRICT,
    "contexts": $CONTEXTS
  },
  "enforce_admins": $ENFORCE_ADMINS,
  "required_pull_request_reviews": $REVIEW_CONFIG,
  "restrictions": {
    "users": ["$GH_USER"],
    "teams": []
  },
  "required_linear_history": $LINEAR,
  "allow_force_pushes": $FORCE_PUSH,
  "allow_deletions": $DELETIONS,
  "required_conversation_resolution": $CONVERSATION
}
EOF

echo "Push restrictions applied: only $GH_USER can push to $BRANCH"
```

### Remove push restrictions (going private)

```bash
#!/bin/bash
# Remove push restrictions (not needed when repo is private)
# Uses read-modify-write: reads current config, removes restrictions, writes back

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"

# Read current protection
BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "No branch protection found. Skipping."
  exit 0
fi

# Extract current settings to preserve them
STRICT=$(echo "$BP_JSON" | jq -r '.required_status_checks.strict // true')
CONTEXTS=$(echo "$BP_JSON" | jq -c '.required_status_checks.contexts // []')
ENFORCE_ADMINS=$(echo "$BP_JSON" | jq -r '.enforce_admins.enabled // false')
LINEAR=$(echo "$BP_JSON" | jq -r '.required_linear_history.enabled // false')
FORCE_PUSH=$(echo "$BP_JSON" | jq -r '.allow_force_pushes.enabled // false')
DELETIONS=$(echo "$BP_JSON" | jq -r '.allow_deletions.enabled // false')
CONVERSATION=$(echo "$BP_JSON" | jq -r '.required_conversation_resolution.enabled // false')

# Extract review settings
HAS_REVIEWS=$(echo "$BP_JSON" | jq 'has("required_pull_request_reviews")')
if [ "$HAS_REVIEWS" = "true" ] && [ "$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews')" != "null" ]; then
  DISMISS_STALE=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
  CODEOWNER=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
  REVIEW_COUNT=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
  REVIEW_CONFIG="{
    \"dismiss_stale_reviews\": $DISMISS_STALE,
    \"require_code_owner_reviews\": $CODEOWNER,
    \"required_approving_review_count\": $REVIEW_COUNT
  }"
else
  REVIEW_CONFIG="null"
fi

# Write back with restrictions removed
gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": $STRICT,
    "contexts": $CONTEXTS
  },
  "enforce_admins": $ENFORCE_ADMINS,
  "required_pull_request_reviews": $REVIEW_CONFIG,
  "restrictions": null,
  "required_linear_history": $LINEAR,
  "allow_force_pushes": $FORCE_PUSH,
  "allow_deletions": $DELETIONS,
  "required_conversation_resolution": $CONVERSATION
}
EOF

echo "Push restrictions removed from $BRANCH"
```

### Add CodeQL to required status checks

```bash
#!/bin/bash
# Add "CodeQL Analysis" to required status checks (going public)

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"

BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "No branch protection found. Skipping."
  exit 0
fi

# Get current contexts
CURRENT_CONTEXTS=$(echo "$BP_JSON" | jq -c '.required_status_checks.contexts // []')

# Check if CodeQL is already there
if echo "$CURRENT_CONTEXTS" | jq -e 'index("CodeQL Analysis")' >/dev/null 2>&1; then
  echo "CodeQL Analysis already in required status checks."
  exit 0
fi

# Add CodeQL Analysis
NEW_CONTEXTS=$(echo "$CURRENT_CONTEXTS" | jq -c '. + ["CodeQL Analysis"]')

# Read all other settings and write back with updated contexts
STRICT=$(echo "$BP_JSON" | jq -r '.required_status_checks.strict // true')
ENFORCE_ADMINS=$(echo "$BP_JSON" | jq -r '.enforce_admins.enabled // false')
LINEAR=$(echo "$BP_JSON" | jq -r '.required_linear_history.enabled // false')
FORCE_PUSH=$(echo "$BP_JSON" | jq -r '.allow_force_pushes.enabled // false')
DELETIONS=$(echo "$BP_JSON" | jq -r '.allow_deletions.enabled // false')
CONVERSATION=$(echo "$BP_JSON" | jq -r '.required_conversation_resolution.enabled // false')

# Extract review settings
HAS_REVIEWS=$(echo "$BP_JSON" | jq 'has("required_pull_request_reviews")')
if [ "$HAS_REVIEWS" = "true" ] && [ "$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews')" != "null" ]; then
  DISMISS_STALE=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
  CODEOWNER=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
  REVIEW_COUNT=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
  REVIEW_CONFIG="{
    \"dismiss_stale_reviews\": $DISMISS_STALE,
    \"require_code_owner_reviews\": $CODEOWNER,
    \"required_approving_review_count\": $REVIEW_COUNT
  }"
else
  REVIEW_CONFIG="null"
fi

# Extract restrictions
HAS_RESTRICTIONS=$(echo "$BP_JSON" | jq '.restrictions != null')
if [ "$HAS_RESTRICTIONS" = "true" ]; then
  RESTRICT_USERS=$(echo "$BP_JSON" | jq -c '[.restrictions.users[].login]')
  RESTRICT_TEAMS=$(echo "$BP_JSON" | jq -c '[.restrictions.teams[].slug]')
  RESTRICTIONS_CONFIG="{
    \"users\": $RESTRICT_USERS,
    \"teams\": $RESTRICT_TEAMS
  }"
else
  RESTRICTIONS_CONFIG="null"
fi

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": $STRICT,
    "contexts": $NEW_CONTEXTS
  },
  "enforce_admins": $ENFORCE_ADMINS,
  "required_pull_request_reviews": $REVIEW_CONFIG,
  "restrictions": $RESTRICTIONS_CONFIG,
  "required_linear_history": $LINEAR,
  "allow_force_pushes": $FORCE_PUSH,
  "allow_deletions": $DELETIONS,
  "required_conversation_resolution": $CONVERSATION
}
EOF

echo "Added 'CodeQL Analysis' to required status checks on $BRANCH"
```

### Remove CodeQL from required status checks

```bash
#!/bin/bash
# Remove "CodeQL Analysis" from required status checks (going private)

REPO="${1:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${2:-main}"

BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)
if [ $? -ne 0 ]; then
  echo "No branch protection found. Skipping."
  exit 0
fi

# Get current contexts
CURRENT_CONTEXTS=$(echo "$BP_JSON" | jq -c '.required_status_checks.contexts // []')

# Check if CodeQL is there
if ! echo "$CURRENT_CONTEXTS" | jq -e 'index("CodeQL Analysis")' >/dev/null 2>&1; then
  echo "CodeQL Analysis not in required status checks. No changes needed."
  exit 0
fi

# Remove CodeQL Analysis
NEW_CONTEXTS=$(echo "$CURRENT_CONTEXTS" | jq -c 'map(select(. != "CodeQL Analysis"))')

# Read all other settings and write back with updated contexts
STRICT=$(echo "$BP_JSON" | jq -r '.required_status_checks.strict // true')
ENFORCE_ADMINS=$(echo "$BP_JSON" | jq -r '.enforce_admins.enabled // false')
LINEAR=$(echo "$BP_JSON" | jq -r '.required_linear_history.enabled // false')
FORCE_PUSH=$(echo "$BP_JSON" | jq -r '.allow_force_pushes.enabled // false')
DELETIONS=$(echo "$BP_JSON" | jq -r '.allow_deletions.enabled // false')
CONVERSATION=$(echo "$BP_JSON" | jq -r '.required_conversation_resolution.enabled // false')

# Extract review settings
HAS_REVIEWS=$(echo "$BP_JSON" | jq 'has("required_pull_request_reviews")')
if [ "$HAS_REVIEWS" = "true" ] && [ "$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews')" != "null" ]; then
  DISMISS_STALE=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.dismiss_stale_reviews // false')
  CODEOWNER=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.require_code_owner_reviews // false')
  REVIEW_COUNT=$(echo "$BP_JSON" | jq -r '.required_pull_request_reviews.required_approving_review_count // 0')
  REVIEW_CONFIG="{
    \"dismiss_stale_reviews\": $DISMISS_STALE,
    \"require_code_owner_reviews\": $CODEOWNER,
    \"required_approving_review_count\": $REVIEW_COUNT
  }"
else
  REVIEW_CONFIG="null"
fi

# Extract restrictions
HAS_RESTRICTIONS=$(echo "$BP_JSON" | jq '.restrictions != null')
if [ "$HAS_RESTRICTIONS" = "true" ]; then
  RESTRICT_USERS=$(echo "$BP_JSON" | jq -c '[.restrictions.users[].login]')
  RESTRICT_TEAMS=$(echo "$BP_JSON" | jq -c '[.restrictions.teams[].slug]')
  RESTRICTIONS_CONFIG="{
    \"users\": $RESTRICT_USERS,
    \"teams\": $RESTRICT_TEAMS
  }"
else
  RESTRICTIONS_CONFIG="null"
fi

gh api \
  --method PUT \
  -H "Accept: application/vnd.github+json" \
  "/repos/$REPO/branches/$BRANCH/protection" \
  --input - <<EOF
{
  "required_status_checks": {
    "strict": $STRICT,
    "contexts": $NEW_CONTEXTS
  },
  "enforce_admins": $ENFORCE_ADMINS,
  "required_pull_request_reviews": $REVIEW_CONFIG,
  "restrictions": $RESTRICTIONS_CONFIG,
  "required_linear_history": $LINEAR,
  "allow_force_pushes": $FORCE_PUSH,
  "allow_deletions": $DELETIONS,
  "required_conversation_resolution": $CONVERSATION
}
EOF

echo "Removed 'CodeQL Analysis' from required status checks on $BRANCH"
```

---

## Pre-flight Security Scan Script

```bash
#!/bin/bash
# Pre-flight security scan before making a repo public
# Returns non-zero if issues found (blocks unless --force)

ISSUES_FOUND=0

echo "Running pre-flight security scan..."
echo ""

# 1. Check for tracked sensitive files
echo "Checking for tracked sensitive files..."
SENSITIVE_FILES=$(git ls-files | grep -iE '\.(env|pem|key|p12|pfx|credentials|secret)$|id_rsa|id_ed25519|\.env\.' 2>/dev/null || true)
if [ -n "$SENSITIVE_FILES" ]; then
  echo "  BLOCKED: Sensitive files found in tracked files:"
  echo "$SENSITIVE_FILES" | sed 's/^/    /'
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo "  PASS: No sensitive files in tracked files"
fi
echo ""

# 2. Check for secrets in tracked files
echo "Checking for secrets in tracked files..."
SECRET_FILES=$(git grep -lE '(AKIA[0-9A-Z]{16}|sk_live_[0-9a-zA-Z]{24,}|ghp_[0-9a-zA-Z]{36}|gho_[0-9a-zA-Z]{36}|github_pat_[0-9a-zA-Z_]{22,}|password\s*=\s*['\''"][^'\''"]+['\''"]|secret\s*=\s*['\''"][^'\''"]+['\''"]|mongodb\+srv://|postgres://[^/]*:[^@]*@)' 2>/dev/null || true)
if [ -n "$SECRET_FILES" ]; then
  echo "  BLOCKED: Potential secrets found in:"
  echo "$SECRET_FILES" | sed 's/^/    /'
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo "  PASS: No secrets detected in tracked files"
fi
echo ""

# 3. Check git history for sensitive files ever committed
echo "Checking git history for sensitive files..."
HISTORICAL_FILES=$(git log --all --diff-filter=A --name-only --pretty=format: | grep -iE '\.(env|pem|key|p12|pfx|credentials|secret)$|id_rsa|id_ed25519' | sort -u 2>/dev/null || true)
if [ -n "$HISTORICAL_FILES" ]; then
  echo "  BLOCKED: Sensitive files found in git history:"
  echo "$HISTORICAL_FILES" | sed 's/^/    /'
  echo ""
  echo "  These files were committed at some point. Even if deleted, they exist in history."
  echo "  Use 'git filter-repo' to remove them before making the repo public."
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  echo "  PASS: No sensitive files in git history"
fi
echo ""

# 4. Check .gitignore coverage
echo "Checking .gitignore coverage..."
if [ ! -f .gitignore ]; then
  echo "  WARNING: No .gitignore file found"
  ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
  MISSING_PATTERNS=""
  for pattern in ".env*" "*.pem" "*.key" "node_modules/"; do
    if ! grep -qF "$pattern" .gitignore 2>/dev/null; then
      MISSING_PATTERNS="$MISSING_PATTERNS $pattern"
    fi
  done
  if [ -n "$MISSING_PATTERNS" ]; then
    echo "  WARNING: .gitignore is missing patterns:$MISSING_PATTERNS"
  else
    echo "  PASS: .gitignore covers common sensitive patterns"
  fi
fi
echo ""

# Summary
if [ "$ISSUES_FOUND" -gt 0 ]; then
  echo "Pre-flight scan found $ISSUES_FOUND issue(s). Making this repo public is blocked."
  echo ""
  echo "Options:"
  echo "  1. Fix the issues above and re-run"
  echo "  2. Use --force to bypass (at your own risk)"
  echo "  3. For historical files: pip install git-filter-repo && git filter-repo --invert-paths --path <file>"
  exit 1
else
  echo "Pre-flight scan passed. Safe to make repo public."
  exit 0
fi
```

---

## Verification Script

```bash
#!/bin/bash
# Verify github-visibility settings after toggle
# Usage: verify-visibility.sh <public|private>

set -e

TARGET="${1:?Usage: verify-visibility.sh <public|private>}"
REPO="${2:-$(gh repo view --json nameWithOwner -q .nameWithOwner)}"
BRANCH="${3:-$(gh repo view --json defaultBranchRef -q .defaultBranchRef.name)}"

PASS=0
FAIL=0
WARN=0

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

warn() {
  local label="$1" message="$2"
  echo "  WARN  $label — $message"
  WARN=$((WARN + 1))
}

echo "Verifying visibility settings for $REPO (target: $TARGET)"
echo ""

# 1. Visibility
echo "Visibility..."
ACTUAL_VIS=$(gh repo view --json visibility -q .visibility | tr '[:upper:]' '[:lower:]')
check "Repository visibility" "$ACTUAL_VIS" "$TARGET"
echo ""

# 2. Repo features
echo "Repository features..."
REPO_JSON=$(gh repo view --json hasIssuesEnabled,hasWikiEnabled,hasDiscussionsEnabled,hasProjectsEnabled)
check "Issues disabled" "$(echo "$REPO_JSON" | jq -r .hasIssuesEnabled)" "false"
check "Wiki disabled" "$(echo "$REPO_JSON" | jq -r .hasWikiEnabled)" "false"
check "Discussions disabled" "$(echo "$REPO_JSON" | jq -r .hasDiscussionsEnabled)" "false"
check "Projects disabled" "$(echo "$REPO_JSON" | jq -r .hasProjectsEnabled)" "false"
echo ""

# 3. Security (public only)
if [ "$TARGET" = "public" ]; then
  echo "Security scanning..."
  SEC_JSON=$(gh api "/repos/$REPO" --jq '.security_and_analysis' 2>/dev/null || echo "{}")
  if [ -n "$SEC_JSON" ] && [ "$SEC_JSON" != "{}" ] && [ "$SEC_JSON" != "null" ]; then
    SECRET_SCAN=$(echo "$SEC_JSON" | jq -r '.secret_scanning.status // "disabled"')
    PUSH_PROTECT=$(echo "$SEC_JSON" | jq -r '.secret_scanning_push_protection.status // "disabled"')
    check "Secret scanning" "$SECRET_SCAN" "enabled"
    check "Push protection" "$PUSH_PROTECT" "enabled"
  else
    warn "Security scanning" "Could not read security_and_analysis (may need admin access)"
  fi
  echo ""
fi

# 4. Branch protection
echo "Branch protection..."
BP_JSON=$(gh api "/repos/$REPO/branches/$BRANCH/protection" 2>/dev/null)
if [ $? -eq 0 ]; then
  if [ "$TARGET" = "public" ]; then
    # Check push restrictions exist
    HAS_RESTRICTIONS=$(echo "$BP_JSON" | jq '.restrictions != null')
    check "Push restrictions configured" "$HAS_RESTRICTIONS" "true"

    # Check CodeQL in status checks (if security.yml exists)
    if [ -f .github/workflows/security.yml ]; then
      HAS_CODEQL=$(echo "$BP_JSON" | jq '[.required_status_checks.contexts[] | select(. == "CodeQL Analysis")] | length > 0')
      check "CodeQL in required checks" "$HAS_CODEQL" "true"
    fi
  else
    # Private: restrictions should be null
    HAS_RESTRICTIONS=$(echo "$BP_JSON" | jq '.restrictions == null')
    check "Push restrictions removed" "$HAS_RESTRICTIONS" "true"

    # CodeQL should NOT be in required checks
    if [ -f .github/workflows/security.yml ]; then
      HAS_CODEQL=$(echo "$BP_JSON" | jq '[.required_status_checks.contexts[] | select(. == "CodeQL Analysis")] | length > 0')
      check "CodeQL removed from required checks" "$HAS_CODEQL" "false"
    fi
  fi
else
  warn "Branch protection" "No branch protection configured on $BRANCH"
fi
echo ""

# 5. Workflow files
echo "Workflow files..."
if [ "$TARGET" = "public" ]; then
  if [ -f .github/workflows/close-external-prs.yml ]; then
    check "close-external-prs.yml exists" "true" "true"
  else
    check "close-external-prs.yml exists" "false" "true"
  fi
else
  if [ -f .github/workflows/close-external-prs.yml ]; then
    check "close-external-prs.yml removed" "true" "false"
  else
    check "close-external-prs.yml removed" "true" "true"
  fi
fi
echo ""

# 6. LICENSE (public only)
if [ "$TARGET" = "public" ]; then
  echo "License..."
  if [ -f LICENSE ] || [ -f LICENSE.md ] || [ -f LICENSE.txt ]; then
    check "LICENSE file exists" "true" "true"
  else
    check "LICENSE file exists" "false" "true"
  fi
  echo ""
fi

# 7. CodeQL condition in security.yml
if [ -f .github/workflows/security.yml ]; then
  echo "security.yml CodeQL condition..."
  HAS_CONDITION=$(grep -c "if: github.repository_visibility == 'public'" .github/workflows/security.yml 2>/dev/null || echo "0")
  if [ "$TARGET" = "private" ]; then
    check "CodeQL has visibility condition" "$([ "$HAS_CONDITION" -gt 0 ] && echo 'true' || echo 'false')" "true"
  else
    check "CodeQL has no visibility condition" "$([ "$HAS_CONDITION" -eq 0 ] && echo 'true' || echo 'false')" "true"
  fi
  echo ""
fi

# Summary
echo "Results: $PASS passed, $FAIL failed, $WARN warnings"

if [ "$FAIL" -gt 0 ]; then
  exit 1
else
  exit 0
fi
```
