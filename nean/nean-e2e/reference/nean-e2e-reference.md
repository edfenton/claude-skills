# NEAN E2E Reference

Playwright configuration and patterns for NEAN applications.

---

## Playwright Configuration

```typescript
// apps/web-e2e/playwright.config.ts
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './src',
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
    baseURL: process.env.PLAYWRIGHT_BASE_URL || 'http://localhost:4200',
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
  ],

  // Use production build in CI (faster), dev server locally
  webServer: [
    {
      command: process.env.CI ? 'npm run start:api' : 'npm run dev:api',
      url: 'http://localhost:3000/api/health',
      reuseExistingServer: !process.env.CI,
      timeout: 120000,
    },
    {
      command: process.env.CI ? 'npm run start:web' : 'npm run dev:web',
      url: 'http://localhost:4200',
      reuseExistingServer: !process.env.CI,
      timeout: 120000,
    },
  ],
});
```

---

## CI Configuration

```yaml
# .github/workflows/ci.yml (e2e job)
e2e:
  runs-on: ubuntu-latest
  needs: lint-test-build

  services:
    postgres:
      image: postgres:16
      env:
        POSTGRES_USER: postgres
        POSTGRES_PASSWORD: postgres
        POSTGRES_DB: test
      ports:
        - 5432:5432
      options: >-
        --health-cmd pg_isready
        --health-interval 10s
        --health-timeout 5s
        --health-retries 5

  steps:
    - uses: actions/checkout@v6

    - uses: actions/setup-node@v6
      with:
        node-version: '22'
        cache: 'npm'

    - name: Install dependencies
      run: npm ci

    - name: Install Playwright browsers
      run: npx playwright install --with-deps chromium

    - name: Build
      run: npm run build

    - name: Run E2E tests
      run: npm run e2e
      env:
        CI: true
        DATABASE_HOST: localhost
        DATABASE_PORT: 5432
        DATABASE_USERNAME: postgres
        DATABASE_PASSWORD: postgres
        DATABASE_NAME: test

    - name: Upload report
      uses: actions/upload-artifact@v4
      if: always()
      with:
        name: playwright-report
        path: apps/web-e2e/playwright-report/
        retention-days: 7
```

---

## Page Object Model

```typescript
// apps/web-e2e/src/pages/base.page.ts
import { Page, Locator } from '@playwright/test';

export abstract class BasePage {
  constructor(protected readonly page: Page) {}

  async waitForAngular(): Promise<void> {
    await this.page.waitForSelector('app-root:not(.loading)', { timeout: 10000 });
  }

  async waitForToast(type: 'success' | 'error' | 'info'): Promise<void> {
    await this.page.waitForSelector(`.p-toast-message-${type}`);
  }

  async dismissToast(): Promise<void> {
    const closeButton = this.page.locator('.p-toast-icon-close');
    if (await closeButton.isVisible()) {
      await closeButton.click();
    }
  }
}
```

```typescript
// apps/web-e2e/src/pages/login.page.ts
import { Page, Locator } from '@playwright/test';
import { BasePage } from './base.page';

export class LoginPage extends BasePage {
  readonly emailInput: Locator;
  readonly passwordInput: Locator;
  readonly submitButton: Locator;
  readonly errorMessage: Locator;

  constructor(page: Page) {
    super(page);
    this.emailInput = page.locator('[data-testid="email-input"]');
    this.passwordInput = page.locator('[data-testid="password-input"]');
    this.submitButton = page.locator('[data-testid="login-button"]');
    this.errorMessage = page.locator('[data-testid="login-error"]');
  }

  async goto(): Promise<void> {
    await this.page.goto('/auth/login');
    await this.waitForAngular();
  }

  async login(email: string, password: string): Promise<void> {
    await this.emailInput.fill(email);
    await this.passwordInput.fill(password);
    await this.submitButton.click();
  }

  async expectError(message: string): Promise<void> {
    await expect(this.errorMessage).toContainText(message);
  }
}
```

---

## Test Fixtures

```typescript
// apps/web-e2e/src/fixtures/auth.fixture.ts
import { test as base, Page } from '@playwright/test';

interface AuthFixtures {
  authenticatedPage: Page;
}

export const test = base.extend<AuthFixtures>({
  authenticatedPage: async ({ page }, use) => {
    // Login via API (faster than UI)
    const response = await page.request.post('/api/auth/login', {
      data: {
        email: 'test@example.com',
        password: 'TestPassword123',
      },
    });

    const { accessToken } = await response.json();

    // Set token in localStorage
    await page.addInitScript((token) => {
      localStorage.setItem('accessToken', token);
    }, accessToken);

    await use(page);
  },
});

export { expect } from '@playwright/test';
```

