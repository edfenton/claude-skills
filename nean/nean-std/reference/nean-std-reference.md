# NEAN Coding Standards Reference

Detailed patterns and examples for NEAN applications.

---

## Response envelope pattern

### API responses

```typescript
// libs/api/common/src/response/api-response.dto.ts

export class ApiResponse<T> {
  success: boolean;
  data?: T;
  error?: {
    code: string;
    message: string;
    details?: Record<string, unknown>;
  };
  meta?: {
    page?: number;
    limit?: number;
    total?: number;
    totalPages?: number;
  };
}

// Success helper
export function ok<T>(data: T, meta?: ApiResponse<T>['meta']): ApiResponse<T> {
  return { success: true, data, meta };
}

// Error helper
export function err(code: string, message: string, details?: Record<string, unknown>): ApiResponse<never> {
  return { success: false, error: { code, message, details } };
}
```

### Pagination

```typescript
// libs/shared/types/src/pagination.dto.ts

export class PaginationDto {
  @IsOptional()
  @IsInt()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10))
  page?: number = 1;

  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Transform(({ value }) => parseInt(value, 10))
  limit?: number = 20;

  @IsOptional()
  @IsString()
  sortBy?: string;

  @IsOptional()
  @IsEnum(['ASC', 'DESC'])
  sortOrder?: 'ASC' | 'DESC' = 'DESC';
}

export class PaginatedResponse<T> {
  items: T[];
  meta: {
    page: number;
    limit: number;
    total: number;
    totalPages: number;
  };
}
```

### Service implementation

```typescript
// Paginated query helper
async findAll(dto: PaginationDto): Promise<PaginatedResponse<UserResponseDto>> {
  const { page, limit, sortBy, sortOrder } = dto;
  const skip = (page - 1) * limit;

  const [items, total] = await this.userRepo.findAndCount({
    skip,
    take: limit,
    order: sortBy ? { [sortBy]: sortOrder } : { createdAt: 'DESC' },
  });

  return {
    items: items.map(this.toResponseDto),
    meta: {
      page,
      limit,
      total,
      totalPages: Math.ceil(total / limit),
    },
  };
}
```

---

## NestJS patterns

### Module structure

```typescript
// modules/users/users.module.ts
@Module({
  imports: [
    TypeOrmModule.forFeature([UserEntity]),
    AuthModule, // If auth is needed
  ],
  controllers: [UsersController],
  providers: [UsersService],
  exports: [UsersService], // Only export if needed by other modules
})
export class UsersModule {}
```

### Controller pattern

```typescript
@Controller('users')
@ApiTags('users')
@UseGuards(JwtAuthGuard) // Protect all routes
export class UsersController {
  constructor(private readonly usersService: UsersService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create user' })
  @ApiCreatedResponse({ type: UserResponseDto })
  async create(
    @Body(new ValidationPipe({ whitelist: true })) dto: CreateUserDto,
  ): Promise<UserResponseDto> {
    return this.usersService.create(dto);
  }

  @Get()
  @ApiOperation({ summary: 'List users' })
  async findAll(
    @Query(new ValidationPipe({ transform: true })) query: PaginationDto,
  ): Promise<PaginatedResponse<UserResponseDto>> {
    return this.usersService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user' })
  async findOne(
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<UserResponseDto> {
    return this.usersService.findOne(id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update user' })
  @UseGuards(OwnershipGuard) // Additional authorization
  async update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ValidationPipe({ whitelist: true })) dto: UpdateUserDto,
  ): Promise<UserResponseDto> {
    return this.usersService.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete user' })
  @UseGuards(OwnershipGuard)
  async remove(@Param('id', ParseUUIDPipe) id: string): Promise<void> {
    return this.usersService.remove(id);
  }
}
```

### Service pattern

