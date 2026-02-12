# NEAN Stack Reference

Versions, setup patterns, and deployment configuration.

---

## Recommended versions

```json
{
  "engines": {
    "node": ">=22.0.0",
    "npm": ">=10.0.0"
  },
  "dependencies": {
    "@angular/core": "^21.0.0",
    "@angular/cli": "^21.0.0",
    "@angular/animations": "^21.0.0",
    "@angular/cdk": "^21.0.0",
    "@nestjs/core": "^11.0.0",
    "@nestjs/common": "^11.0.0",
    "@nestjs/platform-express": "^11.0.0",
    "@nestjs/typeorm": "^11.0.0",
    "@nestjs/passport": "^11.0.0",
    "@nestjs/jwt": "^11.0.0",
    "@nestjs/swagger": "^11.0.0",
    "swagger-ui-express": "^5.0.0",
    "typeorm": "^0.3.20",
    "pg": "^8.11.0",
    "class-validator": "^0.14.1",
    "class-transformer": "^0.5.1",
    "passport": "^0.7.0",
    "passport-jwt": "^4.0.1",
    "@casl/ability": "^6.7.0",
    "primeng": "^21.0.0",
    "@primeuix/themes": "^21.0.0",
    "primeicons": "^7.0.0",
    "tailwindcss": "^4.0.0",
    "@tailwindcss/postcss": "^4.0.0",
    "tailwindcss-primeui": "^0.5.0",
    "@ngrx/store": "^21.0.0",
    "@ngrx/effects": "^21.0.0",
    "helmet": "^8.0.0",
    "express-rate-limit": "^8.0.0"
  },
  "devDependencies": {
    "@nx/workspace": "^22.0.0",
    "@nx/angular": "^22.0.0",
    "@nx/nest": "^22.0.0",
    "typescript": "^5.9.0",
    "eslint": "^9.8.0",
    "prettier": "^3.3.0",
    "jest": "^30.0.0",
    "@playwright/test": "^1.44.0"
  }
}
```

Update versions as appropriate; these are baseline minimums.

---

## Environment variables

### Naming convention

```bash
# Database
DATABASE_HOST=localhost
DATABASE_PORT=5432
DATABASE_USERNAME=postgres
DATABASE_PASSWORD=...
DATABASE_NAME=myapp

# Auth
JWT_SECRET=...                    # Generate with: openssl rand -base64 64
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=...
JWT_REFRESH_EXPIRES_IN=7d

# App
API_PORT=3000
API_PREFIX=api/v1
CORS_ORIGINS=http://localhost:4200

# Third-party services (as needed)
STRIPE_SECRET_KEY=...
SMTP_HOST=...
SMTP_PORT=...
```

### File structure

```
.env                    # Local dev (gitignored)
.env.example            # Template (committed)
.env.test               # Test environment (gitignored)
apps/api/.env           # API-specific overrides (gitignored)
apps/web/.env           # Web-specific (Angular env files preferred)
```

### Env validation (libs/api/common/src/config/env.validation.ts)

```typescript
import { plainToInstance } from 'class-transformer';
import { IsEnum, IsNumber, IsString, Min, validateSync } from 'class-validator';

enum Environment {
  Development = 'development',
  Production = 'production',
  Test = 'test',
}

class EnvironmentVariables {
  @IsEnum(Environment)
  NODE_ENV: Environment;

  @IsString()
  DATABASE_HOST: string;

  @IsNumber()
  @Min(1)
  DATABASE_PORT: number;

  @IsString()
  DATABASE_USERNAME: string;

  @IsString()
  DATABASE_PASSWORD: string;

  @IsString()
  DATABASE_NAME: string;

  @IsString()
  JWT_SECRET: string;

  @IsString()
  JWT_EXPIRES_IN: string;

  @IsNumber()
  @Min(1)
  API_PORT: number;
}

export function validate(config: Record<string, unknown>) {
  const validatedConfig = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(validatedConfig, {
    skipMissingProperties: false,
  });

  if (errors.length > 0) {
    throw new Error(errors.toString());
  }
  return validatedConfig;
}
```

---

## Nx workspace setup

### nx.json

Nx 22 uses a plugins-based configuration instead of explicit `targetDefaults`:

```json
{
  "$schema": "./node_modules/nx/schemas/nx-schema.json",
  "plugins": [
    { "plugin": "@nx/js/typescript", "options": { "typecheck": { "targetName": "typecheck" } } },
    { "plugin": "@nx/webpack/plugin", "options": { "buildTargetName": "build", "serveTargetName": "serve" } },
    { "plugin": "@nx/playwright/plugin", "options": { "targetName": "e2e" } },
    { "plugin": "@nx/eslint/plugin", "options": { "targetName": "lint" } },
    { "plugin": "@nx/jest/plugin", "options": { "targetName": "test" } }
  ],
  "namedInputs": {
    "default": ["{projectRoot}/**/*", "sharedGlobals"],
    "production": [
      "default",
      "!{projectRoot}/**/?(*.)+(spec|test).[jt]s?(x)?(.snap)",
      "!{projectRoot}/tsconfig.spec.json",
      "!{projectRoot}/jest.config.[jt]s"
    ],
    "sharedGlobals": []
  },
  "targetDefaults": {
    "build": { "cache": true, "dependsOn": ["^build"] }
  }
}
```

