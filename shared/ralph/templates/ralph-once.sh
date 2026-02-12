#!/bin/bash

# Ralph Single Iteration (Human-in-the-Loop)
# Usage: ./scripts/ralph/ralph-once.sh [--merge]
#
# Workflow (TDD enforced):
#   1. Sync with main (pull latest)
#   2. Create feature branch from main
#   3. Run scaffold skill if specified
#   4. RED: Write failing tests first (from acceptance criteria)
#   5. GREEN: Implement minimum code to pass tests
#   6. REFACTOR: Clean up while tests stay green
#   7. Run quality checks (lint, test, build)
#   8. Commit changes (with TDD evidence in progress.txt)
#   9. Push and create PR to main
#   10. (Optional) Auto-merge if --merge flag is set
#
# TDD is mandatory - stories cannot pass without test files and TDD evidence.
# This creates independent PRs that all target main directly.
# No stacked branches = no cascading merge conflicts.

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/ralph-common.sh"

# Initialize
ralph_init

# Defaults for this script
AUTO_MERGE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --merge)
            AUTO_MERGE=true
            shift
            ;;
        --merge-timeout)
            MERGE_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./ralph-once.sh [--merge] [--merge-timeout N]"
            echo ""
            echo "Options:"
            echo "  --merge          Auto-merge PR after creation (waits for CI)"
            echo "  --merge-timeout  Max seconds to wait for merge (default: 600)"
            echo ""
            echo "Examples:"
            echo "  ./ralph-once.sh           # Create PR, stop for review"
            echo "  ./ralph-once.sh --merge   # Create PR and auto-merge"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./ralph-once.sh [--merge]"
            exit 1
            ;;
    esac
done

# Banner
ralph_banner "Ralph Single Iteration"
[ "$AUTO_MERGE" = true ] && echo "  (Auto-merge enabled)"
echo ""

# Check prerequisites
ralph_check_prerequisites

cd "$PROJECT_ROOT"

# Show current status
ralph_show_stories

# Check if all complete
REMAINING=$(ralph_get_remaining_count)

if [ "$REMAINING" -eq 0 ]; then
    echo "✓ All stories complete!"
    exit 0
fi

# Get next story
ralph_get_next_story

echo "Next Story"
ralph_banner "$STORY_ID"
echo "Title:       $STORY_TITLE"
[ -n "$STORY_DESC" ] && echo "Description: $STORY_DESC"
[ -n "$SCAFFOLD_SKILL" ] && echo "Scaffold:    $SCAFFOLD_SKILL"
echo "Branch:      $BRANCH_NAME → $MAIN_BRANCH"
echo ""

# Determine step count based on merge flag
if [ "$AUTO_MERGE" = true ]; then
    TOTAL_STEPS=8
else
    TOTAL_STEPS=7
fi

# Step 1: Check for uncommitted changes and sync
ralph_step 1 $TOTAL_STEPS "Syncing with $MAIN_BRANCH..."
ralph_check_clean_worktree
ralph_sync_main
echo "✓ Synced with $MAIN_BRANCH"

# Step 2: Create feature branch
ralph_step 2 $TOTAL_STEPS "Creating branch $BRANCH_NAME..."
ralph_create_branch "$BRANCH_NAME" || exit 1
echo "✓ Created branch $BRANCH_NAME from $MAIN_BRANCH"

# Step 3: Run scaffold skill if specified
ralph_step 3 $TOTAL_STEPS "Running scaffold skill..."
if [ -n "$SCAFFOLD_SKILL" ]; then
    echo "Scaffold: $SCAFFOLD_SKILL"
    ralph_run_scaffold "$SCAFFOLD_SKILL" "$STORY_ID"
else
    echo "No scaffold skill specified, skipping..."
fi

# Step 4: Implement (TDD: red → green → refactor)
ralph_step 4 $TOTAL_STEPS "Implementing story (TDD)..."
echo ""
ralph_run_implementation "$STORY_ID" "$STORY_TITLE"
echo ""

# Step 5: Check if passed
ralph_step 5 $TOTAL_STEPS "Verifying story passed..."
STORY_PASSED=$(ralph_check_story_passed "$STORY_ID")

if [ "$STORY_PASSED" != "true" ]; then
    ralph_banner "✗ Story did not pass"
    echo ""
    echo "Review the output above for errors."
    echo "You're on branch: $BRANCH_NAME"
    echo ""
    echo "Debug commands:"
    echo "  git status              # See changes"
    echo "  git diff                # Review changes"
    echo ""
    echo "To retry this story:"
    echo "  git checkout $MAIN_BRANCH"
    echo "  git branch -D $BRANCH_NAME"
    echo "  ./scripts/ralph/ralph-once.sh"
    echo ""
    ralph_log_failed "$STORY_ID"
    exit 1
fi

echo "✓ Story passed quality checks"

# Step 6: Commit changes
ralph_step 6 $TOTAL_STEPS "Committing changes..."
ralph_commit_changes "$STORY_ID" "$STORY_TITLE" "$STORY_DESC" "$STORY_CRITERIA" "$STORY_NOTES" "" "$BRANCH_NAME"

# Step 7: Push and create PR
ralph_step 7 $TOTAL_STEPS "Pushing and creating PR..."
PR_BODY=$(ralph_build_pr_body "$STORY_DESC" "$NEXT_STORY" "$STORY_FILES" "$STORY_NOTES" "$STORY_ID")
ralph_create_pr "$BRANCH_NAME" "$STORY_ID" "$STORY_TITLE" "$PR_BODY"
echo ""

# Step 8 (optional): Auto-merge
if [ "$AUTO_MERGE" = true ] && [ -n "$PR_NUMBER" ]; then
    ralph_step 8 $TOTAL_STEPS "Auto-merging PR..."
    ralph_auto_merge "$PR_NUMBER" "$BRANCH_NAME" "$MERGE_TIMEOUT" || {
        echo ""
        echo "PR will merge when CI passes: $PR_URL"
    }
    echo ""
fi

# Summary
ralph_banner "✓ Story Complete"
echo ""
echo "Branch: $BRANCH_NAME"
echo "PR:     $PR_URL"
echo ""

# Show commit
echo "Commit:"
git log -1 --pretty=format:"  %h %s"
echo ""
echo ""

# Progress
DONE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
TOTAL=$(ralph_get_total_count)
echo "Progress: $DONE / $TOTAL complete"
echo ""

if [ "$DONE" -lt "$TOTAL" ]; then
    NEXT_REMAINING=$(jq -r '[.userStories[] | select(.passes == false)] | sort_by(.priority) | .[0] | "\(.id): \(.title)"' "$PRD_FILE")
    echo "Next story: $NEXT_REMAINING"
    echo ""
fi

ralph_banner "Next Steps"
echo ""

if [ "$AUTO_MERGE" = true ]; then
    echo "Continue with next story:"
    echo "  ./scripts/ralph/ralph-once.sh --merge"
else
    echo "Review the PR:"
    echo "  $PR_URL"
    echo ""
    echo "Merge when ready:"
    echo "  gh pr merge --squash --delete-branch"
    echo ""
    echo "Or merge all open PRs:"
    echo "  /github-merge-stack"
    echo ""
    echo "Continue with next story (after merging):"
    echo "  ./scripts/ralph/ralph-once.sh"
fi
echo ""
