# NEAN Design Review Reference

Playwright setup, screenshot capture, and evaluation checklist.

---

## Playwright setup

### Install

```bash
npm install -D @playwright/test
npx playwright install
```

### Config (playwright.config.ts)

```typescript
import { defineConfig, devices } from '@playwright/test';

export default defineConfig({
  testDir: './e2e',
  outputDir: './playwright-artifacts',
  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:4200',
    screenshot: 'on',
  },
  projects: [
    {
      name: 'mobile',
      use: { ...devices['iPhone 14'] },
    },
    {
      name: 'tablet',
      use: { ...devices['iPad Pro 11'] },
    },
    {
      name: 'desktop',
      use: { viewport: { width: 1440, height: 900 } },
    },
  ],
});
```

---

## Screenshot capture script

### Design review test (e2e/design-review.spec.ts)

```typescript
import { test } from '@playwright/test';
import * as fs from 'fs';
import * as path from 'path';

// Routes to capture (or discover dynamically)
const routes = ['/', '/settings', '/profile', '/dashboard'];

// Breakpoints
const viewports = {
  mobile: { width: 390, height: 844 },
  tablet: { width: 834, height: 1194 },
  desktop: { width: 1440, height: 900 },
};

const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
const outputDir = `./playwright-artifacts/design-review/${timestamp}`;

test.describe('Design Review Screenshots', () => {
  test.beforeAll(() => {
    fs.mkdirSync(outputDir, { recursive: true });
  });

  for (const route of routes) {
    for (const [viewport, size] of Object.entries(viewports)) {
      test(`${route} @ ${viewport}`, async ({ page }) => {
        await page.setViewportSize(size);
        await page.goto(route);

        // Wait for content to stabilize
        await page.waitForLoadState('networkidle');

        // Optional: wait for fonts and Angular rendering
        await page.waitForTimeout(500);

        const filename = `${route.replace(/\//g, '_') || 'home'}-${viewport}.png`;
        await page.screenshot({
          path: path.join(outputDir, filename),
          fullPage: true,
        });
      });
    }
  }
});
```

### Run capture

```bash
# Run design review tests
npx playwright test e2e/design-review.spec.ts

# With specific base URL
BASE_URL=http://localhost:4200 npx playwright test e2e/design-review.spec.ts
```

---

## Route discovery

### Script to find Angular routes

```typescript
// scripts/discover-routes.ts
import * as fs from 'fs';
import * as path from 'path';

function discoverRoutes(routeFile: string): string[] {
  const content = fs.readFileSync(routeFile, 'utf-8');
  const routes: string[] = ['/'];

  // Match path properties in Angular route config
  const pathRegex = /path:\s*['"]([^'"]+)['"]/g;
  let match: RegExpExecArray | null;

  while ((match = pathRegex.exec(content)) !== null) {
    const routePath = match[1];
    // Skip wildcard and parameterized routes for screenshots
    if (routePath !== '**' && !routePath.includes(':')) {
      routes.push(`/${routePath}`);
    }
  }

  return routes;
}

// Usage — scan Angular app.routes.ts
const routeFile = path.join(
  process.cwd(),
  'apps/web/src/app/app.routes.ts'
);
const routes = discoverRoutes(routeFile);
console.log('Discovered routes:', routes);
```

---

## Evaluation checklist

### Responsiveness

| Check            | Pass criteria                                            |
| ---------------- | -------------------------------------------------------- |
| Mobile layout    | Content reflows intentionally, not just squished         |
| Tablet layout    | Uses available space, not stretched mobile               |
| Desktop layout   | Comfortable reading width, proper use of space           |
| Navigation       | Appropriate pattern per breakpoint (drawer/sidebar/tabs) |
| Touch targets    | >=44px on mobile                                         |
| Text readability | No horizontal scroll, appropriate line length            |

### Typography

| Check        | Pass criteria                                           |
| ------------ | ------------------------------------------------------- |
| Primary font | Not in banned list (Inter, Roboto, Open Sans, etc.)     |
| Hierarchy    | Clear distinction between heading levels                |
| Scale        | Appropriate sizing per breakpoint                       |
| Line height  | Comfortable reading (1.4-1.6 for body)                  |
| Voice        | Typography contributes personality, not just legibility |

### Spacing & hierarchy

| Check            | Pass criteria                             |
| ---------------- | ----------------------------------------- |
| Visual hierarchy | Clear what to look at first               |
| Whitespace       | Generous, intentional, aids comprehension |
| Consistency      | Same elements have same spacing           |
| Density          | Balanced — not cramped, not sparse        |
| Alignment        | Intentional grid, not arbitrary           |

### Color

| Check           | Pass criteria                                |
| --------------- | -------------------------------------------- |
| Semantic tokens | No raw hex values visible in code            |
| Contrast        | Text meets WCAG AA (4.5:1 normal, 3:1 large) |
| Brand accent    | Used decisively, not timidly                 |
| Dark mode       | Proper inversion, not just swapped colors    |
| Consistency     | Same semantic meaning = same color           |

### Accessibility

| Check              | Pass criteria                         |
| ------------------ | ------------------------------------- |
| Focus states       | Visible, on-brand focus ring          |
| Color independence | Meaning not conveyed by color alone   |
| Touch targets      | >=44px interactive elements on mobile |
| Contrast           | Text and interactive elements pass AA |
| Motion             | Respects `prefers-reduced-motion`     |

### Anti-patterns

| Anti-pattern           | What to look for                                   |
| ---------------------- | -------------------------------------------------- |
| Unchanged PrimeNG      | Default component styles with no customization     |
| Card nesting           | Cards inside cards inside cards                    |
| Generic SaaS           | "Hero + 3 cards + CTA" template layout             |
| Decorative glass       | Blur effects without conveying depth/focus         |
| Muted accent           | Brand color used timidly or not at all             |
| Perfect symmetry       | Everything centered without intentional hierarchy  |

---

## Common issues and fixes

### Issue: Unchanged PrimeNG defaults

```html
<!-- ❌ Generic PrimeNG card -->
<p-card header="Title">
  <p>Content</p>
