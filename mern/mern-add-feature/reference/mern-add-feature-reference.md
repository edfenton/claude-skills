# MERN Add Feature Reference

Templates and patterns for scaffolding features.

---

## Zod Schema Template

```typescript
// packages/shared/schemas/todo-item.ts
import { z } from 'zod';

// Base fields
const TodoItemBase = z.object({
  title: z.string().min(1).max(200),
  description: z.string().max(2000).optional(),
  status: z.enum(['pending', 'in_progress', 'completed']).default('pending'),
});

// Create input
export const CreateTodoItemSchema = TodoItemBase;
export type CreateTodoItemInput = z.infer<typeof CreateTodoItemSchema>;

// Update input (all optional)
export const UpdateTodoItemSchema = TodoItemBase.partial();
export type UpdateTodoItemInput = z.infer<typeof UpdateTodoItemSchema>;

// Full entity (includes server fields)
export const TodoItemSchema = TodoItemBase.extend({
  id: z.string(),
  userId: z.string(),
  createdAt: z.string().datetime(),
  updatedAt: z.string().datetime(),
});
export type TodoItem = z.infer<typeof TodoItemSchema>;

// List query params
export const TodoItemQuerySchema = z.object({
  cursor: z.string().optional(),
  limit: z.coerce.number().min(1).max(100).default(20),
  status: z.enum(['pending', 'in_progress', 'completed']).optional(),
});
export type TodoItemQuery = z.infer<typeof TodoItemQuerySchema>;
```

---

## Mongoose Model Template

```typescript
// apps/web/src/server/db/models/todo-item.ts
import mongoose, { Schema, Document, Types } from 'mongoose';

export interface ITodoItem extends Document {
  _id: Types.ObjectId;
  userId: Types.ObjectId;
  title: string;
  description?: string;
  status: 'pending' | 'in_progress' | 'completed';
  createdAt: Date;
  updatedAt: Date;
}

const todoItemSchema = new Schema<ITodoItem>(
  {
    userId: { type: Schema.Types.ObjectId, required: true, ref: 'User' },
    title: { type: String, required: true, maxlength: 200, trim: true },
    description: { type: String, maxlength: 2000, trim: true },
    status: {
      type: String,
      enum: ['pending', 'in_progress', 'completed'],
      default: 'pending',
    },
  },
  { timestamps: true }
);

// Index: user's items by date (list endpoint)
todoItemSchema.index({ userId: 1, createdAt: -1 });

// Index: filter by status (filtered lists)
todoItemSchema.index({ userId: 1, status: 1 });

todoItemSchema.set('toJSON', {
  transform: (_doc, ret) => {
    ret.id = ret._id.toString();
    ret.userId = ret.userId.toString();
    delete ret._id;
    delete ret.__v;
    return ret;
  },
});

export const TodoItem =
  mongoose.models.TodoItem || mongoose.model<ITodoItem>('TodoItem', todoItemSchema);
```

---

## API Route Template (Collection)

```typescript
// apps/web/src/app/api/todo-item/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';
import { connectMongoose } from '@/server/db/mongoose';
import { TodoItem } from '@/server/db/models/todo-item';
import { rejectMongoOperators } from '@/server/db/sanitize';
import { ok, err } from '@/server/http/response';
import { parseJson } from '@/server/http/validate';
import { CreateTodoItemSchema, TodoItemQuerySchema } from '@repo/shared';

export async function GET(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json(err('UNAUTHORIZED', 'Authentication required'), { status: 401 });
    }

    await connectMongoose();
    const query = TodoItemQuerySchema.parse(
      Object.fromEntries(req.nextUrl.searchParams)
    );

    const filter: Record<string, unknown> = { userId: session.user.id };
    if (query.status) filter.status = query.status;
    if (query.cursor) filter._id = { $lt: query.cursor };

    const items = await TodoItem.find(filter)
      .sort({ createdAt: -1 })
      .limit(query.limit + 1)
      .lean();

    const hasMore = items.length > query.limit;
    const results = hasMore ? items.slice(0, -1) : items;

    return NextResponse.json(ok({
      items: results,
      cursor: hasMore ? results.at(-1)?._id?.toString() : undefined,
      hasMore,
    }));
  } catch (error) {
    console.error('[GET /api/todo-item]', error);
    return NextResponse.json(err('INTERNAL_ERROR', 'Failed to fetch'), { status: 500 });
  }
}

export async function POST(req: NextRequest) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json(err('UNAUTHORIZED', 'Authentication required'), { status: 401 });
    }

    await connectMongoose();
    const body = rejectMongoOperators(await req.json());
    const input = parseJson(CreateTodoItemSchema, body);

    const item = await TodoItem.create({ ...input, userId: session.user.id });
    return NextResponse.json(ok(item.toJSON()), { status: 201 });
  } catch (error) {
    if (error instanceof Error && error.message.startsWith('Validation')) {
      return NextResponse.json(err('VALIDATION_ERROR', error.message), { status: 400 });
    }
    console.error('[POST /api/todo-item]', error);
    return NextResponse.json(err('INTERNAL_ERROR', 'Failed to create'), { status: 500 });
  }
}
```

