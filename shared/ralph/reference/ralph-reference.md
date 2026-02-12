# Ralph Reference

Complete documentation for Ralph loop setup and execution.

---

## Overview

Ralph is an autonomous AI development loop that uses **Test-Driven Development (TDD)**:

1. Syncs with main (pulls latest code)
2. Creates a feature branch from main
3. Optionally runs a scaffold skill (e.g., `/mern-add-feature`)
4. **RED: Writes failing tests first** (from testCriteria/acceptanceCriteria)
5. **GREEN: Implements minimum code to pass tests**
6. **REFACTOR: Cleans up while keeping tests green**
7. Runs quality checks
8. Commits with detailed message (including TDD evidence)
9. Pushes and creates a PR targeting main
10. Repeats until all complete

Each iteration uses a **fresh context window**. Memory persists via:
- Git history (commits with full context)
- `progress.txt` (learnings, timestamps, **TDD evidence**)
- `prd.json` (task status)

### TDD in Ralph

Every story follows red-green-refactor:

| Phase | Action | Verification |
|-------|--------|--------------|
| Red | Write tests that fail | Project test command shows failures |
| Green | Write minimum code | Project test command passes |
| Refactor | Clean up code | Project test command still passes |

**Stories cannot be marked `passes: true` without TDD evidence in progress.txt.**

---

## Branch Strategy

### All PRs Target Main Directly

Every story creates a feature branch from `main` and a PR back to `main`:

```
main ─────┬─────────────────────────────────
          │
          ├── feat/story-001 ──→ PR #1 → main
          │
          ├── feat/story-002 ──→ PR #2 → main
          │
          └── feat/story-003 ──→ PR #3 → main
```

### Benefits

| Benefit | Description |
|---------|-------------|
| No cascading conflicts | Merging one PR doesn't break others |
| Independent PRs | Each PR can be reviewed/merged separately |
| Simple merges | No rebasing or base updates needed |
| Clear history | Each feature is a single squash commit |

### Workflow

1. **ralph-once.sh** (or **ralph.sh**):
   - Pulls latest `main`
   - Creates `feat/<story-id>` branch
   - Implements story
   - Commits, pushes, creates PR

2. **github-merge-stack**:
   - Finds all open PRs targeting main
   - Merges them in order (oldest first)
   - Squash merge + delete branch

### What About Sequential Dependencies?

