---
name: ci-pipeline-generator
description: Generates and maintains CI/CD pipeline configurations for GitHub Actions, Bitbucket Pipelines, and GitLab CI. Use this skill whenever a new pipeline is needed, existing stages need extension, AWS deployment needs to be wired in, or secrets/caching need to be configured. Activate when someone says "create pipeline", "CI/CD for", "GitHub Actions", "Bitbucket pipeline", "GitLab CI", "deploy to AWS", "add CI", or when a new repo is being bootstrapped. Don't let a new service ship without a pipeline: manual deployments are the fastest path to production incidents.
---

# CI Pipeline Generator

Generate production-grade CI/CD configurations for GitHub Actions, Bitbucket Pipelines, and GitLab CI.

## Pipeline architecture (common across providers)

```
Trigger -> Lint/Format -> Test -> Build -> Security Scan -> Deploy (staging) -> Smoke Test -> Deploy (prod)
```

### Stage responsibilities

| Stage | Purpose | Blocking? |
|-------|---------|-----------|
| Lint/Format | Code style enforcement | Yes |
| Test | Unit + integration tests | Yes |
| Build | Compile, package, Docker build | Yes |
| Security scan | SAST, dependency audit | Yes (configurable) |
| Deploy staging | Deploy to staging env | Yes |
| Smoke test | Verify staging deployment | Yes |
| Deploy prod | Deploy to production | Yes (manual gate) |

## GitHub Actions templates

### Python service

```yaml
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        python-version: ["3.11", "3.12"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: ${{ matrix.python-version }}
          cache: pip
      - run: pip install -r requirements.txt -r requirements-dev.txt
      - run: ruff check .
      - run: ruff format --check .
      - run: mypy src/
      - run: pytest tests/ --cov=src --cov-report=xml -v
      - uses: actions/upload-artifact@v4
        with:
          name: coverage-${{ matrix.python-version }}
          path: coverage.xml

  build-and-push:
    needs: lint-and-test
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: actions/checkout@v4
      - uses: aws-actions/configure-aws-credentials@v4
        with:
          role-to-arn: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: ${{ vars.AWS_REGION }}
      - uses: aws-actions/amazon-ecr-login@v2
        id: ecr
      - run: |
          docker build -t ${{ steps.ecr.outputs.registry }}/${{ vars.ECR_REPO }}:${{ github.sha }} .
          docker push ${{ steps.ecr.outputs.registry }}/${{ vars.ECR_REPO }}:${{ github.sha }}
```

### TypeScript service

```yaml
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint-and-test:
    runs-on: ubuntu-latest
    strategy:
      matrix:
        node-version: ["18", "20"]
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node-version }}
          cache: npm
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test -- --coverage
```

### Java service

```yaml
name: CI
on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  build-and-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-java@v4
        with:
          distribution: corretto
          java-version: "17"
          cache: maven
      - run: mvn verify -B
```

## Bitbucket Pipelines templates

### Python service

```yaml
image: python:3.12

definitions:
  caches:
    pip: ~/.cache/pip
  steps:
    - step: &lint-test
        name: Lint and Test
        caches: [pip]
        script:
          - pip install -r requirements.txt -r requirements-dev.txt
          - ruff check .
          - pytest tests/ --cov=src -v

pipelines:
  pull-requests:
    '**':
      - step: *lint-test

  branches:
    main:
      - step: *lint-test
      - step:
          name: Deploy to staging
          deployment: staging
          script:
            - pipe: atlassian/aws-ecs-deploy:1.0.0
              variables:
                AWS_ACCESS_KEY_ID: $AWS_ACCESS_KEY_ID
                AWS_SECRET_ACCESS_KEY: $AWS_SECRET_ACCESS_KEY
                AWS_DEFAULT_REGION: $AWS_REGION
                CLUSTER_NAME: $ECS_CLUSTER
                SERVICE_NAME: $ECS_SERVICE
```

## GitLab CI templates

### Python service

