# Repo context for Claude Code (NEAN)

## Stack

- Monorepo: Nx
- Backend: NestJS in `apps/api`
- Frontend: Angular in `apps/web`
- UI Components: PrimeNG + Tailwind CSS
- Database: PostgreSQL + TypeORM
- Shared: `libs/shared/types` (DTOs, interfaces)

## Boundaries

| Layer            | Location                           |
| ---------------- | ---------------------------------- |
| API              | `apps/api/src/modules/`            |
| UI               | `apps/web/src/app/`                |
| Shared contracts | `libs/shared/types/`               |
| API utilities    | `libs/api/common/`                 |
| Database         | `libs/api/database/`               |

Don't read `process.env` directly—use ConfigService.

## Commands

```bash
npm install           # Install
npm run dev           # Dev servers (api + web)
npm run dev:api       # API only
npm run dev:web       # Web only
npm run lint          # Lint check
npm run lint:fix      # Lint fix
npm run format        # Format check
npm run format:fix    # Format fix
npm run test          # Unit tests
npm run build         # Build all
npm run e2e           # E2E tests
npm run db:migrate    # Run migrations
npm run db:generate   # Generate migration
```

## TDD (Test-Driven Development)

**All new features and bug fixes must follow TDD:**

1. **Red** — Write failing tests first
   - Derive test cases from acceptance criteria
   - Run `npm run test` to confirm tests fail
   - Do NOT write implementation code yet

2. **Green** — Implement minimum code to pass
   - Write only enough code to make tests pass
   - Run tests after each change

3. **Refactor** — Clean up while tests stay green
   - Improve code quality without changing behavior
   - Run tests to confirm no regressions

### Test locations

| Source | Test |
|--------|------|
| `apps/api/src/modules/foo/foo.service.ts` | `apps/api/src/modules/foo/foo.service.spec.ts` |
| `apps/api/src/modules/foo/foo.controller.ts` | `apps/api/src/modules/foo/foo.controller.spec.ts` |
| `apps/web/src/app/features/bar/bar.component.ts` | `apps/web/src/app/features/bar/bar.component.spec.ts` |
| `libs/shared/types/src/lib/baz.dto.ts` | `libs/shared/types/src/lib/baz.dto.spec.ts` |

### What to test

- **Services:** Business logic, error handling, external integrations
- **Controllers:** Request validation, response format, authorization
- **Components:** Rendering, user interactions, state changes
- **DTOs:** Validation decorators, transformation

## Skills

**Always-on:** nean-sec, nean-nfr, nean-std, nean-styleguide, retro-create

**Manual invocation:**

- `/nean-kit` — project setup
- `/nean-stack` — stack decisions reference
- `/nean-scaffold` — scaffold new features
- `/nean-add-feature` — add feature module
- `/nean-add-auth` — add authentication
- `/nean-unit-test` — run tests and fix failures
- `/nean-code-review` — review against policies
- `/nean-design-review` — visual review with Playwright
- `/nean-api-docs` — generate OpenAPI docs
- `/nean-e2e` — E2E test management
- `/nean-deploy` — deployment preparation
