# NEAN Add Auth Reference

Passport.js + JWT setup templates and OAuth provider configuration.

---

## Dependencies

```bash
npm install @nestjs/passport passport passport-jwt passport-local bcrypt @nestjs/jwt
npm install -D @types/passport-jwt @types/passport-local @types/bcrypt
```

---

## JWT Strategy

```typescript
// libs/api/auth/src/strategies/jwt.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { ExtractJwt, Strategy } from 'passport-jwt';
import { ConfigService } from '@nestjs/config';
import { UsersService } from '../../users/users.service';

export interface JwtPayload {
  sub: string;
  email: string;
  iat?: number;
  exp?: number;
}

@Injectable()
export class JwtStrategy extends PassportStrategy(Strategy) {
  constructor(
    configService: ConfigService,
    private readonly usersService: UsersService,
  ) {
    super({
      jwtFromRequest: ExtractJwt.fromAuthHeaderAsBearerToken(),
      ignoreExpiration: false,
      secretOrKey: configService.get<string>('JWT_SECRET'),
      algorithms: ['HS256'],
    });
  }

  async validate(payload: JwtPayload) {
    const user = await this.usersService.findById(payload.sub);
    if (!user || !user.isActive) {
      throw new UnauthorizedException();
    }
    return { id: user.id, email: user.email, roles: user.roles };
  }
}
```

---

## Local Strategy

```typescript
// libs/api/auth/src/strategies/local.strategy.ts
import { Injectable, UnauthorizedException } from '@nestjs/common';
import { PassportStrategy } from '@nestjs/passport';
import { Strategy } from 'passport-local';
import { AuthService } from '../auth.service';

@Injectable()
export class LocalStrategy extends PassportStrategy(Strategy) {
  constructor(private readonly authService: AuthService) {
    super({ usernameField: 'email' });
  }

  async validate(email: string, password: string) {
    const user = await this.authService.validateUser(email, password);
    if (!user) {
      throw new UnauthorizedException('Invalid credentials');
    }
    return user;
  }
}
```

---

## Auth Service

```typescript
// libs/api/auth/src/auth.service.ts
import { Injectable, ConflictException, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import * as bcrypt from 'bcrypt';
import { UserEntity } from '@libs/api/database/entities/user.entity';
import { RefreshTokenEntity } from '@libs/api/database/entities/refresh-token.entity';
import { RegisterDto, LoginResponseDto } from '@libs/shared/types/auth.dto';

const SALT_ROUNDS = 12;

@Injectable()
export class AuthService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
    @InjectRepository(RefreshTokenEntity)
    private readonly refreshTokenRepo: Repository<RefreshTokenEntity>,
    private readonly jwtService: JwtService,
    private readonly configService: ConfigService,
  ) {}

  async register(dto: RegisterDto): Promise<LoginResponseDto> {
    const exists = await this.userRepo.findOneBy({ email: dto.email });
    if (exists) {
      throw new ConflictException('Email already registered');
    }

    const passwordHash = await bcrypt.hash(dto.password, SALT_ROUNDS);
    const user = this.userRepo.create({
      email: dto.email,
      firstName: dto.firstName,
      lastName: dto.lastName,
      passwordHash,
    });
    const saved = await this.userRepo.save(user);

    return this.generateTokens(saved);
  }

  async validateUser(email: string, password: string): Promise<UserEntity | null> {
    const user = await this.userRepo.findOne({
      where: { email },
      select: ['id', 'email', 'passwordHash', 'firstName', 'lastName', 'roles', 'isActive'],
    });

    if (!user || !user.passwordHash) {
      return null;
    }

    const isValid = await bcrypt.compare(password, user.passwordHash);
    return isValid ? user : null;
  }

  async login(user: UserEntity): Promise<LoginResponseDto> {
    return this.generateTokens(user);
  }

  async refreshToken(refreshToken: string): Promise<LoginResponseDto> {
    const stored = await this.refreshTokenRepo.findOne({
      where: { token: refreshToken, revoked: false },
      relations: ['user'],
    });

    if (!stored || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Invalid refresh token');
    }

    // Revoke old token (rotation)
    stored.revoked = true;
    await this.refreshTokenRepo.save(stored);

    return this.generateTokens(stored.user);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.refreshTokenRepo.update(
      { token: refreshToken },
      { revoked: true },
    );
  }

  private async generateTokens(user: UserEntity): Promise<LoginResponseDto> {
    const payload = { sub: user.id, email: user.email };

    const accessToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_SECRET'),
      expiresIn: this.configService.get('JWT_EXPIRES_IN', '15m'),
    });

    const refreshToken = this.jwtService.sign(payload, {
      secret: this.configService.get('JWT_REFRESH_SECRET'),
      expiresIn: this.configService.get('JWT_REFRESH_EXPIRES_IN', '7d'),
    });

    // Store refresh token
    const expiresAt = new Date();
    expiresAt.setDate(expiresAt.getDate() + 7);
    await this.refreshTokenRepo.save({
      token: refreshToken,
      user,
      expiresAt,
    });

    return {
      accessToken,
      refreshToken,
      user: {
        id: user.id,
        email: user.email,
        firstName: user.firstName,
        lastName: user.lastName,
      },
    };
  }
}
```

