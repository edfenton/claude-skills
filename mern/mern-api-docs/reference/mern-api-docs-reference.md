# MERN API Docs Reference

OpenAPI generation from Zod schemas and Swagger UI setup.

---

## Dependencies

```bash
pnpm add zod-openapi @asteasolutions/zod-to-openapi swagger-ui-react --filter=web
pnpm add -D @types/swagger-ui-react --filter=web
```

---

## OpenAPI Generator

```typescript
// apps/web/src/lib/openapi.ts
import {
  OpenAPIRegistry,
  OpenApiGeneratorV3,
  extendZodWithOpenApi,
} from '@asteasolutions/zod-to-openapi';
import { z } from 'zod';
import * as schemas from '@repo/shared';

// Extend Zod with OpenAPI methods
extendZodWithOpenApi(z);

const registry = new OpenAPIRegistry();

// Register schemas
registry.register('TodoItem', schemas.TodoItemSchema);
registry.register('CreateTodoItem', schemas.CreateTodoItemSchema);
registry.register('UpdateTodoItem', schemas.UpdateTodoItemSchema);
// Add more schemas as needed

// Define API endpoints
registry.registerPath({
  method: 'get',
  path: '/api/todo-item',
  summary: 'List todo items',
  tags: ['Todo Items'],
  request: {
    query: schemas.TodoItemQuerySchema,
  },
  responses: {
    200: {
      description: 'List of todo items',
      content: {
        'application/json': {
          schema: z.object({
            ok: z.literal(true),
            data: z.object({
              items: z.array(schemas.TodoItemSchema),
              cursor: z.string().optional(),
              hasMore: z.boolean(),
            }),
          }),
        },
      },
    },
    401: {
      description: 'Unauthorized',
    },
  },
  security: [{ bearerAuth: [] }],
});

registry.registerPath({
  method: 'post',
  path: '/api/todo-item',
  summary: 'Create todo item',
  tags: ['Todo Items'],
  request: {
    body: {
      content: {
        'application/json': {
          schema: schemas.CreateTodoItemSchema,
        },
      },
    },
  },
  responses: {
    201: {
      description: 'Created todo item',
      content: {
        'application/json': {
          schema: z.object({
            ok: z.literal(true),
            data: schemas.TodoItemSchema,
          }),
        },
      },
    },
    400: {
      description: 'Validation error',
    },
    401: {
      description: 'Unauthorized',
    },
  },
  security: [{ bearerAuth: [] }],
});

registry.registerPath({
  method: 'get',
  path: '/api/todo-item/{id}',
  summary: 'Get todo item by ID',
  tags: ['Todo Items'],
  request: {
    params: z.object({
      id: z.string().openapi({ description: 'Todo item ID' }),
    }),
  },
  responses: {
    200: {
      description: 'Todo item',
      content: {
        'application/json': {
          schema: z.object({
            ok: z.literal(true),
            data: schemas.TodoItemSchema,
          }),
        },
      },
    },
    404: {
      description: 'Not found',
    },
  },
  security: [{ bearerAuth: [] }],
});

registry.registerPath({
  method: 'patch',
  path: '/api/todo-item/{id}',
  summary: 'Update todo item',
  tags: ['Todo Items'],
  request: {
    params: z.object({
      id: z.string(),
    }),
    body: {
      content: {
        'application/json': {
          schema: schemas.UpdateTodoItemSchema,
        },
      },
    },
  },
  responses: {
    200: {
      description: 'Updated todo item',
      content: {
        'application/json': {
          schema: z.object({
            ok: z.literal(true),
            data: schemas.TodoItemSchema,
          }),
        },
      },
    },
    404: {
      description: 'Not found',
    },
  },
  security: [{ bearerAuth: [] }],
});

registry.registerPath({
  method: 'delete',
  path: '/api/todo-item/{id}',
  summary: 'Delete todo item',
  tags: ['Todo Items'],
  request: {
    params: z.object({
      id: z.string(),
    }),
  },
  responses: {
    200: {
      description: 'Deleted',
      content: {
        'application/json': {
          schema: z.object({
            ok: z.literal(true),
            data: z.object({ deleted: z.literal(true) }),
          }),
        },
      },
    },
    404: {
      description: 'Not found',
    },
  },
  security: [{ bearerAuth: [] }],
});

// Generate OpenAPI document
const generator = new OpenApiGeneratorV3(registry.definitions);

export const openApiDocument = generator.generateDocument({
  openapi: '3.0.0',
  info: {
    title: 'My App API',
    version: '1.0.0',
    description: 'API documentation for My App',
  },
  servers: [
    {
      url: process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000',
      description: 'Current environment',
    },
  ],
  security: [{ bearerAuth: [] }],
  components: {
    securitySchemes: {
      bearerAuth: {
        type: 'http',
        scheme: 'bearer',
        bearerFormat: 'JWT',
      },
    },
  },
});
```

