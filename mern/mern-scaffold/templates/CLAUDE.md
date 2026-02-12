# Repo context for Claude Code (MERN)

## Stack

- Monorepo: pnpm workspaces + Turborepo
- App: Next.js (app router) in `apps/web`
- Shared: `packages/shared` (Zod schemas + inferred types)
- Data: MongoDB + Mongoose
  - Connection: `apps/web/src/server/db/mongoose.ts`
  - Sanitization: `apps/web/src/server/db/sanitize.ts`

## Boundaries

| Layer            | Location                                        |
| ---------------- | ----------------------------------------------- |
| UI               | `apps/web/src/app/`, `apps/web/src/components/` |
| Server           | `apps/web/src/server/`                          |
| Shared contracts | `packages/shared/`                              |

Don't read `process.env` directly—use the env helper.

## Commands

```bash
pnpm install          # Install
pnpm dev              # Dev server
pnpm lint             # Lint check
pnpm lint:fix         # Lint fix
pnpm format           # Format check
pnpm format:write     # Format fix
pnpm test             # Unit tests
pnpm build            # Build
pnpm test:e2e         # E2E tests
```

## TDD (Test-Driven Development)

**All new features and bug fixes must follow TDD:**

1. **Red** — Write failing tests first
   - Derive test cases from acceptance criteria
   - Run `pnpm test` to confirm tests fail
   - Do NOT write implementation code yet

2. **Green** — Implement minimum code to pass
   - Write only enough code to make tests pass
   - Run `pnpm test` after each change

3. **Refactor** — Clean up while tests stay green
   - Improve code quality without changing behavior
   - Run `pnpm test` to confirm no regressions

### Test locations

| Source | Test |
|--------|------|
| `apps/web/src/components/Foo.tsx` | `apps/web/src/components/__tests__/Foo.test.tsx` |
| `apps/web/src/lib/bar.ts` | `apps/web/src/lib/__tests__/bar.test.ts` |
| `apps/web/src/app/api/foo/route.ts` | `apps/web/src/app/api/foo/__tests__/route.test.ts` |
| `packages/shared/src/schemas/baz.ts` | `packages/shared/src/schemas/baz.test.ts` |

**Important:** All app router files must be in `apps/web/src/app/`, never `apps/web/app/`.

### What to test

- **Components:** Rendering, user interactions, conditional display
- **Utilities:** Input/output, edge cases, error handling
- **Schemas:** Validation success and failure cases
- **API routes:** Request validation, response format, error responses

## Next.js Notes

Segment config exports (`revalidate`, `dynamic`, etc.) must be literal values:

```typescript
// CORRECT
export const revalidate = 3600;

// WRONG - fails in Next.js 16+
export const revalidate = IMPORTED_CONSTANT;
```

## Skills

**Always-on:** mern-sec, mern-nfr, mern-std, mern-styleguide, retro-create

**Manual invocation:**

- `/mern-kit` — project setup
- `/mern-stack` — stack decisions reference
- `/mern-scaffold` — scaffold new features
- `/mern-unit-test` — run tests and fix failures
- `/mern-code-review` — review against policies
- `/mern-design-review` — visual review with Playwright
