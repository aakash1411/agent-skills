---
name: progressive-delivery
description: Designs multi-stage deployment pipelines with quality gates, progressive rollout strategies, health checks, and automated rollback on AWS. Use this skill whenever a deployment workflow is being designed or improved, a production incident reveals a rollback gap, or a service needs canary, blue-green, or rolling delivery. Activate when someone says "design deployment", "canary", "blue-green", "rollback strategy", "promote to prod", "deployment gates", or when a new service is about to ship to production for the first time. Don't deploy to production without a rollback mechanism: activate this skill before the first production release of any service.
---

# Progressive Delivery

Multi-stage deployment pipelines with quality gates, progressive rollout, and automated rollback on AWS.

## Environment promotion model

```
develop -> staging -> production
   |          |           |
   v          v           v
  CI tests   Smoke      Canary/Blue-green
  Lint       Integration Full traffic shift
  Build      Manual gate Health check gate
```

### Environment purposes

| Environment | Purpose | Data | Access |
|-------------|---------|------|--------|
| develop/dev | Feature integration, fast feedback | Synthetic/seed | Dev team |
| staging | Pre-prod validation, integration testing | Production-like (anonymized) | Dev + QA |
| production | Live traffic | Real | Restricted |

## Deployment strategies

### Rolling update (default for ECS)

- Replace instances gradually; old and new coexist during rollout.
- Config: `minimumHealthyPercent: 50`, `maximumPercent: 200`.
- Rollback: ECS circuit breaker with `enable: true, rollback: true`.
- Best for: stateless services, internal APIs, workers.

```json
{
  "deploymentConfiguration": {
    "minimumHealthyPercent": 50,
    "maximumPercent": 200,
    "deploymentCircuitBreaker": {
      "enable": true,
      "rollback": true
    }
  }
}
```

### Blue-green deployment

- Two identical environments; switch traffic atomically.
- AWS: CodeDeploy with ECS blue-green, or ALB target group swap.
- Rollback: instant: switch back to original target group.
- Best for: critical services, zero-downtime requirements.

```yaml
# CodeDeploy AppSpec for ECS blue-green
version: 0.0
Resources:
  - TargetService:
      Type: AWS::ECS::Service
      Properties:
        TaskDefinition: <TASK_DEFINITION>
        LoadBalancerInfo:
          ContainerName: app
          ContainerPort: 8000
Hooks:
  - BeforeAllowTraffic: "LambdaFunctionToValidateBeforeTrafficShift"
  - AfterAllowTraffic: "LambdaFunctionToValidateAfterTrafficShift"
```

### Canary deployment

- Route small percentage of traffic to new version; monitor; gradually increase.
- AWS: CodeDeploy canary config (`Canary10Percent5Minutes`, `Linear10PercentEvery1Minute`).
- Lambda: alias traffic shifting with `CodeDeployDefault.LambdaCanary10Percent5Minutes`.
- Rollback: automatic on CloudWatch alarm trigger.
- Best for: user-facing APIs, high-risk changes.

### Feature flags (complementary)

- Deploy code to production but gate behind feature flag.
- Tools: LaunchDarkly, AWS AppConfig feature flags, Unleash.
- Decouple deployment from release; enable instant disable without rollback.

## Quality gates

### Gate 1: Pre-deployment checks

- [ ] All CI tests pass (unit, integration).
- [ ] Security scan clean (no critical/high CVEs).
- [ ] Docker image pushed and tagged.
- [ ] IaC diff reviewed (no unintended resource changes).
- [ ] Database migrations tested in staging.

### Gate 2: Staging validation

- [ ] Deployment to staging succeeds.
- [ ] Smoke tests pass (health endpoint, critical paths).
- [ ] Integration tests pass against staging environment.
- [ ] Performance baseline within acceptable range.
- [ ] Manual QA sign-off (if required).

### Gate 3: Production deployment

- [ ] Manual approval (GitHub environment protection, GitLab manual job, Bitbucket deployment permissions).
- [ ] Change window compliance (if applicable).
- [ ] Rollback plan documented.
- [ ] On-call team notified.

### Gate 4: Post-deployment verification

- [ ] Health checks pass for N minutes (typically 5-15).
- [ ] Error rate does not exceed baseline + threshold.
- [ ] Latency (p99) does not exceed baseline + threshold.
- [ ] No increase in CloudWatch alarms.
- [ ] Canary percentage increased or full traffic shifted.

