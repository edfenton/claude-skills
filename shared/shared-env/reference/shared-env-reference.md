# Shared Env Reference

Environment variable management patterns for MERN and iOS projects.

---

## .env.example Template

```bash
# .env.example
# Copy this file to .env and fill in your values
# DO NOT commit .env to version control

# =============================================================================
# Application
# =============================================================================
NODE_ENV=development                    # development | production | test
APP_NAME=MyApp                          # Application name
APP_URL=http://localhost:3000           # Base URL for the application

# =============================================================================
# Database
# =============================================================================
MONGODB_URI=mongodb://localhost:27017/myapp   # MongoDB connection string
# For production, use MongoDB Atlas:
# MONGODB_URI=mongodb+srv://<username>:<password>@<cluster>.mongodb.net/<dbname>?retryWrites=true&w=majority

# =============================================================================
# Authentication
# =============================================================================
NEXTAUTH_URL=http://localhost:3000      # Must match APP_URL
NEXTAUTH_SECRET=                        # Generate: openssl rand -base64 32

# OAuth: Google (https://console.cloud.google.com/apis/credentials)
GOOGLE_CLIENT_ID=                       # OAuth 2.0 Client ID
GOOGLE_CLIENT_SECRET=                   # OAuth 2.0 Client Secret

# OAuth: GitHub (https://github.com/settings/developers)
GITHUB_CLIENT_ID=                       # OAuth App Client ID
GITHUB_CLIENT_SECRET=                   # OAuth App Client Secret

# =============================================================================
# External Services (Optional)
# =============================================================================
# Error Tracking
SENTRY_DSN=                             # Sentry project DSN
NEXT_PUBLIC_SENTRY_DSN=                 # Sentry DSN for client-side

# Analytics
NEXT_PUBLIC_GA_ID=                      # Google Analytics measurement ID

# Email
SMTP_HOST=                              # SMTP server host
SMTP_PORT=587                           # SMTP port (587 for TLS)
SMTP_USER=                              # SMTP username
SMTP_PASS=                              # SMTP password
EMAIL_FROM=noreply@example.com          # Default from address

# =============================================================================
# Feature Flags (Optional)
# =============================================================================
ENABLE_ANALYTICS=false                  # Enable analytics tracking
ENABLE_DEBUG_LOGGING=true               # Enable verbose logging
```

---

## Zod Schema (MERN)

```typescript
// apps/web/src/server/env.ts
import { z } from 'zod';

const EnvSchema = z.object({
  // Application
  NODE_ENV: z.enum(['development', 'production', 'test']).default('development'),
  APP_NAME: z.string().default('MyApp'),
  APP_URL: z.string().url().default('http://localhost:3000'),

  // Database
  MONGODB_URI: z.string().min(1, 'MONGODB_URI is required'),

  // Auth
  NEXTAUTH_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32, 'NEXTAUTH_SECRET must be at least 32 characters'),

  // OAuth (optional)
  GOOGLE_CLIENT_ID: z.string().optional(),
  GOOGLE_CLIENT_SECRET: z.string().optional(),
  GITHUB_CLIENT_ID: z.string().optional(),
  GITHUB_CLIENT_SECRET: z.string().optional(),

  // External services (optional)
  SENTRY_DSN: z.string().url().optional().or(z.literal('')),
  
  // Feature flags
  ENABLE_ANALYTICS: z.coerce.boolean().default(false),
  ENABLE_DEBUG_LOGGING: z.coerce.boolean().default(true),
});

export type Env = z.infer<typeof EnvSchema>;

let cachedEnv: Env | null = null;

export function env(): Env {
  if (cachedEnv) return cachedEnv;

  const parsed = EnvSchema.safeParse(process.env);

  if (!parsed.success) {
    console.error('❌ Invalid environment variables:');
    console.error(parsed.error.flatten().fieldErrors);
    throw new Error('Invalid environment variables');
  }

  cachedEnv = parsed.data;
  return cachedEnv;
}

// Validate on startup
env();
```

---

## iOS Environment Configuration

### Using xcconfig files

```
# Config/Base.xcconfig
APP_NAME = MyApp
API_TIMEOUT = 30

# Config/NonProd.xcconfig
#include "Base.xcconfig"
APP_ENVIRONMENT = non-prod
API_BASE_URL = https:/$()/api.nonprod.example.com

# Config/Prod.xcconfig
#include "Base.xcconfig"
APP_ENVIRONMENT = prod
API_BASE_URL = https:/$()/api.example.com
```

