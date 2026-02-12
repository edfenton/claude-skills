# MERN E2E Reference

Playwright configuration, patterns, and journey templates.

---

## Playwright Configuration

```typescript
// apps/web/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  outputDir: './playwright-results',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { outputFolder: 'playwright-report' }],
    ['list'],
  ],

  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:3000',
    trace: 'on-first-retry',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
    {
      name: 'mobile-safari',
      use: { ...devices['iPhone 12'] },
    },
  ],

  // Use production server in CI (faster startup), dev server locally
  // Check /api/health endpoint which always exists in scaffolded projects
  webServer: {
    command: process.env.CI ? 'pnpm start' : 'pnpm dev',
    url: 'http://localhost:3000/api/health',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
});
```

---

## Auth Fixture

```typescript
// apps/web/e2e/fixtures/auth.ts
import { test as base, Page } from '@playwright/test';

// Test user credentials (use test database)
const TEST_USER = {
  email: 'test@example.com',
  password: 'TestPassword123!',
  name: 'Test User',
};

type AuthFixtures = {
  authenticatedPage: Page;
  testUser: typeof TEST_USER;
};

export const test = base.extend<AuthFixtures>({
  testUser: TEST_USER,

  authenticatedPage: async ({ page }, use) => {
    // Sign in before test
    await page.goto('/auth/signin');
    await page.getByLabel('Email').fill(TEST_USER.email);
    await page.getByLabel('Password').fill(TEST_USER.password);
    await page.getByRole('button', { name: 'Sign in' }).click();
    await page.waitForURL('/dashboard');

    await use(page);

    // Sign out after test
    await page.goto('/api/auth/signout');
  },
});

export { expect } from '@playwright/test';
```

---

## Database Fixture

```typescript
// apps/web/e2e/fixtures/db.ts
import { test as base } from '@playwright/test';

type DbFixtures = {
  resetDb: () => Promise<void>;
  seedDb: (data: Record<string, unknown[]>) => Promise<void>;
};

export const test = base.extend<DbFixtures>({
  resetDb: async ({ request }, use) => {
    const reset = async () => {
      // Call test-only API endpoint to reset database
      await request.post('/api/test/reset-db', {
        headers: { 'x-test-secret': process.env.TEST_SECRET! },
      });
    };

    await reset();
    await use(reset);
  },

  seedDb: async ({ request }, use) => {
    const seed = async (data: Record<string, unknown[]>) => {
      await request.post('/api/test/seed-db', {
        headers: { 'x-test-secret': process.env.TEST_SECRET! },
        data,
      });
    };

    await use(seed);
  },
});
```

---

## Page Object Model

```typescript
// apps/web/e2e/pages/HomePage.ts
import { Page, Locator } from '@playwright/test';

export class HomePage {
  readonly page: Page;
  readonly heading: Locator;
  readonly addButton: Locator;
  readonly itemList: Locator;
  readonly emptyState: Locator;

  constructor(page: Page) {
    this.page = page;
    this.heading = page.getByRole('heading', { name: 'Items' });
    this.addButton = page.getByRole('button', { name: 'Add Item' });
    this.itemList = page.getByTestId('item-list');
    this.emptyState = page.getByText('No items yet');
  }

  async goto() {
    await this.page.goto('/');
    await this.heading.waitFor();
  }

  async addItem(title: string, description?: string) {
    await this.addButton.click();
    await this.page.getByLabel('Title').fill(title);
    if (description) {
      await this.page.getByLabel('Description').fill(description);
    }
    await this.page.getByRole('button', { name: 'Save' }).click();
  }

  async getItemCount(): Promise<number> {
    return await this.itemList.getByTestId('item-card').count();
  }

  async deleteItem(title: string) {
    const item = this.itemList.getByTestId('item-card').filter({ hasText: title });
    await item.getByRole('button', { name: /delete/i }).click();
    await this.page.getByRole('button', { name: 'Confirm' }).click();
  }
}
```

---

## Journey Test Template

```typescript
// apps/web/e2e/journeys/auth.spec.ts
import { test, expect } from '../fixtures/auth';

test.describe('Authentication', () => {
  test.describe('Sign Up', () => {
    test('new user can create account', async ({ page }) => {
      const uniqueEmail = `test-${Date.now()}@example.com`;

      await page.goto('/auth/signup');
      await page.getByLabel('Name').fill('New User');
      await page.getByLabel('Email').fill(uniqueEmail);
      await page.getByLabel('Password').fill('SecurePassword123!');
      await page.getByLabel('Confirm Password').fill('SecurePassword123!');
      await page.getByRole('button', { name: 'Create Account' }).click();

      await expect(page).toHaveURL('/dashboard');
      await expect(page.getByText('Welcome, New User')).toBeVisible();
    });

    test('shows error for existing email', async ({ page }) => {
      await page.goto('/auth/signup');
      await page.getByLabel('Name').fill('Test');
      await page.getByLabel('Email').fill('existing@example.com');
      await page.getByLabel('Password').fill('Password123!');
      await page.getByLabel('Confirm Password').fill('Password123!');
      await page.getByRole('button', { name: 'Create Account' }).click();

      await expect(page.getByText('Email already registered')).toBeVisible();
    });
  });

  test.describe('Sign In', () => {
    test('existing user can sign in', async ({ page, testUser }) => {
      await page.goto('/auth/signin');
      await page.getByLabel('Email').fill(testUser.email);
      await page.getByLabel('Password').fill(testUser.password);
      await page.getByRole('button', { name: 'Sign in' }).click();

      await expect(page).toHaveURL('/dashboard');
    });

    test('shows error for wrong password', async ({ page, testUser }) => {
      await page.goto('/auth/signin');
      await page.getByLabel('Email').fill(testUser.email);
      await page.getByLabel('Password').fill('WrongPassword');
      await page.getByRole('button', { name: 'Sign in' }).click();

      await expect(page.getByText('Invalid credentials')).toBeVisible();
    });
  });

  test.describe('Sign Out', () => {
    test('user can sign out', async ({ authenticatedPage }) => {
      await authenticatedPage.goto('/dashboard');
      await authenticatedPage.getByRole('button', { name: 'Sign out' }).click();

      await expect(authenticatedPage).toHaveURL('/');
      await expect(authenticatedPage.getByRole('link', { name: 'Sign in' })).toBeVisible();
    });
  });
});
```

