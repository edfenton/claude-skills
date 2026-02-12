# NEAN Code Review Reference

Checklists and common issues. Use alongside nean-std, nean-nfr, and nean-sec skills.

---

## Automated gates

### Commands

```bash
# Lint
npm run lint
# or via Nx
npx nx run-many --target=lint

# Format check (don't auto-fix during review)
npm run format -- --check
# or
npx prettier --check .

# Type check
npx nx run-many --target=typecheck
# or per project
npx nx run api:typecheck
npx nx run web:typecheck

# Tests (optional, if fast)
npm test
```

### Common lint issues

| Issue                                | Fix                                      |
| ------------------------------------ | ---------------------------------------- |
| `@typescript-eslint/no-explicit-any` | Replace with proper type or `unknown`    |
| `@typescript-eslint/no-unused-vars`  | Remove or prefix with `_`                |
| `import/order`                       | Run `npm run lint -- --fix`              |
| `@angular-eslint/no-empty-lifecycle-method` | Remove empty lifecycle hook or add logic |

---

## Standards review checklist (nean-std)

### Project structure

- [ ] NestJS modules in `apps/api/src/modules/`
- [ ] Shared types/DTOs in `libs/shared/types/`
- [ ] Entities in `libs/api/database/src/entities/`
- [ ] Angular components in `apps/web/src/app/`
- [ ] Data-access services in `libs/web/data-access/`
- [ ] No API-only code imported in Angular components

### TypeScript

- [ ] No `any` without justification
- [ ] Explicit types at module boundaries (exports, DTOs, controller returns)
- [ ] Types derived from DTOs with class-validator, not duplicated

### NestJS controllers

- [ ] Input validated with `ValidationPipe({ whitelist: true })`
- [ ] Consistent response envelope (`ApiResponse<T>`)
- [ ] Pagination on list endpoints (`PaginationDto`)
- [ ] Error responses don't leak internals
- [ ] `@ApiTags` and `@ApiOperation` on all endpoints

### TypeORM entities

- [ ] Entities have `@CreateDateColumn` and `@UpdateDateColumn`
- [ ] Indexes documented with reason (comment in decorator)
- [ ] No raw user input in queries
- [ ] UUID primary keys (`@PrimaryGeneratedColumn('uuid')`)

### Naming

- [ ] Folders: kebab-case
- [ ] Angular components: kebab-case.component.ts, PascalCase class
- [ ] NestJS services: kebab-case.service.ts, PascalCase class
- [ ] DTOs: kebab-case.dto.ts

---

## NFR review checklist (nean-nfr)

### Performance

- [ ] No N+1 queries (use `relations` or query builder joins)
- [ ] Large lists paginated
- [ ] Expensive operations have timeouts
- [ ] Angular components use `OnPush` change detection

### Reliability

- [ ] Errors handled, not swallowed
- [ ] Retry logic is idempotent
- [ ] Graceful degradation for optional features

### Observability

- [ ] Key operations logged (NestJS `Logger`)
- [ ] No PII/secrets in logs
- [ ] Correlation IDs where applicable

### Accessibility

- [ ] Interactive elements keyboard accessible
- [ ] Color not sole indicator
- [ ] Reasonable contrast
- [ ] PrimeNG components have appropriate ARIA attributes

---

## Security review checklist (nean-sec)

### Input validation

- [ ] All DTOs use class-validator decorators
- [ ] `ValidationPipe({ whitelist: true })` strips unknown properties
- [ ] File uploads validated (type, size)
- [ ] Query params validated via DTO with `@Transform`

### SQL injection

- [ ] TypeORM parameterized queries — no string interpolation
- [ ] No raw SQL with user input
- [ ] Query builder uses `:param` syntax

### Authentication/Authorization

- [ ] Protected routes have `@UseGuards(JwtAuthGuard)`
- [ ] Resource ownership verified in queries or guards
- [ ] Tokens in httpOnly cookies (not localStorage)

### Error handling

- [ ] `AllExceptionsFilter` prevents stack traces in responses
- [ ] No internal details leaked
- [ ] Generic messages for auth failures

### Dependencies

- [ ] No known critical vulnerabilities (`npm audit`)
- [ ] Lockfile committed

---

## Common issues by category

### Security (must-fix)

**Raw TypeORM query with user input**

