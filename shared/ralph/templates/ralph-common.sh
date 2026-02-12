#!/bin/bash

# Ralph Common Library
# Shared functions for ralph.sh and ralph-once.sh
#
# Usage: source this file at the top of ralph scripts
#   source "$(dirname "${BASH_SOURCE[0]}")/ralph-common.sh"

# ============================================================================
# INITIALIZATION
# ============================================================================

ralph_init() {
    # Set strict mode
    set -e

    # Establish paths
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
    PROGRESS_FILE="$SCRIPT_DIR/progress.txt"
    PRD_FILE="$SCRIPT_DIR/prd.json"
    CLAUDE_MD="$SCRIPT_DIR/CLAUDE.md"
    MAIN_BRANCH="${RALPH_MAIN_BRANCH:-main}"

    # Defaults
    MERGE_TIMEOUT=600  # 10 minutes
}

# ============================================================================
# PREREQUISITES
# ============================================================================

ralph_check_prerequisites() {
    command -v claude >/dev/null || { echo "Error: claude CLI not found"; exit 1; }
    command -v jq >/dev/null || { echo "Error: jq not found"; exit 1; }
    command -v gh >/dev/null || { echo "Error: gh CLI not found (required for PR creation)"; exit 1; }
    [ -f "$PRD_FILE" ] || { echo "Error: prd.json not found at $PRD_FILE"; exit 1; }
    [ -f "$CLAUDE_MD" ] || { echo "Error: CLAUDE.md not found at $CLAUDE_MD"; exit 1; }
}

ralph_check_clean_worktree() {
    if ! git diff --quiet || ! git diff --cached --quiet; then
        echo ""
        echo "Error: You have uncommitted changes. Please commit or stash them first."
        echo ""
        echo "  git status        # See what's changed"
        echo "  git stash         # Temporarily save changes"
        echo "  git checkout .    # Discard changes"
        exit 1
    fi
}

# ============================================================================
# STORY MANAGEMENT
# ============================================================================

ralph_get_remaining_count() {
    jq '[.userStories[] | select(.passes == false)] | length' "$PRD_FILE"
}

ralph_get_total_count() {
    jq '.userStories | length' "$PRD_FILE"
}

ralph_get_next_story() {
    # Get next incomplete story (lowest priority number)
    NEXT_STORY=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0]' "$PRD_FILE")

    # Extract story fields
    STORY_ID=$(echo "$NEXT_STORY" | jq -r '.id')
    STORY_TITLE=$(echo "$NEXT_STORY" | jq -r '.title')
    STORY_DESC=$(echo "$NEXT_STORY" | jq -r '.description // empty')
    STORY_CRITERIA=$(echo "$NEXT_STORY" | jq -r '.acceptanceCriteria // [] | join("\n- ")')
    STORY_FILES=$(echo "$NEXT_STORY" | jq -r '.filesToCreate // [] | join("\n- ")')
    STORY_NOTES=$(echo "$NEXT_STORY" | jq -r '.notes // empty')
    SCAFFOLD_SKILL=$(echo "$NEXT_STORY" | jq -r '.scaffoldSkill // empty')
    BRANCH_NAME="feat/$STORY_ID"

    # Export for use in calling script
    export NEXT_STORY STORY_ID STORY_TITLE STORY_DESC STORY_CRITERIA
    export STORY_FILES STORY_NOTES SCAFFOLD_SKILL BRANCH_NAME
}

ralph_check_story_passed() {
    local story_id="$1"
    jq -r --arg id "$story_id" '.userStories[] | select(.id == $id) | .passes' "$PRD_FILE"
}

ralph_show_stories() {
    echo "Stories:"
    jq -r '.userStories[] | "  [\(if .passes then "✓" else " " end)] \(.id): \(.title)"' "$PRD_FILE"
    echo ""
}

# ============================================================================
# GIT OPERATIONS
# ============================================================================

ralph_sync_main() {
    git fetch origin
    git checkout "$MAIN_BRANCH"
    git pull origin "$MAIN_BRANCH"
}

ralph_create_branch() {
    local branch_name="$1"
    local force="${2:-false}"

    # Check if branch already exists locally
    if git rev-parse --verify "$branch_name" >/dev/null 2>&1; then
        if [ "$force" = "true" ]; then
            git branch -D "$branch_name" 2>/dev/null || true
        else
            echo "Branch $branch_name already exists locally."
            echo "Options:"
            echo "  git branch -D $branch_name  # Delete and start fresh"
            echo "  git checkout $branch_name   # Resume work on it"
            return 1
        fi
    fi

    # Check if branch exists on remote
    if git rev-parse --verify "origin/$branch_name" >/dev/null 2>&1; then
        if [ "$force" = "true" ]; then
            git push origin --delete "$branch_name" 2>/dev/null || true
        else
            echo "Branch $branch_name exists on remote."
            echo "A PR may already exist for this story."
            echo ""
            echo "Check: gh pr list --head $branch_name"
            return 1
        fi
    fi

    git checkout -b "$branch_name"
}

