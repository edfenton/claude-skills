# Claude Skills

A collection of Claude Code skills for full-stack development across iOS, MERN, NEAN, and shared workflows.

These skills automate scaffolding, code review, security audits, testing, deployment, and more. Each skill is a self-contained folder with a `SKILL.md` file that Claude Code discovers automatically.

## Skill Categories

### iOS (15 skills)

| Skill | Description |
|-------|-------------|
| `/ios-kit` | Startup runbook — establishes stack, scaffolds project, configures GitHub security |
| `/ios-scaffold` | Scaffold a SwiftUI app (iPhone + iPad) with offline-first persistence, push notifications, linting, CI |
| `/ios-add-feature` | Scaffold a new feature with View, ViewModel, and tests |
| `/ios-add-auth` | Add authentication with Sign in with Apple, biometrics, and Keychain storage |
| `/ios-code-review` | Review iOS code for compliance with standards, NFRs, and security policy |
| `/ios-design-review` | Visual design review against ios-styleguide |
| `/ios-unit-test` | Run unit/UI tests, report results, and optionally fix failures |
| `/ios-deps` | Manage Swift Package Manager dependencies with security checks |
| `/ios-release` | App Store release checklist — archive, validation, and submission |
| `/ios-teardown` | Tear down an iOS project — remove local files, git hooks, optionally delete GitHub repo |
| `/ios-stack` | Stack decisions for iOS apps (SwiftUI, offline-first, push notifications) |
| `/ios-std` | Coding standards for iOS apps (SwiftUI, MVVM, offline-first) |
| `/ios-styleguide` | Design and UI style guide — premium consumer aesthetic |
| `/ios-nfr` | Non-functional requirements checklist |
| `/ios-sec` | Security policy — OWASP Top 10, Mobile Top 10, CWE Top 25 |

### MERN (17 skills)

| Skill | Description |
|-------|-------------|
| `/mern-kit` | Startup runbook — establishes stack, scaffolds project, configures GitHub security |
| `/mern-scaffold` | Scaffold a pnpm + Turborepo monorepo with Next.js, tooling, tests, CI |
| `/mern-add-feature` | Scaffold a new feature with API route, Zod schema, Mongoose model, and UI components |
| `/mern-add-auth` | Add authentication using NextAuth.js with OAuth and/or credentials |
| `/mern-code-review` | Review MERN code for compliance with standards, NFRs, and security policy |
| `/mern-design-review` | Visual design review using Playwright screenshots against mern-styleguide |
| `/mern-unit-test` | Run unit tests, report results, and optionally fix failures |
| `/mern-e2e` | Manage Playwright E2E tests for critical user journeys |
| `/mern-deps` | Check and update dependencies with security audits and test verification |
| `/mern-api-docs` | Generate OpenAPI documentation from Zod schemas and API routes |
| `/mern-deploy` | Deployment checklist and setup for Vercel, AWS, or Docker |
| `/mern-teardown` | Tear down a MERN project — delete local files, optionally delete GitHub repo |
| `/mern-stack` | Stack decisions for MERN apps (Next.js, pnpm monorepo) |
| `/mern-std` | Coding standards for MERN Next.js apps in a pnpm monorepo |
| `/mern-styleguide` | Design and UI style guide — premium consumer aesthetic |
| `/mern-nfr` | Non-functional requirements checklist |
| `/mern-sec` | Security policy — OWASP Top 10, CWE Top 25 |

### NEAN (17 skills)

| Skill | Description |
|-------|-------------|
| `/nean-kit` | Startup runbook — establishes stack, scaffolds project, configures GitHub security |
| `/nean-scaffold` | Scaffold an Nx monorepo with NestJS API, Angular frontend, and shared libraries |
| `/nean-add-feature` | Scaffold a new feature with NestJS module, TypeORM entity, DTOs, and Angular components |
| `/nean-add-auth` | Add authentication using Passport.js with JWT and optional OAuth |
| `/nean-code-review` | Review NEAN code for compliance with standards, NFRs, and security policy |
| `/nean-design-review` | Visual design review using Playwright screenshots against nean-styleguide |
| `/nean-unit-test` | Run unit tests, report results, and optionally fix failures |
| `/nean-e2e` | Manage Playwright E2E tests for critical user journeys |
| `/nean-deps` | Check and update dependencies with security audits and test verification |
| `/nean-api-docs` | Generate and serve OpenAPI documentation from NestJS decorators |
| `/nean-deploy` | Deployment checklist and setup for Docker, AWS, or Kubernetes |
| `/nean-teardown` | Tear down a NEAN project — drop database, delete local files, optionally delete GitHub repo |
| `/nean-stack` | Stack decisions for NEAN apps (NestJS, Angular, Nx monorepo) |
| `/nean-std` | Coding standards for NEAN apps in an Nx monorepo |
| `/nean-styleguide` | Design and UI style guide — premium consumer aesthetic |
| `/nean-nfr` | Non-functional requirements checklist |
| `/nean-sec` | Security policy — OWASP Top 10, CWE Top 25 |