Stories often build on each other (story-002 needs story-001's code). The workflow handles this:

1. Run ralph-once → story-001 gets PR created
2. Merge PR #1 (via github-merge-stack or manually)
3. Run ralph-once → pulls latest main (now has story-001 code)
4. story-002 implementation has access to story-001's code

For fully autonomous operation, merge PRs as they're created.

---

## Scaffold Skills

### Purpose

Scaffold skills create boilerplate structure before implementation. This ensures:
- Consistent file organization
- Standard naming conventions
- Proper imports and exports
- Test file structure

### Available Skills

| Skill | Creates | Use For |
|-------|---------|---------|
| `mern-add-feature` | Zod schema, Mongoose model, API routes, UI components, tests | New CRUD features |
| `mern-add-auth` | Auth routes, middleware, session handling | Authentication |
| `nean-add-feature` | DTOs, entity, service, controller, Angular components | NEAN CRUD features |
| `nean-add-auth` | Passport strategies, guards, auth module | NEAN authentication |
| `ios-add-feature` | View, ViewModel, tests | iOS features |
| `ios-add-auth` | Auth service, keychain, biometrics | iOS authentication |

### prd.json with Scaffold Skill

```json
{
  "id": "invoice-001",
  "title": "Create Invoice management",
  "scaffoldSkill": "mern-add-feature",
  "description": "Implement invoice CRUD with PDF generation",
  "acceptanceCriteria": [
    "InvoiceSchema with line items",
    "API routes with validation",
    "Invoice list with filtering",
    "Invoice form with calculations",
    "PDF export endpoint"
  ],
  "filesToCreate": [
    "packages/shared/schemas/invoice.ts",
    "apps/web/app/api/invoice/route.ts",
    "apps/web/app/api/invoice/[id]/route.ts",
    "apps/web/app/api/invoice/[id]/pdf/route.ts",
    "apps/web/src/server/db/models/invoice.ts",
    "apps/web/src/components/invoice/InvoiceList.tsx",
    "apps/web/src/components/invoice/InvoiceForm.tsx"
  ],
  "notes": "PDF generation uses @react-pdf/renderer",
  "passes": false
}
```

### When NOT to Use Scaffold Skills

| Story Type | Scaffold Skill | Reason |
|------------|----------------|--------|
| Bug fix | None | Modifying existing code |
| Refactoring | None | Restructuring existing code |
| Configuration | None | No new features |
| Adding to existing feature | None | Files already exist |
| Documentation | None | No code structure needed |

---

## Detailed Commit Messages

### Format

```
feat(<story-id>): <title>

<description>

Acceptance Criteria:
- <criterion 1>
- <criterion 2>

Files changed (N):
- <file 1>
- <file 2>

Notes: <notes if any>

Story-ID: <story-id>
```

### Example

```
feat(invoice-001): create invoice management

Implement invoice CRUD with PDF generation capability

Acceptance Criteria:
- InvoiceSchema with line items
- API routes with validation
- Invoice list with filtering
- Invoice form with calculations
- PDF export endpoint

Files changed (12):
- packages/shared/schemas/invoice.ts
- apps/web/app/api/invoice/route.ts
- apps/web/app/api/invoice/[id]/route.ts
- apps/web/app/api/invoice/[id]/pdf/route.ts
- apps/web/src/server/db/models/invoice.ts
- apps/web/src/components/invoice/InvoiceList.tsx
- apps/web/src/components/invoice/InvoiceForm.tsx
- apps/web/src/components/invoice/InvoiceCard.tsx
- apps/web/src/components/invoice/__tests__/InvoiceForm.test.tsx
... and 3 more

Notes: PDF generation uses @react-pdf/renderer

Story-ID: invoice-001
```

---

## PR Bodies

PRs are created automatically with detailed bodies:

```markdown
## Summary

Implement invoice CRUD with PDF generation capability

## Acceptance Criteria
- [x] InvoiceSchema with line items
- [x] API routes with validation
- [x] Invoice list with filtering
- [x] Invoice form with calculations
- [x] PDF export endpoint

## Files
- packages/shared/schemas/invoice.ts
- apps/web/app/api/invoice/route.ts
- apps/web/app/api/invoice/[id]/route.ts
- apps/web/app/api/invoice/[id]/pdf/route.ts

## Notes
PDF generation uses @react-pdf/renderer

---
**Story ID:** `invoice-001`

🤖 Generated by Ralph
```

---

## prd.json Schema

```json
{
  "projectName": "my-app",
  "description": "Application description",
  "userStories": [
    {
      "id": "string (kebab-case: feature-NNN)",
      "title": "string (short, imperative)",
      "priority": "number (1 = highest)",
      "description": "string (what to implement)",
      "acceptanceCriteria": ["string (testable criteria)"],
      "testCriteria": ["string (specific test assertions to write)"],
      "testFiles": ["string (test file paths to create)"],
      "filesToCreate": ["string (expected file paths)"],
      "scaffoldSkill": "string (optional: skill name without slash)",
      "notes": "string (optional: implementation hints)",
      "passes": false
    }
  ]
}
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique ID in kebab-case (e.g., `auth-001`) |
| `title` | Yes | Short imperative title |
| `priority` | Yes | Execution order (1 = first) |
| `description` | Yes | What to implement |
| `acceptanceCriteria` | Yes | Testable success criteria |
| `testCriteria` | Yes | Specific test assertions to write (derived from acceptanceCriteria) |
| `testFiles` | Yes | Test file paths to create BEFORE implementation |
| `filesToCreate` | No | Expected file paths (documentation) |
| `scaffoldSkill` | No | Skill to run before implementation |
| `notes` | No | Hints for implementation |
| `passes` | Yes | Set to `true` when complete |

---

## Story Sizing

### The Rule

Each story must complete in ONE context window (~100-200K tokens of output).

### Right-Sized Stories

- Add a single API endpoint
- Create one UI component
- Add tests for one module
- Configure one tool
- Fix one bug

### Stories That Are Too Big

| Too Big | Split Into |
|---------|------------|
| "Build authentication" | Login form, Registration, Session management, Protected routes |
| "Create user CRUD" | User schema, User model + API, User list UI, User form UI |
| "Add dashboard" | Dashboard layout, Stats cards, Charts, Filters |
| "Implement search" | Search API, Search UI, Filters, Pagination |

### MERN-Specific Splits

| Too Big | Split Into |
|---------|------------|
| "Create users feature" | Schema (shared), Model + API routes, List component, Form component |
| "Add file uploads" | Upload API route, Storage service, Upload UI, File list UI |

### NEAN-Specific Splits

| Too Big | Split Into |
|---------|------------|
| "Create users module" | DTOs (shared), Entity + migration, Service, Controller |
| "Add Angular feature" | Routes + shell, List component, Form component, Detail component |
| "Implement RBAC" | CASL abilities, Guards + decorators, Permission UI |

### iOS-Specific Splits

| Too Big | Split Into |
|---------|------------|
| "Create settings screen" | SettingsView, ProfileSection, PreferencesSection, SettingsViewModel |
| "Add offline sync" | SyncService protocol, SyncEngine, ConflictResolver, SyncUI |

---

## Priority Rules

### Order of Implementation

1. **Shared code** (schemas, types, utilities)
2. **Infrastructure** (config, services, middleware)
3. **Data layer** (models, entities, migrations)
4. **API layer** (routes, controllers)
5. **UI layer** (components, views)
6. **Polish** (tests, documentation, optimization)

### MERN Priority Order

1. Zod schemas in `packages/shared`
2. Mongoose models
3. API route handlers
4. React components
5. Integration tests

### NEAN Priority Order

1. DTOs in `libs/shared/types`
2. Entities + migrations
3. NestJS services
4. NestJS controllers
5. Angular data-access
6. Angular components

### iOS Priority Order

1. Models (SwiftData)
2. Services (protocols first)
3. ViewModels
4. Views
5. Tests

---

## Commands

### Single Iteration (Recommended)

```bash
# Run one story
./scripts/ralph/ralph-once.sh

# Creates branch, implements, commits, pushes, creates PR
# Then returns control to you
```

### Full Loop

```bash
# Run up to 10 stories
./scripts/ralph/ralph.sh

# Custom max iterations
./scripts/ralph/ralph.sh 50
```

### Merge All PRs

```bash
# Via skill
/github-merge-stack

# Or directly
./scripts/github-merge-stack.sh

# Dry run (show plan)
./scripts/github-merge-stack.sh --dry-run

# Wait for CI before each merge
./scripts/github-merge-stack.sh --wait
```

### Status

```bash
# Story status
cat scripts/ralph/prd.json | jq '.userStories[] | {id, title, passes}'

# Progress log
cat scripts/ralph/progress.txt

# Open PRs
gh pr list
```

---

## Troubleshooting

### Story keeps failing

1. **Too big** — Split into smaller stories
2. **Missing context** — Add notes to description
3. **Missing dependency** — Merge previous PRs first, then re-run
4. **Quality check failing** — Run quality commands manually

### Branch already exists

```bash
# Delete local branch and retry
git branch -D feat/story-001
./scripts/ralph/ralph-once.sh
```

### PR already exists

The story may have been partially completed. Check:
```bash
gh pr list --head feat/story-001
gh pr view <number>
```

### Scaffold skill fails

Check the skill exists and works:
```bash
# In Claude Code
/mern-add-feature test-feature
```

The loop continues without scaffolding if it fails.

### Merge conflicts

If main changed and a PR has conflicts:
```bash
# Checkout the PR branch
gh pr checkout <number>

# Rebase onto main
git rebase main

# Resolve conflicts, then
git push --force-with-lease
```

### Need previous story's code

If story-002 needs story-001's code but PR #1 isn't merged yet:

1. Merge PR #1 first: `gh pr merge 1 --squash --delete-branch`
2. Then run ralph-once for story-002

---

## Example prd.json

> **Note:** This example uses MERN conventions. For NEAN projects, adjust file paths (e.g., `libs/shared/types/`, `*.spec.ts`). For iOS projects, use Swift paths (e.g., `Models/`, `*Tests.swift`).

```json
{
  "projectName": "task-manager",
  "description": "Task management application with teams and projects",
  "userStories": [
    {
      "id": "setup-001",
      "title": "Configure MongoDB connection",
      "priority": 1,
      "description": "Set up MongoDB connection with environment-based configuration",
      "acceptanceCriteria": [
        "MONGODB_URI in .env.example",
        "Connection utility in src/server/db",
        "Health check endpoint verifies connection"
      ],
      "testCriteria": [
        "Health check returns 200 when DB connected",
        "Health check returns 503 when DB disconnected"
      ],
      "testFiles": [
        "apps/web/src/server/db/__tests__/connection.test.ts"
      ],
      "passes": false
    },
    {
      "id": "task-001",
      "title": "Create Task schema and types",
      "priority": 2,
      "description": "Define Task data structure with validation",
      "acceptanceCriteria": [
        "TaskSchema in packages/shared/schemas",
        "CreateTaskInput and UpdateTaskInput types",
        "TaskStatus enum (todo, in-progress, done)",
        "Due date validation"
      ],
      "testCriteria": [
        "TaskSchema validates required fields",
        "TaskSchema rejects invalid status values",
        "Due date must be in the future",
        "CreateTaskInput requires title and status"
      ],
      "testFiles": [
        "packages/shared/schemas/__tests__/task.test.ts"
      ],
      "filesToCreate": [
        "packages/shared/schemas/task.ts"
      ],
      "passes": false
    },
    {
      "id": "task-002",
      "title": "Create Task model and API",
      "priority": 3,
      "scaffoldSkill": "mern-add-feature",
      "description": "Implement Task CRUD with Mongoose model and API routes",
      "acceptanceCriteria": [
        "Task Mongoose model with indexes",
        "GET /api/tasks with pagination and filtering",
        "POST /api/tasks with validation",
        "PATCH /api/tasks/[id]",
        "DELETE /api/tasks/[id]"
      ],
      "testCriteria": [
        "GET /api/tasks returns paginated list",
        "POST /api/tasks creates task with valid input",
        "POST /api/tasks returns 400 for invalid input",
        "PATCH /api/tasks/[id] updates existing task",
        "DELETE /api/tasks/[id] removes task"
      ],
      "testFiles": [
        "apps/web/app/api/tasks/__tests__/route.test.ts",
        "apps/web/app/api/tasks/[id]/__tests__/route.test.ts"
      ],
      "filesToCreate": [
        "apps/web/src/server/db/models/task.ts",
        "apps/web/app/api/tasks/route.ts",
        "apps/web/app/api/tasks/[id]/route.ts"
      ],
      "passes": false
    },
    {
      "id": "task-003",
      "title": "Create Task list UI",
      "priority": 4,
      "description": "Implement task list with filtering and status updates",
      "acceptanceCriteria": [
        "TaskList component with loading state",
        "Filter by status",
        "Quick status toggle",
        "Empty state message"
      ],
      "testCriteria": [
        "TaskList shows loading spinner while fetching",
        "TaskList renders task cards from API response",
        "Filter dropdown changes displayed tasks",
        "Status toggle updates task via API",
        "Empty state shows when no tasks exist"
      ],
      "testFiles": [
        "apps/web/src/components/task/__tests__/TaskList.test.tsx",
        "apps/web/e2e/tasks.spec.ts"
      ],
      "filesToCreate": [
        "apps/web/src/components/task/TaskList.tsx",
        "apps/web/src/components/task/TaskCard.tsx"
      ],
      "passes": false
    },
    {
      "id": "task-004",
      "title": "Create Task form UI",
      "priority": 5,
      "description": "Implement task creation and editing form",
      "acceptanceCriteria": [
        "TaskForm component with validation",
        "Date picker for due date",
        "Status selector",
        "Form tests"
      ],
      "testCriteria": [
        "TaskForm validates required fields",
        "Date picker sets due date",
        "Status selector shows all TaskStatus values",
        "Submit creates task via POST /api/tasks"
      ],
      "testFiles": [
        "apps/web/src/components/task/__tests__/TaskForm.test.tsx"
      ],
      "filesToCreate": [
        "apps/web/src/components/task/TaskForm.tsx"
      ],
      "passes": false
    }
  ]
}
```

---

## References

- [Geoffrey Huntley's Ralph](https://ghuntley.com/ralph/)
- [snarktank/ralph](https://github.com/snarktank/ralph)