### Environment Swift file

```swift
// Services/Config/AppEnvironment.swift
import Foundation

enum AppEnvironment: String {
  case nonProd = "non-prod"
  case prod = "prod"

  static var current: AppEnvironment {
    guard let value = Bundle.main.object(forInfoDictionaryKey: "APP_ENVIRONMENT") as? String,
          let env = AppEnvironment(rawValue: value) else {
      #if DEBUG
      return .nonProd
      #else
      fatalError("APP_ENVIRONMENT not configured")
      #endif
    }
    return env
  }

  var apiBaseURL: URL {
    guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
          let url = URL(string: urlString) else {
      fatalError("API_BASE_URL not configured")
    }
    return url
  }

  var isDebug: Bool {
    self == .nonProd
  }
}
```

### Info.plist entries

```xml
<key>APP_ENVIRONMENT</key>
<string>$(APP_ENVIRONMENT)</string>
<key>API_BASE_URL</key>
<string>$(API_BASE_URL)</string>
```

---

## Validation Script

```bash
#!/bin/bash
# scripts/validate-env.sh

set -e

echo "🔍 Validating environment variables..."

MISSING=()
INVALID=()

# Required variables
REQUIRED=(
  "MONGODB_URI"
  "NEXTAUTH_URL"
  "NEXTAUTH_SECRET"
)

# Check required
for var in "${REQUIRED[@]}"; do
  if [ -z "${!var}" ]; then
    MISSING+=("$var")
  fi
done

# Format validation
if [ -n "$MONGODB_URI" ]; then
  if [[ ! "$MONGODB_URI" =~ ^mongodb(\+srv)?:// ]]; then
    INVALID+=("MONGODB_URI: must start with mongodb:// or mongodb+srv://")
  fi
fi

if [ -n "$NEXTAUTH_SECRET" ]; then
  if [ ${#NEXTAUTH_SECRET} -lt 32 ]; then
    INVALID+=("NEXTAUTH_SECRET: must be at least 32 characters")
  fi
fi

if [ -n "$NEXTAUTH_URL" ]; then
  if [[ ! "$NEXTAUTH_URL" =~ ^https?:// ]]; then
    INVALID+=("NEXTAUTH_URL: must be a valid URL")
  fi
fi

# Report
echo ""
if [ ${#MISSING[@]} -eq 0 ] && [ ${#INVALID[@]} -eq 0 ]; then
  echo "✅ All environment variables are valid!"
  exit 0
fi

if [ ${#MISSING[@]} -gt 0 ]; then
  echo "❌ Missing required variables:"
  for var in "${MISSING[@]}"; do
    echo "   - $var"
  done
fi

if [ ${#INVALID[@]} -gt 0 ]; then
  echo ""
  echo "❌ Invalid variables:"
  for msg in "${INVALID[@]}"; do
    echo "   - $msg"
  done
fi

exit 1
```

---

## Generate .env.example Script

```bash
#!/bin/bash
# scripts/generate-env-example.sh

set -e

INPUT="${1:-.env}"
OUTPUT="${2:-.env.example}"

if [ ! -f "$INPUT" ]; then
  echo "❌ $INPUT not found"
  exit 1
fi

echo "📝 Generating $OUTPUT from $INPUT..."

# Patterns that indicate secrets (redact these)
SECRET_PATTERNS=(
  "SECRET"
  "PASSWORD"
  "PASS"
  "KEY"
  "TOKEN"
  "CREDENTIAL"
  "AUTH"
  "API_KEY"
  "PRIVATE"
)

# Build regex
SECRET_REGEX=$(IFS="|"; echo "${SECRET_PATTERNS[*]}")

# Process file
while IFS= read -r line || [ -n "$line" ]; do
  # Skip empty lines and comments
  if [[ -z "$line" ]] || [[ "$line" =~ ^# ]]; then
    echo "$line"
    continue
  fi

  # Parse KEY=VALUE
  if [[ "$line" =~ ^([A-Z_][A-Z0-9_]*)=(.*)$ ]]; then
    KEY="${BASH_REMATCH[1]}"
    VALUE="${BASH_REMATCH[2]}"

    # Check if it's a secret
    if echo "$KEY" | grep -qiE "$SECRET_REGEX"; then
      echo "$KEY="
    else
      # Keep non-secret values as examples
      echo "$KEY=$VALUE"
    fi
  else
    echo "$line"
  fi
done < "$INPUT" > "$OUTPUT"

echo "✅ Generated $OUTPUT"
echo ""
echo "Review the file and add helpful comments!"
```