## Automated rollback triggers

Configure CloudWatch Alarms to trigger rollback:

- Error rate > 5% (or 2x baseline).
- p99 latency > 2x baseline.
- Health check failures > threshold.
- 5xx response rate > 1%.
- Lambda: concurrent executions spike, throttles increase.
- ECS: task failure count > 0 in deployment.

### Rollback mechanisms by service

| Service | Rollback method |
|---------|----------------|
| ECS | Circuit breaker auto-rollback; or update to previous task definition |
| Lambda | Alias revert to previous version; CodeDeploy auto-rollback |
| Step Functions | Version alias revert; or redeploy previous definition |
| CDK/CloudFormation | Stack rollback (automatic on failure) |
| Terraform | `terraform apply` with previous state/plan |
| Glue | Redeploy previous script version from S3 |

## Health check design

### HTTP services

```
GET /health -> 200 OK
{
  "status": "healthy",
  "version": "<git-sha>",
  "checks": {
    "database": "ok",
    "cache": "ok",
    "upstream_api": "ok"
  }
}
```

- Shallow health: process is alive (for load balancer).
- Deep health: dependencies reachable (for deployment verification).
- Never expose sensitive info in health response.

### Non-HTTP services (workers, pipelines)

- Publish heartbeat metric to CloudWatch every N seconds.
- Alert if heartbeat missing for > 2 intervals.
- For Step Functions: monitor execution success rate.

## CI/CD provider deployment stages

### GitHub Actions

```yaml
deploy-staging:
  needs: build
  environment:
    name: staging
    url: https://staging.example.com
  steps:
    - name: Deploy to ECS
      run: ./scripts/deploy.sh staging

deploy-prod:
  needs: deploy-staging
  environment:
    name: production
    url: https://example.com
  steps:
    - name: Deploy to ECS
      run: ./scripts/deploy.sh production
```

### Bitbucket Pipelines

```yaml
- step:
    name: Deploy staging
    deployment: staging
    trigger: automatic
    script:
      - ./scripts/deploy.sh staging
- step:
    name: Deploy production
    deployment: production
    trigger: manual
    script:
      - ./scripts/deploy.sh production
```

### GitLab CI

```yaml
deploy_staging:
  stage: deploy
  environment:
    name: staging
  rules:
    - if: $CI_COMMIT_BRANCH == "main"

deploy_production:
  stage: deploy
  environment:
    name: production
  when: manual
  rules:
    - if: $CI_COMMIT_BRANCH == "main"
```

## Rules

- Don't deploy directly to production without staging validation: staging exists to catch the class of bugs that only appear with real configuration, real data shapes, and real service integrations.
- Configure automated rollback before the first production deploy: manual rollback under incident pressure is slow and error-prone.
- Health checks must exist before enabling progressive delivery: without them, the rollback trigger has nothing to monitor.
- Require a manual approval gate for production via environment protection rules: this creates a forcing function for reviewing what's being deployed.
- Database migrations must be backward-compatible (expand-contract pattern): a migration that breaks the running version means rollback also requires a DB rollback, which is extremely risky.
- Don't delete or rename DB columns in the same deployment as the code change that stops using them: the old code will fail immediately on the new schema during the rollout window.

## Edge cases

- **Database migration failure:** migrations must be idempotent; separate migration deployment from code deployment.
- **Multi-service dependency:** deploy in dependency order; use feature flags to decouple.
- **Hotfix bypass:** allow fast-track path that still requires Gate 1 (tests) + Gate 4 (post-deploy verification).
- **Rollback with data migration:** design migrations to be forward-only; use compensating transactions.
- **Cross-region deployment:** deploy to primary first; replicate only after health verification.
- **Deployment during peak traffic:** schedule deployments for low-traffic windows; or use canary to limit blast radius.
- **Shared infrastructure changes (VPC, IAM):** deploy infra changes separately from application changes.
- **Glue job deployment:** version scripts in S3 with commit SHA; update job definition to point to new script.

## Output format

```
## Deployment Plan
**Service:** <name>
**Strategy:** rolling / blue-green / canary
**Environments:** <promotion path>
**Gates:**
  - <gate>: <verification method>
**Rollback trigger:** <condition>
**Rollback method:** <how>
**Health check:** <endpoint/metric>
**Estimated duration:** <time>
```