### project.json (apps/api)

Nx 22 infers most targets via plugins. The API `project.json` is minimal — build/serve/lint/test are inferred from `nx.json` plugins. The NestJS API uses a `webpack.config.js` with explicit resolve aliases for `@myapp/*` path mappings.

```json
{
  "name": "api",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "apps/api/src",
  "projectType": "application",
  "tags": []
}
```

### project.json (apps/web)

Angular projects include explicit style entries for both SCSS and CSS:

```json
{
  "name": "web",
  "$schema": "../../node_modules/nx/schemas/project-schema.json",
  "sourceRoot": "apps/web/src",
  "projectType": "application",
  "prefix": "app",
  "tags": []
}
```

> **Note:** Angular build options (styles, scripts, etc.) are configured in the Angular-specific config rather than project.json targets in Nx 22.

---

## TypeScript configuration

### tsconfig.base.json

Nx 22 uses TypeScript project references with `composite: true`:

```json
{
  "compilerOptions": {
    "composite": true,
    "declaration": true,
    "declarationMap": true,
    "importHelpers": true,
    "isolatedModules": true,
    "lib": ["es2022"],
    "module": "nodenext",
    "moduleResolution": "nodenext",
    "noEmitOnError": true,
    "noFallthroughCasesInSwitch": true,
    "noImplicitOverride": true,
    "noImplicitReturns": true,
    "noUnusedLocals": true,
    "skipLibCheck": true,
    "strict": true,
    "target": "es2022",
    "emitDecoratorMetadata": true,
    "experimentalDecorators": true,
    "strictPropertyInitialization": false,
    "baseUrl": ".",
    "paths": {
      "@myapp/shared/types": ["libs/shared/types/src/index.ts"],
      "@myapp/api/common": ["libs/api/common/src/index.ts"],
      "@myapp/api/database": ["libs/api/database/src/index.ts"]
    }
  }
}
```

> **Angular app override:** `apps/web/tsconfig.json` must set `composite: false`, `declaration: false`, `declarationMap: false`, `isolatedModules: false`, and add `"dom"` to `lib`. Angular's compiler doesn't support `emitDeclarationOnly` or project references.

---

## Webpack path aliases

NestJS API projects using Nx 22 with project references need explicit webpack resolve aliases for `@myapp/*` imports. TypeScript path mappings in `tsconfig.base.json` are not automatically resolved by webpack.

Add to `apps/api/webpack.config.js`:

```javascript
resolve: {
  alias: {
    '@myapp/api/common': join(__dirname, '../../libs/api/common/src/index.ts'),
    '@myapp/api/database': join(__dirname, '../../libs/api/database/src/index.ts'),
    '@myapp/shared/types': join(__dirname, '../../libs/shared/types/src/index.ts'),
  },
},
```

Update these aliases whenever a new library is added to the monorepo.

---

## PrimeNG 21 styling

PrimeNG 21 no longer uses CSS file imports for theming. Configure via `providePrimeNG()` in `app.config.ts`:

```typescript
import { providePrimeNG } from 'primeng/config';
import Aura from '@primeuix/themes/aura';

providePrimeNG({
  theme: {
    preset: Aura,
  },
})
```

Only `primeicons/primeicons.css` needs importing (in `styles.scss`).

---

## Tailwind CSS v4

Tailwind v4 uses `@import "tailwindcss"` in a `.css` file processed by `@tailwindcss/postcss`. Keep it in a separate `styles.css` — do NOT put it in a `.scss` file (Sass import deprecation warnings and processing conflicts).

Setup:
1. Create `apps/web/postcss.config.js` with `@tailwindcss/postcss` plugin
2. Create `apps/web/src/styles.css` with `@import "tailwindcss"`
3. Keep `apps/web/src/styles.scss` for PrimeIcons only
4. Add both `styles.scss` and `styles.css` to the Angular project's styles array

---

## Angular + Nx project references

When running Angular generators with Nx 22 TypeScript project references, set `NX_IGNORE_UNSUPPORTED_TS_SETUP=true`. Angular's compiler doesn't support `composite`/`emitDeclarationOnly` — override these in `apps/web/tsconfig.json`:

