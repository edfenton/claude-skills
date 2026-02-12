# MERN Deploy Reference

Platform-specific deployment configurations and checklists.

---

## Vercel Deployment

### Configuration

```json
// vercel.json
{
  "buildCommand": "pnpm build",
  "installCommand": "pnpm install",
  "framework": "nextjs",
  "regions": ["iad1"],
  "env": {
    "MONGODB_URI": "@mongodb_uri",
    "NEXTAUTH_SECRET": "@nextauth_secret",
    "NEXTAUTH_URL": "@nextauth_url"
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "X-Content-Type-Options", "value": "nosniff" },
        { "key": "X-Frame-Options", "value": "DENY" }
      ]
    }
  ]
}
```

### Deploy Commands

```bash
# Install Vercel CLI
pnpm add -g vercel

# Login
vercel login

# Deploy preview
vercel

# Deploy production
vercel --prod

# Set environment variables
vercel env add MONGODB_URI production
vercel env add NEXTAUTH_SECRET production
vercel env add NEXTAUTH_URL production
```

### Environment Variables in Vercel Dashboard
1. Go to Project Settings → Environment Variables
2. Add all variables from `.env.example`
3. Set appropriate environments (Production, Preview, Development)

---

## Docker Deployment

### Dockerfile

```dockerfile
# Dockerfile
FROM node:20-alpine AS base
# Enable corepack - it will use the pnpm version from packageManager in package.json
RUN corepack enable pnpm

# Dependencies
FROM base AS deps
WORKDIR /app
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml ./
COPY apps/web/package.json ./apps/web/
COPY packages/shared/package.json ./packages/shared/
RUN pnpm install --frozen-lockfile

# Builder
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY --from=deps /app/apps/web/node_modules ./apps/web/node_modules
COPY --from=deps /app/packages/shared/node_modules ./packages/shared/node_modules
COPY . .

ENV NEXT_TELEMETRY_DISABLED=1
ENV NODE_ENV=production

RUN pnpm build

# Runner
FROM base AS runner
WORKDIR /app

ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1

RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs

COPY --from=builder /app/apps/web/public ./apps/web/public
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/apps/web/.next/static ./apps/web/.next/static

USER nextjs

EXPOSE 3000
ENV PORT=3000
ENV HOSTNAME="0.0.0.0"

CMD ["node", "apps/web/server.js"]
```

### Next.js Config for Standalone

```javascript
// apps/web/next.config.mjs
/** @type {import('next').NextConfig} */
const nextConfig = {
  output: 'standalone',
  // ... other config
};

export default nextConfig;
```

### Docker Compose

```yaml
# docker-compose.yml
version: '3.8'

services:
  web:
    build: .
    ports:
      - "3000:3000"
    environment:
      - NODE_ENV=production
      - MONGODB_URI=${MONGODB_URI}
      - NEXTAUTH_SECRET=${NEXTAUTH_SECRET}
      - NEXTAUTH_URL=${NEXTAUTH_URL}
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:3000/api/health"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### .dockerignore

```
node_modules
.next
.git
.gitignore
*.md
.env*
!.env.example
coverage
.turbo
```

### Build and Run

```bash
# Build
docker build -t myapp:latest .

# Run
docker run -p 3000:3000 --env-file .env.production myapp:latest

# With compose
docker-compose up -d
```

---

## AWS Deployment (Serverless)

### serverless.yml

```yaml
# serverless.yml
service: myapp

frameworkVersion: '3'

provider:
  name: aws
  runtime: nodejs20.x
  region: us-east-1
  memorySize: 1024
  timeout: 30
  environment:
    NODE_ENV: production
    MONGODB_URI: ${ssm:/myapp/mongodb-uri}
    NEXTAUTH_SECRET: ${ssm:/myapp/nextauth-secret}
    NEXTAUTH_URL: ${ssm:/myapp/nextauth-url}

functions:
  web:
    handler: apps/web/.next/serverless/handler.handler
    events:
      - http:
          path: /
          method: ANY
      - http:
          path: /{proxy+}
          method: ANY

plugins:
  - serverless-nextjs-plugin

custom:
  serverless-nextjs:
    nextConfigDir: ./apps/web
```

### SSM Parameters

```bash
# Store secrets in AWS SSM Parameter Store
aws ssm put-parameter \
  --name "/myapp/mongodb-uri" \
  --value "mongodb+srv://..." \
  --type SecureString