---

## CRUD Journey Template

```typescript
// apps/web/e2e/journeys/todo-crud.spec.ts
import { test, expect } from '../fixtures/auth';
import { HomePage } from '../pages/HomePage';

test.describe('Todo Item CRUD', () => {
  test.beforeEach(async ({ authenticatedPage }) => {
    // Reset to clean state
    await authenticatedPage.request.post('/api/test/reset-db');
  });

  test('user can create, view, edit, and delete an item', async ({ authenticatedPage }) => {
    const home = new HomePage(authenticatedPage);
    await home.goto();

    // Create
    await home.addItem('My first task', 'This is a test task');
    await expect(authenticatedPage.getByText('My first task')).toBeVisible();
    expect(await home.getItemCount()).toBe(1);

    // View
    await authenticatedPage.getByText('My first task').click();
    await expect(authenticatedPage.getByText('This is a test task')).toBeVisible();

    // Edit
    await authenticatedPage.getByRole('button', { name: 'Edit' }).click();
    await authenticatedPage.getByLabel('Title').fill('Updated task');
    await authenticatedPage.getByRole('button', { name: 'Save' }).click();
    await expect(authenticatedPage.getByText('Updated task')).toBeVisible();

    // Delete
    await authenticatedPage.goto('/');
    await home.deleteItem('Updated task');
    await expect(home.emptyState).toBeVisible();
  });

  test('handles concurrent edits gracefully', async ({ authenticatedPage, browser }) => {
    const home = new HomePage(authenticatedPage);
    await home.goto();
    await home.addItem('Shared task');

    // Open second browser context
    const context2 = await browser.newContext();
    const page2 = await context2.newPage();
    // ... simulate concurrent edit
  });
});
```

---

## Common Patterns

### Waiting for Network

```typescript
// Wait for API response
await Promise.all([
  page.waitForResponse(resp => resp.url().includes('/api/items') && resp.status() === 200),
  page.getByRole('button', { name: 'Save' }).click(),
]);
```

### Handling Modals

```typescript
// Wait for modal and interact
const modal = page.getByRole('dialog');
await expect(modal).toBeVisible();
await modal.getByRole('button', { name: 'Confirm' }).click();
await expect(modal).not.toBeVisible();
```

### Testing Responsive

```typescript
test('mobile navigation works', async ({ page }) => {
  await page.setViewportSize({ width: 375, height: 667 });
  await page.goto('/');

  // Mobile menu should be visible
  await page.getByRole('button', { name: 'Menu' }).click();
  await expect(page.getByRole('navigation')).toBeVisible();
});
```

### Handling Flaky Tests

```typescript
// Use explicit waits instead of arbitrary timeouts
// ❌ Bad
await page.waitForTimeout(1000);

// ✅ Good
await page.waitForSelector('[data-testid="loaded"]');
await expect(page.getByTestId('item')).toBeVisible({ timeout: 10000 });

// Use retry for flaky assertions
await expect(async () => {
  const count = await page.getByTestId('item').count();
  expect(count).toBeGreaterThan(0);
}).toPass({ timeout: 5000 });
```

---

## CI Configuration

```yaml
# .github/workflows/ci.yml (add to existing)
e2e:
  runs-on: ubuntu-latest
  needs: lint-test-build  # Run after main CI job
  steps:
    - uses: actions/checkout@v4

    # No version specified - reads from packageManager in package.json
    - name: Setup pnpm
      uses: pnpm/action-setup@v4

    - name: Setup Node
      uses: actions/setup-node@v4
      with:
        node-version: '22'
        cache: 'pnpm'

    - name: Install dependencies
      run: pnpm install --frozen-lockfile

    # Use --filter to run in the web workspace where playwright is installed
    - name: Install Playwright browsers
      run: pnpm --filter @*/web exec playwright install --with-deps chromium

    - name: Build
      run: pnpm build

    - name: Run E2E tests
      run: pnpm test:e2e
      env:
        CI: true

    - name: Upload report
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: playwright-report
        path: apps/web/playwright-report/
        retention-days: 7
```

---

## Test Data Attributes

Add to components for stable selectors:

```tsx
// Use data-testid for E2E targeting
<div data-testid="item-list">
  {items.map(item => (
    <div key={item.id} data-testid="item-card">
      {item.title}
    </div>
  ))}
</div>

<button data-testid="submit-button">Submit</button>
```
