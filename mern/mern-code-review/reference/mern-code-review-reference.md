# MERN Code Review Reference

Checklists and common issues. Use alongside mern-std, mern-nfr, and mern-sec skills.

---

## Automated gates

### Commands

```bash
# Lint
pnpm lint

# Format check (don't auto-fix during review)
pnpm format --check
# or
pnpm prettier --check .

# Type check
pnpm typecheck
# or
pnpm tsc --noEmit

# Tests (optional, if fast)
pnpm test
```

### Common lint issues

| Issue                                | Fix                                      |
| ------------------------------------ | ---------------------------------------- |
| `@typescript-eslint/no-explicit-any` | Replace with proper type or `unknown`    |
| `@typescript-eslint/no-unused-vars`  | Remove or prefix with `_`                |
| `import/order`                       | Run `pnpm lint --fix`                    |
| `react-hooks/exhaustive-deps`        | Add missing deps or justify with comment |

---

## Standards review checklist (mern-std)

### Project structure

- [ ] API routes in `apps/web/src/app/api/`
- [ ] Shared schemas in `packages/shared/`
- [ ] Server-only code in `apps/web/src/server/`
- [ ] No server code imported in client components

### TypeScript

- [ ] No `any` without justification
- [ ] Explicit types at module boundaries (exports, API handlers)
- [ ] Types inferred from Zod schemas, not duplicated

### API routes

- [ ] Input validated with Zod at boundary
- [ ] Consistent response envelope
- [ ] Pagination on list endpoints
- [ ] Error responses don't leak internals

### Mongoose

- [ ] Schemas have `timestamps: true`
- [ ] Indexes documented with reason
- [ ] No raw user input in queries

### Naming

- [ ] Folders: kebab-case
- [ ] React components: PascalCase.tsx
- [ ] Utilities: camelCase.ts

---

## NFR review checklist (mern-nfr)

### Performance

- [ ] No N+1 queries
- [ ] Large lists paginated
- [ ] Expensive operations have timeouts
- [ ] Images optimized / lazy loaded

### Reliability

- [ ] Errors handled, not swallowed
- [ ] Retry logic is idempotent
- [ ] Graceful degradation for optional features

### Observability

- [ ] Key operations logged
- [ ] No PII/secrets in logs
- [ ] Correlation IDs where applicable

### Accessibility

- [ ] Interactive elements keyboard accessible
- [ ] Color not sole indicator
- [ ] Reasonable contrast

---

## Security review checklist (mern-sec)

### Input validation

- [ ] All API inputs validated with Zod
- [ ] File uploads validated (type, size)
- [ ] Query params sanitized

### NoSQL injection

- [ ] No `$`-prefixed keys from user input
- [ ] No dot-notation keys from user input
- [ ] Sanitization helper used consistently

### Authentication/Authorization

- [ ] Protected routes check auth
- [ ] Resource ownership verified
- [ ] Tokens in httpOnly cookies (not localStorage)

### Error handling

- [ ] No stack traces in responses
- [ ] No internal details leaked
- [ ] Generic messages for auth failures

### Dependencies

- [ ] No known critical vulnerabilities (`pnpm audit`)
- [ ] Lockfile committed

---

## Common issues by category

### Security (must-fix)

**Unsanitized MongoDB query**

```typescript
// ❌ Bad
const user = await User.findOne(req.body);

// ✅ Good
const { email } = UserQuerySchema.parse(req.body);
const user = await User.findOne({ email });
```

**Stack trace in response**

```typescript
// ❌ Bad
catch (error) {
  return Response.json({ error: error.message, stack: error.stack }, { status: 500 });
}

// ✅ Good
catch (error) {
  console.error(error);
  return Response.json({ error: 'Internal server error' }, { status: 500 });
}
```

**Token in localStorage**

```typescript
// ❌ Bad
localStorage.setItem("token", jwt);

// ✅ Good: use httpOnly cookie set by server
```

### Standards (should-fix)

**Type duplication**

```typescript
// ❌ Bad: manual interface
interface CreateUserInput {
  email: string;
  name: string;
}

// ✅ Good: infer from Zod
const CreateUserSchema = z.object({
  email: z.string().email(),
  name: z.string().min(1),
});
type CreateUserInput = z.infer<typeof CreateUserSchema>;
```

**Missing input validation**

```typescript
// ❌ Bad
export async function POST(req: Request) {
  const body = await req.json();
  await createUser(body);
}

// ✅ Good
export async function POST(req: Request) {
  const body = await req.json();
  const input = CreateUserSchema.parse(body);
  await createUser(input);
}
```

**Wrong file location**

```typescript
// ❌ Bad: Zod schema in apps/web
// apps/web/src/schemas/user.ts

// ✅ Good: Zod schema in shared package
// packages/shared/schemas/user.ts
```

### NFR (should-fix)

**Missing pagination**

```typescript
// ❌ Bad
const items = await Item.find({});
return Response.json({ items });

// ✅ Good
const { cursor, limit } = PaginationSchema.parse(req.query);
const items = await Item.find(cursor ? { _id: { $gt: cursor } } : {})
  .limit(limit + 1)
  .sort({ _id: 1 });
```

**N+1 query**

```typescript
// ❌ Bad
const orders = await Order.find({ userId });
for (const order of orders) {
  order.items = await OrderItem.find({ orderId: order._id });
}

// ✅ Good
const orders = await Order.find({ userId });
const orderIds = orders.map((o) => o._id);
const items = await OrderItem.find({ orderId: { $in: orderIds } });
// Group items by orderId...
```

**Swallowed error**

```typescript
// ❌ Bad
try {
  await riskyOperation();
} catch {
  // Silent failure
}

// ✅ Good
try {
  await riskyOperation();
} catch (error) {
  logger.error("Operation failed", { error });
  throw new AppError("OPERATION_FAILED", "Unable to complete operation");
}
```

---

## Report template

```
## Code Review Results

### Automated Gates
| Check | Status |
|-------|--------|
| Lint | ✅ Pass |
| Format | ❌ Fail (3 files) |
| Typecheck | ✅ Pass |

### Policy Review
| Category | Must-fix | Should-fix | Nice-to-have |
|----------|----------|------------|--------------|
| Security | 1 | 0 | 0 |
| Standards | 0 | 4 | 2 |
| NFR | 0 | 2 | 1 |

### Must-fix Issues

#### [sec] Unsanitized MongoDB query
**File:** `apps/web/src/app/api/users/route.ts:23`
**Issue:** User input passed directly to `findOne()` without sanitization
**Fix:** Use Zod schema and sanitize input before query

### Should-fix Issues

#### [std] Type not inferred from Zod
**File:** `apps/web/src/types/user.ts:5`
**Issue:** Manual interface duplicates Zod schema
**Fix:** Use `z.infer<typeof CreateUserSchema>` instead

...
```

---

## Quick reference

| Task               | Command               |
| ------------------ | --------------------- |
| Lint               | `pnpm lint`           |
| Lint with auto-fix | `pnpm lint --fix`     |
| Format check       | `pnpm format --check` |
| Format fix         | `pnpm format`         |
| Type check         | `pnpm typecheck`      |
| Security audit     | `pnpm audit`          |
| Run tests          | `pnpm test`           |
