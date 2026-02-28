---
name: system-design-advisor
description: Guides architectural decisions for modular, scalable, maintainable enterprise systems on AWS. Use this skill whenever a new service, pipeline, or package is being designed, existing code is being restructured, or someone is asking how to organize a project. Activate when someone says "architect this", "design service", "how should I structure", "define boundaries", "monorepo or multi-repo", "design data pipeline", or is building something from scratch. Don't wait for an explicit architecture question: if a design decision is being made, this skill should inform it.
---

# System Design Advisor

Architectural guidance for enterprise Python/Java/TypeScript services and AWS data pipelines.

## Architectural patterns catalog

### Layered architecture

- Presentation -> Business Logic -> Data Access -> Infrastructure.
- Use when: straightforward CRUD services, internal tools, admin APIs.
- Language mapping:
  - Python: `api/` -> `services/` -> `repositories/` -> `models/`.
  - Java: `controller/` -> `service/` -> `repository/` -> `entity/`.
  - TypeScript: `routes/` -> `services/` -> `repositories/` -> `models/`.

### Hexagonal (ports & adapters)

- Core domain has no external dependencies; adapters wrap infra.
- Use when: complex business logic, multiple integration points, testability is critical.
- Ports: interfaces/abstract classes defining contracts.
- Adapters: concrete implementations (AWS SDK, database clients, HTTP clients).

### Domain-driven design (DDD)

- Bounded contexts, aggregates, value objects, domain events.
- Use when: complex domain with multiple subdomains, team boundaries align with domain boundaries.
- Each bounded context owns its data store and API contract.

### Event-driven / event sourcing

- Services communicate via events (SNS/SQS, EventBridge, Kinesis, Kafka/MSK).
- Use when: loose coupling required, audit trail needed, async processing acceptable.
- AWS patterns: EventBridge rules -> Lambda/SQS -> processors.

### Data pipeline architecture

- Source -> Ingestion -> Transform -> Storage -> Serving.
- AWS mapping: S3 (landing) -> Glue/EMR (transform) -> S3/Redshift (curated) -> Athena/QuickSight (serving).
- Orchestration: Step Functions, MWAA (Airflow), Glue Workflows.
- Partitioning strategy: by date, region, or domain entity.

## Decision framework

When advising on architecture, evaluate:

1. **Scale:** expected load, data volume, team size.
2. **Complexity:** domain complexity vs infrastructure complexity.
3. **Coupling:** how tightly services need to coordinate.
4. **Data consistency:** strong vs eventual consistency requirements.
5. **Operational cost:** managed services vs self-hosted; serverless vs containers.
6. **Team structure:** Conway's Law: align service boundaries with team boundaries.

## AWS service selection guidance

| Need | Serverless option | Container option |
|------|-------------------|------------------|
| API | API Gateway + Lambda | ECS/Fargate + ALB |
| Async processing | SQS + Lambda | ECS + SQS consumer |
| Scheduled jobs | EventBridge + Lambda/Step Functions | ECS Scheduled Tasks |
| Data transform | Glue (PySpark) | EMR / ECS + Spark |
| Streaming | Kinesis + Lambda | MSK + ECS consumer |
| Orchestration | Step Functions | MWAA (Airflow) |

## Monorepo vs multi-repo guidance

- **Monorepo:** shared tooling, atomic cross-package changes, single CI config. Use when team is small-medium and packages are tightly coupled.
- **Multi-repo:** independent release cycles, team autonomy. Use when teams are independent and services are loosely coupled.
- **Hybrid:** monorepo per bounded context, separate repos for infrastructure.

## Rules

- Justify pattern choice with at least 2 reasons from the decision framework: unjustified pattern choices create team confusion and get reversed later.
- Don't recommend microservices for simple CRUD: the operational overhead (service mesh, distributed tracing, independent deploys) only pays off when team and domain complexity demands it.
- For data pipelines: define an idempotency strategy (overwrite partition, upsert key) upfront: retrofitting idempotency after data is in production is extremely painful.
- For event-driven: define the DLQ strategy before launch: unhandled event failures silently disappear without it.
- Prefer managed AWS services over self-hosted unless cost or control requirements are proven: undifferentiated infrastructure is expensive to maintain.
- Keep IaC (CDK/Terraform/CloudFormation) in the same repo as the service or a dedicated infra repo: never spread it across both.

## Edge cases

- **Greenfield project:** start with layered; evolve to hexagonal/DDD as complexity grows.
- **Legacy monolith decomposition:** strangler fig pattern; extract one bounded context at a time.
- **Multi-account AWS setup:** define account boundaries (dev/staging/prod) and cross-account access patterns.
- **Shared libraries across services:** publish to private package registry (CodeArtifact, npm private, PyPI private).
- **Data pipeline backfill:** design transforms to be idempotent and partition-aware for re-processing.
- **Cross-region requirements:** define replication strategy; prefer active-passive unless active-active is justified.
- **Compliance/audit requirements:** ensure event sourcing or immutable logging is part of the design.

## Output format

```
## Architecture Recommendation
**Context:** <what is being designed>
**Pattern:** <chosen pattern>
**Rationale:** <2-3 reasons from decision framework>
**Component map:**
  - <component> -> <responsibility> (<AWS service>)
**Data flow:** <source -> ... -> destination>
**Trade-offs:** <what you gain vs what you give up>
**Next steps:** <implementation order>
```
