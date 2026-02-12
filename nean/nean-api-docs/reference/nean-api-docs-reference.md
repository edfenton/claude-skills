# NEAN API Docs Reference

@nestjs/swagger setup and OpenAPI documentation patterns.

---

## Dependencies

```bash
npm install @nestjs/swagger
```

No additional packages needed — `@nestjs/swagger` bundles Swagger UI and OpenAPI generation.

---

## Swagger Setup (main.ts)

```typescript
// apps/api/src/main.ts
import { NestFactory } from '@nestjs/core';
import { ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from './app.module';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  // Global prefix
  app.setGlobalPrefix('api');

  // Validation
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));

  // Swagger setup
  if (process.env.NODE_ENV !== 'production') {
    const config = new DocumentBuilder()
      .setTitle('My App API')
      .setDescription('API documentation for My App')
      .setVersion('1.0')
      .addBearerAuth(
        {
          type: 'http',
          scheme: 'bearer',
          bearerFormat: 'JWT',
          description: 'Enter JWT token',
        },
        'bearer',
      )
      .addTag('auth', 'Authentication endpoints')
      .addTag('users', 'User management')
      .build();

    const document = SwaggerModule.createDocument(app, config);

    SwaggerModule.setup('api/docs', app, document, {
      swaggerOptions: {
        persistAuthorization: true,
        tagsSorter: 'alpha',
        operationsSorter: 'alpha',
      },
      customSiteTitle: 'My App API Docs',
    });
  }

  await app.listen(3000);
}
bootstrap();
```

---

## Controller Decorator Examples

```typescript
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
import {
  ApiTags,
  ApiOperation,
  ApiResponse,
  ApiBearerAuth,
  ApiCreatedResponse,
  ApiParam,
  ApiQuery,
} from '@nestjs/swagger';

@Controller('users')
@ApiTags('users')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth('bearer')
export class UsersController {
  @Get()
  @ApiOperation({ summary: 'List all users' })
  @ApiQuery({ name: 'page', required: false, type: Number })
  @ApiQuery({ name: 'limit', required: false, type: Number })
  @ApiResponse({ status: 200, description: 'Paginated list of users' })
  findAll(@Query(new ValidationPipe({ transform: true })) query: PaginationDto) {
    return this.usersService.findAll(query);
  }

  @Get(':id')
  @ApiOperation({ summary: 'Get user by ID' })
  @ApiParam({ name: 'id', description: 'User UUID', type: String })
  @ApiResponse({ status: 200, description: 'User details', type: UserResponseDto })
  @ApiResponse({ status: 404, description: 'User not found' })
  findOne(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.findOne(id);
  }

  @Post()
  @HttpCode(HttpStatus.CREATED)
  @ApiOperation({ summary: 'Create a new user' })
  @ApiCreatedResponse({ description: 'User created', type: UserResponseDto })
  @ApiResponse({ status: 400, description: 'Validation error' })
  @ApiResponse({ status: 409, description: 'Email already exists' })
  create(@Body(new ValidationPipe({ whitelist: true })) dto: CreateUserDto) {
    return this.usersService.create(dto);
  }

  @Patch(':id')
  @ApiOperation({ summary: 'Update user' })
  @ApiResponse({ status: 200, description: 'User updated', type: UserResponseDto })
  @ApiResponse({ status: 404, description: 'User not found' })
  update(
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ValidationPipe({ whitelist: true })) dto: UpdateUserDto,
  ) {
    return this.usersService.update(id, dto);
  }

  @Delete(':id')
  @HttpCode(HttpStatus.NO_CONTENT)
  @ApiOperation({ summary: 'Delete user' })
  @ApiResponse({ status: 204, description: 'User deleted' })
  @ApiResponse({ status: 404, description: 'User not found' })
  remove(@Param('id', ParseUUIDPipe) id: string) {
    return this.usersService.remove(id);
  }
}
```

---

## DTO Decorator Examples

