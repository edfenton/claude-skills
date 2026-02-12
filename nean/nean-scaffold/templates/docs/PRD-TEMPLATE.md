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
- `libs/shared/types/src/lib/[name].dto.ts`
- `apps/api/src/modules/[name]/[name].entity.ts`
- `apps/api/src/modules/[name]/[name].service.ts`
- `apps/api/src/modules/[name]/[name].controller.ts`
- `apps/web/src/app/[name]/[name].component.ts`

**Test Files:**
- `libs/shared/types/src/lib/[name].dto.spec.ts`
- `apps/api/src/modules/[name]/[name].service.spec.ts`
- `apps/api/src/modules/[name]/[name].controller.spec.ts`
- `apps/web/src/app/[name]/[name].component.spec.ts`

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
| "Create users module" | DTOs (shared), Entity + migration, Service, Controller |
| "Add Angular feature" | Routes + shell, List component, Form component, Detail component |

## Priority Order (NEAN)

1. DTOs in `libs/shared/types`
2. Entities + migrations
3. NestJS services
4. NestJS controllers
5. Angular data-access
6. Angular components

---

## Converting to prd.json

Run `/ralph` with this PRD file to convert it to `scripts/ralph/prd.json` and set up the Ralph loop for autonomous development.
