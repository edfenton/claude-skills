# Product Requirements Document

## Project Overview

**Project Name:** [Project name]

**Description:** [Brief description of what the application does]

**Target Users:** [Who will use this application]

---

## User Stories

### Story 1: [Title]

**ID:** `feature-001`

**Priority:** 1

**Description:**
[Detailed description of what needs to be implemented]

**Acceptance Criteria:**
- [ ] [Testable criterion 1]
- [ ] [Testable criterion 2]
- [ ] [Testable criterion 3]

**Test Criteria:**
- [ ] [Specific test assertion 1]
- [ ] [Specific test assertion 2]

**Files to Create:**
- `packages/shared/schemas/[name].ts`
- `apps/web/src/app/api/[name]/route.ts`
- `apps/web/src/components/[name]/[Component].tsx`

**Test Files:**
- `packages/shared/schemas/[name].test.ts`
- `apps/web/src/app/api/[name]/__tests__/route.test.ts`
- `apps/web/src/components/[name]/__tests__/[Component].test.tsx`

**Notes:**
[Implementation hints, dependencies, or constraints]

---

### Story 2: [Title]

**ID:** `feature-002`

**Priority:** 2

**Description:**
[Detailed description]

**Acceptance Criteria:**
- [ ] [Criterion 1]
- [ ] [Criterion 2]

**Test Criteria:**
- [ ] [Test assertion 1]
- [ ] [Test assertion 2]

**Files to Create:**
- [File paths]

**Test Files:**
- [Test file paths]

**Notes:**
[Notes]

---

## Story Sizing Guidelines

Each story should complete in ONE context window. Right-sized stories:
- Add a single API endpoint
- Create one UI component
- Add tests for one module
- Configure one tool
- Fix one bug

Stories that are too big should be split:
| Too Big | Split Into |
|---------|------------|
| "Build authentication" | Login form, Registration, Session management, Protected routes |
| "Create user CRUD" | User schema, User model + API, User list UI, User form UI |

## Priority Order (MERN)

1. Zod schemas in `packages/shared`
2. Mongoose models in `apps/web/src/server/db/models`
3. API route handlers in `apps/web/src/app/api`
4. React components in `apps/web/src/components`
5. Integration tests

---

## Converting to prd.json

Run `/ralph` with this PRD file to convert it to `scripts/ralph/prd.json` and set up the Ralph loop for autonomous development.