</p-card>

<!-- ✅ Customized with brand styling -->
<div class="space-y-4">
  <h2 class="text-2xl font-brand tracking-tight">{{ title }}</h2>
  <p class="text-secondary leading-relaxed">{{ content }}</p>
</div>
```

### Issue: Mobile just stacks desktop

```html
<!-- ❌ Lazy responsive — same content just stacked -->
<div class="flex flex-column md:flex-row">
  <!-- Identical layout at all sizes -->
</div>

<!-- ✅ Intentional mobile design -->
<div class="block md:hidden">
  <app-mobile-optimized-layout />
</div>
<div class="hidden md:block">
  <app-desktop-layout />
</div>
```

### Issue: No visible focus states

```scss
/* ❌ Hidden focus */
:focus {
  outline: none;
}

/* ✅ Visible, on-brand focus */
:focus-visible {
  outline: none;
  box-shadow:
    0 0 0 2px var(--surface-ground),
    0 0 0 4px var(--primary-color);
}
```

### Issue: Low contrast text

```html
<!-- ❌ Low contrast -->
<p class="text-400">Important information</p>

<!-- ✅ Adequate contrast -->
<p class="text-color-secondary">Important information</p>
<!-- Where text-color-secondary maps to a color with sufficient contrast -->
```

### Issue: Tiny touch targets

```html
<!-- ❌ Too small -->
<button pButton icon="pi pi-trash" class="p-button-text p-button-sm"></button>

<!-- ✅ Adequate target -->
<button
  pButton
  icon="pi pi-trash"
  class="p-button-text"
  style="min-width: 44px; min-height: 44px"
  aria-label="Delete item"
></button>
```

---

## Report template

```
## Design Review Results

**Base URL:** http://localhost:4200
**Routes reviewed:** 5
**Viewports captured:** 15 (5 routes x 3 breakpoints)

### Summary
| Severity | Count |
|----------|-------|
| Must-fix | 2 |
| Should-fix | 5 |
| Nice-to-have | 3 |

### Findings

#### / (Home)

**Mobile (390x844)**
- ✅ Pass

**Tablet (834x1194)**
- [should-fix] Layout is stretched mobile, not tablet-optimized
  - *Fix: Use 2-column grid for feature cards*

**Desktop (1440x900)**
- [must-fix] Hero text contrast fails AA (3.2:1, needs 4.5:1)
  - *Fix: Use `text-color` instead of `text-400` for headline*
- [should-fix] Default PrimeNG Card styling unchanged
  - *Fix: Remove p-card wrapper, use spacing and typography for hierarchy*

#### /settings

**Mobile (390x844)**
- [must-fix] Form inputs have no visible focus state
  - *Fix: Add focus-visible ring using brand accent*
- [nice-to-have] Toggle switches slightly small (40px)
  - *Fix: Increase to 44px minimum*

...
```

---

## Automation script

### Full design review runner

```bash
#!/bin/bash
# scripts/design-review.sh

set -e

# Start dev server if not running
if ! curl -s http://localhost:4200 > /dev/null; then
  echo "Starting dev server..."
  npx nx serve web &
  sleep 10
fi

# Capture screenshots
echo "Capturing screenshots..."
npx playwright test e2e/design-review.spec.ts

# Output location
echo "Screenshots saved to playwright-artifacts/design-review/"
echo "Review screenshots and evaluate against nean-styleguide"
```

---

## Quick reference

| Task                | Command                                                    |
| ------------------- | ---------------------------------------------------------- |
| Install Playwright  | `npm install -D @playwright/test && npx playwright install`|
| Capture screenshots | `npx playwright test e2e/design-review.spec.ts`            |
| View report         | `npx playwright show-report`                               |
| Specific route      | Modify `routes` array in test file                         |
| Contrast checker    | DevTools -> Lighthouse -> Accessibility                    |
