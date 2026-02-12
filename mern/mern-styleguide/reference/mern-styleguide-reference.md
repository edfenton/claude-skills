# MERN Style Guide Reference

Detailed tokens, patterns, and implementation guidance. Load when building UI.

---

## Semantic Color Tokens

### Light mode

```typescript
const lightTheme = {
  color: {
    background: "#FFFFFF",
    surface: "#FFFFFF",
    surfaceElevated: "#FFFFFF",
    textPrimary: "#000000",
    textSecondary: "#282828",
    textMuted: "#282828", // use with reduced opacity
    border: "#DAD9D9",
    divider: "#DAD9D9",
    accent: "#FF5E1A",
    onAccent: "#000000",
    focusRing: "#FF5E1A",
  },
};
```

### Dark mode

```typescript
const darkTheme = {
  color: {
    background: "#000000",
    surface: "#282828",
    surfaceElevated: "#282828",
    textPrimary: "#FFFFFF",
    textSecondary: "#DAD9D9",
    textMuted: "#DAD9D9", // use with reduced opacity
    border: "#282828",
    divider: "#282828",
    accent: "#FF5E1A",
    onAccent: "#000000",
    focusRing: "#FF5E1A",
  },
};
```

### CSS custom properties

```css
:root {
  --color-background: #ffffff;
  --color-surface: #ffffff;
  --color-surface-elevated: #ffffff;
  --color-text-primary: #000000;
  --color-text-secondary: #282828;
  --color-text-muted: rgba(40, 40, 40, 0.6);
  --color-border: #dad9d9;
  --color-divider: #dad9d9;
  --color-accent: #ff5e1a;
  --color-on-accent: #000000;
  --color-focus-ring: #ff5e1a;
}

[data-theme="dark"] {
  --color-background: #000000;
  --color-surface: #282828;
  --color-surface-elevated: #282828;
  --color-text-primary: #ffffff;
  --color-text-secondary: #dad9d9;
  --color-text-muted: rgba(218, 217, 217, 0.6);
  --color-border: #282828;
  --color-divider: #282828;
  /* accent, onAccent, focusRing unchanged */
}
```

### Tailwind config

```typescript
// tailwind.config.ts
const config = {
  theme: {
    extend: {
      colors: {
        brand: {
          orange: "#FF5E1A",
        },
        neutral: {
          white: "#FFFFFF",
          lightGray: "#DAD9D9",
          darkGray: "#282828",
          black: "#000000",
        },
      },
    },
  },
};
```

---

## Responsive Breakpoints

```typescript
const breakpoints = {
  mobile: "0px", // 0-639px
  tablet: "640px", // 640-1023px
  desktop: "1024px", // 1024-1439px
  large: "1440px", // 1440px+
};
```

### Tailwind classes

- Mobile-first: default styles
- `sm:` — tablet (640px+)
- `md:` — small desktop (768px+)
- `lg:` — desktop (1024px+)
- `xl:` — large desktop (1280px+)
- `2xl:` — extra large (1536px+)

### Responsive patterns

```tsx
// Navigation: drawer on mobile, sidebar on desktop
<nav className="fixed inset-y-0 left-0 w-64 hidden lg:block">
  {/* Desktop sidebar */}
</nav>
<Sheet>
  <SheetTrigger className="lg:hidden">
    {/* Mobile menu button */}
  </SheetTrigger>
  <SheetContent side="left">
    {/* Mobile drawer */}
  </SheetContent>
</Sheet>

// Grid: 1 col mobile, 2 tablet, 3 desktop
<div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 gap-6">
  {items.map(item => <Card key={item.id} />)}
</div>

// Typography scaling
<h1 className="text-2xl sm:text-3xl lg:text-4xl font-bold">
  {title}
</h1>
```

---

## Typography Recommendations

### Premium font pairings

**Option 1: Editorial**

- Headings: `'PP Mori', 'Sohne', sans-serif`
- Body: `'Soehne', 'Inter', sans-serif`

**Option 2: Modern geometric**

- Headings: `'Geist', 'Satoshi', sans-serif`
- Body: `'Geist', sans-serif`

**Option 3: Classic with character**

- Headings: `'GT Walsheim', 'Founders Grotesk', sans-serif`
- Body: `'Suisse Int'l', 'Akkurat', sans-serif`

### Type scale

```css
--text-xs: 0.75rem; /* 12px */
--text-sm: 0.875rem; /* 14px */
--text-base: 1rem; /* 16px */
--text-lg: 1.125rem; /* 18px */
--text-xl: 1.25rem; /* 20px */
--text-2xl: 1.5rem; /* 24px */
--text-3xl: 1.875rem; /* 30px */
--text-4xl: 2.25rem; /* 36px */
--text-5xl: 3rem; /* 48px */
```

---

## Spacing and Shape

