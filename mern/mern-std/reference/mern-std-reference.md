# MERN Coding Standards Reference

Detailed patterns and examples. Load when implementing specific features.

---

## API Route Handler Template

```typescript
// apps/web/src/app/api/users/route.ts
import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import { CreateUserSchema } from "@repo/shared/schemas/user";
import { createUser } from "@/server/services/user";
import { mapErrorToResponse } from "@/server/utils/errors";
import { withRateLimit } from "@/server/middleware/rate-limit";

export async function POST(req: NextRequest) {
  try {
    const body = await req.json();
    const input = CreateUserSchema.parse(body);
    const user = await createUser(input);

    return NextResponse.json({
      success: true,
      data: user,
    });
  } catch (error) {
    return mapErrorToResponse(error);
  }
}
```

## JSON Response Envelope

```typescript
// Success
{
  success: true,
  data: T,
  meta?: { cursor?: string, total?: number }
}

// Error
{
  success: false,
  error: {
    code: string,      // e.g., "VALIDATION_ERROR", "NOT_FOUND"
    message: string,   // User-safe message
    details?: unknown  // Optional field-level errors for validation
  }
}
```

## Pagination Pattern

```typescript
// Cursor-based (preferred for large datasets)
const PaginatedRequestSchema = z.object({
  cursor: z.string().optional(),
  limit: z.number().min(1).max(100).default(20),
});

// In handler
const { cursor, limit } = PaginatedRequestSchema.parse(req.query);
const query = cursor ? { _id: { $gt: cursor } } : {};
const items = await Model.find(query)
  .limit(limit + 1)
  .sort({ _id: 1 });

const hasMore = items.length > limit;
const results = hasMore ? items.slice(0, -1) : items;
const nextCursor = hasMore ? results[results.length - 1]._id : undefined;

return { data: results, meta: { cursor: nextCursor, hasMore } };
```

---

## Shared Zod Schemas

```typescript
// packages/shared/schemas/user.ts
import { z } from "zod";

export const CreateUserSchema = z.object({
  email: z.string().email().max(255),
  name: z.string().min(1).max(100),
  role: z.enum(["user", "admin"]).default("user"),
});

export type CreateUserInput = z.infer<typeof CreateUserSchema>;

export const UserResponseSchema = z.object({
  id: z.string(),
  email: z.string(),
  name: z.string(),
  role: z.enum(["user", "admin"]),
  createdAt: z.string().datetime(),
});

export type UserResponse = z.infer<typeof UserResponseSchema>;
```

---

## Mongoose Model Pattern

```typescript
// apps/web/src/server/db/models/user.ts
import mongoose, { Schema, Document } from "mongoose";

export interface IUser extends Document {
  email: string;
  name: string;
  role: "user" | "admin";
  createdAt: Date;
  updatedAt: Date;
}

const userSchema = new Schema<IUser>(
  {
    email: {
      type: String,
      required: true,
      unique: true,
      lowercase: true,
      trim: true,
    },
    name: {
      type: String,
      required: true,
      trim: true,
      maxlength: 100,
    },
    role: {
      type: String,
      enum: ["user", "admin"],
      default: "user",
    },
  },
  {
    timestamps: true,
  },
);

// Index for email lookups (unique constraint)
userSchema.index({ email: 1 });

// Index for listing users by role, sorted by creation
// Used by: admin user list, role-based queries
userSchema.index({ role: 1, createdAt: -1 });

export const User =
  mongoose.models.User || mongoose.model<IUser>("User", userSchema);
```

## Input Sanitization

```typescript
// apps/web/src/server/utils/sanitize.ts

/**
 * Strips MongoDB operator keys ($-prefixed) and dot notation
 * to prevent NoSQL injection
 */
export function sanitizeInput<T extends Record<string, unknown>>(
  obj: T,
): Partial<T> {
  const result: Record<string, unknown> = {};

  for (const [key, value] of Object.entries(obj)) {
    if (key.startsWith("$") || key.includes(".")) {
      continue; // Skip dangerous keys
    }

    if (value && typeof value === "object" && !Array.isArray(value)) {
      result[key] = sanitizeInput(value as Record<string, unknown>);
    } else {
      result[key] = value;
    }
  }

  return result as Partial<T>;
}
```

