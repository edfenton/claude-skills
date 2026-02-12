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
- `App/Sources/Features/[Name]/[Name]View.swift`
- `App/Sources/Features/[Name]/[Name]ViewModel.swift`
- `App/Sources/Models/[Model].swift`
- `App/Sources/Services/[Service]/[Service].swift`

**Test Files:**
- `Tests/UnitTests/[Name]ViewModelTests.swift`
- `Tests/UnitTests/[Service]Tests.swift`

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
- Add a single View + ViewModel
- Create one service
- Add tests for one module
- Configure one feature
- Fix one bug

Stories that are too big should be split:
| Too Big | Split Into |
|---------|------------|
| "Create settings screen" | SettingsView, ProfileSection, PreferencesSection, SettingsViewModel |
| "Add offline sync" | SyncService protocol, SyncEngine, ConflictResolver, SyncUI |

## Priority Order (iOS)

1. Models (SwiftData)
2. Services (protocols first)
3. ViewModels
4. Views
5. Tests

---

## Converting to prd.json

Run `/ralph` with this PRD file to convert it to `scripts/ralph/prd.json` and set up the Ralph loop for autonomous development.