```yaml
stages:
  - lint
  - test
  - build
  - deploy

variables:
  PIP_CACHE_DIR: "$CI_PROJECT_DIR/.cache/pip"

cache:
  paths:
    - .cache/pip/

lint:
  stage: lint
  image: python:3.12
  script:
    - pip install ruff mypy
    - ruff check .
    - ruff format --check .

test:
  stage: test
  image: python:3.12
  script:
    - pip install -r requirements.txt -r requirements-dev.txt
    - pytest tests/ --cov=src --junitxml=report.xml
  artifacts:
    reports:
      junit: report.xml

deploy_staging:
  stage: deploy
  environment:
    name: staging
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
  script:
    - # AWS deployment commands
```

## AWS deployment integration patterns

### CDK deployment stage

```yaml
# GitHub Actions
- name: CDK Deploy
  run: |
    npm ci
    npx cdk diff --require-approval never
    npx cdk deploy --require-approval never --all
  env:
    AWS_REGION: ${{ vars.AWS_REGION }}
```

### Terraform deployment stage

```yaml
- name: Terraform Plan
  run: |
    terraform init -backend-config=envs/$ENV/backend.hcl
    terraform plan -var-file=envs/$ENV/terraform.tfvars -out=plan.out
- name: Terraform Apply
  if: github.ref == 'refs/heads/main'
  run: terraform apply plan.out
```

### Lambda deployment (SAM)

```yaml
- name: SAM Deploy
  run: |
    sam build
    sam deploy --stack-name $STACK_NAME --no-confirm-changeset --no-fail-on-empty-changeset
```

## Caching strategies

| Language | Cache key | Cache path |
|----------|-----------|------------|
| Python | `requirements*.txt` hash | `~/.cache/pip` |
| TypeScript | `package-lock.json` hash | `~/.npm` or `node_modules` |
| Java | `pom.xml` hash | `~/.m2/repository` |
| Docker | layer cache | BuildKit inline cache or ECR cache |

## Security scanning integration

- **Dependency audit:** `pip-audit` (Python), `npm audit` (TypeScript), `mvn dependency-check:check` (Java).
- **SAST:** `bandit` (Python), `semgrep`, `trivy` for container images.
- **Secret scanning:** `gitleaks`, `trufflehog`.
- Add as non-blocking warning stage initially; promote to blocking after baseline is clean.

## Rules

- Use `concurrency` (GitHub Actions) or equivalent deduplication to avoid wasted builds: without it, rapid pushes queue up redundant runs that consume minutes and credits.
- Pin action/image versions to a major version tag (e.g., `actions/checkout@v4`): unpinned versions can break overnight when upstream releases change behavior.
- Use OIDC for AWS authentication (`id-token: write`): long-lived AWS keys in CI secrets are a credential leak waiting to happen and rotate awkwardly.
- Use repository variables for secrets in Bitbucket/GitLab: hardcoded secrets in pipeline definitions get committed to history and are a common source of leaks.
- Separate CI (test on PR) from CD (deploy on main merge): conflating them means every test run risks a deploy and every deploy waits for tests.
- Require a manual approval gate for production deploys: automated deploys to production should be opt-in, not the default.
- Run tests before every deploy: deploying untested code is the leading cause of avoidable production incidents.

## Edge cases

- **Monorepo with multiple services:** use path filters to trigger only affected pipelines.
- **Large Docker builds:** use BuildKit cache mounts and multi-stage builds to speed up.
- **Flaky tests in CI:** add retry at test runner level, not pipeline level; track and fix.
- **Cross-account AWS deployment:** use assume-role chains; define role per environment.
- **Long-running integration tests:** run in parallel job; don't block fast lint/unit feedback.
- **Secrets rotation:** use short-lived OIDC tokens; rotate repository secrets on schedule.
- **Branch protection:** ensure required status checks match job names exactly.
- **Forked PRs:** restrict secret access; run only safe jobs (lint/test) on fork PRs.
