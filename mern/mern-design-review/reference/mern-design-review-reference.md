# MERN Design Review Reference

Playwright setup, screenshot capture, and evaluation checklist.

---

## Playwright setup

### Install

```bash
pnpm add -D @playwright/test
npx playwright install
```

### Config (playwright.config.ts)

```typescript
import { defineConfig, devices } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  outputDir: "./playwright-artifacts",
  use: {
    baseURL: process.env.BASE_URL || "http://localhost:3000",
    screenshot: "on",
  },
  projects: [
    {
      name: "mobile",
      use: { ...devices["iPhone 14"] },
    },
    {
      name: "tablet",
      use: { ...devices["iPad Pro 11"] },
    },
    {
      name: "desktop",
      use: { viewport: { width: 1440, height: 900 } },
    },
  ],
});
```

---

## Screenshot capture script

### Design review test (e2e/design-review.spec.ts)

```typescript
import { test } from "@playwright/test";
import * as fs from "fs";
import * as path from "path";

// Routes to capture (or discover dynamically)
const routes = ["/", "/settings", "/profile", "/dashboard"];

// Breakpoints
const viewports = {
  mobile: { width: 390, height: 844 },
  tablet: { width: 834, height: 1194 },
  desktop: { width: 1440, height: 900 },
};

const timestamp = new Date().toISOString().replace(/[:.]/g, "-");
const outputDir = `./playwright-artifacts/design-review/${timestamp}`;

test.describe("Design Review Screenshots", () => {
  test.beforeAll(() => {
    fs.mkdirSync(outputDir, { recursive: true });
  });

  for (const route of routes) {
    for (const [viewport, size] of Object.entries(viewports)) {
      test(`${route} @ ${viewport}`, async ({ page }) => {
        await page.setViewportSize(size);
        await page.goto(route);

        // Wait for content to stabilize
        await page.waitForLoadState("networkidle");

        // Optional: wait for fonts
        await page.waitForTimeout(500);

        const filename = `${route.replace(/\//g, "_") || "home"}-${viewport}.png`;
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
BASE_URL=http://localhost:3000 npx playwright test e2e/design-review.spec.ts
```

---

## Route discovery

### Script to find routes

```typescript
// scripts/discover-routes.ts
import * as fs from "fs";
import * as path from "path";
import { glob } from "glob";

async function discoverRoutes(): Promise<string[]> {
  const pageFiles = await glob("apps/web/src/app/**/page.tsx");

  return pageFiles.map((file) => {
    // apps/web/src/app/settings/page.tsx -> /settings
    // apps/web/src/app/page.tsx -> /
    const relativePath = file
      .replace("apps/web/src/app", "")
      .replace("/page.tsx", "")
      .replace(/\[([^\]]+)\]/g, ":$1"); // [id] -> :id

    return relativePath || "/";
  });
}

// Usage
const routes = await discoverRoutes();
console.log("Discovered routes:", routes);
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
| Touch targets    | ≥44px on mobile                                          |
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
| Density          | Balanced—not cramped, not sparse          |
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
| Touch targets      | ≥44px interactive elements on mobile  |
| Contrast           | Text and interactive elements pass AA |
| Motion             | Respects `prefers-reduced-motion`     |

### Anti-patterns

| Anti-pattern     | What to look for                                  |
| ---------------- | ------------------------------------------------- |
| Unchanged shadcn | Default component styles with no customization    |
| Card nesting     | Cards inside cards inside cards                   |
| Generic SaaS     | "Hero + 3 cards + CTA" template layout            |
| Decorative glass | Blur effects without conveying depth/focus        |
| Muted accent     | Brand color used timidly or not at all            |
| Perfect symmetry | Everything centered without intentional hierarchy |

---

## Common issues and fixes

### Issue: Unchanged shadcn defaults

```tsx
// ❌ Generic
<Card>
  <CardHeader>
    <CardTitle>Title</CardTitle>
  </CardHeader>
  <CardContent>Content</CardContent>
</Card>

// ✅ Customized
<div className="space-y-4">
  <h2 className="text-2xl font-brand tracking-tight">{title}</h2>
  <p className="text-secondary leading-relaxed">{content}</p>
</div>
```

### Issue: Mobile just stacks desktop

```tsx
// ❌ Lazy responsive
<div className="flex flex-col md:flex-row">
  {/* Same content, just stacked */}
</div>

// ✅ Intentional mobile design
<div className="md:hidden">
  <MobileOptimizedLayout />
</div>
<div className="hidden md:block">
  <DesktopLayout />
</div>
```

### Issue: No visible focus states

```css
/* ❌ Hidden focus */
:focus {
  outline: none;
}

/* ✅ Visible, on-brand focus */
:focus-visible {
  outline: none;
  box-shadow:
    0 0 0 2px var(--color-background),
    0 0 0 4px var(--color-focus-ring);
}
```

### Issue: Low contrast text

```tsx
// ❌ Low contrast
<p className="text-gray-400">Important information</p>

// ✅ Adequate contrast
<p className="text-secondary">Important information</p>
// Where text-secondary maps to a color with sufficient contrast
```

### Issue: Tiny touch targets

```tsx
// ❌ Too small
<button className="p-1">
  <Icon size={16} />
</button>

// ✅ Adequate target
<button className="p-2 min-w-[44px] min-h-[44px] flex items-center justify-center">
  <Icon size={20} />
</button>
```

---

## Report template

```
## Design Review Results

**Base URL:** http://localhost:3000
**Routes reviewed:** 5
**Viewports captured:** 15 (5 routes × 3 breakpoints)

### Summary
| Severity | Count |
|----------|-------|
| Must-fix | 2 |
| Should-fix | 5 |
| Nice-to-have | 3 |

### Findings

#### / (Home)

**Mobile (390×844)**
- ✅ Pass

**Tablet (834×1194)**
- [should-fix] Layout is stretched mobile, not tablet-optimized
  - *Fix: Use 2-column grid for feature cards*

**Desktop (1440×900)**
- [must-fix] Hero text contrast fails AA (3.2:1, needs 4.5:1)
  - *Fix: Use `text-primary` instead of `text-muted` for headline*
- [should-fix] Default shadcn Card styling unchanged
  - *Fix: Remove card wrapper, use spacing and typography for hierarchy*

#### /settings

**Mobile (390×844)**
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
if ! curl -s http://localhost:3000 > /dev/null; then
  echo "Starting dev server..."
  pnpm dev &
  sleep 5
fi

# Capture screenshots
echo "Capturing screenshots..."
npx playwright test e2e/design-review.spec.ts

# Output location
echo "Screenshots saved to playwright-artifacts/design-review/"
echo "Review screenshots and evaluate against mern-styleguide"
```

---

## Quick reference

| Task                | Command                                                  |
| ------------------- | -------------------------------------------------------- |
| Install Playwright  | `pnpm add -D @playwright/test && npx playwright install` |
| Capture screenshots | `npx playwright test e2e/design-review.spec.ts`          |
| View report         | `npx playwright show-report`                             |
| Specific route      | Modify `routes` array in test file                       |
| Contrast checker    | DevTools → Lighthouse → Accessibility                    |