```typescript
// ❌ Bad
const users = await this.repo.query(
  `SELECT * FROM users WHERE name = '${name}'`
);

// ✅ Good
const users = await this.repo
  .createQueryBuilder('user')
  .where('user.name = :name', { name })
  .getMany();
```

**Missing ValidationPipe**

```typescript
// ❌ Bad
@Post()
async create(@Body() dto: CreateUserDto) {
  // dto is not validated — class-validator decorators ignored
  return this.usersService.create(dto);
}

// ✅ Good
@Post()
async create(
  @Body(new ValidationPipe({ whitelist: true })) dto: CreateUserDto,
) {
  return this.usersService.create(dto);
}
```

**Sensitive data in error response**

```typescript
// ❌ Bad
catch (error) {
  throw new InternalServerErrorException({
    message: error.message,
    stack: error.stack,
    query: error.query,
  });
}

// ✅ Good
catch (error) {
  this.logger.error('Operation failed', error.stack);
  throw new InternalServerErrorException('Internal server error');
}
```

### Standards (should-fix)

**Business logic in controller**

```typescript
// ❌ Bad: controller does too much
@Post()
async create(@Body(ValidationPipe) dto: CreateOrderDto) {
  const user = await this.userRepo.findOneBy({ id: dto.userId });
  if (!user) throw new NotFoundException();
  const total = dto.items.reduce((sum, i) => sum + i.price * i.qty, 0);
  const order = this.orderRepo.create({ ...dto, total });
  return this.orderRepo.save(order);
}

// ✅ Good: delegate to service
@Post()
async create(@Body(ValidationPipe) dto: CreateOrderDto) {
  return this.ordersService.create(dto);
}
```

**Missing DTO — exposing entity directly**

```typescript
// ❌ Bad: returns entity with internal fields
@Get(':id')
async findOne(@Param('id', ParseUUIDPipe) id: string) {
  return this.userRepo.findOneBy({ id });
  // Exposes passwordHash, internal flags, etc.
}

// ✅ Good: map to response DTO
@Get(':id')
async findOne(@Param('id', ParseUUIDPipe) id: string): Promise<UserResponseDto> {
  return this.usersService.findOne(id);
}
```

**DTOs without class-validator decorators**

```typescript
// ❌ Bad: plain class, no validation
export class CreateUserDto {
  email: string;
  name: string;
}

// ✅ Good: validated DTO
export class CreateUserDto {
  @IsEmail()
  @MaxLength(255)
  email: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;
}
```

### NFR (should-fix)

**Missing pagination**

```typescript
// ❌ Bad
@Get()
async findAll() {
  return this.itemRepo.find();
}

// ✅ Good
@Get()
async findAll(
  @Query(new ValidationPipe({ transform: true })) query: PaginationDto,
) {
  return this.itemsService.findAll(query);
}
```

**N+1 query**

```typescript
// ❌ Bad
const orders = await this.orderRepo.find({ where: { userId } });
for (const order of orders) {
  order.items = await this.orderItemRepo.find({ where: { orderId: order.id } });
}

// ✅ Good
const orders = await this.orderRepo.find({
  where: { userId },
  relations: ['items'],
});
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
  this.logger.error('Operation failed', error.stack);
  throw new InternalServerErrorException('Unable to complete operation');
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

#### [sec] Raw SQL with user input
**File:** `apps/api/src/modules/users/users.service.ts:45`
**Issue:** User input interpolated directly into SQL query
**Fix:** Use TypeORM query builder with parameterized query

### Should-fix Issues

#### [std] Business logic in controller
**File:** `apps/api/src/modules/orders/orders.controller.ts:28`
**Issue:** Order total calculation belongs in service layer
**Fix:** Move to `OrdersService.create()`

...
```

---

## Quick reference

| Task               | Command                                          |
| ------------------ | ------------------------------------------------ |
| Lint               | `npm run lint`                                   |
| Lint with auto-fix | `npm run lint -- --fix`                          |
| Format check       | `npm run format -- --check`                      |
| Format fix         | `npm run format`                                 |
| Type check         | `npx nx run-many --target=typecheck`             |
| Lint affected only | `npx nx affected --target=lint`                  |
| Security audit     | `npm audit`                                      |
| Run tests          | `npm test`                                       |