aws ssm put-parameter \
  --name "/myapp/nextauth-secret" \
  --value "your-secret" \
  --type SecureString
```

---

## MongoDB Atlas Setup

### Create Cluster
1. Go to [MongoDB Atlas](https://cloud.mongodb.com/)
2. Create new cluster (M0 free tier for dev, M10+ for production)
3. Choose region close to your deployment

### Configure Access
1. Database Access → Add Database User
   - Username/password authentication
   - Built-in role: `readWriteAnyDatabase` for dev
   - Custom role with minimal permissions for production
2. Network Access → Add IP Address
   - `0.0.0.0/0` for serverless (Vercel, Lambda)
   - Specific IPs for VPC-based deployments

### Connection String
```
mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<database>?retryWrites=true&w=majority
```

---

## Security Headers

```typescript
// apps/web/next.config.mjs
const securityHeaders = [
  {
    key: 'X-DNS-Prefetch-Control',
    value: 'on',
  },
  {
    key: 'Strict-Transport-Security',
    value: 'max-age=63072000; includeSubDomains; preload',
  },
  {
    key: 'X-Content-Type-Options',
    value: 'nosniff',
  },
  {
    key: 'X-Frame-Options',
    value: 'DENY',
  },
  {
    key: 'X-XSS-Protection',
    value: '1; mode=block',
  },
  {
    key: 'Referrer-Policy',
    value: 'strict-origin-when-cross-origin',
  },
  {
    key: 'Permissions-Policy',
    value: 'camera=(), microphone=(), geolocation=()',
  },
  {
    key: 'Content-Security-Policy',
    value: "default-src 'self'; script-src 'self' 'unsafe-eval' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' https:;",
  },
];

/** @type {import('next').NextConfig} */
const nextConfig = {
  async headers() {
    return [
      {
        source: '/:path*',
        headers: securityHeaders,
      },
    ];
  },
};
```

---

## Error Tracking (Sentry)

### Install

```bash
pnpm add @sentry/nextjs --filter=web
npx @sentry/wizard@latest -i nextjs
```

### Configuration

```javascript
// sentry.client.config.ts
import * as Sentry from '@sentry/nextjs';

Sentry.init({
  dsn: process.env.NEXT_PUBLIC_SENTRY_DSN,
  environment: process.env.NODE_ENV,
  tracesSampleRate: process.env.NODE_ENV === 'production' ? 0.1 : 1.0,
  enabled: process.env.NODE_ENV === 'production',
});
```

---

## Health Check Endpoint

```typescript
// apps/web/src/app/api/health/route.ts
import { NextResponse } from 'next/server';
import { connectMongoose } from '@/server/db/mongoose';

export async function GET() {
  try {
    // Check database connection
    const mongoose = await connectMongoose();
    const dbStatus = mongoose.connection.readyState === 1 ? 'connected' : 'disconnected';

    return NextResponse.json({
      ok: true,
      data: {
        status: 'ok',
        timestamp: new Date().toISOString(),
        database: dbStatus,
        version: process.env.npm_package_version || 'unknown',
      },
    });
  } catch (error) {
    return NextResponse.json(
      {
        ok: false,
        error: { code: 'HEALTH_CHECK_FAILED', message: 'Service unhealthy' },
      },
      { status: 503 }
    );
  }
}
```

---

## Pre-deployment Checklist Script

```bash
#!/bin/bash
# scripts/pre-deploy-check.sh

set -e

echo "🔍 Running pre-deployment checks..."

# Build check
echo "📦 Checking build..."
pnpm build || { echo "❌ Build failed"; exit 1; }
echo "✅ Build passed"

# Type check
echo "📝 Checking types..."
pnpm tsc --noEmit || { echo "❌ Type check failed"; exit 1; }
echo "✅ Types passed"

# Lint check
echo "🔍 Checking lint..."
pnpm lint || { echo "❌ Lint failed"; exit 1; }
echo "✅ Lint passed"

# Test check
echo "🧪 Running tests..."
pnpm test || { echo "❌ Tests failed"; exit 1; }
echo "✅ Tests passed"

# Env check
echo "🔐 Checking environment..."
required_vars=("MONGODB_URI" "NEXTAUTH_SECRET" "NEXTAUTH_URL")
for var in "${required_vars[@]}"; do
  if [ -z "${!var}" ]; then
    echo "⚠️  Warning: $var is not set"
  fi
done

echo ""
echo "✅ All pre-deployment checks passed!"
echo "Ready to deploy."
```