### Shared (19 skills)

| Skill | Description |
|-------|-------------|
| `/ralph` | Convert a PRD to prd.json and set up autonomous development with feature branches |
| `/ralph-add` | Add new stories to an existing prd.json without resetting completed statuses |
| `/github-visibility` | Toggle repo between private and public with security hardening |
| `/github-secure` | Configure GitHub repo security — branch protection, Dependabot, security scanning, CI |
| `/github-hooks` | Set up local Git hooks for pre-commit validation (lint, format, tests, secrets) |
| `/github-merge-stack` | Merge stacked feature branches into main, preserving full feature history |
| `/retro-create` | Post-invocation retrospective — tracks skill issues and applies fixes |
| `/retro-resolve` | Scan retro.md files across all skills, resolve open issues, update entries |
| `/shared-adr` | Create and manage Architecture Decision Records |
| `/shared-brand` | Brand identity, design tokens, and anti-pattern philosophy |
| `/shared-changelog` | Generate CHANGELOG.md from conventional commits with semantic versioning |
| `/shared-deps-safety` | Universal safety rules and update priority for dependency management |
| `/shared-env` | Environment variable management with validation and .env.example generation |
| `/shared-nfr` | Standard NFR concerns and output format shared across platforms |
| `/shared-readme` | Generate comprehensive README.md with project overview and setup instructions |
| `/shared-review-workflow` | Severity definitions, approval gate protocol, and fix constraints for reviews |
| `/shared-sec-baseline` | Security output format and core refusal policy shared across platforms |
| `/shared-tdd` | TDD policy — red-green-refactor workflow and evidence requirements |
| `/python-scaffold` | Scaffold a Python/FastAPI project with VS Code workspace config |

## Installation

Clone the repo, then symlink or copy skills into `~/.claude/skills/` (personal/global) or `.claude/skills/` (project-specific). Symlinks are recommended — they stay in sync when you `git pull` updates.

### Install all skills (symlinks)

```bash
git clone https://github.com/edfenton/claude-skills.git
for dir in claude-skills/{ios,mern,nean,shared}/*/; do
  ln -sf "$(cd "$dir" && pwd)" ~/.claude/skills/"$(basename "$dir")"
done
```

### Install a single skill

```bash
ln -sf "$(cd claude-skills/mern/mern-scaffold && pwd)" ~/.claude/skills/mern-scaffold
```

### Install a category

```bash
for dir in claude-skills/mern/*/; do
  ln -sf "$(cd "$dir" && pwd)" ~/.claude/skills/"$(basename "$dir")"
done
```

### Copy instead of symlink

If you prefer copies over symlinks (won't auto-update):

```bash
cp -r claude-skills/mern/mern-scaffold ~/.claude/skills/mern-scaffold
```

### Project-specific installation

Symlink or copy skills to `.claude/skills/` in your project root instead of `~/.claude/skills/` for project-scoped usage.

Skills are auto-discovered by Claude Code — no registration step needed.

## Usage

Invoke any skill with its slash command:

```
/mern-scaffold my-app --github
/ios-kit
/ralph prd.md
/nean-add-feature users
```

Reference skills (stack, std, styleguide, sec, nfr) are loaded automatically during development workflows — you don't invoke them directly.

## Skill Structure

Each skill is a folder containing a `SKILL.md` file with YAML frontmatter:

```yaml
---
name: skill-name
description: What the skill does
category: ios | mern | nean | shared
---
```

The frontmatter is followed by the skill's prompt — instructions that Claude Code follows when the skill is invoked. Skills may include additional supporting files (templates, configs, checklists).

## License

MIT