---

## API Route Template (Single Item)

```typescript
// apps/web/src/app/api/todo-item/[id]/route.ts
import { NextRequest, NextResponse } from 'next/server';
import { getServerSession } from 'next-auth';
import { Types } from 'mongoose';
import { authOptions } from '@/lib/auth';
import { connectMongoose } from '@/server/db/mongoose';
import { TodoItem } from '@/server/db/models/todo-item';
import { rejectMongoOperators } from '@/server/db/sanitize';
import { ok, err } from '@/server/http/response';
import { parseJson } from '@/server/http/validate';
import { UpdateTodoItemSchema } from '@repo/shared';

type Params = { params: { id: string } };

function isValidId(id: string) {
  return Types.ObjectId.isValid(id) && new Types.ObjectId(id).toString() === id;
}

export async function GET(_req: NextRequest, { params }: Params) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json(err('UNAUTHORIZED', 'Authentication required'), { status: 401 });
    }
    if (!isValidId(params.id)) {
      return NextResponse.json(err('INVALID_ID', 'Invalid ID format'), { status: 400 });
    }

    await connectMongoose();
    const item = await TodoItem.findOne({ _id: params.id, userId: session.user.id }).lean();

    if (!item) {
      return NextResponse.json(err('NOT_FOUND', 'Item not found'), { status: 404 });
    }
    return NextResponse.json(ok(item));
  } catch (error) {
    console.error('[GET /api/todo-item/[id]]', error);
    return NextResponse.json(err('INTERNAL_ERROR', 'Failed to fetch'), { status: 500 });
  }
}

export async function PATCH(req: NextRequest, { params }: Params) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json(err('UNAUTHORIZED', 'Authentication required'), { status: 401 });
    }
    if (!isValidId(params.id)) {
      return NextResponse.json(err('INVALID_ID', 'Invalid ID format'), { status: 400 });
    }

    await connectMongoose();
    const body = rejectMongoOperators(await req.json());
    const input = parseJson(UpdateTodoItemSchema, body);

    const item = await TodoItem.findOneAndUpdate(
      { _id: params.id, userId: session.user.id },
      { $set: input },
      { new: true }
    ).lean();

    if (!item) {
      return NextResponse.json(err('NOT_FOUND', 'Item not found'), { status: 404 });
    }
    return NextResponse.json(ok(item));
  } catch (error) {
    console.error('[PATCH /api/todo-item/[id]]', error);
    return NextResponse.json(err('INTERNAL_ERROR', 'Failed to update'), { status: 500 });
  }
}

export async function DELETE(_req: NextRequest, { params }: Params) {
  try {
    const session = await getServerSession(authOptions);
    if (!session?.user?.id) {
      return NextResponse.json(err('UNAUTHORIZED', 'Authentication required'), { status: 401 });
    }
    if (!isValidId(params.id)) {
      return NextResponse.json(err('INVALID_ID', 'Invalid ID format'), { status: 400 });
    }

    await connectMongoose();
    const result = await TodoItem.deleteOne({ _id: params.id, userId: session.user.id });

    if (result.deletedCount === 0) {
      return NextResponse.json(err('NOT_FOUND', 'Item not found'), { status: 404 });
    }
    return NextResponse.json(ok({ deleted: true }));
  } catch (error) {
    console.error('[DELETE /api/todo-item/[id]]', error);
    return NextResponse.json(err('INTERNAL_ERROR', 'Failed to delete'), { status: 500 });
  }
}
```

---

## UI Components

### List Component

