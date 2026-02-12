# NEAN Add Feature Reference

Templates and patterns for scaffolding features.

---

## Shared DTO Template

```typescript
// libs/shared/types/src/todo-item.dto.ts
import {
  IsString,
  IsOptional,
  IsEnum,
  IsInt,
  Min,
  Max,
  MaxLength,
  MinLength,
} from 'class-validator';
import { Transform } from 'class-transformer';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// --- Create DTO ---

export class CreateTodoItemDto {
  @ApiProperty({ description: 'Title of the item', example: 'Buy groceries' })
  @IsString()
  @MinLength(1)
  @MaxLength(200)
  title: string;

  @ApiPropertyOptional({ description: 'Detailed description', example: 'Milk, eggs, bread' })
  @IsOptional()
  @IsString()
  @MaxLength(2000)
  description?: string;

  @ApiPropertyOptional({ enum: ['pending', 'in_progress', 'completed'], default: 'pending' })
  @IsOptional()
  @IsEnum(['pending', 'in_progress', 'completed'])
  status?: 'pending' | 'in_progress' | 'completed' = 'pending';
}

// --- Update DTO (PartialType from @nestjs/swagger) ---

import { PartialType } from '@nestjs/swagger';

export class UpdateTodoItemDto extends PartialType(CreateTodoItemDto) {}

// --- Response DTO ---

export class TodoItemResponseDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000' })
  id: string;

  @ApiProperty()
  title: string;

  @ApiPropertyOptional()
  description?: string;

  @ApiProperty({ enum: ['pending', 'in_progress', 'completed'] })
  status: string;

  @ApiProperty()
  userId: string;

  @ApiProperty()
  createdAt: Date;

  @ApiProperty()
  updatedAt: Date;
}

// --- Query DTO ---

export class TodoItemQueryDto {
  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Transform(({ value }) => parseInt(value, 10))
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @IsInt()
  @Min(1)
  @Max(100)
  @Transform(({ value }) => parseInt(value, 10))
  limit?: number = 20;

  @ApiPropertyOptional({ enum: ['pending', 'in_progress', 'completed'] })
  @IsOptional()
  @IsEnum(['pending', 'in_progress', 'completed'])
  status?: 'pending' | 'in_progress' | 'completed';
}
```

---

## TypeORM Entity Template

```typescript
// libs/api/database/src/entities/todo-item.entity.ts
import {
  Entity,
  PrimaryGeneratedColumn,
  Column,
  CreateDateColumn,
  UpdateDateColumn,
  Index,
  ManyToOne,
  JoinColumn,
} from 'typeorm';
import { UserEntity } from './user.entity';

@Entity('todo_items')
export class TodoItemEntity {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ length: 200 })
  title: string;

  @Column({ type: 'text', nullable: true })
  description: string | null;

  @Column({
    type: 'enum',
    enum: ['pending', 'in_progress', 'completed'],
    default: 'pending',
  })
  status: 'pending' | 'in_progress' | 'completed';

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => UserEntity, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: UserEntity;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}

// Index: user's items by date (list endpoint)
@Index('IDX_todo_items_user_created', ['userId', 'createdAt'])

// Index: filter by status (filtered lists)
@Index('IDX_todo_items_user_status', ['userId', 'status'])
```

---

## NestJS Module Template

```typescript
// apps/api/src/modules/todo-item/todo-item.module.ts
import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { TodoItemEntity } from '@libs/api/database/entities/todo-item.entity';
import { TodoItemController } from './todo-item.controller';
import { TodoItemService } from './todo-item.service';

@Module({
  imports: [TypeOrmModule.forFeature([TodoItemEntity])],
  controllers: [TodoItemController],
  providers: [TodoItemService],
  exports: [TodoItemService],
})
export class TodoItemModule {}
```

---

## NestJS Controller Template