```typescript
@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(UserEntity)
    private readonly userRepo: Repository<UserEntity>,
  ) {}

  async create(dto: CreateUserDto): Promise<UserResponseDto> {
    // Check uniqueness
    const exists = await this.userRepo.findOneBy({ email: dto.email });
    if (exists) {
      throw new ConflictException('Email already registered');
    }

    // Hash password
    const passwordHash = await bcrypt.hash(dto.password, 12);

    // Create entity
    const user = this.userRepo.create({
      ...dto,
      passwordHash,
    });

    const saved = await this.userRepo.save(user);
    return this.toResponseDto(saved);
  }

  async findOne(id: string): Promise<UserResponseDto> {
    const user = await this.userRepo.findOneBy({ id });
    if (!user) {
      throw new NotFoundException('User not found');
    }
    return this.toResponseDto(user);
  }

  private toResponseDto(entity: UserEntity): UserResponseDto {
    return {
      id: entity.id,
      email: entity.email,
      firstName: entity.firstName,
      lastName: entity.lastName,
      createdAt: entity.createdAt,
    };
  }
}
```

---

## Angular patterns

### Smart vs Presentational components

```typescript
// Smart component (container) - handles state and logic
@Component({
  selector: 'app-user-list-page',
  standalone: true,
  imports: [CommonModule, UserListComponent, UserFilterComponent],
  template: `
    <app-user-filter (filterChange)="onFilterChange($event)" />
    <app-user-list
      [users]="users()"
      [loading]="loading()"
      (userSelect)="onUserSelect($event)"
    />
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListPageComponent {
  private store = inject(Store);
  
  users = this.store.selectSignal(selectUsers);
  loading = this.store.selectSignal(selectUsersLoading);

  onFilterChange(filter: UserFilter) {
    this.store.dispatch(usersActions.loadUsers({ filter }));
  }

  onUserSelect(user: User) {
    this.router.navigate(['/users', user.id]);
  }
}

// Presentational component - pure display
@Component({
  selector: 'app-user-list',
  standalone: true,
  imports: [CommonModule, TableModule],
  template: `
    <p-table [value]="users" [loading]="loading">
      <ng-template pTemplate="body" let-user>
        <tr (click)="userSelect.emit(user)">
          <td>{{ user.email }}</td>
          <td>{{ user.firstName }} {{ user.lastName }}</td>
        </tr>
      </ng-template>
    </p-table>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class UserListComponent {
  @Input({ required: true }) users: User[] = [];
  @Input() loading = false;
  @Output() userSelect = new EventEmitter<User>();
}
```

### Service pattern

```typescript
@Injectable({ providedIn: 'root' })
export class UsersApiService {
  private http = inject(HttpClient);
  private apiUrl = inject(API_URL);

  getUsers(params?: PaginationParams): Observable<PaginatedResponse<User>> {
    return this.http.get<PaginatedResponse<User>>(`${this.apiUrl}/users`, {
      params: params ? this.toHttpParams(params) : undefined,
    });
  }

  getUser(id: string): Observable<User> {
    return this.http.get<User>(`${this.apiUrl}/users/${id}`);
  }

  createUser(dto: CreateUserDto): Observable<User> {
    return this.http.post<User>(`${this.apiUrl}/users`, dto);
  }

  updateUser(id: string, dto: UpdateUserDto): Observable<User> {
    return this.http.patch<User>(`${this.apiUrl}/users/${id}`, dto);
  }

  deleteUser(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/users/${id}`);
  }

  private toHttpParams(params: Record<string, unknown>): HttpParams {
    let httpParams = new HttpParams();
    Object.entries(params).forEach(([key, value]) => {
      if (value !== undefined && value !== null) {
        httpParams = httpParams.set(key, String(value));
      }
    });
    return httpParams;
  }
}
```

### NgRx state pattern

```typescript
// users.state.ts
export interface UsersState {
  users: User[];
  selectedUser: User | null;
  loading: boolean;
  error: string | null;
  pagination: PaginationMeta | null;
}

export const initialState: UsersState = {
  users: [],
  selectedUser: null,
  loading: false,
  error: null,
  pagination: null,
};

// users.actions.ts
export const usersActions = createActionGroup({
  source: 'Users',
  events: {
    'Load Users': props<{ filter?: UserFilter }>(),
    'Load Users Success': props<{ response: PaginatedResponse<User> }>(),
    'Load Users Failure': props<{ error: string }>(),
    'Select User': props<{ id: string }>(),
  },
});

