# MERN Security Reference

Detailed implementation patterns for OWASP Top 10 and CWE mitigations. Load when implementing specific security controls.

---

## OWASP Top 10:2025 — MERN mitigations

### A01: Broken Access Control

- Check authorization in route handlers, not just UI
- Verify resource ownership in Mongoose queries:

```typescript
// Bad: trusts client-provided ID
const doc = await Model.findById(req.params.id);

// Good: scoped to authenticated user
const doc = await Model.findOne({ _id: req.params.id, userId: req.user.id });
```

- Use middleware for role checks; fail closed

### A02: Cryptographic Failures

- Passwords: bcrypt with cost factor 12+
- JWTs: RS256 for distributed systems, HS256 + secure rotation for single-service
- Never store secrets in code or localStorage
- Use HTTPS everywhere; set `secure` flag on cookies

### A03: Injection (including NoSQL)

- Sanitize user input before MongoDB queries:

```typescript
// Strip dangerous keys
function sanitizeInput(obj: Record<string, unknown>) {
  return Object.fromEntries(
    Object.entries(obj).filter(
      ([key]) => !key.startsWith("$") && !key.includes("."),
    ),
  );
}
```

- Use Mongoose schemas with strict: true
- Parameterize aggregation pipelines; never interpolate user input

### A04: Insecure Design

- Threat model auth flows before building
- Rate limit password reset, login, and registration
- Implement account lockout after failed attempts

### A05: Security Misconfiguration

- Remove default credentials and sample code
- Disable X-Powered-By header in Express
- Set security headers (helmet.js or Next.js config):

```typescript
// next.config.js
headers: [
  { key: "X-Content-Type-Options", value: "nosniff" },
  { key: "X-Frame-Options", value: "DENY" },
  { key: "Referrer-Policy", value: "strict-origin-when-cross-origin" },
];
```

### A06: Vulnerable Components

- Run `npm audit` in CI; fail on critical/high
- Pin dependencies in package-lock.json
- Review transitive dependencies periodically

### A07: Authentication Failures

- Use established libraries (NextAuth, Passport)
- Secure session config:

```typescript
  cookie: {
    httpOnly: true,
    secure: process.env.NODE_ENV === 'production',
    sameSite: 'strict',
    maxAge: 60 * 60 * 24 // 24 hours
  }
```

- Invalidate sessions on password change

### A08: Data Integrity Failures

- Verify webhook signatures
- Use SRI for external scripts
- Sign and verify JWTs; check `iss` and `aud` claims

### A09: Logging Failures

- Log auth events: login, logout, failed attempts, password changes
- Never log: passwords, tokens, PII, full request bodies
- Include correlation IDs for tracing

### A10: SSRF

- Validate and allowlist URLs before fetching
- Don't allow user input to control internal service URLs
- Use network segmentation for internal services

---

## CWE mitigations — MERN patterns

### CWE-20: Input Validation

```typescript
import { z } from "zod";

const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(["user", "admin"]).default("user"),
});

// In route handler
const result = CreateUserSchema.safeParse(req.body);
if (!result.success) {
  return res
    .status(400)
    .json({ error: "Invalid input", details: result.error.flatten() });
}
```

### CWE-79: XSS

```tsx
// Bad: renders raw HTML
<div dangerouslySetInnerHTML={{ __html: userInput }} />

// Good: React escapes by default
<div>{userInput}</div>

// If HTML required, sanitize first
import DOMPurify from 'dompurify';
<div dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(userInput) }} />
```

### CWE-352: CSRF

```typescript
// Next.js API route with CSRF token
import { createCsrfToken, validateCsrfToken } from "@/lib/csrf";

// GET: issue token
export async function GET(req: Request) {
  const token = createCsrfToken(req);
  return Response.json({ csrfToken: token });
}

// POST: validate token
export async function POST(req: Request) {
  const body = await req.json();
  if (!validateCsrfToken(req, body.csrfToken)) {
    return Response.json({ error: "Invalid CSRF token" }, { status: 403 });
  }
  // proceed...
}
```

### CWE-862: Missing Authorization

```typescript
// Middleware pattern
function requireOwnership(model: Model<any>) {
  return async (req: Request, res: Response, next: NextFunction) => {
    const doc = await model.findById(req.params.id);
    if (!doc) return res.status(404).json({ error: "Not found" });
    if (doc.userId.toString() !== req.user.id) {
      return res.status(403).json({ error: "Forbidden" });
    }
    req.resource = doc;
    next();
  };
}
```

### CWE-770: Resource Exhaustion

```typescript
// Express rate limiting
import rateLimit from "express-rate-limit";

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max: 5, // 5 attempts
  message: { error: "Too many attempts, try again later" },
});

app.post("/api/login", authLimiter, loginHandler);
```

### CWE-200: Information Exposure

```typescript
// Safe error envelope
function errorHandler(
  err: Error,
  req: Request,
  res: Response,
  next: NextFunction,
) {
  console.error(err); // log full error server-side

  res.status(500).json({
    error: "Internal server error",
    requestId: req.id, // for support correlation
    // Never include: err.message, err.stack, internal details
  });
}
```

---

## Quick checklist

| Concern         | Check                                          |
| --------------- | ---------------------------------------------- |
| NoSQL injection | `$` and `.` keys stripped from input           |
| XSS             | No raw HTML; dangerouslySetInnerHTML sanitized |
| CSRF            | Token validation on state-changing requests    |
| Auth            | httpOnly cookies; secure flag in prod          |
| Authz           | Ownership check in route handler               |
| Rate limiting   | On login, registration, expensive endpoints    |
| Errors          | Safe envelope; no stack traces                 |
| Logging         | Auth events logged; no secrets/PII             |
| Deps            | Lockfile committed; npm audit clean            |
