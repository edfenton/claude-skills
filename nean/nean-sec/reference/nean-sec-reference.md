# NEAN Security Reference

Detailed implementation patterns for OWASP Top 10 and CWE mitigations. Load when implementing specific security controls.

---

## OWASP Top 10:2025 — NEAN mitigations

### A01: Broken Access Control

- Check authorization in NestJS guards, not just UI
- Verify resource ownership in TypeORM queries:

```typescript
// Bad: trusts client-provided ID
const doc = await this.repo.findOneBy({ id });

// Good: scoped to authenticated user
const doc = await this.repo.findOne({
  where: { id, userId: currentUser.id },
});
```

- Use CASL for attribute-based access control:

```typescript
// Define abilities
const ability = defineAbility((can, cannot) => {
  can('read', 'Article');
  can('update', 'Article', { authorId: user.id });
  cannot('delete', 'Article');
});

// Check in guard
if (!ability.can('update', article)) {
  throw new ForbiddenException();
}
```

### A02: Cryptographic Failures

- Passwords: bcrypt with cost factor 12+

```typescript
import * as bcrypt from 'bcrypt';

const SALT_ROUNDS = 12;
const hash = await bcrypt.hash(password, SALT_ROUNDS);
const isValid = await bcrypt.compare(password, hash);
```

- JWTs: RS256 for distributed systems, HS256 + secure rotation for single-service
- Never store secrets in code or localStorage
- Use HTTPS everywhere; set `secure` flag on cookies

### A03: Injection (SQL)

- Always use TypeORM's query builder with parameters:

```typescript
// Bad: string interpolation
const users = await this.repo.query(
  `SELECT * FROM users WHERE name = '${name}'`
);

// Good: parameterized query
const users = await this.repo
  .createQueryBuilder('user')
  .where('user.name = :name', { name })
  .getMany();

// Good: repository methods
const users = await this.repo.findBy({ name });
```

- Validate input before it reaches the database:

```typescript
// DTO with validation
export class CreateUserDto {
  @IsString()
  @MaxLength(100)
  @Matches(/^[a-zA-Z\s]+$/)
  name: string;

  @IsEmail()
  email: string;
}
```

### A04: Insecure Design

- Threat model auth flows before building
- Rate limit password reset, login, and registration
- Implement account lockout after failed attempts

```typescript
// Rate limiting decorator
@Throttle({ default: { limit: 5, ttl: 60000 } })
@Post('login')
async login(@Body() dto: LoginDto) {
  // ...
}
```

### A05: Security Misconfiguration

- Configure Helmet for security headers:

```typescript
// main.ts
import helmet from 'helmet';

app.use(helmet({
  contentSecurityPolicy: {
    directives: {
      defaultSrc: ["'self'"],
      styleSrc: ["'self'", "'unsafe-inline'"],
      scriptSrc: ["'self'"],
      imgSrc: ["'self'", 'data:', 'https:'],
    },
  },
  hsts: {
    maxAge: 31536000,
    includeSubDomains: true,
  },
}));
```

- Disable unnecessary features in production
- Remove default credentials and sample code

### A06: Vulnerable Components

- Run `npm audit` in CI; fail on critical/high
- Pin dependencies in package-lock.json
- Review transitive dependencies periodically

### A07: Authentication Failures

- Use Passport.js with secure JWT configuration:

```typescript
// JWT strategy
@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(configService: ConfigService) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get('JWT_SECRET'),
      algorithms: ['HS256'],
    });
  }

  async validate(payload: JwtPayload) {
    // Verify user still exists and is active
    const user = await this.usersService.findById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException();
    }
    return user;
  }
}
```

- Secure cookie config for refresh tokens:

```typescript
res.cookie('refreshToken', token, {
  httpOnly: true,
  secure: process.env.NODE_ENV === 'production',
  sameSite: 'strict',
  maxAge: 7 * 24 * 60 * 60 * 1000, // 7 days
  path: '/api/auth/refresh',
});
```

- Invalidate sessions on password change

### A08: Data Integrity Failures

- Verify webhook signatures
- Use SRI for external scripts (Angular handles this)
- Sign and verify JWTs; check `iss` and `aud` claims

### A09: Logging Failures

- Log auth events: login, logout, failed attempts, password changes

```typescript
// Audit log interceptor
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  intercept(context: ExecutionContext, next: CallHandler) {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const action = `${request.method} ${request.url}`;
    
    return next.handle().pipe(
      tap(() => {
        this.logger.log({
          userId: user?.id,
          action,
          ip: request.ip,
          userAgent: request.headers['user-agent'],
          timestamp: new Date().toISOString(),
        });
      }),
    );
  }
}
```