---

## Swagger UI API Route

```typescript
// apps/web/src/app/api/docs/route.ts
import { NextResponse } from 'next/server';
import { openApiDocument } from '@/lib/openapi';

export async function GET() {
  return NextResponse.json(openApiDocument);
}
```

---

## Swagger UI Page

```tsx
// apps/web/src/app/docs/page.tsx
'use client';

import dynamic from 'next/dynamic';
import 'swagger-ui-react/swagger-ui.css';

const SwaggerUI = dynamic(() => import('swagger-ui-react'), { ssr: false });

export default function DocsPage() {
  return (
    <div className="min-h-screen">
      <SwaggerUI url="/api/docs" />
    </div>
  );
}
```

---

## Export Script

```typescript
// scripts/export-openapi.ts
import fs from 'fs';
import path from 'path';
import { openApiDocument } from '../apps/web/src/lib/openapi';

const outputPath = path.join(process.cwd(), 'openapi.json');
fs.writeFileSync(outputPath, JSON.stringify(openApiDocument, null, 2));
console.log(`OpenAPI spec exported to ${outputPath}`);
```

```json
// package.json - add script
{
  "scripts": {
    "docs:export": "tsx scripts/export-openapi.ts"
  }
}
```

---

## Zod OpenAPI Extensions

```typescript
// Enhance schemas with OpenAPI metadata
import { z } from 'zod';
import { extendZodWithOpenApi } from '@asteasolutions/zod-to-openapi';

extendZodWithOpenApi(z);

export const CreateTodoItemSchema = z.object({
  title: z.string()
    .min(1)
    .max(200)
    .openapi({
      description: 'Title of the todo item',
      example: 'Buy groceries',
    }),
  description: z.string()
    .max(2000)
    .optional()
    .openapi({
      description: 'Optional detailed description',
      example: 'Milk, eggs, bread',
    }),
  priority: z.enum(['low', 'medium', 'high'])
    .default('medium')
    .openapi({
      description: 'Priority level',
      example: 'medium',
    }),
}).openapi('CreateTodoItem');
```

---

## Auto-Discovery Pattern

```typescript
// apps/web/src/lib/openapi-auto.ts
import fs from 'fs';
import path from 'path';
import { OpenAPIRegistry } from '@asteasolutions/zod-to-openapi';

// Auto-discover API routes
function discoverRoutes(dir: string, basePath = '/api'): string[] {
  const routes: string[] = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);

    if (entry.isDirectory()) {
      if (entry.name.startsWith('[') && entry.name.endsWith(']')) {
        // Dynamic route: [id] -> {id}
        const param = entry.name.slice(1, -1);
        routes.push(...discoverRoutes(fullPath, `${basePath}/{${param}}`));
      } else {
        routes.push(...discoverRoutes(fullPath, `${basePath}/${entry.name}`));
      }
    } else if (entry.name === 'route.ts' || entry.name === 'route.js') {
      routes.push(basePath);
    }
  }

  return routes;
}

// Usage
const apiDir = path.join(process.cwd(), 'apps/web/src/app/api');
const routes = discoverRoutes(apiDir);
console.log('Discovered routes:', routes);
```

---

## Error Response Schema

```typescript
// Standard error response for all endpoints
const ErrorResponseSchema = z.object({
  ok: z.literal(false),
  error: z.object({
    code: z.string().openapi({ example: 'VALIDATION_ERROR' }),
    message: z.string().openapi({ example: 'Invalid input' }),
  }),
}).openapi('ErrorResponse');

// Register common error responses
const commonErrorResponses = {
  400: {
    description: 'Bad request / Validation error',
    content: {
      'application/json': { schema: ErrorResponseSchema },
    },
  },
  401: {
    description: 'Unauthorized',
    content: {
      'application/json': { schema: ErrorResponseSchema },
    },
  },
  404: {
    description: 'Resource not found',
    content: {
      'application/json': { schema: ErrorResponseSchema },
    },
  },
  500: {
    description: 'Internal server error',
    content: {
      'application/json': { schema: ErrorResponseSchema },
    },
  },
};
```

---

## Protecting Docs in Production

```typescript
// apps/web/src/app/docs/page.tsx
import { redirect } from 'next/navigation';

export default function DocsPage() {
  // Only show in development
  if (process.env.NODE_ENV === 'production') {
    redirect('/');
  }

  return (
    <div className="min-h-screen">
      <SwaggerUI url="/api/docs" />
    </div>
  );
}
```

Or use authentication:

```typescript
import { getServerSession } from 'next-auth';
import { authOptions } from '@/lib/auth';

export default async function DocsPage() {
  const session = await getServerSession(authOptions);

  // Only show to authenticated users or admins
  if (!session || !session.user.isAdmin) {
    redirect('/');
  }

  return <SwaggerUI url="/api/docs" />;
}
```