```typescript
// apps/api/src/modules/todo-item/todo-item.controller.ts
import {
  Controller,
  Get,
  Post,
  Patch,
  Delete,
  Body,
  Param,
  Query,
  HttpCode,
  HttpStatus,
  UseGuards,
  ParseUUIDPipe,
  ValidationPipe,
} from '@nestjs/common';
import { ApiTags, ApiOperation, ApiBearerAuth, ApiCreatedResponse } from '@nestjs/swagger';
import { JwtAuthGuard } from '@libs/api/auth/guards/jwt-auth.guard';
import { CurrentUser } from '@libs/api/auth/decorators/current-user.decorator';
import { TodoItemService } from './todo-item.service';
import {
  CreateTodoItemDto,
  UpdateTodoItemDto,
  TodoItemQueryDto,
  TodoItemResponseDto,
} from '@libs/shared/types';
import { PaginatedResponse } from '@libs/shared/types/pagination.dto';

@Controller('todo-items')
@ApiTags('todo-items')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class TodoItemController {
  constructor(private readonly todoItemService: TodoItemService) {}

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create todo item' })
  @ApiCreatedResponse({ type: TodoItemResponseDto })
  async create(
    @CurrentUser('id') userId: string,
    @Body(new ValidationPipe({ whitelist: true })) dto: CreateTodoItemDto,
  ): Promise<TodoItemResponseDto> {
    return this.todoItemService.create(userId, dto);
  }

  @Get()
  @ApiOperation({ summary: 'List todo items' })
  async findAll(
    @CurrentUser('id') userId: string,
    @Query(new ValidationPipe({ transform: true })) query: TodoItemQueryDto,
  ): Promise<PaginatedResponse<TodoItemResponseDto>> {
    return this.todoItemService.findAll(userId, query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get todo item' })
  async findOne(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<TodoItemResponseDto> {
    return this.todoItemService.findOne(userId, id);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update todo item' })
  async update(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ValidationPipe({ whitelist: true })) dto: UpdateTodoItemDto,
  ): Promise<TodoItemResponseDto> {
    return this.todoItemService.update(userId, id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete todo item' })
  async remove(
    @CurrentUser('id') userId: string,
    @Param('id', ParseUUIDPipe) id: string,
  ): Promise<void> {
    return this.todoItemService.remove(userId, id);
  }
}
```

---

## NestJS Service Template

```typescript
// apps/api/src/modules/todo-item/todo-item.service.ts
import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { TodoItemEntity } from '@libs/api/database/entities/todo-item.entity';
import {
  CreateTodoItemDto,
  UpdateTodoItemDto,
  TodoItemQueryDto,
  TodoItemResponseDto,
} from '@libs/shared/types';
import { PaginatedResponse } from '@libs/shared/types/pagination.dto';

@Injectable()
export class TodoItemService {
  constructor(
    @InjectRepository(TodoItemEntity)
    private readonly todoItemRepo: Repository<TodoItemEntity>,
  ) {}

  async create(userId: string, dto: CreateTodoItemDto): Promise<TodoItemResponseDto> {
    const entity = this.todoItemRepo.create({ ...dto, userId });
    const saved = await this.todoItemRepo.save(entity);
    return this.toResponseDto(saved);
  }

  async findAll(
    userId: string,
    query: TodoItemQueryDto,
  ): Promise<PaginatedResponse<TodoItemResponseDto>> {
    const { page, limit, status } = query;
    const skip = (page - 1) * limit;

    const where: Record<string, unknown> = { userId };
    if (status) where.status = status;

    const [items, total] = await this.todoItemRepo.findAndCount({
      where,
      skip,
      take: limit,
      order: { createdAt: 'DESC' },
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

  async findOne(userId: string, id: string): Promise<TodoItemResponseDto> {
    const entity = await this.todoItemRepo.findOneBy({ id, userId });
    if (!entity) {
      throw new NotFoundException('Todo item not found');
    }
    return this.toResponseDto(entity);
  }

  async update(
    userId: string,
    id: string,
    dto: UpdateTodoItemDto,
  ): Promise<TodoItemResponseDto> {
    const entity = await this.todoItemRepo.findOneBy({ id, userId });
    if (!entity) {
      throw new NotFoundException('Todo item not found');
    }

    Object.assign(entity, dto);
    const saved = await this.todoItemRepo.save(entity);
    return this.toResponseDto(saved);
  }

  async remove(userId: string, id: string): Promise<void> {
    const result = await this.todoItemRepo.delete({ id, userId });
    if (result.affected === 0) {
      throw new NotFoundException('Todo item not found');
    }
  }

  private toResponseDto(entity: TodoItemEntity): TodoItemResponseDto {
    return {
      id: entity.id,
      title: entity.title,
      description: entity.description,
      status: entity.status,
      userId: entity.userId,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
    };
  }
}
```

---

## Angular Components

### Smart (container) component