```typescript
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { IsEmail, IsString, MinLength, MaxLength, IsOptional, IsEnum } from 'class-validator';

export class CreateUserDto {
  @ApiProperty({
    description: 'User email address',
    example: 'jane@example.com',
  })
  @IsEmail()
  @MaxLength(255)
  email: string;

  @ApiProperty({
    description: 'User first name',
    example: 'Jane',
    minLength: 1,
    maxLength: 100,
  })
  @IsString()
  @MinLength(1)
  @MaxLength(100)
  firstName: string;

  @ApiPropertyOptional({
    description: 'User last name',
    example: 'Doe',
  })
  @IsOptional()
  @IsString()
  @MaxLength(100)
  lastName?: string;

  @ApiProperty({
    description: 'User password (8+ chars, upper+lower+digit)',
    example: 'SecurePass1',
    minLength: 8,
  })
  @IsString()
  @MinLength(8)
  @MaxLength(72)
  password: string;
}

export class UserResponseDto {
  @ApiProperty({ example: '550e8400-e29b-41d4-a716-446655440000' })
  id: string;

  @ApiProperty({ example: 'jane@example.com' })
  email: string;

  @ApiProperty({ example: 'Jane' })
  firstName: string;

  @ApiPropertyOptional({ example: 'Doe' })
  lastName?: string;

  @ApiProperty()
  createdAt: Date;
}
```

---

## Custom Decorators

### @ApiPaginatedResponse

```typescript
// libs/api/common/src/decorators/api-paginated-response.decorator.ts
import { applyDecorators, Type } from '@nestjs/common';
import { ApiOkResponse, getSchemaPath, ApiExtraModels } from '@nestjs/swagger';

export const ApiPaginatedResponse = <TModel extends Type<any>>(model: TModel) => {
  return applyDecorators(
    ApiExtraModels(model),
    ApiOkResponse({
      description: 'Paginated list',
      schema: {
        properties: {
          items: {
            type: 'array',
            items: { $ref: getSchemaPath(model) },
          },
          meta: {
            type: 'object',
            properties: {
              page: { type: 'number', example: 1 },
              limit: { type: 'number', example: 20 },
              total: { type: 'number', example: 100 },
              totalPages: { type: 'number', example: 5 },
            },
          },
        },
      },
    }),
  );
};

// Usage
@Get()
@ApiOperation({ summary: 'List users' })
@ApiPaginatedResponse(UserResponseDto)
findAll(@Query() query: PaginationDto) {
  return this.usersService.findAll(query);
}
```

### Common error response decorators

```typescript
// libs/api/common/src/decorators/api-error-responses.decorator.ts
import { applyDecorators } from '@nestjs/common';
import { ApiResponse } from '@nestjs/swagger';

export const ApiCommonErrors = () => {
  return applyDecorators(
    ApiResponse({ status: 400, description: 'Bad request / Validation error' }),
    ApiResponse({ status: 401, description: 'Unauthorized' }),
    ApiResponse({ status: 500, description: 'Internal server error' }),
  );
};

export const ApiNotFoundError = () => {
  return applyDecorators(
    ApiResponse({ status: 404, description: 'Resource not found' }),
  );
};

// Usage
@Get(':id')
@ApiCommonErrors()
@ApiNotFoundError()
findOne(@Param('id', ParseUUIDPipe) id: string) { }
```

---

## Export Script

```typescript
// scripts/export-openapi.ts
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import * as fs from 'fs';
import * as path from 'path';
import { AppModule } from '../apps/api/src/app.module';

async function exportSpec() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api');

  const config = new DocumentBuilder()
    .setTitle('My App API')
    .setDescription('API documentation')
    .setVersion('1.0')
    .addBearerAuth()
    .build();

  const document = SwaggerModule.createDocument(app, config);
  const outputPath = path.join(process.cwd(), 'openapi.json');

  fs.writeFileSync(outputPath, JSON.stringify(document, null, 2));
  console.log(`OpenAPI spec exported to ${outputPath}`);

  await app.close();
}

exportSpec();
```

```json
// package.json — add script
{
  "scripts": {
    "docs:export": "ts-node scripts/export-openapi.ts"
  }
}
```

---

## Swagger UI Customization

```typescript
SwaggerModule.setup('api/docs', app, document, {
  swaggerOptions: {
    persistAuthorization: true,        // Remember auth token across reloads
    tagsSorter: 'alpha',               // Sort tags alphabetically
    operationsSorter: 'alpha',         // Sort operations alphabetically
    docExpansion: 'list',              // Collapse operations by default
    filter: true,                      // Enable search filter
    showRequestDuration: true,         // Show request time
  },
  customSiteTitle: 'My App API Docs',
  customCss: `
    .swagger-ui .topbar { display: none; }
    .swagger-ui .info { margin: 20px 0; }
  `,
});
```