ralph_sync_after_merge() {
    local branch_name="$1"
    git checkout "$MAIN_BRANCH" 2>/dev/null || true
    git pull origin "$MAIN_BRANCH" 2>/dev/null || true
    git branch -D "$branch_name" 2>/dev/null || true
    git push origin --delete "$branch_name" 2>/dev/null || true
    git fetch --prune 2>/dev/null || true
}

# ============================================================================
# SCAFFOLD SKILL
# ============================================================================

ralph_run_scaffold() {
    local scaffold_skill="$1"
    local story_id="$2"

    if [ -z "$scaffold_skill" ]; then
        return 0
    fi

    # Extract feature name from story ID (remove trailing -NNN)
    local feature_name=$(echo "$story_id" | sed 's/-[0-9]*$//')

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Running scaffold: $scaffold_skill $feature_name for $story_id" >> "$PROGRESS_FILE"

    # Run the skill via claude
    echo "/$scaffold_skill $feature_name" | claude --dangerously-skip-permissions --print || {
        echo "Warning: Scaffold skill failed, continuing with implementation"
    }
}

# ============================================================================
# IMPLEMENTATION
# ============================================================================

ralph_run_implementation() {
    local story_id="$1"
    local story_title="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting: $story_id - $story_title" >> "$PROGRESS_FILE"

    claude --dangerously-skip-permissions --print < "$CLAUDE_MD"
}

ralph_run_implementation_captured() {
    # Same as above but captures output (for checking COMPLETE signal)
    local story_id="$1"
    local story_title="$2"

    echo "$(date '+%Y-%m-%d %H:%M:%S') - Starting: $story_id - $story_title" >> "$PROGRESS_FILE"

    claude --dangerously-skip-permissions --print < "$CLAUDE_MD" 2>&1 | tee /dev/stderr
}

# ============================================================================
# COMMIT & PR
# ============================================================================

ralph_build_commit_message() {
    local story_id="$1"
    local story_title="$2"
    local story_desc="$3"
    local story_criteria="$4"
    local story_notes="$5"
    local iteration="${6:-}"

    # Lowercase title for conventional commits
    local title_lower=$(echo "$story_title" | tr '[:upper:]' '[:lower:]')
    local commit_msg="feat($story_id): $title_lower"
    local commit_body=""

    # Description (wrapped to 100 chars)
    if [ -n "$story_desc" ]; then
        commit_body=$(echo "$story_desc" | fold -s -w 100)
    fi

    # Acceptance Criteria
    if [ -n "$story_criteria" ]; then
        local wrapped_criteria=$(echo "- $story_criteria" | fold -s -w 98)
        commit_body="$commit_body

Acceptance Criteria:
$wrapped_criteria"
    fi

    # Changed files
    local changed_files=$(git diff --cached --name-only | head -20)
    local file_count=$(git diff --cached --name-only | wc -l | tr -d ' ')

    if [ -n "$changed_files" ]; then
        commit_body="$commit_body

Files changed ($file_count):
$changed_files"
        [ "$file_count" -gt 20 ] && commit_body="$commit_body
... and $((file_count - 20)) more"
    fi

    # Notes
    if [ -n "$story_notes" ]; then
        local wrapped_notes=$(echo "$story_notes" | fold -s -w 93)
        commit_body="$commit_body

Notes: $wrapped_notes"
    fi

    # Story ID and iteration
    commit_body="$commit_body

Story-ID: $story_id"

    if [ -n "$iteration" ]; then
        commit_body="$commit_body
Ralph-Iteration: $iteration"
    fi

    # Output the full message
    echo "$commit_msg

$commit_body"
}

ralph_commit_changes() {
    local story_id="$1"
    local story_title="$2"
    local story_desc="$3"
    local story_criteria="$4"
    local story_notes="$5"
    local iteration="${6:-}"
    local branch_name="$7"

    # Log success
    echo "$(date '+%Y-%m-%d %H:%M:%S') - PASSED: $story_id - $story_title (branch: $branch_name)" >> "$PROGRESS_FILE"

    git add -A

    if git diff --cached --quiet; then
        echo "No changes to commit"
        return 0
    fi

    local commit_message=$(ralph_build_commit_message "$story_id" "$story_title" "$story_desc" "$story_criteria" "$story_notes" "$iteration")

    git commit -m "$commit_message"

    local title_lower=$(echo "$story_title" | tr '[:upper:]' '[:lower:]')
    echo "✓ Committed: feat($story_id): $title_lower"
}