### Spacing scale (rem)

```
0.5  = 2px
1    = 4px
2    = 8px
3    = 12px
4    = 16px
6    = 24px
8    = 32px
12   = 48px
16   = 64px
24   = 96px
```

### Border radius

```css
--radius-sm: 4px; /* Subtle rounding */
--radius-md: 8px; /* Default for buttons, inputs */
--radius-lg: 12px; /* Cards, panels */
--radius-xl: 16px; /* Modals, large surfaces */
--radius-full: 9999px; /* Pills, avatars */
```

### Elevation (shadows)

```css
--shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
--shadow-md: 0 4px 6px rgba(0, 0, 0, 0.07);
--shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
--shadow-xl: 0 20px 25px rgba(0, 0, 0, 0.15);
```

Use elevation sparingly. Prefer visual hierarchy through spacing and typography.

---

## Motion Guidelines

### Timing

```css
--duration-fast: 100ms; /* Micro-interactions */
--duration-normal: 200ms; /* Standard transitions */
--duration-slow: 300ms; /* Larger state changes */
--duration-slower: 500ms; /* Page transitions */

--ease-out: cubic-bezier(0.33, 1, 0.68, 1);
--ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
```

### Reduced motion

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

### Appropriate uses

- State changes (hover, focus, active)
- Content appearing/disappearing
- Navigation transitions
- Loading states

### Inappropriate uses

- Continuous decoration
- Attention-seeking pulses
- Parallax without purpose
- Scroll-jacking

---

## Anti-Pattern Examples

### ❌ Card overuse

```tsx
// Bad: unnecessary card nesting
<Card>
  <Card>
    <Card>
      <p>Content</p>
    </Card>
  </Card>
</Card>

// Good: single card or no card
<div className="space-y-4">
  <p>Content uses whitespace, not borders</p>
</div>
```

### ❌ Generic template layout

```tsx
// Bad: every SaaS landing page
<Hero />
<Features grid={3} />
<Testimonials />
<CTA />

// Good: intentional hierarchy
<section className="relative">
  {/* Unique visual treatment */}
  <ProductShowcase />
</section>
<section>
  {/* Asymmetric layout with purpose */}
  <BenefitsNarrative />
</section>
```

### ❌ Decorative glass

```tsx
// Bad: glass everywhere
<div className="backdrop-blur-xl bg-white/10 rounded-xl">
  <div className="backdrop-blur-lg bg-white/20 rounded-lg">
    Everything is frosted
  </div>
</div>

// Good: glass for focus/depth
<Dialog>
  <DialogOverlay className="backdrop-blur-sm bg-black/50" />
  <DialogContent className="bg-surface">
    {/* Clean content, blur only on overlay */}
  </DialogContent>
</Dialog>
```

### ❌ Muted accent

```tsx
// Bad: accent is timid
<Button className="bg-gray-200 text-gray-600">
  Save
</Button>

// Good: accent is decisive
<Button className="bg-brand-orange text-on-accent">
  Save
</Button>
```

---

## Focus States

```css
/* Visible, on-brand focus ring */
:focus-visible {
  outline: 2px solid var(--color-focus-ring);
  outline-offset: 2px;
}

/* Remove default, add custom */
button:focus-visible,
a:focus-visible,
input:focus-visible {
  outline: none;
  box-shadow:
    0 0 0 2px var(--color-background),
    0 0 0 4px var(--color-focus-ring);
}
```

---

## Browser Support Matrix

| Browser    | Version | Priority      |
| ---------- | ------- | ------------- |
| Chrome     | Latest  | Required      |
| Safari     | Latest  | Required      |
| iOS Safari | Latest  | Required      |
| Firefox    | Latest  | Required      |
| Edge       | Latest  | Required      |
| IE         | Any     | Not supported |

### Feature detection

```typescript
// Progressive enhancement pattern
const supportsContainerQueries = CSS.supports("container-type", "inline-size");

if (supportsContainerQueries) {
  // Use container queries
} else {
  // Fallback to media queries
}
```

### Safari gotchas

- Test `backdrop-filter` on iOS
- Watch for `position: sticky` issues in overflow containers
- Test date inputs thoroughly
- Verify Web Animations API behavior

---

## Quick Reference

| Element             | Token/Value                       |
| ------------------- | --------------------------------- |
| Primary background  | `var(--color-background)`         |
| Card surface        | `var(--color-surface)`            |
| Primary text        | `var(--color-text-primary)`       |
| Brand accent        | `var(--color-accent)` / `#FF5E1A` |
| Focus ring          | `var(--color-focus-ring)`         |
| Default radius      | `--radius-md` / `8px`             |
| Standard transition | `200ms ease-out`                  |
| Mobile breakpoint   | `< 640px`                         |
| Desktop breakpoint  | `≥ 1024px`                        |
