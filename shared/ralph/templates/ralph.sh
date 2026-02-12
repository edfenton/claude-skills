#!/bin/bash

# Ralph Loop for Claude Code
# Usage: ./scripts/ralph/ralph.sh [max_iterations] [--no-merge] [--merge-timeout N]
#
# Workflow per story (TDD enforced):
#   1. Sync with main (pull latest)
#   2. Create feature branch from main
#   3. Run scaffold skill if specified
#   4. RED: Write failing tests first (from acceptance criteria)
#   5. GREEN: Implement minimum code to pass tests
#   6. REFACTOR: Clean up while tests stay green
#   7. Run quality checks (lint, test, build)
#   8. Commit changes (with TDD evidence in progress.txt)
#   9. Push and create PR to main
#   10. Auto-merge PR (uses GitHub auto-merge, waits for CI)
#   11. Repeat for next story
#
# TDD is mandatory - stories cannot pass without test files and TDD evidence.
# Each story gets the latest merged code before starting.
# Fully autonomous when repo is configured with /github-secure --ralph-mode.

# Source common functions
source "$(dirname "${BASH_SOURCE[0]}")/ralph-common.sh"

# Initialize
ralph_init

# Defaults for this script
MAX_ITERATIONS=10
AUTO_MERGE=true

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --no-merge)
            AUTO_MERGE=false
            shift
            ;;
        --merge-timeout)
            MERGE_TIMEOUT="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: ./ralph.sh [max_iterations] [options]"
            echo ""
            echo "Options:"
            echo "  --no-merge        Don't auto-merge PRs (just create them)"
            echo "  --merge-timeout N Max seconds to wait for merge (default: 600)"
            echo ""
            echo "Examples:"
            echo "  ./ralph.sh 10              # Run 10 stories, auto-merge each"
            echo "  ./ralph.sh 3 --no-merge    # Run 3 stories, create PRs only"
            echo ""
            echo "Prerequisites:"
            echo "  Run /github-secure --ralph-mode to configure repo for automation"
            exit 0
            ;;
        [0-9]*)
            MAX_ITERATIONS="$1"
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./ralph.sh [max_iterations] [--no-merge]"
            exit 1
            ;;
    esac
done

# Banner
ralph_banner "Ralph Loop - Max iterations: $MAX_ITERATIONS"
echo "  Auto-merge: $AUTO_MERGE"
[ "$AUTO_MERGE" = true ] && echo "  Merge timeout: ${MERGE_TIMEOUT}s"
echo ""

# Check prerequisites
ralph_check_prerequisites

cd "$PROJECT_ROOT"

# Check for uncommitted changes
ralph_check_clean_worktree

# Log start
echo "$(date '+%Y-%m-%d %H:%M:%S') - Ralph loop started (max $MAX_ITERATIONS, auto-merge: $AUTO_MERGE)" >> "$PROGRESS_FILE"

# Track results
COMPLETED_STORIES=()
FAILED_STORIES=()