```typescript
// apps/web-e2e/src/fixtures/db.fixture.ts
import { test as base } from '@playwright/test';
import { Client } from 'pg';

interface DbFixtures {
  seedDatabase: () => Promise<void>;
  cleanDatabase: () => Promise<void>;
}

export const test = base.extend<DbFixtures>({
  seedDatabase: async ({}, use) => {
    const seed = async () => {
      const client = new Client({
        host: process.env.DATABASE_HOST || 'localhost',
        port: parseInt(process.env.DATABASE_PORT || '5432'),
        user: process.env.DATABASE_USERNAME || 'postgres',
        password: process.env.DATABASE_PASSWORD || 'postgres',
        database: process.env.DATABASE_NAME || 'test',
      });

      await client.connect();
      // Insert test data
      await client.query(`
        INSERT INTO users (id, email, password_hash, first_name)
        VALUES ('test-user-id', 'test@example.com', '$2b$12$...', 'Test')
        ON CONFLICT (email) DO NOTHING
      `);
      await client.end();
    };

    await use(seed);
  },

  cleanDatabase: async ({}, use) => {
    const clean = async () => {
      const client = new Client({
        host: process.env.DATABASE_HOST || 'localhost',
        port: parseInt(process.env.DATABASE_PORT || '5432'),
        user: process.env.DATABASE_USERNAME || 'postgres',
        password: process.env.DATABASE_PASSWORD || 'postgres',
        database: process.env.DATABASE_NAME || 'test',
      });

      await client.connect();
      await client.query('TRUNCATE users CASCADE');
      await client.end();
    };

    await use(clean);
  },
});
```

---

## Journey Test Example

```typescript
// apps/web-e2e/src/journeys/auth.spec.ts
import { test, expect } from '../fixtures/auth.fixture';
import { LoginPage } from '../pages/login.page';

test.describe('Authentication', () => {
  test.beforeEach(async ({ page }) => {
    // Clear any existing session
    await page.context().clearCookies();
  });

  test('user can sign in with valid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    await loginPage.login('test@example.com', 'ValidPassword123');

    // Should redirect to dashboard
    await expect(page).toHaveURL('/dashboard');
    await expect(page.locator('[data-testid="user-menu"]')).toBeVisible();
  });

  test('shows error for invalid credentials', async ({ page }) => {
    const loginPage = new LoginPage(page);
    await loginPage.goto();

    await loginPage.login('test@example.com', 'WrongPassword');

    await loginPage.expectError('Invalid credentials');
    await expect(page).toHaveURL('/auth/login');
  });

  test('user can sign out', async ({ authenticatedPage }) => {
    await authenticatedPage.goto('/dashboard');

    await authenticatedPage.click('[data-testid="user-menu"]');
    await authenticatedPage.click('[data-testid="logout-button"]');

    await expect(authenticatedPage).toHaveURL('/auth/login');
  });
});
```

---

## Angular-Specific Patterns

### Waiting for Angular

```typescript
// Wait for Angular to stabilize
await page.waitForSelector('app-root:not(.loading)');

// Wait for route navigation
await page.waitForURL('/expected-route');

// Wait for PrimeNG components to render
await page.waitForSelector('.p-datatable-tbody tr');
await page.waitForSelector('.p-dialog-content');
```

### PrimeNG Component Interactions

```typescript
// Dropdown
await page.click('.p-dropdown');
await page.click('.p-dropdown-item:has-text("Option 1")');

// Calendar
await page.click('.p-calendar input');
await page.click('.p-datepicker-today');

// Table row selection
await page.click('.p-datatable-tbody tr:first-child');

// Dialog confirmation
await page.click('.p-dialog-footer button:has-text("Confirm")');

// Toast dismissal
await page.click('.p-toast-icon-close');
```

### Data-testid Selectors

```typescript
// Prefer data-testid for stability
await page.click('[data-testid="submit-button"]');
await page.fill('[data-testid="email-input"]', 'test@example.com');

// Add to Angular templates
// <button data-testid="submit-button" pButton>Submit</button>
// <input data-testid="email-input" pInputText formControlName="email" />
```

---

## Commands

```bash
# Run all E2E tests
npm run e2e

# Run specific journey
npm run e2e -- --grep "auth"

# Run in headed mode
npm run e2e -- --headed

# Run with UI mode (interactive)
npm run e2e -- --ui

# Run specific browser
npm run e2e -- --project=chromium

# Generate HTML report
npm run e2e -- --reporter=html

# Show report
npx playwright show-report apps/web-e2e/playwright-report

# Debug mode
npm run e2e -- --debug

# Update snapshots
npm run e2e -- --update-snapshots
```

---

## Best Practices

| Practice | Implementation |
|----------|----------------|
| Stable selectors | Use `data-testid` attributes |
| No flaky waits | Use `waitForSelector`, not `waitForTimeout` |
| Test isolation | Reset database between tests |
| Fast auth | Login via API, not UI (except auth tests) |
| Page objects | Encapsulate page interactions |
| Fixtures | Share setup logic across tests |
| CI optimization | Run only Chromium, use production build |