---

## Protecting Docs in Production

### Environment-based conditional setup

```typescript
// Only enable Swagger in non-production
if (process.env.NODE_ENV !== 'production') {
  const config = new DocumentBuilder()
    .setTitle('My App API')
    .setVersion('1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, config);
  SwaggerModule.setup('api/docs', app, document);
}
```

### Guard-protected docs

```typescript
// Protect docs endpoint with a guard
import { Controller, Get, UseGuards } from '@nestjs/common';
import { JwtAuthGuard } from './guards/jwt-auth.guard';
import { RolesGuard } from './guards/roles.guard';
import { Roles } from './decorators/roles.decorator';

// Only admin users can access docs
SwaggerModule.setup('api/docs', app, document, {
  swaggerOptions: {
    withCredentials: true,
  },
});

// Add middleware to protect the route
app.use('/api/docs', (req, res, next) => {
  // Check for admin session or API key
  const apiKey = req.headers['x-api-key'];
  if (process.env.NODE_ENV === 'production' && apiKey !== process.env.DOCS_API_KEY) {
    return res.status(401).json({ message: 'Unauthorized' });
  }
  next();
});
```

---

## Common Error Response Schema

```typescript
// libs/api/common/src/dto/error-response.dto.ts
import { ApiProperty } from '@nestjs/swagger';

export class ErrorResponseDto {
  @ApiProperty({ example: false })
  success: boolean;

  @ApiProperty({
    type: 'object',
    properties: {
      code: { type: 'string', example: 'VALIDATION_ERROR' },
      message: { type: 'string', example: 'Invalid input' },
      timestamp: { type: 'string', example: '2024-01-15T10:30:00.000Z' },
      path: { type: 'string', example: '/api/users' },
    },
  })
  error: {
    code: string;
    message: string;
    timestamp: string;
    path: string;
  };
}
```

---

## Audit Automation

### Script to check for missing decorators

```typescript
// scripts/audit-api-docs.ts
import { NestFactory } from '@nestjs/core';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import { AppModule } from '../apps/api/src/app.module';

async function auditDocs() {
  const app = await NestFactory.create(AppModule, { logger: false });
  app.setGlobalPrefix('api');

  const config = new DocumentBuilder().setTitle('Audit').setVersion('1.0').build();
  const document = SwaggerModule.createDocument(app, config);

  const issues: string[] = [];

  for (const [path, methods] of Object.entries(document.paths)) {
    for (const [method, operation] of Object.entries(methods as Record<string, any>)) {
      const op = operation as any;

      // Check for missing summary
      if (!op.summary) {
        issues.push(`[${method.toUpperCase()} ${path}] Missing @ApiOperation summary`);
      }

      // Check for missing tags
      if (!op.tags || op.tags.length === 0) {
        issues.push(`[${method.toUpperCase()} ${path}] Missing @ApiTags`);
      }

      // Check for missing response docs
      if (!op.responses || Object.keys(op.responses).length === 0) {
        issues.push(`[${method.toUpperCase()} ${path}] Missing @ApiResponse decorators`);
      }
    }
  }

  // Check schemas for missing descriptions
  if (document.components?.schemas) {
    for (const [name, schema] of Object.entries(document.components.schemas)) {
      const s = schema as any;
      if (s.properties) {
        for (const [prop, propSchema] of Object.entries(s.properties)) {
          const ps = propSchema as any;
          if (!ps.description && !ps.example) {
            issues.push(`[Schema: ${name}.${prop}] Missing @ApiProperty description or example`);
          }
        }
      }
    }
  }

  if (issues.length === 0) {
    console.log('All endpoints and schemas are documented!');
  } else {
    console.log(`Found ${issues.length} documentation issues:\n`);
    issues.forEach((issue) => console.log(`  - ${issue}`));
  }

  await app.close();
}

auditDocs();
```

```json
// package.json — add script
{
  "scripts": {
    "docs:audit": "ts-node scripts/audit-api-docs.ts"
  }
}
```

---

## Quick Reference

| Task               | Command                            |
| ------------------ | ---------------------------------- |
| View docs          | Open `http://localhost:3000/api/docs` |
| Export spec         | `npm run docs:export`              |
| Audit decorators   | `npm run docs:audit`               |
| Install swagger    | `npm install @nestjs/swagger`      |
