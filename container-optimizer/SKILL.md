---
name: container-optimizer
description: Builds, optimizes, and secures Docker container images for Python, Java, and TypeScript services on AWS (ECR, ECS, Fargate, Lambda container images). Use this skill whenever a Dockerfile is being created or modified, an image is too large, builds are too slow, a security scan flags vulnerabilities, or a service is being containerized for the first time. Activate when someone says "Dockerfile", "optimize Docker", "reduce image size", "container security", "multi-stage build", "ECR push", or "containerize this". Don't let a Dockerfile be written without multi-stage builds and a non-root user: these are the two most common container mistakes in production.
---

# Container Optimizer

Optimized, secure Docker images for enterprise services on AWS.

## Multi-stage build templates

### Python service

```dockerfile
# Stage 1: Build dependencies
FROM python:3.12-slim AS builder
WORKDIR /app

# Install build tools only in builder stage
RUN apt-get update && apt-get install -y --no-install-recommends gcc && \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim AS runtime
WORKDIR /app

# Copy only installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code
COPY src/ ./src/

# Non-root user
RUN useradd --create-home --shell /bin/bash appuser
USER appuser

EXPOSE 8000
CMD ["python", "-m", "uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8000"]
```

### TypeScript service

```dockerfile
# Stage 1: Install dependencies
FROM node:20-slim AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev

# Stage 2: Build
FROM node:20-slim AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY tsconfig.json ./
COPY src/ ./src/
RUN npm run build

# Stage 3: Runtime
FROM node:20-slim AS runtime
WORKDIR /app
ENV NODE_ENV=production

COPY --from=deps /app/node_modules ./node_modules
COPY --from=builder /app/dist ./dist
COPY package.json ./

RUN groupadd -r appuser && useradd -r -g appuser appuser
USER appuser

EXPOSE 3000
CMD ["node", "dist/index.js"]
```

### Java service

```dockerfile
# Stage 1: Build
FROM maven:3.9-amazoncorretto-17 AS builder
WORKDIR /app
COPY pom.xml .
RUN mvn dependency:go-offline -B
COPY src/ ./src/
RUN mvn package -DskipTests -B

# Stage 2: Runtime
FROM amazoncorretto:17-alpine AS runtime
WORKDIR /app

COPY --from=builder /app/target/*.jar app.jar

RUN addgroup -S appuser && adduser -S appuser -G appuser
USER appuser

EXPOSE 8080
ENTRYPOINT ["java", "-jar", "app.jar"]
```

## Image size optimization techniques

### Base image selection (smallest to largest)

| Language | Smallest | Recommended | Full |
|----------|----------|-------------|------|
| Python | `python:3.12-alpine` (50MB) | `python:3.12-slim` (130MB) | `python:3.12` (900MB) |
| Node.js | `node:20-alpine` (55MB) | `node:20-slim` (200MB) | `node:20` (1GB) |
| Java | `amazoncorretto:17-alpine` (200MB) | `eclipse-temurin:17-jre-alpine` (180MB) | `amazoncorretto:17` (400MB) |

**Guidelines:**
- Prefer `-slim` over `-alpine` for Python (avoids musl/glibc compatibility issues with native extensions).
- Use `-alpine` for Node.js and Java when no native dependencies are needed.
- Never use full images in production: they contain build tools, docs, unnecessary packages.

### Layer caching best practices

```dockerfile
# GOOD: Copy dependency file first, install, then copy source
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY src/ ./src/

# BAD: Copy everything first (busts cache on any source change)
COPY . .
RUN pip install -r requirements.txt
```

### Reduce layer count

```dockerfile
# GOOD: Single RUN with cleanup
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl && \
    rm -rf /var/lib/apt/lists/*

# BAD: Multiple RUNs (each creates a layer)
RUN apt-get update
RUN apt-get install -y curl
```

### .dockerignore (always include)

