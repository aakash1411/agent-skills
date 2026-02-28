---
name: ts-service-scaffolder
description: Scaffolds and standardizes TypeScript backend services with routing, middleware, error handling, validation, and async patterns. Use this skill whenever a new TypeScript/Node.js API is being created, an Express/Fastify service needs restructuring, or a Lambda handler needs a clean TypeScript pattern. Activate when someone says "scaffold TS service", "create TypeScript API", "structure Node backend", "Express project", "Fastify", "TypeScript Lambda", or is starting any new TypeScript backend from scratch. Don't let a new TS service start without a consistent structure: inconsistent patterns across services are the primary driver of maintenance overhead.
---

# TypeScript Service Scaffolder

Standardized patterns for TypeScript backend services and AWS Lambda handlers.

## Project structure (Express/Fastify)

```
service-name/
├── src/
│   ├── index.ts                # Entry point: create app, listen
│   ├── app.ts                  # App factory: configure middleware, routes
│   ├── config/
│   │   └── index.ts            # Environment config with validation
│   ├── routes/
│   │   ├── index.ts            # Route registration
│   │   ├── health.routes.ts    # Health check endpoints
│   │   └── <domain>.routes.ts  # Domain-specific routes
│   ├── middleware/
│   │   ├── error-handler.ts    # Centralized error handling
│   │   ├── request-logger.ts   # Structured request logging
│   │   ├── auth.ts             # Authentication middleware
│   │   └── validation.ts       # Request validation middleware
│   ├── services/
│   │   └── <domain>.service.ts # Business logic
│   ├── repositories/
│   │   └── <domain>.repo.ts    # Data access (DynamoDB, RDS, etc.)
│   ├── types/
│   │   ├── errors.ts           # Typed error classes
│   │   ├── requests.ts         # Request/response types
│   │   └── domain.ts           # Domain models
│   └── utils/
│       ├── logger.ts           # Structured logger (pino/winston)
│       └── aws-clients.ts      # Shared AWS SDK client instances
├── tests/
│   ├── unit/
│   ├── integration/
│   └── fixtures/
├── tsconfig.json
├── package.json
├── .eslintrc.js
├── .prettierrc
└── Dockerfile
```

## Lambda handler structure

```
lambda-name/
├── src/
│   ├── handler.ts              # Lambda entry point
│   ├── processor.ts            # Core logic (testable without Lambda context)
│   ├── types.ts                # Event/response types
│   └── clients.ts              # AWS SDK clients (initialized outside handler)
├── tests/
│   └── handler.test.ts
├── tsconfig.json
└── package.json
```

### Lambda handler pattern

```typescript
// clients.ts: initialized once per cold start
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
export const dynamoClient = new DynamoDBClient({});

// handler.ts
import { APIGatewayProxyHandler } from "aws-lambda";
import { process } from "./processor";
import { dynamoClient } from "./clients";

export const handler: APIGatewayProxyHandler = async (event) => {
  try {
    const result = await process(event, { dynamoClient });
    return { statusCode: 200, body: JSON.stringify(result) };
  } catch (error) {
    // Centralized error mapping
    return mapErrorToResponse(error);
  }
};
```

## Config validation pattern

```typescript
import { z } from "zod";

const configSchema = z.object({
  PORT: z.coerce.number().default(3000),
  NODE_ENV: z.enum(["development", "staging", "production"]).default("development"),
  AWS_REGION: z.string().default("us-east-1"),
  TABLE_NAME: z.string(),
  LOG_LEVEL: z.enum(["debug", "info", "warn", "error"]).default("info"),
});

export const config = configSchema.parse(process.env);
export type Config = z.infer<typeof configSchema>;
```

## Error handling middleware

```typescript
// Centralized error handler (Express example)
export const errorHandler: ErrorRequestHandler = (err, req, res, _next) => {
  const statusCode = err instanceof ServiceError ? err.statusCode : 500;
  const code = err instanceof ServiceError ? err.code : "INTERNAL_ERROR";

  logger.error({ err, requestId: req.id, path: req.path }, "Request failed");

  res.status(statusCode).json({
    error: { code, message: err.message, requestId: req.id },
  });
};
```

## Request validation pattern

```typescript
import { z } from "zod";

const createUserSchema = z.object({
  body: z.object({
    name: z.string().min(1).max(255),
    email: z.string().email(),
    role: z.enum(["admin", "user", "viewer"]),
  }),
  params: z.object({}),
  query: z.object({}),
});

// Validation middleware factory
export function validate<T extends z.ZodSchema>(schema: T) {
  return (req: Request, res: Response, next: NextFunction) => {
    const result = schema.safeParse({ body: req.body, params: req.params, query: req.query });
    if (!result.success) {
      throw new ValidationError("Invalid request", result.error.flatten());
    }
    next();
  };
}
```

## Dependency injection pattern

```typescript
// Simple constructor injection: no framework needed
export class UserService {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly emailService: EmailService,
    private readonly logger: Logger,
  ) {}

  async createUser(data: CreateUserInput): Promise<User> { /* ... */ }
}

// Wire in app factory
const userRepo = new DynamoUserRepository(dynamoClient, config.TABLE_NAME);
const emailService = new SESEmailService(sesClient);
const userService = new UserService(userRepo, emailService, logger);
```

## Async patterns

- Always use `async/await`: never raw `.then()/.catch()` chains.
- Use `Promise.allSettled` for parallel operations that can partially fail.
- Set explicit timeouts on all external calls (`AbortController` or library config).
- Handle unhandled rejections: `process.on('unhandledRejection', handler)`.

## Rules

- Enable `"strict": true` in tsconfig: strict mode catches entire classes of bugs (null access, implicit any, unchecked narrowing) that are expensive to find at runtime.
- Use `unknown` instead of `any` and narrow with type guards: `any` opts out of the type system and defeats the purpose of TypeScript.
- Validate all external input (API requests, event payloads, env vars): TypeScript's type system only applies inside the process; external data can be anything.
- Initialize AWS SDK clients outside request/handler scope: re-initializing per request wastes cold-start budget and prevents connection reuse.
- Use structured logging (JSON) with correlation IDs: free-text logs are unsearchable in CloudWatch.
- Keep route handlers thin and delegate to services: fat handlers are impossible to unit test without spinning up HTTP infrastructure.

## Edge cases

- **Monorepo packages:** use `tsconfig` path aliases and project references.
- **Lambda layers:** share common code via layers; keep handler package minimal.
- **Cold start optimization:** lazy-import heavy modules; minimize top-level initialization.
- **Graceful shutdown:** handle `SIGTERM`/`SIGINT`; drain connections before exit (ECS/Fargate).
- **Large request payloads:** use streaming (`req.pipe()`) instead of buffering.
- **WebSocket support:** separate WS routes from HTTP routes; use API Gateway WebSocket for serverless.
- **Multi-tenant:** isolate tenant context via middleware; never leak data across tenants.