// users.reducer.ts
export const usersReducer = createReducer(
  initialState,
  on(usersActions.loadUsers, (state) => ({
    ...state,
    loading: true,
    error: null,
  })),
  on(usersActions.loadUsersSuccess, (state, { response }) => ({
    ...state,
    users: response.items,
    pagination: response.meta,
    loading: false,
  })),
  on(usersActions.loadUsersFailure, (state, { error }) => ({
    ...state,
    error,
    loading: false,
  })),
);

// users.effects.ts
@Injectable()
export class UsersEffects {
  private actions$ = inject(Actions);
  private usersApi = inject(UsersApiService);

  loadUsers$ = createEffect(() =>
    this.actions$.pipe(
      ofType(usersActions.loadUsers),
      switchMap(({ filter }) =>
        this.usersApi.getUsers(filter).pipe(
          map((response) => usersActions.loadUsersSuccess({ response })),
          catchError((error) =>
            of(usersActions.loadUsersFailure({ error: error.message })),
          ),
        ),
      ),
    ),
  );
}
```

---

## Error handling

### NestJS exception filter

```typescript
// libs/api/common/src/filters/all-exceptions.filter.ts
@Catch()
export class AllExceptionsFilter implements ExceptionFilter {
  private readonly logger = new Logger(AllExceptionsFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse();
    const request = ctx.getRequest();

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'Internal server error';
    let code = 'INTERNAL_ERROR';

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const exceptionResponse = exception.getResponse();
      message = typeof exceptionResponse === 'string' 
        ? exceptionResponse 
        : (exceptionResponse as any).message || message;
      code = this.getErrorCode(status);
    }

    // Log full error server-side
    this.logger.error({
      message: exception instanceof Error ? exception.message : 'Unknown error',
      stack: exception instanceof Error ? exception.stack : undefined,
      path: request.url,
      method: request.method,
      userId: request.user?.id,
    });

    // Safe response to client
    response.status(status).json({
      success: false,
      error: {
        code,
        message,
        timestamp: new Date().toISOString(),
        path: request.url,
      },
    });
  }

  private getErrorCode(status: number): string {
    const codes: Record<number, string> = {
      400: 'BAD_REQUEST',
      401: 'UNAUTHORIZED',
      403: 'FORBIDDEN',
      404: 'NOT_FOUND',
      409: 'CONFLICT',
      422: 'UNPROCESSABLE_ENTITY',
      429: 'TOO_MANY_REQUESTS',
      500: 'INTERNAL_ERROR',
    };
    return codes[status] || 'UNKNOWN_ERROR';
  }
}
```

### Angular error interceptor

```typescript
// libs/web/common/src/interceptors/error.interceptor.ts
@Injectable()
export class ErrorInterceptor implements HttpInterceptor {
  private toastService = inject(ToastService);
  private router = inject(Router);

  intercept(req: HttpRequest<unknown>, next: HttpHandler): Observable<HttpEvent<unknown>> {
    return next.handle(req).pipe(
      catchError((error: HttpErrorResponse) => {
        if (error.status === 401) {
          this.router.navigate(['/auth/login']);
        } else if (error.status === 403) {
          this.toastService.error('You do not have permission to perform this action');
        } else if (error.status >= 500) {
          this.toastService.error('An unexpected error occurred. Please try again later.');
        } else if (error.error?.error?.message) {
          this.toastService.error(error.error.error.message);
        }
        return throwError(() => error);
      }),
    );
  }
}
```

---

## Quick reference

| Question                           | Answer                                        |
| ---------------------------------- | --------------------------------------------- |
| Where do shared types go?          | `libs/shared/types/`                          |
| Where do API services go?          | `libs/web/data-access/`                       |
| Where do entities go?              | `libs/api/database/src/entities/`             |
| How to add a new feature module?   | `nx g @nx/nest:module modules/feature --project=api` |
| How to add a new Angular component?| `nx g @nx/angular:component feature --project=web` |
| Validation library                 | class-validator (NestJS), Angular forms (web) |
| State management                   | NgRx                                          |
| Default change detection           | OnPush                                        |