---

## Auth Controller

```typescript
// libs/api/auth/src/auth.controller.ts
import {
  Controller,
  Post,
  Body,
  UseGuards,
  HttpCode,
  HttpStatus,
  Req,
  Get,
  ValidationPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth } from '@nestjs/swagger';
import { AuthGuard } from '@nestjs/passport';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { CurrentUser } from './decorators/current-user.decorator';
import { Public } from './decorators/public.decorator';
import { AuthService } from './auth.service';
import { RegisterDto, LoginDto, RefreshTokenDto } from '@libs/shared/types/auth.dto';

@Controller('auth')
@ApiTags('auth')
export class AuthController {
  constructor(private readonly authService: AuthService) {}

  @Post('register')
  @Public()
  @ApiOperation({ summary: 'Register new user' })
  async register(
    @Body(new ValidationPipe({ whitelist: true })) dto: RegisterDto,
  ) {
    return this.authService.register(dto);
  }

  @Post('login')
  @Public()
  @HttpCode(HttpStatus.OK)
  @UseGuards(AuthGuard('local'))
  @ApiOperation({ summary: 'Login with email and password' })
  async login(@Req() req: any) {
    return this.authService.login(req.user);
  }

  @Post('refresh')
  @Public()
  @HttpCode(HttpStatus.OK)
  @ApiOperation({ summary: 'Refresh access token' })
  async refresh(
    @Body(new ValidationPipe({ whitelist: true })) dto: RefreshTokenDto,
  ) {
    return this.authService.refreshToken(dto.refreshToken);
  }

  @Post('logout')
  @HttpCode(HttpStatus.NO_CONTENT)
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Logout and revoke refresh token' })
  async logout(
    @Body(new ValidationPipe({ whitelist: true })) dto: RefreshTokenDto,
  ) {
    return this.authService.logout(dto.refreshToken);
  }

  @Get('me')
  @UseGuards(JwtAuthGuard)
  @ApiBearerAuth()
  @ApiOperation({ summary: 'Get current user profile' })
  async me(@CurrentUser() user: any) {
    return user;
  }
}
```

---

## Guards and Decorators

### JwtAuthGuard

```typescript
// libs/api/auth/src/guards/jwt-auth.guard.ts
import { Injectable, ExecutionContext } from '@nestjs/common';
import { AuthGuard } from '@nestjs/passport';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../decorators/public.decorator';

@Injectable()
export class JwtAuthGuard extends AuthGuard('jwt') {
  constructor(private reflector: Reflector) {
    super();
  }

  canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;
    return super.canActivate(context);
  }
}
```

