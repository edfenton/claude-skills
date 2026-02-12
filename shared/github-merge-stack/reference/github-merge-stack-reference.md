# GitHub Merge Stack Reference

Detailed documentation for merging PRs from Ralph.

---

## How It Works

Ralph creates feature branches that all target `main` directly:

```
main ─────┬─────────────────────────────────
          │
          ├── feat/story-001 ──→ PR #1 → main
          │
          ├── feat/story-002 ──→ PR #2 → main
          │
          └── feat/story-003 ──→ PR #3 → main
```

Each PR is independent:
- Contains only its own feature's changes
- Targets `main` directly
- Can be merged without affecting other PRs

---

## Why Merge in Order?

While PRs are independent, merging in order (oldest first) is recommended:

1. **Story dependencies:** Later stories may depend on earlier ones
2. **Cleaner history:** Commits appear in logical implementation order
3. **Easier debugging:** If something breaks, you know which story caused it

However, unlike stacked branches, merging out of order won't cause cascading conflicts.

---

## Using the Skill

### Basic Usage

```bash
/github-merge-stack
```

Or run the script directly:

```bash
./scripts/github-merge-stack.sh
```

### Options

```bash
# Show plan without executing
./scripts/github-merge-stack.sh --dry-run

# Wait for CI checks before each merge
./scripts/github-merge-stack.sh --wait
```

### What It Does

1. Finds all open PRs targeting `main`
2. Sorts by PR number (oldest first)
3. Merges each with squash merge
4. Deletes the feature branch
5. Syncs local repository

---

## Manual Merge Procedure

If the skill fails or you need manual control:

### Step 1: List PRs

```bash
gh pr list --base main --state open --json number,title,headRefName \
  --jq 'sort_by(.number) | .[] | "#\(.number) \(.title)"'
```

### Step 2: Merge Each PR (In Order)

```bash
# Merge PRs in order
gh pr merge 1 --squash --delete-branch
gh pr merge 2 --squash --delete-branch
gh pr merge 3 --squash --delete-branch
# Continue for all PRs...
```

### Step 3: Sync Local

```bash
git checkout main
git pull origin main
git fetch --prune
```

---

## Troubleshooting

### PR Has Merge Conflicts

**Cause:** Main has changed since the PR was created (parallel work merged).

**Solution:**
```bash
# Checkout the PR branch
gh pr checkout <number>

# Rebase onto current main
git rebase main

# Resolve conflicts in your editor
# Then continue
git rebase --continue

# Force push the rebased branch
git push --force-with-lease

# Now merge will succeed
gh pr merge <number> --squash --delete-branch
```

### CI Checks Failing

**Cause:** CI failed on the PR.

**Solution:**
1. Check CI logs: `gh pr checks <number>`
2. Fix issues on the branch
3. Push fixes: CI re-runs
4. Then merge

Or use the `--wait` flag to wait for CI:
```bash
./scripts/github-merge-stack.sh --wait
```

### gh CLI Not Authenticated

**Solution:**
```bash
gh auth login
# Follow prompts
```

### Branch Protection Preventing Merge

**Cause:** Repository has branch protection rules.

**Solution:**
- Wait for required checks to pass
- Get required review approvals
- Or use admin override (if you have permission):
  ```bash
  gh pr merge <number> --squash --delete-branch --admin
  ```

### Local Branch Won't Delete

**Cause:** Git thinks branch has unmerged changes.

**Solution:**
```bash
# Force delete
git branch -D feat/story-001

# Or delete all feature branches
git branch --list 'feat/*' | xargs git branch -D
```

---

## Commit Message Preservation

When using `--squash`, GitHub combines:
- PR title → Commit subject line
- PR body → Commit body

Ralph's detailed commit messages are preserved because the PR body contains:
- Story description
- Acceptance criteria
- Files created/modified
- Notes
- Story ID

---

## Viewing Merged History

### List All Features

```bash
git log --oneline
```

Output:
```
a1b2c3d feat(story-004): order management
e4f5g6h feat(story-003): product catalog
i7j8k9l feat(story-002): user authentication
m0n1o2p feat(story-001): initial setup
```

### See Full Feature Details

```bash
git show a1b2c3d
```

Shows complete commit message with all story context.

### Find Specific Story

```bash
git log --grep="story-003" --oneline
git log --grep="Product" --oneline
```

### See What Files a Feature Changed

```bash
git show a1b2c3d --stat
```

### See Full Diff of a Feature

```bash
git show a1b2c3d -p
```

### Find Which Story Introduced a Line

```bash
git blame path/to/file.ts
```

---

## Alternative Merge Strategies

### Regular Merge (Not Recommended)

```bash
gh pr merge <number> --merge --delete-branch
```

Creates merge commits. History becomes harder to read.

### Rebase Merge (Use Carefully)

```bash
gh pr merge <number> --rebase --delete-branch
```

Replays individual commits onto main. Preserves each small commit but loses the "one commit per feature" clarity.

---

## Integration with Ralph Workflow

### Typical Flow

```
1. /ralph docs/PRD.md
2. ./scripts/ralph/ralph-once.sh  (creates PR #1)
3. /github-merge-stack            (merges PR #1)
4. ./scripts/ralph/ralph-once.sh  (creates PR #2)
5. /github-merge-stack            (merges PR #2)
... repeat until all stories complete
```

### Batch Mode

Run multiple stories, then merge all at once:

```bash
# Run several stories
./scripts/ralph/ralph.sh 5

# Merge all created PRs
/github-merge-stack
```

### Partial Merge

Merge only specific PRs:

```bash
# Merge just PRs 1-3
gh pr merge 1 --squash --delete-branch
gh pr merge 2 --squash --delete-branch
gh pr merge 3 --squash --delete-branch

# PRs 4-5 remain open for later
```

---

## Handling Story Dependencies

If story-002 needs code from story-001:

1. Run `ralph-once.sh` → creates PR #1 for story-001
2. Merge PR #1: `gh pr merge 1 --squash --delete-branch`
3. Run `ralph-once.sh` → pulls main (now has story-001), creates PR #2 for story-002
4. Merge PR #2

The key is: **merge PRs before running the next story that depends on them.**

For fully autonomous operation, merge each PR immediately after it's created.
