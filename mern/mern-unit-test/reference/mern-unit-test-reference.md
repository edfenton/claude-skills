# MERN Unit Test Reference

Coverage setup and common failure patterns.

---

## Coverage setup (Vitest)

### Install

```bash
pnpm add -D @vitest/coverage-v8 -w
```

### Configure apps/web (vitest.config.ts)

```typescript
import { defineConfig } from "vitest/config";
import path from "path";

export default defineConfig({
  test: {
    globals: true,
    environment: "jsdom",
    exclude: ["**/node_modules/**", "**/e2e/**"],
    setupFiles: ["./src/__tests__/setup.tsx"],
    css: false,
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov", "html"],
      reportsDirectory: "./coverage",
      exclude: [
        "node_modules/**",
        "src/__tests__/**",
        "**/*.test.{ts,tsx}",
        "**/*.config.{ts,js}",
        ".next/**",
        "e2e/**",
      ],
    },
  },
  resolve: {
    alias: {
      "@": path.resolve(__dirname, "./src"),
    },
  },
});
```

### Configure packages/shared (vitest.config.ts)

```typescript
import { defineConfig } from "vitest/config";

export default defineConfig({
  test: {
    globals: true,
    environment: "node",
    coverage: {
      provider: "v8",
      reporter: ["text", "lcov", "html"],
      reportsDirectory: "./coverage",
      exclude: ["node_modules/**", "**/*.test.ts", "dist/**"],
    },
  },
});
```

### Run with coverage

```bash
# Via turbo (runs coverage for all packages)
pnpm test -- --coverage

# Scoped to a single package
pnpm -C apps/web test -- --coverage
```

### Coverage output

- `text` — Console summary table
- `lcov` — For CI integration (Codecov, Coveralls)
- `html` — Browse at `coverage/index.html`

---

## Coverage setup (Jest)

### Install

```bash
pnpm add -D jest @types/jest ts-jest
```

### Configure (jest.config.js)

```javascript
module.exports = {
  preset: "ts-jest",
  testEnvironment: "node",
  collectCoverageFrom: [
    "src/**/*.{ts,tsx}",
    "!src/**/*.d.ts",
    "!src/**/types/**",
    "!src/**/mocks/**",
  ],
  coverageThreshold: {
    global: {
      branches: 70,
      functions: 70,
      lines: 70,
      statements: 70,
    },
  },
};
```

---

## React component testing setup

The scaffold includes a test setup file at `src/__tests__/setup.tsx` with mocks for:

- **next/image** — Returns a plain `<img>` element
- **next/navigation** — Mocks `useRouter`, `usePathname`, `useSearchParams`
- **matchMedia** — For theme/responsive testing
- **localStorage** — For persistence testing
- **IntersectionObserver** — For lazy loading components
- **ResizeObserver** — For responsive components

### Component test example

```typescript
import { describe, it, expect } from "vitest";
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MyButton } from "../MyButton";

describe("MyButton", () => {
  it("renders with label", () => {
    render(<MyButton label="Click me" />);
    expect(screen.getByRole("button", { name: /click me/i })).toBeInTheDocument();
  });

  it("calls onClick when clicked", async () => {
    const user = userEvent.setup();
    const handleClick = vi.fn();
    render(<MyButton label="Click" onClick={handleClick} />);

    await user.click(screen.getByRole("button"));
    expect(handleClick).toHaveBeenCalledTimes(1);
  });
});
```

### Testing async components

```typescript
import { render, screen, waitFor } from "@testing-library/react";

it("loads and displays data", async () => {
  render(<AsyncComponent />);

  // Wait for loading to complete
  await waitFor(() => {
    expect(screen.queryByText(/loading/i)).not.toBeInTheDocument();
  });

  expect(screen.getByText(/data loaded/i)).toBeInTheDocument();
});
```

---

## Common failure patterns

### 1. Async test not awaited

**Symptom:** Test passes but warns about unhandled promise, or fails intermittently.

```typescript
// ❌ Bad
it("fetches data", () => {
  const result = fetchData();
  expect(result).toBeDefined();
});

// ✅ Good
it("fetches data", async () => {
  const result = await fetchData();
  expect(result).toBeDefined();
});
```

### 2. Mock not reset between tests

**Symptom:** Tests pass in isolation, fail when run together.

```typescript
// ✅ Reset mocks
beforeEach(() => {
  vi.clearAllMocks();
  // or jest.clearAllMocks();
});
```

### 3. Zod schema mismatch

**Symptom:** `ZodError: invalid_type` or similar.

```typescript
// Check schema matches test input
const schema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});

// ❌ Bad test input
const input = { email: "test", name: "" };

// ✅ Good test input
const input = { email: "test@example.com", name: "Test" };
```

### 4. Database/external dependency not mocked

**Symptom:** Test tries to connect to real database, times out or fails.

```typescript
// ✅ Mock the persistence layer
const mockStore: PersistenceStore = {
  fetchItems: vi.fn().mockResolvedValue([]),
  save: vi.fn().mockResolvedValue(undefined),
  delete: vi.fn().mockResolvedValue(undefined),
};

const sut = new MyService(mockStore);
```

### 5. Timing-dependent test

**Symptom:** Flaky — passes sometimes, fails others.

```typescript
// ❌ Bad: relies on real time
it("debounces calls", async () => {
  handler();
  handler();
  await new Promise((r) => setTimeout(r, 100));
  expect(mock).toHaveBeenCalledTimes(1);
});

// ✅ Good: use fake timers
it("debounces calls", async () => {
  vi.useFakeTimers();
  handler();
  handler();
  await vi.advanceTimersByTimeAsync(100);
  expect(mock).toHaveBeenCalledTimes(1);
  vi.useRealTimers();
});
```

### 6. Snapshot out of date

**Symptom:** Snapshot doesn't match.

```bash
# Update snapshots (only if change is intentional)
pnpm test -- -u
```

Review the diff before updating — don't blindly accept.

---

## Debugging tips

### Run single test file

```bash
pnpm test -- src/utils/sanitize.test.ts
```

### Run tests matching pattern

```bash
pnpm test -- -t "should validate email"
```

### Verbose output

```bash
pnpm test -- --reporter=verbose
```

### Debug mode (Node inspector)

```bash
node --inspect-brk node_modules/.bin/vitest run
```

---

## Report template

```
## Test Results

**Summary:** X passed, Y failed, Z skipped
**Coverage:** Lines 78% | Branches 72% | Functions 80%

### Failures

#### `src/utils/sanitize.test.ts`

**Test:** should strip $-prefixed keys
**Error:**
```

Expected: { name: 'test' }
Received: { name: 'test', $where: 'malicious' }

```
**Likely cause:** sanitizeInput not filtering keys correctly

#### `src/services/user.test.ts`

**Test:** should reject invalid email
**Error:**
```

ZodError: Expected string, received undefined
at path: email

```
**Likely cause:** Test input missing required field
```

---

## Quick reference

| Task              | Command                             |
| ----------------- | ----------------------------------- |
| Run all tests     | `pnpm test`                         |
| Run with coverage | `pnpm test -- --coverage`           |
| Run single file   | `pnpm test -- path/to/file.test.ts` |
| Run matching name | `pnpm test -- -t "pattern"`         |
| Update snapshots  | `pnpm test -- -u`                   |
| Watch mode        | `pnpm test:watch`                   |