---

## ENV.md Documentation Template

```markdown
# Environment Variables

This document describes all environment variables used by the application.

## Required

| Variable | Description | Example |
|----------|-------------|---------|
| `MONGODB_URI` | MongoDB connection string | `mongodb://localhost:27017/myapp` |
| `NEXTAUTH_URL` | Application URL for NextAuth | `http://localhost:3000` |
| `NEXTAUTH_SECRET` | Secret for JWT signing (32+ chars) | Generate with `openssl rand -base64 32` |

## Authentication (Optional)

| Variable | Description | How to obtain |
|----------|-------------|---------------|
| `GOOGLE_CLIENT_ID` | Google OAuth client ID | [Google Cloud Console](https://console.cloud.google.com/apis/credentials) |
| `GOOGLE_CLIENT_SECRET` | Google OAuth client secret | Same as above |
| `GITHUB_CLIENT_ID` | GitHub OAuth client ID | [GitHub Developer Settings](https://github.com/settings/developers) |
| `GITHUB_CLIENT_SECRET` | GitHub OAuth client secret | Same as above |

## External Services (Optional)

| Variable | Description | Default |
|----------|-------------|---------|
| `SENTRY_DSN` | Sentry error tracking DSN | (disabled) |
| `SMTP_HOST` | Email SMTP server | (disabled) |

## Feature Flags

| Variable | Description | Default |
|----------|-------------|---------|
| `ENABLE_ANALYTICS` | Enable analytics tracking | `false` |
| `ENABLE_DEBUG_LOGGING` | Enable verbose logging | `true` in dev |

## Setup

1. Copy `.env.example` to `.env`:
   ```bash
   cp .env.example .env
   ```

2. Fill in required values

3. Validate configuration:
   ```bash
   pnpm env:validate
   ```

## Security Notes

- Never commit `.env` to version control
- Use different values for development and production
- Rotate secrets regularly
- Use a secrets manager in production (e.g., AWS Secrets Manager, Doppler)
```

---

## .gitignore Entries

```gitignore
# Environment files
.env
.env.local
.env.*.local
.env.development.local
.env.test.local
.env.production.local

# Keep examples
!.env.example
!.env.development
!.env.production
```

---

## Secret Detection Script

```bash
#!/bin/bash
# scripts/check-secrets.sh

set -e

echo "🔐 Scanning for hardcoded secrets..."

# Patterns to search for
PATTERNS=(
  'api[_-]?key\s*[:=]\s*["\x27][a-zA-Z0-9]+'
  'secret[_-]?key\s*[:=]\s*["\x27][a-zA-Z0-9]+'
  'password\s*[:=]\s*["\x27][^\s]+'
  'mongodb(\+srv)?://[^"\x27\s]+'
  'postgres://[^"\x27\s]+'
  'Bearer\s+[a-zA-Z0-9._-]+'
  'sk_live_[a-zA-Z0-9]+'
  'pk_live_[a-zA-Z0-9]+'
)

# Files to exclude
EXCLUDE=(
  ".env.example"
  "*.md"
  "package-lock.json"
  "pnpm-lock.yaml"
  ".git"
)

FOUND=0

for pattern in "${PATTERNS[@]}"; do
  results=$(grep -rniE "$pattern" . \
    --include="*.ts" \
    --include="*.tsx" \
    --include="*.js" \
    --include="*.jsx" \
    --include="*.swift" \
    --include="*.json" \
    --include="*.yml" \
    --include="*.yaml" \
    --exclude-dir=".git" \
    --exclude-dir="node_modules" \
    --exclude-dir=".next" \
    --exclude="*.example*" \
    2>/dev/null || true)

  if [ -n "$results" ]; then
    echo ""
    echo "⚠️  Potential secrets found matching: $pattern"
    echo "$results"
    FOUND=1
  fi
done

if [ $FOUND -eq 0 ]; then
  echo "✅ No hardcoded secrets detected"
else
  echo ""
  echo "❌ Review the above findings and remove any real secrets!"
  exit 1
fi
```

---

## Package.json Scripts

```json
{
  "scripts": {
    "env:validate": "./scripts/validate-env.sh",
    "env:example": "./scripts/generate-env-example.sh",
    "env:check-secrets": "./scripts/check-secrets.sh"
  }
}
```