```typescript
// apps/web/src/app/todo-item/todo-item-list-page.component.ts
@Component({
  selector: 'app-todo-item-list-page',
  standalone: true,
  imports: [CommonModule, TodoItemListComponent, TodoItemFormComponent],
  template: `
    <div class="p-4">
      <div class="flex justify-content-between align-items-center mb-4">
        <h2 class="text-xl font-semibold">Todo Items</h2>
        <button pButton label="Add Item" icon="pi pi-plus" (click)="showForm = true"></button>
      </div>

      @if (showForm) {
        <app-todo-item-form
          (submitted)="onCreate($event)"
          (cancelled)="showForm = false"
        />
      }

      <app-todo-item-list
        [items]="items()"
        [loading]="loading()"
        (itemDelete)="onDelete($event)"
      />
    </div>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TodoItemListPageComponent {
  private store = inject(Store);

  items = this.store.selectSignal(selectTodoItems);
  loading = this.store.selectSignal(selectTodoItemsLoading);
  showForm = false;

  constructor() {
    this.store.dispatch(todoItemActions.loadItems({}));
  }

  onCreate(dto: CreateTodoItemDto) {
    this.store.dispatch(todoItemActions.createItem({ dto }));
    this.showForm = false;
  }

  onDelete(id: string) {
    this.store.dispatch(todoItemActions.deleteItem({ id }));
  }
}
```

### Presentational component (list)

```typescript
// apps/web/src/app/todo-item/todo-item-list.component.ts
@Component({
  selector: 'app-todo-item-list',
  standalone: true,
  imports: [CommonModule, TableModule, ButtonModule],
  template: `
    <p-table [value]="items" [loading]="loading" [paginator]="true" [rows]="20">
      <ng-template pTemplate="header">
        <tr>
          <th>Title</th>
          <th>Status</th>
          <th>Created</th>
          <th style="width: 80px"></th>
        </tr>
      </ng-template>
      <ng-template pTemplate="body" let-item>
        <tr>
          <td>{{ item.title }}</td>
          <td>
            <p-tag [value]="item.status" [severity]="statusSeverity(item.status)" />
          </td>
          <td>{{ item.createdAt | date: 'mediumDate' }}</td>
          <td>
            <button
              pButton
              icon="pi pi-trash"
              class="p-button-text p-button-danger"
              (click)="itemDelete.emit(item.id)"
              [attr.aria-label]="'Delete ' + item.title"
            ></button>
          </td>
        </tr>
      </ng-template>
      <ng-template pTemplate="emptymessage">
        <tr>
          <td colspan="4" class="text-center text-color-secondary p-4">
            No items yet.
          </td>
        </tr>
      </ng-template>
    </p-table>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TodoItemListComponent {
  @Input({ required: true }) items: TodoItemResponseDto[] = [];
  @Input() loading = false;
  @Output() itemDelete = new EventEmitter<string>();

  statusSeverity(status: string): string {
    const map: Record<string, string> = {
      pending: 'warning',
      in_progress: 'info',
      completed: 'success',
    };
    return map[status] ?? 'info';
  }
}
```

### Form component

```typescript
// apps/web/src/app/todo-item/todo-item-form.component.ts
@Component({
  selector: 'app-todo-item-form',
  standalone: true,
  imports: [CommonModule, ReactiveFormsModule, InputTextModule, InputTextareaModule, ButtonModule],
  template: `
    <form [formGroup]="form" (ngSubmit)="onSubmit()" class="p-4 border-1 border-round surface-border">
      <div class="field">
        <label for="title" class="block text-sm font-medium mb-1">Title</label>
        <input id="title" pInputText formControlName="title" class="w-full" />
      </div>
      <div class="field">
        <label for="description" class="block text-sm font-medium mb-1">Description</label>
        <textarea
          id="description"
          pInputTextarea
          formControlName="description"
          class="w-full"
          [rows]="3"
        ></textarea>
      </div>
      <div class="flex justify-content-end gap-2">
        <button pButton type="button" label="Cancel" class="p-button-text" (click)="cancelled.emit()"></button>
        <button pButton type="submit" label="Save" [disabled]="form.invalid"></button>
      </div>
    </form>
  `,
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TodoItemFormComponent {
  @Output() submitted = new EventEmitter<CreateTodoItemDto>();
  @Output() cancelled = new EventEmitter<void>();

  form = new FormGroup({
    title: new FormControl('', [Validators.required, Validators.maxLength(200)]),
    description: new FormControl(''),
  });

  onSubmit() {
    if (this.form.valid) {
      this.submitted.emit(this.form.value as CreateTodoItemDto);
    }
  }
}
```

---

## NgRx State Template

```typescript
// libs/web/data-access/src/todo-item/todo-item.actions.ts
import { createActionGroup, props } from '@ngrx/store';
import { CreateTodoItemDto, TodoItemResponseDto, PaginatedResponse } from '@libs/shared/types';

export const todoItemActions = createActionGroup({
  source: 'TodoItem',
  events: {
    'Load Items': props<{ status?: string }>(),
    'Load Items Success': props<{ response: PaginatedResponse<TodoItemResponseDto> }>(),
    'Load Items Failure': props<{ error: string }>(),
    'Create Item': props<{ dto: CreateTodoItemDto }>(),
    'Create Item Success': props<{ item: TodoItemResponseDto }>(),
    'Create Item Failure': props<{ error: string }>(),
    'Delete Item': props<{ id: string }>(),
    'Delete Item Success': props<{ id: string }>(),
    'Delete Item Failure': props<{ error: string }>(),
  },
});
```

```typescript
// libs/web/data-access/src/todo-item/todo-item.reducer.ts
import { createReducer, on } from '@ngrx/store';
import { TodoItemResponseDto, PaginationMeta } from '@libs/shared/types';
import { todoItemActions } from './todo-item.actions';

export interface TodoItemState {
  items: TodoItemResponseDto[];
  loading: boolean;
  error: string | null;
  pagination: PaginationMeta | null;
}

const initialState: TodoItemState = {
  items: [],
  loading: false,
  error: null,
  pagination: null,
};

export const todoItemReducer = createReducer(
  initialState,
  on(todoItemActions.loadItems, (state) => ({
    ...state,
    loading: true,
    error: null,
  })),
  on(todoItemActions.loadItemsSuccess, (state, { response }) => ({
    ...state,
    items: response.items,
    pagination: response.meta,
    loading: false,
  })),
  on(todoItemActions.loadItemsFailure, (state, { error }) => ({
    ...state,
    error,
    loading: false,
  })),
  on(todoItemActions.createItemSuccess, (state, { item }) => ({
    ...state,
    items: [item, ...state.items],
  })),
  on(todoItemActions.deleteItemSuccess, (state, { id }) => ({
    ...state,
    items: state.items.filter((i) => i.id !== id),
  })),
);
```

```typescript
// libs/web/data-access/src/todo-item/todo-item.effects.ts
import { Injectable, inject } from '@angular/core';
import { Actions, createEffect, ofType } from '@ngrx/effects';
import { of } from 'rxjs';
import { map, switchMap, catchError } from 'rxjs/operators';
import { TodoItemApiService } from './todo-item-api.service';
import { todoItemActions } from './todo-item.actions';

@Injectable()
export class TodoItemEffects {
  private actions$ = inject(Actions);
  private api = inject(TodoItemApiService);

  loadItems$ = createEffect(() =>
    this.actions$.pipe(
      ofType(todoItemActions.loadItems),
      switchMap(({ status }) =>
        this.api.getItems({ status }).pipe(
          map((response) => todoItemActions.loadItemsSuccess({ response })),
          catchError((error) =>
            of(todoItemActions.loadItemsFailure({ error: error.message })),
          ),
        ),
      ),
    ),
  );

  createItem$ = createEffect(() =>
    this.actions$.pipe(
      ofType(todoItemActions.createItem),
      switchMap(({ dto }) =>
        this.api.createItem(dto).pipe(
          map((item) => todoItemActions.createItemSuccess({ item })),
          catchError((error) =>
            of(todoItemActions.createItemFailure({ error: error.message })),
          ),
        ),
      ),
    ),
  );

  deleteItem$ = createEffect(() =>
    this.actions$.pipe(
      ofType(todoItemActions.deleteItem),
      switchMap(({ id }) =>
        this.api.deleteItem(id).pipe(
          map(() => todoItemActions.deleteItemSuccess({ id })),
          catchError((error) =>
            of(todoItemActions.deleteItemFailure({ error: error.message })),
          ),
        ),
      ),
    ),
  );
}
```

---

## Angular Data-Access Service

```typescript
// libs/web/data-access/src/todo-item/todo-item-api.service.ts
import { Injectable, inject } from '@angular/core';
import { HttpClient, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import {
  CreateTodoItemDto,
  UpdateTodoItemDto,
  TodoItemResponseDto,
  PaginatedResponse,
} from '@libs/shared/types';
import { API_URL } from '../api-url.token';

@Injectable({ providedIn: 'root' })
export class TodoItemApiService {
  private http = inject(HttpClient);
  private apiUrl = inject(API_URL);

  getItems(params?: { status?: string }): Observable<PaginatedResponse<TodoItemResponseDto>> {
    let httpParams = new HttpParams();
    if (params?.status) {
      httpParams = httpParams.set('status', params.status);
    }
    return this.http.get<PaginatedResponse<TodoItemResponseDto>>(
      `${this.apiUrl}/todo-items`,
      { params: httpParams },
    );
  }

  getItem(id: string): Observable<TodoItemResponseDto> {
    return this.http.get<TodoItemResponseDto>(`${this.apiUrl}/todo-items/${id}`);
  }

  createItem(dto: CreateTodoItemDto): Observable<TodoItemResponseDto> {
    return this.http.post<TodoItemResponseDto>(`${this.apiUrl}/todo-items`, dto);
  }

  updateItem(id: string, dto: UpdateTodoItemDto): Observable<TodoItemResponseDto> {
    return this.http.patch<TodoItemResponseDto>(`${this.apiUrl}/todo-items/${id}`, dto);
  }

  deleteItem(id: string): Observable<void> {
    return this.http.delete<void>(`${this.apiUrl}/todo-items/${id}`);
  }
}
```

---

## Test Templates

### NestJS service spec

```typescript
// apps/api/src/modules/todo-item/__tests__/todo-item.service.spec.ts
import { Test, TestingModule } from '@nestjs/testing';
import { getRepositoryToken } from '@nestjs/typeorm';
import { NotFoundException } from '@nestjs/common';
import { TodoItemService } from '../todo-item.service';
import { TodoItemEntity } from '@libs/api/database/entities/todo-item.entity';

describe('TodoItemService', () => {
  let service: TodoItemService;
  let repo: Record<string, jest.Mock>;

  beforeEach(async () => {
    repo = {
      create: jest.fn(),
      save: jest.fn(),
      findOneBy: jest.fn(),
      findAndCount: jest.fn(),
      delete: jest.fn(),
    };

    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TodoItemService,
        { provide: getRepositoryToken(TodoItemEntity), useValue: repo },
      ],
    }).compile();

    service = module.get(TodoItemService);
  });

  afterEach(() => jest.clearAllMocks());

  describe('create', () => {
    it('should create a todo item', async () => {
      const dto = { title: 'Test', description: 'Desc' };
      const entity = { id: 'uuid-1', ...dto, userId: 'user-1', status: 'pending', createdAt: new Date(), updatedAt: new Date() };

      repo.create.mockReturnValue(entity);
      repo.save.mockResolvedValue(entity);

      const result = await service.create('user-1', dto);

      expect(repo.create).toHaveBeenCalledWith({ ...dto, userId: 'user-1' });
      expect(result.title).toBe('Test');
    });
  });

  describe('findOne', () => {
    it('should throw NotFoundException when not found', async () => {
      repo.findOneBy.mockResolvedValue(null);

      await expect(service.findOne('user-1', 'uuid-1')).rejects.toThrow(NotFoundException);
    });
  });
});
```

### Angular component spec

```typescript
// apps/web/src/app/todo-item/todo-item-list.component.spec.ts
import { ComponentFixture, TestBed } from '@angular/core/testing';
import { TodoItemListComponent } from './todo-item-list.component';

describe('TodoItemListComponent', () => {
  let component: TodoItemListComponent;
  let fixture: ComponentFixture<TodoItemListComponent>;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [TodoItemListComponent],
    }).compileComponents();

    fixture = TestBed.createComponent(TodoItemListComponent);
    component = fixture.componentInstance;
    component.items = [];
    fixture.detectChanges();
  });

  it('should create', () => {
    expect(component).toBeTruthy();
  });

  it('should display empty message when no items', () => {
    const el: HTMLElement = fixture.nativeElement;
    expect(el.textContent).toContain('No items yet');
  });

  it('should emit delete event', () => {
    jest.spyOn(component.itemDelete, 'emit');
    component.items = [
      { id: '1', title: 'Test', status: 'pending', userId: 'u1', createdAt: new Date(), updatedAt: new Date() },
    ];
    fixture.detectChanges();

    const deleteBtn = fixture.nativeElement.querySelector('[aria-label="Delete Test"]');
    deleteBtn?.click();

    expect(component.itemDelete.emit).toHaveBeenCalledWith('1');
  });
});
```