```
.git
.gitignore
node_modules
__pycache__
*.pyc
.pytest_cache
.mypy_cache
.env
.env.*
dist
build
target
*.md
docs/
tests/
.github/
.vscode/
```

## Security hardening

1. **Non-root user:** always `USER appuser`: never run as root.
2. **Read-only filesystem:** use `--read-only` flag in ECS task definition.
3. **No shell in production:** use distroless images or remove shell after build.
4. **Pin base image digests** for reproducibility: `FROM python:3.12-slim@sha256:<digest>`.
5. **Scan images:** `trivy image <image>`, `docker scout cve <image>`.
6. **No secrets in image:** use build args sparingly; prefer runtime injection (env vars, Secrets Manager).
7. **Minimal packages:** `--no-install-recommends`; remove package manager cache.

## AWS ECR patterns

### Push to ECR

```bash
# Authenticate
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT.dkr.ecr.$REGION.amazonaws.com

# Tag and push
docker tag myimage:latest $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG
docker push $ACCOUNT.dkr.ecr.$REGION.amazonaws.com/$REPO:$TAG
```

### ECR lifecycle policy (auto-cleanup)

```json
{
  "rules": [
    {
      "rulePriority": 1,
      "description": "Keep last 10 tagged images",
      "selection": {
        "tagStatus": "tagged",
        "tagPrefixList": ["v"],
        "countType": "imageCountMoreThan",
        "countNumber": 10
      },
      "action": { "type": "expire" }
    },
    {
      "rulePriority": 2,
      "description": "Expire untagged after 7 days",
      "selection": {
        "tagStatus": "untagged",
        "countType": "sinceImagePushed",
        "countUnit": "days",
        "countNumber": 7
      },
      "action": { "type": "expire" }
    }
  ]
}
```

### Lambda container image

```dockerfile
FROM public.ecr.aws/lambda/python:3.12
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY src/ ${LAMBDA_TASK_ROOT}/
CMD ["handler.lambda_handler"]
```

## BuildKit optimizations

```dockerfile
# syntax=docker/dockerfile:1

# Cache pip downloads across builds
RUN --mount=type=cache,target=/root/.cache/pip \
    pip install -r requirements.txt

# Cache Maven repository
RUN --mount=type=cache,target=/root/.m2 \
    mvn package -DskipTests

# Cache npm
RUN --mount=type=cache,target=/root/.npm \
    npm ci
```

Enable: `DOCKER_BUILDKIT=1 docker build .`

## Health check

```dockerfile
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
  CMD curl -f http://localhost:8000/health || exit 1
```

## Rules

- Use multi-stage builds: shipping build tools (gcc, maven, npm devDependencies) in production images bloats size by 5-10x and expands the attack surface.
- Always add `.dockerignore`: without it, `COPY . .` sends `.git`, `node_modules`, `.env` files, and secrets into the build context.
- Always run as a non-root user: a container breach as root means the attacker has root on the host if container isolation fails.
- Never store secrets in image layers: every `RUN`, `COPY`, and `ENV` in a Dockerfile creates a layer that persists in the image history even if deleted in a later layer.
- Pin base image versions and update on a schedule (monthly or on CVE notification): unpinned images silently pick up upstream changes that can break builds or introduce vulnerabilities.
- Test locally before pushing to ECR: ECR push is slow; catching issues locally first saves significant iteration time.

## Edge cases

- **Native Python extensions (numpy, pandas):** use `-slim` not `-alpine`; or pre-built wheels.
- **Private package registry:** use `--mount=type=secret` for auth tokens during build.
- **ARM64 (Graviton):** use `--platform linux/arm64` or multi-platform builds with `docker buildx`.
- **Large ML models in image:** consider mounting from S3/EFS at runtime instead of baking into image.
- **Java GraalVM native image:** separate native-image build stage; produces tiny static binary.
- **Monorepo Docker builds:** use targeted COPY with specific paths; or use Turborepo/Nx docker pruning.
- **Layer size limits:** ECR layers max 10GB; if exceeded, split into base + app image.