### RolesGuard

```typescript
// libs/api/auth/src/guards/roles.guard.ts
import { Injectable, CanActivate, ExecutionContext } from '@nestjs/common';
import { Reflector } from '@nestjs/core';
import { ROLES_KEY } from '../decorators/roles.decorator';

@Injectable()
export class RolesGuard implements CanActivate {
  constructor(private reflector: Reflector) {}

  canActivate(context: ExecutionContext): boolean {
    const requiredRoles = this.reflector.getAllAndOverride<string[]>(ROLES_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (!requiredRoles) return true;

    const { user } = context.switchToHttp().getRequest();
    return requiredRoles.some((role) => user.roles?.includes(role));
  }
}
```

### CurrentUser Decorator

```typescript
// libs/api/auth/src/decorators/current-user.decorator.ts
import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export const CurrentUser = createParamDecorator(
  (data: string | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user;
    return data ? user?.[data] : user;
  },
);
```

### Public Decorator

```typescript
// libs/api/auth/src/decorators/public.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const IS_PUBLIC_KEY = 'isPublic';
export const Public = () => SetMetadata(IS_PUBLIC_KEY, true);
```

### Roles Decorator

```typescript
// libs/api/auth/src/decorators/roles.decorator.ts
import { SetMetadata } from '@nestjs/common';

export const ROLES_KEY = 'roles';
export const Roles = (...roles: string[]) => SetMetadata(ROLES_KEY, roles);
```

---

## User Entity

```typescript
// libs/api/database/src/entities/user.entity.ts
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
  @Index('IDX_users_email', { unique: true })
  email: string;

  @Column({ name: 'first_name', nullable: true })
  firstName: string;

  @Column({ name: 'last_name', nullable: true })
  lastName: string;

  @Column({ name: 'password_hash', select: false, nullable: true })
  passwordHash: string;

  @Column({ type: 'simple-array', default: 'user' })
  roles: string[];

  @Column({ name: 'is_active', default: true })
  isActive: boolean;

  @Column({ nullable: true })
  image: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
```

---

## Refresh Token Entity

```typescript
// libs/api/database/src/entities/refresh-token.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  ManyToOne,
  JoinColumn,
  CreateDateColumn,
  Index,
} from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('refresh_tokens')
export class RefreshTokenEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column()
  @Index('IDX_refresh_tokens_token')
  token: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: UserEntity;

  @Column({ default: false })
  revoked: boolean;

  @Column({ name: 'expires_at' })
  expiresAt: Date;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;
}
```

---

## Auth DTOs

```typescript
// libs/shared/types/src/auth.dto.ts
import { IsEmail, IsString, MinLength, MaxLength, Matches } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  @MaxLength(255)
  email: string;

  @ApiProperty({ example: 'SecurePass1' })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  @Matches(/^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)/, {
    message: 'Password must contain uppercase, lowercase, and number',
  })
  password: string;

  @ApiProperty({ example: 'Jane' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  firstName: string;

  @ApiProperty({ example: 'Doe' })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  lastName: string;
}

export class LoginDto {
  @ApiProperty({ example: 'user@example.com' })
  @IsEmail()
  email: string;

  @ApiProperty()
  @IsString()
  password: string;
}

export class RefreshTokenDto {
  @ApiProperty()
  @IsString()
  refreshToken: string;
}

export class LoginResponseDto {
  @ApiProperty()
  accessToken: string;

  @ApiProperty()
  refreshToken: string;

  @ApiProperty()
  user: {
    id: string;
    email: string;
    firstName: string;
    lastName: string;
  };
}
```

---

## Angular Auth Service

