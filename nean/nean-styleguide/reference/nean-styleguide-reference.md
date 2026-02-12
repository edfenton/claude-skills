# NEAN Styleguide Reference

Semantic tokens, breakpoints, and detailed design patterns for PrimeNG + Tailwind.

---

## Semantic color tokens

### CSS custom properties (styles.scss)

```scss
:root {
  // Brand
  --color-brand-primary: #FF5E1A;
  --color-brand-primary-hover: #E5541A;
  --color-brand-primary-active: #CC4A17;

  // Neutrals
  --color-neutral-white: #FFFFFF;
  --color-neutral-lightest: #F8F8F8;
  --color-neutral-light: #DAD9D9;
  --color-neutral-medium: #9E9E9E;
  --color-neutral-dark: #282828;
  --color-neutral-black: #000000;

  // Semantic
  --color-text-primary: var(--color-neutral-dark);
  --color-text-secondary: var(--color-neutral-medium);
  --color-text-inverse: var(--color-neutral-white);
  
  --color-bg-primary: var(--color-neutral-white);
  --color-bg-secondary: var(--color-neutral-lightest);
  --color-bg-tertiary: var(--color-neutral-light);

  --color-border-default: var(--color-neutral-light);
  --color-border-strong: var(--color-neutral-medium);

  // Feedback
  --color-success: #10B981;
  --color-warning: #F59E0B;
  --color-error: #EF4444;
  --color-info: #3B82F6;

  // Shadows
  --shadow-sm: 0 1px 2px rgba(0, 0, 0, 0.05);
  --shadow-md: 0 4px 6px rgba(0, 0, 0, 0.1);
  --shadow-lg: 0 10px 15px rgba(0, 0, 0, 0.1);
}

// Dark mode
[data-theme="dark"] {
  --color-text-primary: var(--color-neutral-white);
  --color-text-secondary: var(--color-neutral-light);
  --color-text-inverse: var(--color-neutral-dark);
  
  --color-bg-primary: var(--color-neutral-black);
  --color-bg-secondary: var(--color-neutral-dark);
  --color-bg-tertiary: #1F1F1F;

  --color-border-default: #3D3D3D;
  --color-border-strong: var(--color-neutral-medium);
}
```

### Tailwind config (tailwind.config.js)

```javascript
module.exports = {
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: 'var(--color-brand-primary)',
          hover: 'var(--color-brand-primary-hover)',
          active: 'var(--color-brand-primary-active)',
        },
        surface: {
          primary: 'var(--color-bg-primary)',
          secondary: 'var(--color-bg-secondary)',
          tertiary: 'var(--color-bg-tertiary)',
        },
        content: {
          primary: 'var(--color-text-primary)',
          secondary: 'var(--color-text-secondary)',
          inverse: 'var(--color-text-inverse)',
        },
      },
    },
  },
};
```

---

## Breakpoints

| Name     | Min Width | Typical Devices           |
| -------- | --------- | ------------------------- |
| `sm`     | 640px     | Large phones (landscape)  |
| `md`     | 768px     | Tablets                   |
| `lg`     | 1024px    | Small laptops             |
| `xl`     | 1280px    | Desktops                  |
| `2xl`    | 1536px    | Large monitors            |

### Usage

```html
<!-- Tailwind -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3">

<!-- Angular with PrimeNG -->
<p-table [responsive]="true" responsiveLayout="stack" breakpoint="768px">
```

---

## PrimeNG theme customization

### Custom theme variables (styles.scss)

```scss
// Override PrimeNG CSS variables
:root {
  // Primary color
  --primary-color: var(--color-brand-primary);
  --primary-color-text: var(--color-neutral-white);
  
  // Surface colors
  --surface-ground: var(--color-bg-secondary);
  --surface-section: var(--color-bg-primary);
  --surface-card: var(--color-bg-primary);
  --surface-overlay: var(--color-bg-primary);
  --surface-border: var(--color-border-default);
  
  // Text colors
  --text-color: var(--color-text-primary);
  --text-color-secondary: var(--color-text-secondary);
  
  // Focus
  --focus-ring: 0 0 0 2px var(--color-brand-primary);
  
  // Border radius
  --border-radius: 8px;
  
  // Font
  --font-family: 'Your-Brand-Font', system-ui, sans-serif;
}

// Button customization
.p-button {
  border-radius: var(--border-radius);
  font-weight: 600;
  transition: all 0.2s ease;
  
  &:not(.p-button-outlined):not(.p-button-text) {
    box-shadow: var(--shadow-sm);
    
    &:hover {
      transform: translateY(-1px);
      box-shadow: var(--shadow-md);
    }
  }
}

// Card customization
.p-card {
  border-radius: calc(var(--border-radius) * 1.5);
  border: 1px solid var(--surface-border);
  box-shadow: none;
  
  .p-card-content {
    padding: 1.5rem;
  }
}

// Table customization
.p-datatable {
  .p-datatable-header {
    background: transparent;
    border: none;
    padding: 1rem 0;
  }
  
  .p-datatable-thead > tr > th {
    background: var(--surface-ground);
    font-weight: 600;
    text-transform: uppercase;
    font-size: 0.75rem;
    letter-spacing: 0.05em;
  }
}
```

---

## Typography scale

