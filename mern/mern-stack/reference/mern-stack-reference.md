# MERN Stack Reference

Versions, setup patterns, and deployment configuration.

---

## Recommended versions

```json
{
  "engines": {
    "node": ">=22.0.0",
    "pnpm": ">=10.0.0"
  },
  "dependencies": {
    "next": "^16.0",
    "react": "^19.0",
    "react-dom": "^19.0",
    "mongoose": "^8.4",
    "zod": "^3.23"
  },
  "devDependencies": {
    "@types/node": "^22",
    "typescript": "^5.4",
    "eslint": "^9.0",
    "prettier": "^3.3",
    "vitest": "^4.0",
    "@vitest/coverage-v8": "^4.0",
    "@testing-library/react": "^16.0",
    "@testing-library/jest-dom": "^6.5",
    "@testing-library/user-event": "^14.5",
    "jsdom": "^27.0",
    "@playwright/test": "^1.48"
  }
}
```

Update versions as appropriate; these are baseline minimums.

---

## Environment variables

### Naming convention

```bash
# Database
DATABASE_URL=mongodb+srv://...

# Auth
NEXTAUTH_URL=https://...
NEXTAUTH_SECRET=...

# Third-party services
STRIPE_SECRET_KEY=...
STRIPE_WEBHOOK_SECRET=...

# Feature flags (optional)
FEATURE_NEW_DASHBOARD=true
```

### File structure

```
.env.local          # Local dev (gitignored)
.env.example        # Template (committed)
.env.test           # Test environment (gitignored)
```

### Env validation (apps/web/src/env.ts)

```typescript
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]),
  DATABASE_URL: z.string().url(),
  NEXTAUTH_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
});

export const env = envSchema.parse(process.env);
```

---

## pnpm workspace setup

### pnpm-workspace.yaml

```yaml
packages:
  - "apps/*"
  - "packages/*"
```

### Root package.json

```json
{
  "name": "my-app",
  "private": true,
  "packageManager": "pnpm@10.5.2",
  "scripts": {
    "dev": "turbo run dev",
    "build": "turbo run build",
    "lint": "eslint .",
    "lint:fix": "eslint . --fix",
    "format": "prettier --check .",
    "format:write": "prettier --write .",
    "test": "turbo run test",
    "test:e2e": "turbo run test:e2e",
    "typecheck": "turbo run typecheck"
  },
  "pnpm": {
    "onlyBuiltDependencies": ["husky"]
  }
}
```

### apps/web/package.json

```json
{
  "name": "web",
  "dependencies": {
    "@repo/shared": "workspace:*"
  }
}
```

### packages/shared/package.json

```json
{
  "name": "@repo/shared",
  "main": "./src/index.ts",
  "types": "./src/index.ts"
}
```

---

## TypeScript configuration

### Root tsconfig.json

```json
{
  "compilerOptions": {
    "target": "ES2022",
    "lib": ["ES2022", "DOM", "DOM.Iterable"],
    "module": "ESNext",
    "moduleResolution": "bundler",
    "strict": true,
    "noEmit": true,
    "esModuleInterop": true,
    "skipLibCheck": true,
    "resolveJsonModule": true,
    "isolatedModules": true
  }
}
```

### apps/web/tsconfig.json

```json
{
  "extends": "../../tsconfig.json",
  "compilerOptions": {
    "jsx": "preserve",
    "plugins": [{ "name": "next" }],
    "paths": {
      "@/*": ["./src/*"],
      "@repo/shared": ["../../packages/shared/src"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx"],
  "exclude": ["node_modules"]
}
```

---

## MongoDB connection

### Connection utility

```typescript
// apps/web/src/server/db/connection.ts
import mongoose from "mongoose";
import { env } from "@/env";

const MONGODB_URI = env.DATABASE_URL;

let cached = global.mongoose;

if (!cached) {
  cached = global.mongoose = { conn: null, promise: null };
}

export async function connectDB() {
  if (cached.conn) {
    return cached.conn;
  }

  if (!cached.promise) {
    cached.promise = mongoose.connect(MONGODB_URI, {
      bufferCommands: false,
    });
  }

  cached.conn = await cached.promise;
  return cached.conn;
}
```

### Global type declaration

```typescript
// apps/web/src/types/global.d.ts
import mongoose from "mongoose";

declare global {
  var mongoose: {
    conn: typeof mongoose | null;
    promise: Promise<typeof mongoose> | null;
  };
}
```

---

## GitHub Actions CI

> **Canonical template:** `mern-scaffold/templates/.github/workflows/ci.yml`. This code block is for reference.

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-test-build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v6

      # No version specified - reads from packageManager in package.json
      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "pnpm"

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Format check
        run: pnpm format

      - name: Type check
        run: pnpm typecheck

      - name: Test
        run: pnpm test

      - name: Build
        run: pnpm build

  e2e:
    runs-on: ubuntu-latest
    needs: lint-test-build

    env:
      CI: true
      MONGODB_URI: mongodb://localhost:27017/test

    services:
      mongodb:
        image: mongo:7
        ports:
          - 27017:27017
        options: >-
          --health-cmd "mongosh --eval 'db.runCommand({ping:1})'"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v6

      - uses: pnpm/action-setup@v4

      - uses: actions/setup-node@v6
        with:
          node-version: "22"
          cache: "pnpm"

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Install Playwright browsers
        run: pnpm --filter web exec playwright install --with-deps chromium

      # Turbo filters env vars — write .env.local so Next.js sees MONGODB_URI
      - name: Create env file for Next.js
        run: echo "MONGODB_URI=$MONGODB_URI" > apps/web/.env.local

      - name: Build
        run: pnpm build

      - name: Run E2E tests
        run: pnpm test:e2e
```

---

## E2E testing with Playwright

### Install browsers (required before running e2e tests)

```bash
pnpm exec playwright install chromium
```

### Run e2e tests

```bash
pnpm test:e2e
```

### CI with e2e tests

Add to GitHub Actions after build step:

```yaml
      - run: pnpm exec playwright install chromium
      - run: pnpm test:e2e
```

---

## Deployment patterns

### Vercel (recommended for Next.js)

```json
// vercel.json (usually not needed)
{
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install"
}
```

Environment variables set in Vercel dashboard.

### AWS (if required)

- **Compute:** AWS Lambda via SST or Serverless Framework
- **Database:** MongoDB Atlas (preferred) or DocumentDB
- **Secrets:** AWS Secrets Manager or Parameter Store
- **CDN:** CloudFront

### Docker (only if forced)

```dockerfile
# Dockerfile
FROM node:22-alpine AS base
RUN corepack enable pnpm

FROM base AS deps
WORKDIR /app
COPY pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json ./apps/web/
COPY packages/shared/package.json ./packages/shared/
RUN pnpm install --frozen-lockfile

FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=builder /app/apps/web/.next/standalone ./
COPY --from=builder /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=builder /app/apps/web/public ./apps/web/public

EXPOSE 3000
CMD ["node", "apps/web/server.js"]
```

---

## Quick reference

| Question                         | Answer                                |
| -------------------------------- | ------------------------------------- |
| Package manager                  | pnpm 10+                             |
| Node version                     | 22+                                   |
| Where do APIs go?                | `apps/web/src/app/api/`               |
| Where do shared schemas go?      | `packages/shared/`                    |
| How to reference shared package? | `workspace:*`                         |
| Env validation                   | Zod schema in `src/env.ts`            |
| Default deployment               | Vercel                                |
| When to containerize             | Only if deployment target requires it |