```typescript
// libs/web/auth/src/auth.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Router } from '@angular/router';
import { BehaviorSubject, Observable, tap } from 'rxjs';
import { API_URL } from '@libs/web/data-access';
import { LoginDto, RegisterDto, LoginResponseDto } from '@libs/shared/types/auth.dto';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private http = inject(HttpClient);
  private router = inject(Router);
  private apiUrl = inject(API_URL);

  private currentUser$ = new BehaviorSubject<LoginResponseDto['user'] | null>(null);
  user$ = this.currentUser$.asObservable();

  get isAuthenticated(): boolean {
    return !!this.getAccessToken();
  }

  register(dto: RegisterDto): Observable<LoginResponseDto> {
    return this.http.post<LoginResponseDto>(`${this.apiUrl}/auth/register`, dto).pipe(
      tap((res) => this.storeTokens(res)),
    );
  }

  login(dto: LoginDto): Observable<LoginResponseDto> {
    return this.http.post<LoginResponseDto>(`${this.apiUrl}/auth/login`, dto).pipe(
      tap((res) => this.storeTokens(res)),
    );
  }

  logout(): void {
    const refreshToken = this.getRefreshToken();
    if (refreshToken) {
      this.http.post(`${this.apiUrl}/auth/logout`, { refreshToken }).subscribe();
    }
    this.clearTokens();
    this.router.navigate(['/auth/login']);
  }

  refreshToken(): Observable<LoginResponseDto> {
    const refreshToken = this.getRefreshToken();
    return this.http.post<LoginResponseDto>(`${this.apiUrl}/auth/refresh`, { refreshToken }).pipe(
      tap((res) => this.storeTokens(res)),
    );
  }

  getAccessToken(): string | null {
    return localStorage.getItem('accessToken');
  }

  private getRefreshToken(): string | null {
    return localStorage.getItem('refreshToken');
  }

  private storeTokens(res: LoginResponseDto): void {
    localStorage.setItem('accessToken', res.accessToken);
    localStorage.setItem('refreshToken', res.refreshToken);
    this.currentUser$.next(res.user);
  }

  private clearTokens(): void {
    localStorage.removeItem('accessToken');
    localStorage.removeItem('refreshToken');
    this.currentUser$.next(null);
  }
}
```

---

## Angular Auth Interceptor

```typescript
// libs/web/auth/src/auth.interceptor.ts
import { Injectable, inject } from '@angular/core';
import {
  HttpInterceptor,
  HttpRequest,
  HttpHandler,
  HttpEvent,
  HttpErrorResponse,
} from '@angular/common/http';
import { Observable, throwError, BehaviorSubject, filter, take, switchMap, catchError } from 'rxjs';
import { AuthService } from './auth.service';

@Injectable()
export class AuthInterceptor implements HttpInterceptor {
  private authService = inject(AuthService);
  private isRefreshing = false;
  private refreshSubject = new BehaviorSubject<string | null>(null);

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    const token = this.authService.getAccessToken();
    const authReq = token ? this.addToken(req, token) : req;

    return next.handle(authReq).pipe(
      catchError((error: HttpErrorResponse) => {
        if (error.status === 401 && !req.url.includes('/auth/')) {
          return this.handle401(req, next);
        }
        return throwError(() => error);
      }),
    );
  }

  private addToken(req: HttpRequest<unknown>, token: string): HttpRequest<unknown> {
    return req.clone({
      setHeaders: { Authorization: `Bearer ${token}` },
    });
  }

  private handle401(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    if (!this.isRefreshing) {
      this.isRefreshing = true;
      this.refreshSubject.next(null);

      return this.authService.refreshToken().pipe(
        switchMap((res) => {
          this.isRefreshing = false;
          this.refreshSubject.next(res.accessToken);
          return next.handle(this.addToken(req, res.accessToken));
        }),
        catchError((err) => {
          this.isRefreshing = false;
          this.authService.logout();
          return throwError(() => err);
        }),
      );
    }

    return this.refreshSubject.pipe(
      filter((token) => token !== null),
      take(1),
      switchMap((token) => next.handle(this.addToken(req, token!))),
    );
  }
}
```

---

## Angular Auth Guard