```tsx
// apps/web/src/components/todo-item/TodoItemList.tsx
'use client';

import { useState } from 'react';
import useSWR from 'swr';
import { TodoItemCard } from './TodoItemCard';
import { TodoItemForm } from './TodoItemForm';
import type { TodoItem, CreateTodoItemInput } from '@repo/shared';

const fetcher = (url: string) => fetch(url).then(r => r.json());

export function TodoItemList() {
  const [showForm, setShowForm] = useState(false);
  const { data, mutate } = useSWR('/api/todo-item', fetcher);

  const handleCreate = async (input: CreateTodoItemInput) => {
    await fetch('/api/todo-item', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(input),
    });
    setShowForm(false);
    mutate();
  };

  const items: TodoItem[] = data?.data?.items ?? [];

  return (
    <div className="space-y-4">
      <div className="flex justify-between items-center">
        <h2 className="text-xl font-semibold">Items</h2>
        <button onClick={() => setShowForm(true)} className="btn-primary">
          Add Item
        </button>
      </div>

      {showForm && (
        <TodoItemForm onSubmit={handleCreate} onCancel={() => setShowForm(false)} />
      )}

      {items.length === 0 ? (
        <p className="text-secondary">No items yet.</p>
      ) : (
        items.map(item => (
          <TodoItemCard key={item.id} item={item} onDelete={() => mutate()} />
        ))
      )}
    </div>
  );
}
```

### Card Component

```tsx
// apps/web/src/components/todo-item/TodoItemCard.tsx
import type { TodoItem } from '@repo/shared';

interface Props {
  item: TodoItem;
  onDelete?: () => void;
}

export function TodoItemCard({ item, onDelete }: Props) {
  const handleDelete = async () => {
    await fetch(`/api/todo-item/${item.id}`, { method: 'DELETE' });
    onDelete?.();
  };

  return (
    <div className="p-4 border rounded-lg flex justify-between">
      <div>
        <h3 className="font-medium">{item.title}</h3>
        {item.description && <p className="text-sm text-secondary">{item.description}</p>}
      </div>
      <button onClick={handleDelete} className="text-red-600 text-sm" aria-label={`Delete ${item.title}`}>
        Delete
      </button>
    </div>
  );
}
```

### Form Component

```tsx
// apps/web/src/components/todo-item/TodoItemForm.tsx
'use client';

import { useState } from 'react';
import type { CreateTodoItemInput } from '@repo/shared';

interface Props {
  onSubmit: (data: CreateTodoItemInput) => Promise<void>;
  onCancel: () => void;
}

export function TodoItemForm({ onSubmit, onCancel }: Props) {
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [submitting, setSubmitting] = useState(false);

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setSubmitting(true);
    await onSubmit({ title, description: description || undefined });
    setSubmitting(false);
  };

  return (
    <form onSubmit={handleSubmit} className="space-y-4 p-4 border rounded-lg">
      <div>
        <label htmlFor="title" className="block text-sm font-medium">Title</label>
        <input
          id="title"
          value={title}
          onChange={e => setTitle(e.target.value)}
          required
          className="mt-1 w-full px-3 py-2 border rounded-md"
        />
      </div>
      <div>
        <label htmlFor="description" className="block text-sm font-medium">Description</label>
        <textarea
          id="description"
          value={description}
          onChange={e => setDescription(e.target.value)}
          className="mt-1 w-full px-3 py-2 border rounded-md"
          rows={3}
        />
      </div>
      <div className="flex justify-end gap-2">
        <button type="button" onClick={onCancel} className="px-4 py-2">Cancel</button>
        <button type="submit" disabled={submitting || !title} className="btn-primary">
          {submitting ? 'Saving...' : 'Save'}
        </button>
      </div>
    </form>
  );
}
```

---

## Test Template

```typescript
// packages/shared/schemas/__tests__/todo-item.test.ts
import { describe, it, expect } from 'vitest';
import { CreateTodoItemSchema, UpdateTodoItemSchema } from '../todo-item';

describe('CreateTodoItemSchema', () => {
  it('accepts valid input', () => {
    expect(() => CreateTodoItemSchema.parse({ title: 'Test' })).not.toThrow();
  });

  it('rejects empty title', () => {
    expect(() => CreateTodoItemSchema.parse({ title: '' })).toThrow();
  });

  it('applies defaults', () => {
    const result = CreateTodoItemSchema.parse({ title: 'Test' });
    expect(result.status).toBe('pending');
  });
});

describe('UpdateTodoItemSchema', () => {
  it('allows partial updates', () => {
    expect(() => UpdateTodoItemSchema.parse({ title: 'Updated' })).not.toThrow();
    expect(() => UpdateTodoItemSchema.parse({})).not.toThrow();
  });
});
```
