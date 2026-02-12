# NEAN Unit Test Reference

Coverage setup and common failure patterns.

---

## Coverage setup (Jest)

### Install

```bash
npm install -D jest @types/jest ts-jest @nestjs/testing
```

### Configure API project (apps/api/jest.config.ts)

```typescript
export default {
  displayName: 'api',
  preset: 'ts-jest',
  testEnvironment: 'node',
  rootDir: '.',
  testMatch: ['**/*.spec.ts'],
  moduleNameMapper: {
    '^@libs/(.*)$': '<rootDir>/../../libs/$1/src',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.module.ts',
    '!src/main.ts',
    '!src/**/index.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 50,
      functions: 60,
      lines: 60,
      statements: 60,
    },
  },
};
```

### Configure Web project (apps/web/jest.config.ts)

```typescript
export default {
  displayName: 'web',
  preset: 'jest-preset-angular',
  setupFilesAfterSetup: ['<rootDir>/setup-jest.ts'],
  testMatch: ['**/*.spec.ts'],
  moduleNameMapper: {
    '^@libs/(.*)$': '<rootDir>/../../libs/$1/src',
  },
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/*.module.ts',
    '!src/main.ts',
    '!src/**/index.ts',
    '!src/**/*.routes.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 50,
      functions: 60,
      lines: 60,
      statements: 60,
    },
  },
};
```

### Configure libs (libs/shared/types/jest.config.ts)

```typescript
export default {
  displayName: 'shared-types',
  preset: 'ts-jest',
  testEnvironment: 'node',
  testMatch: ['**/*.spec.ts'],
  collectCoverageFrom: [
    'src/**/*.ts',
    '!src/**/*.d.ts',
    '!src/**/index.ts',
  ],
  coverageThreshold: {
    global: {
      branches: 80,
      functions: 80,
      lines: 80,
      statements: 80,
    },
  },
};
```

### Run with coverage

```bash
# Via Nx (runs coverage for all projects)
npx nx run-many --target=test -- --coverage

# Scoped to a single project
npx nx run api:test -- --coverage
npx nx run web:test -- --coverage
```

### Coverage output

- `text` — Console summary table
- `lcov` — For CI integration (Codecov, Coveralls)
- `html` — Browse at `coverage/index.html`

---

## NestJS testing

### TestingModule setup

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { UsersService } from './users.service';
import { UserEntity } from '@libs/api/database/entities/user.entity';

describe('UsersService', () => {
  let service: UsersService;
  let repo: jest.Mocked<Repository<UserEntity>>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        UsersService,
        {
          provide: getRepositoryToken(UserEntity),
          useValue: {
            find: jest.fn(),
            findOneBy: jest.fn(),
            findAndCount: jest.fn(),
            create: jest.fn(),
            save: jest.fn(),
            delete: jest.fn(),
          },
        },
      ],
    }).compile();

    service = module.get(UsersService);
    repo = module.get(getRepositoryToken(UserEntity));
  });

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('should be defined', () => {
    expect(service).toBeDefined();
  });
});
```

### Controller spec

```typescript
import { Test, TestingModule } from '@nestjs/testing';
import { UsersController } from './users.controller';
import { UsersService } from './users.service';

describe('UsersController', () => {
  let controller: UsersController;
  let service: jest.Mocked<UsersService>;

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      controllers: [UsersController],
      providers: [
        {
          provide: UsersService,
          useValue: {
            findAll: jest.fn(),
            findOne: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
            remove: jest.fn(),
          },
        },
      ],
    }).compile();

    controller = module.get(UsersController);
    service = module.get(UsersService);
  });

  it('should return paginated users', async () => {
    const expected = {
      items: [{ id: '1', email: 'test@example.com' }],
      meta: { page: 1, limit: 20, total: 1, totalPages: 1 },
    };
    service.findAll.mockResolvedValue(expected);

    const result = await controller.findAll({ page: 1, limit: 20 });
    expect(result).toEqual(expected);
    expect(service.findAll).toHaveBeenCalledWith({ page: 1, limit: 20 });
  });
});
```

### Service spec

```typescript
describe('UsersService', () => {
  // ... setup from above

  describe('create', () => {
    it('should create a user', async () => {
      const dto = { email: 'test@example.com', name: 'Test', password: 'Password1' };
      const entity = { id: 'uuid-1', ...dto, passwordHash: 'hashed', createdAt: new Date() };

      repo.findOneBy.mockResolvedValue(null); // No existing user
      repo.create.mockReturnValue(entity as any);
      repo.save.mockResolvedValue(entity as any);

      const result = await service.create(dto);

      expect(repo.findOneBy).toHaveBeenCalledWith({ email: dto.email });
      expect(repo.save).toHaveBeenCalled();
      expect(result.email).toBe(dto.email);
    });

    it('should throw ConflictException for duplicate email', async () => {
      const dto = { email: 'test@example.com', name: 'Test', password: 'Password1' };
      repo.findOneBy.mockResolvedValue({ id: 'existing' } as any);

      await expect(service.create(dto)).rejects.toThrow('Email already registered');
    });
  });
});
```

---

## Angular testing

### TestBed setup with PrimeNG

```typescript
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { provideHttpClientTesting } from '@angular/common/http/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideMockStore, MockStore } from '@ngrx/store/testing';
import { UserListPageComponent } from './user-list-page.component';