- Never log: passwords, tokens, PII, full request bodies
- Include correlation IDs for tracing

### A10: SSRF

- Validate and allowlist URLs before fetching
- Don't allow user input to control internal service URLs
- Use network segmentation for internal services

---

## CWE mitigations — NEAN patterns

### CWE-20: Input Validation

```typescript
import { IsString, IsEmail, MaxLength, MinLength, Matches } from 'class-validator';

export class CreateUserDto {
  @IsEmail()
  @MaxLength(255)
  email: string;

  @IsString()
  @MinLength(1)
  @MaxLength(100)
  name: string;

  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message: 'Password must contain uppercase, lowercase, and number',
  })
  password: string;
}

// In controller
@Post()
async create(@Body(new ValidationPipe({ whitelist: true })) dto: CreateUserDto) {
  // dto is validated and stripped of unknown properties
}
```

### CWE-79: XSS

```typescript
// Angular: default escaping
// Bad: bypasses sanitization
<div [innerHTML]="userInput"></div>

// Good: Angular escapes by default
<div>{{ userInput }}</div>

// If HTML required, sanitize on backend first
import * as DOMPurify from 'isomorphic-dompurify';
const cleanHtml = DOMPurify.sanitize(userInput);
```

### CWE-352: CSRF

```typescript
// For cookie-based auth, implement CSRF tokens
// main.ts
import * as csurf from 'csurf';

app.use(csurf({ cookie: { httpOnly: true, sameSite: 'strict' } }));

// Controller
@Get('csrf-token')
getCsrfToken(@Req() req) {
  return { csrfToken: req.csrfToken() };
}

// All state-changing requests require X-CSRF-Token header
```

### CWE-862: Missing Authorization

```typescript
// Guard pattern
@Injectable()
export class OwnershipGuard implements CanActivate {
  constructor(private readonly resourceService: ResourceService) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const request = context.switchToHttp().getRequest();
    const user = request.user;
    const resourceId = request.params.id;

    const resource = await this.resourceService.findById(resourceId);
    if (!resource) {
      throw new NotFoundException();
    }

    if (resource.ownerId !== user.id) {
      throw new ForbiddenException();
    }

    request.resource = resource;
    return true;
  }
}

// Usage
@UseGuards(JwtAuthGuard, OwnershipGuard)
@Patch(':id')
update(@Req() req, @Body() dto: UpdateDto) {
  return this.service.update(req.resource, dto);
}
```

### CWE-770: Resource Exhaustion

```typescript
// NestJS throttling
import { ThrottlerModule, ThrottlerGuard } from '@nestjs/throttler';

@Module({
  imports: [
    ThrottlerModule.forRoot([{
      ttl: 60000,
      limit: 10,
    }]),
  ],
})
export class AppModule {}

// Global guard
app.useGlobalGuards(new ThrottlerGuard());

// Per-route override
@Throttle({ default: { limit: 3, ttl: 60000 } })
@Post('login')
async login() { }
```

### CWE-200: Information Exposure

```typescript
// Global exception filter
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();

    const status =
      exception instanceof HttpException
        ? exception.getStatus()
        : HttpStatus.INTERNAL_SERVER_ERROR;

    // Log full error server-side
    this.logger.error({
      exception,
      path: request.url,
      method: request.method,
      userId: request.user?.id,
    });

    // Return safe response to client
    response.status(status).json({
      statusCode: status,
      message: status === 500 ? 'Internal server error' : exception.message,
      timestamp: new Date().toISOString(),
      path: request.url,
      // Never include: stack traces, internal details, query info
    });
  }
}
```

---

## Quick checklist

| Concern         | Check                                              |
| --------------- | -------------------------------------------------- |
| SQL injection   | TypeORM parameterized queries; no string concat    |
| XSS             | No innerHTML; bypassSecurityTrust audited          |
| CSRF            | Token validation on state-changing requests        |
| Auth            | httpOnly cookies; secure flag in prod              |
| Authz           | Guards check ownership; CASL for complex rules     |
| Rate limiting   | ThrottlerModule on login, registration, expensive  |
| Errors          | AllExceptionsFilter; no stack traces               |
| Logging         | Auth events logged; no secrets/PII                 |
| Deps            | Lockfile committed; npm audit clean                |
| Mass assignment | DTOs with whitelist: true; no object spread        |