# Main loop
for i in $(seq 1 $MAX_ITERATIONS); do
    ralph_banner "Iteration $i of $MAX_ITERATIONS"

    # Check remaining stories
    REMAINING=$(ralph_get_remaining_count)
    TOTAL=$(ralph_get_total_count)
    DONE=$((TOTAL - REMAINING))
    echo "Progress: $DONE / $TOTAL stories complete"

    if [ "$REMAINING" -eq 0 ]; then
        echo ""
        echo "✓ All stories complete!"
        echo "$(date '+%Y-%m-%d %H:%M:%S') - ALL COMPLETE ($TOTAL stories)" >> "$PROGRESS_FILE"
        break
    fi

    # Step 1: Sync with main
    ralph_step 1 8 "Syncing with $MAIN_BRANCH..."
    ralph_sync_main
    echo "✓ Synced"

    # Get next story
    ralph_get_next_story

    echo ""
    echo "→ Story: $STORY_ID - $STORY_TITLE"
    [ -n "$SCAFFOLD_SKILL" ] && echo "→ Scaffold skill: $SCAFFOLD_SKILL"

    # Step 2: Create feature branch (force cleanup of existing)
    ralph_step 2 8 "Creating branch $BRANCH_NAME..."
    ralph_create_branch "$BRANCH_NAME" "true"
    echo "✓ Created branch $BRANCH_NAME"

    # Step 3: Run scaffold skill if specified
    if [ -n "$SCAFFOLD_SKILL" ]; then
        ralph_step 3 8 "Running scaffold skill: $SCAFFOLD_SKILL..."
        ralph_run_scaffold "$SCAFFOLD_SKILL" "$STORY_ID"
    else
        ralph_step 3 8 "No scaffold skill specified, skipping..."
    fi

    # Step 4: Implement (TDD: red → green → refactor)
    ralph_step 4 8 "Implementing story (TDD)..."
    OUTPUT=$(ralph_run_implementation_captured "$STORY_ID" "$STORY_TITLE") || true

    # Step 5: Verify quality checks
    ralph_step 5 8 "Verifying quality checks..."

    STORY_PASSED=$(ralph_check_story_passed "$STORY_ID")

    if [ "$STORY_PASSED" != "true" ]; then
        echo "✗ Story did not pass quality checks"
        ralph_log_failed "$STORY_ID" "quality checks"
        FAILED_STORIES+=("$STORY_ID")

        # Clean up and continue
        git checkout "$MAIN_BRANCH"
        git branch -D "$BRANCH_NAME" 2>/dev/null || true
        echo "Cleaned up, continuing with next story..."
        continue
    fi

    # Step 6: Commit changes
    ralph_step 6 8 "Committing changes..."
    ralph_commit_changes "$STORY_ID" "$STORY_TITLE" "$STORY_DESC" "$STORY_CRITERIA" "$STORY_NOTES" "$i" "$BRANCH_NAME"

    # Step 7: Push and create PR
    ralph_step 7 8 "Pushing and creating PR..."
    PR_BODY=$(ralph_build_pr_body "$STORY_DESC" "$NEXT_STORY" "$STORY_FILES" "$STORY_NOTES" "$STORY_ID" "$i")
    ralph_create_pr "$BRANCH_NAME" "$STORY_ID" "$STORY_TITLE" "$PR_BODY" || {
        echo "Warning: PR creation failed"
        PR_NUMBER=""
    }

    # Step 8: Auto-merge if enabled
    if [ "$AUTO_MERGE" = true ] && [ -n "$PR_NUMBER" ]; then
        ralph_step 8 8 "Auto-merging PR..."

        if ralph_auto_merge "$PR_NUMBER" "$BRANCH_NAME" "$MERGE_TIMEOUT"; then
            COMPLETED_STORIES+=("$STORY_ID")
            echo ""
            echo "→ Story $STORY_ID complete and merged, continuing..."
        else
            echo ""
            echo "→ Story $STORY_ID: PR created but merge incomplete"
            echo "  PR will merge when CI passes: $PR_URL"
            FAILED_STORIES+=("$STORY_ID (merge pending)")

            # Return to main for next iteration
            git checkout "$MAIN_BRANCH" 2>/dev/null || true
            git pull origin "$MAIN_BRANCH" 2>/dev/null || true
        fi
    else
        ralph_step 8 8 "Skipping auto-merge (--no-merge or no PR)"
        COMPLETED_STORIES+=("$STORY_ID")

        # Return to main for next iteration
        git checkout "$MAIN_BRANCH" 2>/dev/null || true
    fi

    # Brief pause between iterations
    sleep 2
done

# Final summary
ralph_banner "Summary"

DONE=$(jq '[.userStories[] | select(.passes == true)] | length' "$PRD_FILE")
TOTAL=$(ralph_get_total_count)
echo "Completed: $DONE / $TOTAL"
echo ""

if [ ${#COMPLETED_STORIES[@]} -gt 0 ]; then
    echo "✓ Completed stories:"
    printf '  • %s\n' "${COMPLETED_STORIES[@]}"
    echo ""
fi

if [ ${#FAILED_STORIES[@]} -gt 0 ]; then
    echo "✗ Failed/pending stories:"
    printf '  • %s\n' "${FAILED_STORIES[@]}"
    echo ""
fi

if [ "$DONE" -lt "$TOTAL" ]; then
    echo "Remaining stories:"
    jq -r '.userStories[] | select(.passes == false) | "  ○ \(.id): \(.title)"' "$PRD_FILE"
    echo ""
fi

# Check for open PRs
OPEN_PRS=$(gh pr list --base "$MAIN_BRANCH" --state open --json number --jq 'length' 2>/dev/null || echo "0")
if [ "$OPEN_PRS" -gt 0 ]; then
    echo "Open PRs: $OPEN_PRS (will auto-merge when CI passes)"
    echo "  gh pr list"
    echo ""
fi

# Return to main
git checkout "$MAIN_BRANCH" 2>/dev/null || true

echo "Progress log: $PROGRESS_FILE"
echo ""