describe('UserListPageComponent', () => {
  let component: UserListPageComponent;
  let fixture: ComponentFixture<UserListPageComponent>;
  let store: MockStore;

  const initialState = {
    users: {
      users: [],
      loading: false,
      error: null,
      pagination: null,
    },
  };

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [UserListPageComponent],
      providers: [
        provideHttpClient(),
        provideHttpClientTesting(),
        provideMockStore({ initialState }),
      ],
    }).compileComponents();

    store = TestBed.inject(MockStore);
    fixture = TestBed.createComponent(UserListPageComponent);
    component = fixture.componentInstance;
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });
});
```

### Service testing with HttpClientTestingModule

```typescript
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import {
  HttpTestingController,
  provideHttpClientTesting,
} from '@angular/common/http/testing';
import { UsersApiService } from './users-api.service';

describe('UsersApiService', () => {
  let service: UsersApiService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [
        UsersApiService,
        provideHttpClient(),
        provideHttpClientTesting(),
        { provide: 'API_URL', useValue: 'http://localhost:3000/api' },
      ],
    });

    service = TestBed.inject(UsersApiService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => {
    httpMock.verify();
  });

  it('should fetch users', () => {
    const mockUsers = [{ id: '1', email: 'test@example.com' }];

    service.getUsers().subscribe((users) => {
      expect(users).toEqual(mockUsers);
    });

    const req = httpMock.expectOne('http://localhost:3000/api/users');
    expect(req.request.method).toBe('GET');
    req.flush(mockUsers);
  });
});
```

---

## Common failure patterns

### 1. Async test not awaited

**Symptom:** Test passes but warns about unhandled promise, or fails intermittently.

```typescript
// ❌ Bad
it('fetches data', () => {
  const result = fetchData();
  expect(result).toBeDefined();
});

// ✅ Good
it('fetches data', async () => {
  const result = await fetchData();
  expect(result).toBeDefined();
});
```

### 2. Mock not reset between tests

**Symptom:** Tests pass in isolation, fail when run together.

```typescript
// ✅ Reset mocks
beforeEach(() => {
  jest.clearAllMocks();
});
```

### 3. class-validator mismatch

**Symptom:** `BadRequestException` with validation errors in test.

```typescript
// ❌ Bad test input — missing decorators' constraints
const dto = { email: 'not-an-email', name: '' };

// ✅ Good test input — matches DTO validation
const dto = { email: 'test@example.com', name: 'Test User' };
```

### 4. TypeORM repository not mocked

**Symptom:** Test tries to connect to real database, times out or fails.

```typescript
// ✅ Mock the repository
{
  provide: getRepositoryToken(UserEntity),
  useValue: {
    find: jest.fn().mockResolvedValue([]),
    findOneBy: jest.fn().mockResolvedValue(null),
    save: jest.fn().mockResolvedValue(undefined),
    delete: jest.fn().mockResolvedValue({ affected: 1 }),
  },
}
```

### 5. Timing-dependent test

**Symptom:** Flaky — passes sometimes, fails others.

```typescript
// ❌ Bad: relies on real time
it('debounces calls', async () => {
  handler();
  handler();
  await new Promise((r) => setTimeout(r, 100));
  expect(mock).toHaveBeenCalledTimes(1);
});

// ✅ Good: use fake timers
it('debounces calls', () => {
  jest.useFakeTimers();
  handler();
  handler();
  jest.advanceTimersByTime(100);
  expect(mock).toHaveBeenCalledTimes(1);
  jest.useRealTimers();
});
```

### 6. Snapshot out of date

**Symptom:** Snapshot doesn't match.

```bash
# Update snapshots (only if change is intentional)
npx nx run web:test -- -u
```

Review the diff before updating — don't blindly accept.

---

## Debugging tips

### Run single test file

```bash
npx nx run api:test -- --testPathPattern=users.service.spec
```

### Run tests matching pattern

```bash
npx nx run api:test -- -t "should validate email"
```

### Verbose output

```bash
npx nx run api:test -- --verbose
```

### Debug mode (Node inspector)

```bash
node --inspect-brk node_modules/.bin/jest --runInBand --config apps/api/jest.config.ts
```

---

## Report template

```
## Test Results

**Summary:** X passed, Y failed, Z skipped
**Coverage:** Lines 78% | Branches 72% | Functions 80%

### Failures

#### `apps/api/src/modules/users/__tests__/users.service.spec.ts`

**Test:** should reject duplicate email
**Error:**
```
Expected: ConflictException
Received: no exception thrown
```
**Likely cause:** findOneBy mock not returning existing user

#### `apps/web/src/app/users/user-list.component.spec.ts`

**Test:** should display users in table
**Error:**
```
Expected element to contain text "test@example.com"
Received: ""
```
**Likely cause:** Missing fixture.detectChanges() after state update
```

---

## Quick reference

| Task              | Command                                            |
| ----------------- | -------------------------------------------------- |
| Run all tests     | `npm test`                                         |
| Run with coverage | `npx nx run-many --target=test -- --coverage`      |
| Run API tests     | `npx nx run api:test`                              |
| Run web tests     | `npx nx run web:test`                              |
| Run single file   | `npx nx run api:test -- --testPathPattern=<name>`  |
| Run matching name | `npx nx run api:test -- -t "pattern"`              |
| Update snapshots  | `npx nx run web:test -- -u`                        |
| Watch mode        | `npx nx run api:test -- --watch`                   |
| Affected only     | `npx nx affected --target=test`                    |