```json
{
  "extends": "../../tsconfig.base.json",
  "compilerOptions": {
    "composite": false,
    "declaration": false,
    "declarationMap": false,
    "isolatedModules": false,
    "lib": ["es2022", "dom"]
  }
}
```

---

## TypeORM configuration

### Database module (libs/api/database/src/database.module.ts)

```typescript
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ConfigModule, ConfigService } from '@nestjs/config';

@Module({
  imports: [
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      useFactory: (configService: ConfigService) => ({
        type: 'postgres',
        host: configService.get('DATABASE_HOST'),
        port: configService.get('DATABASE_PORT'),
        username: configService.get('DATABASE_USERNAME'),
        password: configService.get('DATABASE_PASSWORD'),
        database: configService.get('DATABASE_NAME'),
        autoLoadEntities: true,
        synchronize: configService.get('NODE_ENV') === 'development',
        logging: configService.get('NODE_ENV') === 'development',
        ssl: configService.get('NODE_ENV') === 'production' 
          ? { rejectUnauthorized: false } 
          : false,
      }),
      inject: [ConfigService],
    }),
  ],
})
export class DatabaseModule {}
```

### Entity example (libs/api/database/src/entities/user.entity.ts)

```typescript
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
} from 'typeorm';

@Entity('users')
export class UserEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  @Index()
  email: string;

  @Column()
  passwordHash: string;

  @Column({ nullable: true })
  firstName: string;

  @Column({ nullable: true })
  lastName: string;

  @Column({ type: 'simple-array', default: 'user' })
  roles: string[];

  @Column({ default: true })
  isActive: boolean;

  @CreateDateColumn()
  createdAt: Date;

  @UpdateDateColumn()
  updatedAt: Date;
}
```

### Migrations

```bash
# Generate migration
npx typeorm migration:generate -d apps/api/src/data-source.ts src/migrations/MigrationName

# Run migrations
npx typeorm migration:run -d apps/api/src/data-source.ts

# Revert migration
npx typeorm migration:revert -d apps/api/src/data-source.ts
```

---

## GitHub Actions CI

```yaml
# .github/workflows/ci.yml
name: CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  build:
    runs-on: ubuntu-latest

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
        with:
          fetch-depth: 0

      - name: Derive Nx SHAs
        uses: nrwl/nx-set-shas@v4

      - uses: actions/setup-node@v6
        with:
          node-version: '22'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Lint
        run: npx nx affected --target=lint --parallel=3

      - name: Test
        run: npx nx affected --target=test --parallel=3 --coverage
        env:
          DATABASE_HOST: localhost
          DATABASE_PORT: 5432
          DATABASE_USERNAME: postgres
          DATABASE_PASSWORD: postgres
          DATABASE_NAME: test

      - name: Build
        run: npx nx affected --target=build --parallel=3

      - name: E2E
        run: npx nx affected --target=e2e --parallel=1
```

---

## Deployment patterns

### Docker (recommended)

```dockerfile
# Dockerfile.api
FROM node:22-alpine AS base

FROM base AS deps
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production

FROM base AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx nx build api --prod

FROM base AS runner
WORKDIR /app
ENV NODE_ENV=production
COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist/apps/api ./dist

EXPOSE 3000
CMD ["node", "dist/main.js"]
```

```dockerfile
# Dockerfile.web
FROM node:22-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npx nx build web --prod

FROM nginx:alpine
COPY docker/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist/apps/web/browser /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  api:
    build:
      context: .
      dockerfile: docker/Dockerfile.api
    ports:
      - "3000:3000"
    environment:
      - DATABASE_HOST=db
      - DATABASE_PORT=5432
      - DATABASE_USERNAME=postgres
      - DATABASE_PASSWORD=postgres
      - DATABASE_NAME=myapp
    depends_on:
      db:
        condition: service_healthy

  web:
    build:
      context: .
      dockerfile: docker/Dockerfile.web
    ports:
      - "80:80"
    depends_on:
      - api

  db:
    image: postgres:16-alpine
    volumes:
      - postgres_data:/var/lib/postgresql/data
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=myapp
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5

volumes:
  postgres_data:
```

---

## Quick reference

| Question                         | Answer                                     |
| -------------------------------- | ------------------------------------------ |
| Package manager                  | npm (Nx default)                           |
| Node version                     | 22+                                        |
| Where do APIs go?                | `apps/api/src/modules/`                    |
| Where do shared types go?        | `libs/shared/types/`                       |
| How to reference shared library? | `@myapp/shared/types` (tsconfig paths)     |
| Env validation                   | class-validator in ConfigModule            |
| Default database                 | PostgreSQL 16+                             |
| ORM                              | TypeORM                                    |
| Migration strategy               | TypeORM CLI migrations                     |
| Default deployment               | Docker containers                          |
| When to add services             | Only if scaling/isolation requirements     |