---

## Error Handling

```typescript
// apps/web/src/server/utils/errors.ts
import { NextResponse } from "next/server";
import { ZodError } from "zod";

// Typed error classes
export class AppError extends Error {
  constructor(
    public code: string,
    message: string,
    public status: number = 500,
  ) {
    super(message);
  }
}

export class ValidationError extends AppError {
  constructor(
    message: string,
    public details?: unknown,
  ) {
    super("VALIDATION_ERROR", message, 400);
  }
}

export class NotFoundError extends AppError {
  constructor(resource: string) {
    super("NOT_FOUND", `${resource} not found`, 404);
  }
}

export class ForbiddenError extends AppError {
  constructor(message = "Access denied") {
    super("FORBIDDEN", message, 403);
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super("CONFLICT", message, 409);
  }
}

// Error-to-response mapper
export function mapErrorToResponse(error: unknown): NextResponse {
  // Log full error server-side
  console.error("[API Error]", error);

  if (error instanceof ZodError) {
    return NextResponse.json(
      {
        success: false,
        error: {
          code: "VALIDATION_ERROR",
          message: "Invalid input",
          details: error.flatten(),
        },
      },
      { status: 400 },
    );
  }

  if (error instanceof AppError) {
    return NextResponse.json(
      {
        success: false,
        error: {
          code: error.code,
          message: error.message,
        },
      },
      { status: error.status },
    );
  }

  // Unknown error — safe generic response
  return NextResponse.json(
    {
      success: false,
      error: {
        code: "INTERNAL_ERROR",
        message: "An unexpected error occurred",
      },
    },
    { status: 500 },
  );
}
```

---

## Environment Module

```typescript
// apps/web/src/env.ts
import { z } from "zod";

const envSchema = z.object({
  NODE_ENV: z.enum(["development", "production", "test"]),
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),
});

export const env = envSchema.parse(process.env);
```

---

## Testing Patterns

### Unit Test Example

```typescript
// apps/web/src/server/utils/__tests__/sanitize.test.ts
import { sanitizeInput } from "../sanitize";

describe("sanitizeInput", () => {
  it("removes $-prefixed keys", () => {
    const input = { name: "test", $where: "malicious" };
    expect(sanitizeInput(input)).toEqual({ name: "test" });
  });

  it("removes dot-notation keys", () => {
    const input = { name: "test", "nested.key": "bad" };
    expect(sanitizeInput(input)).toEqual({ name: "test" });
  });

  it("recursively sanitizes nested objects", () => {
    const input = { user: { name: "test", $gt: 1 } };
    expect(sanitizeInput(input)).toEqual({ user: { name: "test" } });
  });

  it("preserves safe keys and values", () => {
    const input = { email: "test@example.com", count: 5 };
    expect(sanitizeInput(input)).toEqual(input);
  });
});
```

### Validation Test Example

```typescript
// packages/shared/schemas/__tests__/user.test.ts
import { CreateUserSchema } from "../user";

describe("CreateUserSchema", () => {
  it("accepts valid input", () => {
    const input = { email: "test@example.com", name: "Test User" };
    expect(() => CreateUserSchema.parse(input)).not.toThrow();
  });

  it("rejects invalid email", () => {
    const input = { email: "not-an-email", name: "Test" };
    expect(() => CreateUserSchema.parse(input)).toThrow();
  });

  it("defaults role to user", () => {
    const input = { email: "test@example.com", name: "Test" };
    const result = CreateUserSchema.parse(input);
    expect(result.role).toBe("user");
  });
});
```

---

## Quick Reference

| Item             | Location                             |
| ---------------- | ------------------------------------ |
| Shared schemas   | `packages/shared/schemas/`           |
| Shared types     | `packages/shared/types/`             |
| API routes       | `apps/web/src/app/api/**/route.ts`   |
| Server utilities | `apps/web/src/server/`               |
| Mongoose models  | `apps/web/src/server/db/models/`     |
| UI components    | `apps/web/src/components/`           |
| Env config       | `apps/web/src/env.ts`                |