```typescript
// libs/web/auth/src/auth.guard.ts
import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { AuthService } from './auth.service';

export const authGuard: CanActivateFn = () => {
  const authService = inject(AuthService);
  const router = inject(Router);

  if (authService.isAuthenticated) {
    return true;
  }

  return router.createUrlTree(['/auth/login']);
};
```

---

## Environment Variables

```bash
# .env.example

# JWT
JWT_SECRET=your-secret-key-at-least-32-chars-long
JWT_EXPIRES_IN=15m
JWT_REFRESH_SECRET=another-secret-key-at-least-32-chars
JWT_REFRESH_EXPIRES_IN=7d

# OAuth — Google
GOOGLE_CLIENT_ID=your-google-client-id
GOOGLE_CLIENT_SECRET=your-google-client-secret
GOOGLE_CALLBACK_URL=http://localhost:3000/api/auth/google/callback

# OAuth — GitHub
GITHUB_CLIENT_ID=your-github-client-id
GITHUB_CLIENT_SECRET=your-github-client-secret
GITHUB_CALLBACK_URL=http://localhost:3000/api/auth/github/callback
```

---

## OAuth Provider Setup

### Google
1. Go to [Google Cloud Console](https://console.cloud.google.com/)
2. Create project or select existing
3. APIs & Services -> Credentials -> Create OAuth Client ID
4. Application type: Web application
5. Authorized redirect URIs: `http://localhost:3000/api/auth/google/callback`
6. Copy Client ID and Client Secret to `.env`

### GitHub
1. Go to [GitHub Developer Settings](https://github.com/settings/developers)
2. OAuth Apps -> New OAuth App
3. Authorization callback URL: `http://localhost:3000/api/auth/github/callback`
4. Copy Client ID and generate Client Secret to `.env`

---

## Testing Auth

### Mock JWT strategy for tests

```typescript
// libs/api/auth/src/__tests__/auth.mock.ts
import { Test, TestingModule } from '@nestjs/testing';
import { JwtService } from '@nestjs/jwt';
import { getRepositoryToken } from '@nestjs/typeorm';
import { AuthService } from '../auth.service';
import { UserEntity } from '@libs/api/database/entities/user.entity';
import { RefreshTokenEntity } from '@libs/api/database/entities/refresh-token.entity';

export function createAuthTestingModule() {
  return Test.createTestingModule({
    providers: [
      AuthService,
      {
        provide: JwtService,
        useValue: {
          sign: jest.fn().mockReturnValue('mock-token'),
          verify: jest.fn().mockReturnValue({ sub: 'user-1', email: 'test@example.com' }),
        },
      },
      {
        provide: 'ConfigService',
        useValue: {
          get: jest.fn((key: string) => {
            const config: Record<string, string> = {
              JWT_SECRET: 'test-secret',
              JWT_EXPIRES_IN: '15m',
              JWT_REFRESH_SECRET: 'test-refresh-secret',
              JWT_REFRESH_EXPIRES_IN: '7d',
            };
            return config[key];
          }),
        },
      },
      {
        provide: getRepositoryToken(UserEntity),
        useValue: {
          findOneBy: jest.fn(),
          findOne: jest.fn(),
          create: jest.fn(),
          save: jest.fn(),
        },
      },
      {
        provide: getRepositoryToken(RefreshTokenEntity),
        useValue: {
          findOne: jest.fn(),
          save: jest.fn(),
          update: jest.fn(),
        },
      },
    ],
  });
}
```

### Test helper for authenticated requests

```typescript
// Override JwtAuthGuard in e2e tests
const moduleFixture = await Test.createTestingModule({
  imports: [AppModule],
})
  .overrideGuard(JwtAuthGuard)
  .useValue({
    canActivate: (context: ExecutionContext) => {
      const req = context.switchToHttp().getRequest();
      req.user = { id: 'test-user-id', email: 'test@example.com', roles: ['user'] };
      return true;
    },
  })
  .compile();
```
