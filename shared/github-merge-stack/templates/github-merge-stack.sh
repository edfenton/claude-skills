#!/bin/bash

# GitHub Merge Stack - Merge open PRs in order
# Usage: ./github-merge-stack.sh [--dry-run] [--wait]
#
# Merges all open PRs targeting main, oldest first.
# Since all PRs target main directly, no rebasing or base updates needed.

set -e

DRY_RUN=false
WAIT_FOR_CI=false
MAIN_BRANCH="${RALPH_MAIN_BRANCH:-main}"

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --wait)
            WAIT_FOR_CI=true
            shift
            ;;
        -h|--help)
            echo "Usage: ./github-merge-stack.sh [--dry-run] [--wait]"
            echo ""
            echo "Merge all open PRs targeting $MAIN_BRANCH, oldest first."
            echo ""
            echo "Options:"
            echo "  --dry-run  Show merge plan without executing"
            echo "  --wait     Wait for CI checks to pass before each merge"
            echo ""
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./github-merge-stack.sh [--dry-run] [--wait]"
            exit 1
            ;;
    esac
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Merge Stack"
[ "$DRY_RUN" = true ] && echo "  (Dry Run - No Changes)"
[ "$WAIT_FOR_CI" = true ] && echo "  (Will wait for CI)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check prerequisites
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found"
    echo "Install: https://cli.github.com/"
    exit 1
fi

if ! gh auth status &> /dev/null; then
    echo "Error: gh CLI not authenticated"
    echo "Run: gh auth login"
    exit 1
fi

# Get open PRs targeting main, sorted by number (oldest first)
echo "→ Fetching open PRs targeting $MAIN_BRANCH..."
PRS_JSON=$(gh pr list --base "$MAIN_BRANCH" --state open --json number,title,headRefName --jq 'sort_by(.number)' 2>/dev/null || echo "[]")
PR_COUNT=$(echo "$PRS_JSON" | jq 'length')

if [ "$PR_COUNT" -eq 0 ]; then
    echo ""
    echo "No open PRs found targeting $MAIN_BRANCH."
    exit 0
fi

# Display PRs
echo ""
echo "Open PRs ($PR_COUNT):"
echo "$PRS_JSON" | jq -r '.[] | "  #\(.number) \(.title)"'
echo ""

# Get PR numbers
PR_NUMBERS=$(echo "$PRS_JSON" | jq -r '.[].number')

# Dry run - show plan and exit
if [ "$DRY_RUN" = true ]; then
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Merge Plan"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    STEP=1
    for PR in $PR_NUMBERS; do
        TITLE=$(echo "$PRS_JSON" | jq -r --argjson n "$PR" '.[] | select(.number == $n) | .title')
        echo "  $STEP. Squash merge PR #$PR: $TITLE"
        echo "     Delete branch after merge"
        echo ""
        STEP=$((STEP + 1))
    done

    echo "Run without --dry-run to execute."
    exit 0
fi

# Execute merges
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Merging PRs"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

MERGED_COUNT=0
FAILED_PRS=()

for PR in $PR_NUMBERS; do
    TITLE=$(echo "$PRS_JSON" | jq -r --argjson n "$PR" '.[] | select(.number == $n) | .title')
    BRANCH=$(echo "$PRS_JSON" | jq -r --argjson n "$PR" '.[] | select(.number == $n) | .headRefName')

    echo "→ PR #$PR: $TITLE"

    # Wait for CI if requested
    if [ "$WAIT_FOR_CI" = true ]; then
        echo "  Waiting for CI checks..."

        MAX_WAIT=300  # 5 minutes max
        WAITED=0
        INTERVAL=10

        while [ $WAITED -lt $MAX_WAIT ]; do
            # Get check status
            CHECK_STATUS=$(gh pr checks "$PR" --json state --jq '[.[] | .state] | if all(. == "SUCCESS") then "pass" elif any(. == "FAILURE") then "fail" elif any(. == "PENDING") then "pending" else "unknown" end' 2>/dev/null || echo "unknown")

            if [ "$CHECK_STATUS" = "pass" ]; then
                echo "  ✓ CI passed"
                break
            elif [ "$CHECK_STATUS" = "fail" ]; then
                echo "  ✗ CI failed - skipping"
                FAILED_PRS+=("$PR (CI failed)")
                continue 2
            elif [ "$CHECK_STATUS" = "pending" ]; then
                echo "  Checks pending... (${WAITED}s / ${MAX_WAIT}s)"
                sleep $INTERVAL
                WAITED=$((WAITED + INTERVAL))
            else
                echo "  No checks or unknown status, proceeding..."
                break
            fi
        done

        if [ $WAITED -ge $MAX_WAIT ]; then
            echo "  ✗ Timed out waiting for CI - skipping"
            FAILED_PRS+=("$PR (CI timeout)")
            echo ""
            continue
        fi
    fi

    # Attempt merge
    echo "  Merging..."
    MERGE_OUTPUT=$(gh pr merge "$PR" --squash --delete-branch 2>&1)
    MERGE_STATUS=$?

    if [ $MERGE_STATUS -eq 0 ]; then
        echo "  ✓ Merged and branch deleted"
        MERGED_COUNT=$((MERGED_COUNT + 1))
    else
        echo "  ✗ Merge failed"

        # Parse common failure reasons
        if echo "$MERGE_OUTPUT" | grep -qi "conflict"; then
            echo "    Merge conflict - resolve manually:"
            echo "    gh pr checkout $PR"
            echo "    # Fix conflicts, commit, push"
        elif echo "$MERGE_OUTPUT" | grep -qi "check"; then
            echo "    CI checks must pass first."
            echo "    Use --wait flag or wait for CI to complete."
        elif echo "$MERGE_OUTPUT" | grep -qi "review"; then
            echo "    PR requires review approval."
        elif echo "$MERGE_OUTPUT" | grep -qi "protected"; then
            echo "    Branch protection rules prevent merge."
        else
            echo "    $MERGE_OUTPUT"
        fi

        FAILED_PRS+=("$PR")
    fi

    echo ""
done

# Sync local
echo "→ Syncing local repository..."
git fetch origin --prune
git checkout "$MAIN_BRANCH" 2>/dev/null || true
git pull origin "$MAIN_BRANCH" 2>/dev/null || true

# Summary
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Merged: $MERGED_COUNT of $PR_COUNT PRs"

if [ ${#FAILED_PRS[@]} -gt 0 ]; then
    echo ""
    echo "Failed PRs:"
    for PR in "${FAILED_PRS[@]}"; do
        echo "  - #$PR"
    done
fi

echo ""
echo "Recent commits on $MAIN_BRANCH:"
git log --oneline -"$((MERGED_COUNT + 2))" 2>/dev/null || git log --oneline -5

# Check for remaining PRs
REMAINING_PRS=$(gh pr list --base "$MAIN_BRANCH" --state open --json number --jq 'length' 2>/dev/null || echo "0")

if [ "$REMAINING_PRS" -gt 0 ]; then
    echo ""
    echo "Remaining open PRs: $REMAINING_PRS"
    echo "  gh pr list"
fi

echo ""