```scss
// Type scale (based on 1.25 ratio)
:root {
  --text-xs: 0.75rem;    // 12px
  --text-sm: 0.875rem;   // 14px
  --text-base: 1rem;     // 16px
  --text-lg: 1.25rem;    // 20px
  --text-xl: 1.5rem;     // 24px
  --text-2xl: 1.875rem;  // 30px
  --text-3xl: 2.25rem;   // 36px
  --text-4xl: 3rem;      // 48px
}

// Headings
h1, .h1 {
  font-size: var(--text-3xl);
  font-weight: 700;
  line-height: 1.2;
  letter-spacing: -0.02em;
}

h2, .h2 {
  font-size: var(--text-2xl);
  font-weight: 600;
  line-height: 1.3;
}

h3, .h3 {
  font-size: var(--text-xl);
  font-weight: 600;
  line-height: 1.4;
}

// Body
body {
  font-size: var(--text-base);
  line-height: 1.6;
}

// Small text
.text-small {
  font-size: var(--text-sm);
}

.text-caption {
  font-size: var(--text-xs);
  text-transform: uppercase;
  letter-spacing: 0.05em;
}
```

---

## Spacing scale

```scss
// Spacing (4px base)
:root {
  --space-1: 0.25rem;   // 4px
  --space-2: 0.5rem;    // 8px
  --space-3: 0.75rem;   // 12px
  --space-4: 1rem;      // 16px
  --space-5: 1.25rem;   // 20px
  --space-6: 1.5rem;    // 24px
  --space-8: 2rem;      // 32px
  --space-10: 2.5rem;   // 40px
  --space-12: 3rem;     // 48px
  --space-16: 4rem;     // 64px
  --space-20: 5rem;     // 80px
  --space-24: 6rem;     // 96px
}
```

---

## Component patterns

### Page layout

```html
<div class="min-h-screen bg-surface-secondary">
  <!-- Top nav -->
  <nav class="sticky top-0 z-50 bg-surface-primary border-b border-surface-border">
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
      <!-- Nav content -->
    </div>
  </nav>

  <!-- Main content -->
  <main class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
    <!-- Page header -->
    <header class="mb-8">
      <h1 class="text-content-primary">Page Title</h1>
      <p class="text-content-secondary mt-2">Page description</p>
    </header>

    <!-- Content -->
    <div class="bg-surface-primary rounded-xl p-6">
      <!-- ... -->
    </div>
  </main>
</div>
```

### Data table with actions

```html
<p-table
  [value]="items"
  [paginator]="true"
  [rows]="10"
  [rowsPerPageOptions]="[10, 25, 50]"
  styleClass="p-datatable-striped"
>
  <ng-template pTemplate="header">
    <tr>
      <th pSortableColumn="name">Name <p-sortIcon field="name" /></th>
      <th pSortableColumn="status">Status <p-sortIcon field="status" /></th>
      <th class="w-24">Actions</th>
    </tr>
  </ng-template>
  
  <ng-template pTemplate="body" let-item>
    <tr>
      <td>{{ item.name }}</td>
      <td>
        <p-tag [severity]="getStatusSeverity(item.status)">
          {{ item.status }}
        </p-tag>
      </td>
      <td>
        <div class="flex gap-2">
          <button pButton icon="pi pi-pencil" class="p-button-text p-button-sm" />
          <button pButton icon="pi pi-trash" class="p-button-text p-button-danger p-button-sm" />
        </div>
      </td>
    </tr>
  </ng-template>
  
  <ng-template pTemplate="emptymessage">
    <tr>
      <td colspan="3" class="text-center py-8 text-content-secondary">
        No items found
      </td>
    </tr>
  </ng-template>
</p-table>
```

### Form layout

```html
<form [formGroup]="form" (ngSubmit)="onSubmit()" class="space-y-6">
  <!-- Form field -->
  <div class="field">
    <label for="email" class="block text-sm font-medium mb-2">Email</label>
    <input
      pInputText
      id="email"
      formControlName="email"
      class="w-full"
      [class.ng-invalid]="form.get('email')?.invalid && form.get('email')?.touched"
    />
    <small
      *ngIf="form.get('email')?.invalid && form.get('email')?.touched"
      class="p-error block mt-1"
    >
      Please enter a valid email
    </small>
  </div>

  <!-- Form actions -->
  <div class="flex justify-end gap-3 pt-4 border-t">
    <button pButton type="button" label="Cancel" class="p-button-outlined" />
    <button pButton type="submit" label="Save" [loading]="saving" />
  </div>
</form>
```

---

## Animation guidelines

```scss
// Transitions
:root {
  --transition-fast: 150ms ease;
  --transition-normal: 200ms ease;
  --transition-slow: 300ms ease;
}

// Use for micro-interactions
.interactive {
  transition: all var(--transition-fast);
}

// Use for page transitions
.page-transition {
  transition: opacity var(--transition-normal), transform var(--transition-normal);
}

// Respect reduced motion
@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

---

## Accessibility checklist

| Requirement               | Implementation                                    |
| ------------------------- | ------------------------------------------------- |
| Focus visible             | `:focus-visible` ring on all interactive elements |
| Skip links                | Hidden link to main content at page start         |
| Color contrast            | 4.5:1 for text, 3:1 for large text and icons      |
| Touch targets             | Minimum 44x44px on mobile                         |
| Screen reader text        | `.sr-only` class for icon-only buttons            |
| Keyboard navigation       | Tab order logical; no keyboard traps              |
| ARIA labels               | On icon buttons, complex widgets                  |
| Reduced motion            | Respect `prefers-reduced-motion`                  |
| Form error announcements  | `aria-describedby` linking errors to fields       |