ralph_build_pr_body() {
    local story_desc="$1"
    local story_criteria_json="$2"  # Pass the raw NEXT_STORY json
    local story_files="$3"
    local story_notes="$4"
    local story_id="$5"
    local iteration="${6:-}"

    local pr_body="## Summary

$story_desc

## Acceptance Criteria"

    # Add criteria as checked items
    if [ -n "$story_criteria_json" ]; then
        local criteria_list=$(echo "$story_criteria_json" | jq -r '.acceptanceCriteria // [] | map("- [x] " + .) | join("\n")')
        pr_body="$pr_body
$criteria_list"
    fi

    # Files section
    if [ -n "$story_files" ]; then
        pr_body="$pr_body

## Files
- $story_files"
    fi

    # Notes section
    if [ -n "$story_notes" ]; then
        pr_body="$pr_body

## Notes
$story_notes"
    fi

    # Footer
    pr_body="$pr_body

---
**Story ID:** \`$story_id\`"

    if [ -n "$iteration" ]; then
        pr_body="$pr_body
**Ralph Iteration:** $iteration"
    fi

    pr_body="$pr_body

🤖 Generated by Ralph"

    echo "$pr_body"
}

ralph_create_pr() {
    local branch_name="$1"
    local story_id="$2"
    local story_title="$3"
    local pr_body="$4"

    # Push branch
    git push -u origin "$branch_name"
    echo "✓ Pushed to origin/$branch_name"

    # Lowercase title
    local title_lower=$(echo "$story_title" | tr '[:upper:]' '[:lower:]')

    # Create PR
    local pr_url=$(gh pr create \
        --base "$MAIN_BRANCH" \
        --head "$branch_name" \
        --title "feat($story_id): $title_lower" \
        --body "$pr_body" 2>&1) || {
        echo "Warning: PR creation failed"
        echo ""
        return 1
    }

    # Extract PR number
    PR_NUMBER=$(echo "$pr_url" | grep -oE '[0-9]+$' || echo "")
    PR_URL="$pr_url"

    export PR_NUMBER PR_URL

    echo "✓ PR created: $pr_url"
}

# ============================================================================
# AUTO-MERGE
# ============================================================================

ralph_auto_merge() {
    local pr_number="$1"
    local branch_name="$2"
    local timeout="${3:-$MERGE_TIMEOUT}"

    # Enable auto-merge
    echo "  Enabling auto-merge..."
    if ! gh pr merge "$pr_number" --auto --squash --delete-branch 2>/dev/null; then
        # Auto-merge not available, try direct merge
        echo "  Auto-merge not available, attempting direct merge..."
        if gh pr merge "$pr_number" --squash --delete-branch 2>/dev/null; then
            echo "  ✓ Merged directly"
            ralph_sync_after_merge "$branch_name"
            return 0
        else
            echo "  ✗ Direct merge failed (CI may be required)"
            echo "    Waiting for CI and auto-merge..."
        fi
    else
        echo "  ✓ Auto-merge enabled"
    fi

    # Wait for PR to be merged
    echo "  Waiting for merge (timeout: ${timeout}s)..."
    local waited=0
    local interval=15

    while [ $waited -lt $timeout ]; do
        local pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")

        case "$pr_state" in
            MERGED)
                echo "  ✓ PR merged successfully"
                ralph_sync_after_merge "$branch_name"
                return 0
                ;;
            CLOSED)
                echo "  ✗ PR was closed without merging"
                return 1
                ;;
            OPEN)
                local mergeable=$(gh pr view "$pr_number" --json mergeable --jq '.mergeable' 2>/dev/null || echo "UNKNOWN")
                if [ "$mergeable" = "CONFLICTING" ]; then
                    echo "  ✗ PR has merge conflicts"
                    return 1
                fi
                echo "  Waiting... (${waited}s / ${timeout}s)"
                sleep $interval
                waited=$((waited + interval))
                ;;
            *)
                echo "  PR state: $pr_state, waiting..."
                sleep $interval
                waited=$((waited + interval))
                ;;
        esac
    done

    echo "  ✗ Timeout waiting for merge"
    echo "    PR remains open with auto-merge enabled"
    echo "    It will merge automatically when CI passes"
    return 1
}

# ============================================================================
# DISPLAY HELPERS
# ============================================================================

ralph_banner() {
    local title="$1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  $title"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

ralph_step() {
    local step="$1"
    local total="$2"
    local message="$3"
    echo ""
    echo "→ Step $step/$total: $message"
}

ralph_log_failed() {
    local story_id="$1"
    local reason="${2:-quality checks}"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - FAILED: $story_id ($reason)" >> "$PROGRESS_FILE"
}
