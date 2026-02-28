---
name: resilience-patterns
description: Applies structured error handling, retry logic, circuit breakers, fallbacks, and observability patterns to enterprise services on AWS. Use this skill whenever error handling is being added or reviewed, an AWS integration is being built, or a data pipeline needs failure recovery. Activate when someone says "add error handling", "make this resilient", "handle failures", "add retries", "circuit breaker", or when bare try/except/catch blocks appear in code. Don't wait to be asked: if code touches an external dependency (AWS, database, HTTP) without structured error handling, this skill applies.
---

# Resilience Patterns

Structured error handling and fault tolerance for Python/Java/TypeScript services on AWS.

## Error handling hierarchy (apply in order)

### Level 1: Structured error types

Define typed errors: never throw raw strings or generic exceptions.

**Python:**
```python
class ServiceError(Exception):
    def __init__(self, message: str, code: str, context: dict | None = None):
        super().__init__(message)
        self.code = code
        self.context = context or {}

class NotFoundError(ServiceError): ...
class ValidationError(ServiceError): ...
class UpstreamError(ServiceError): ...
```

**Java:**
```java
public class ServiceException extends RuntimeException {
    private final String code;
    private final Map<String, Object> context;
    // constructor, getters
}
```

**TypeScript:**
```typescript
class ServiceError extends Error {
  constructor(
    message: string,
    public readonly code: string,
    public readonly context: Record<string, unknown> = {}
  ) { super(message); }
}
```

### Level 2: Retry with backoff

- Use exponential backoff with jitter for transient failures.
- Default: 3 retries, base delay 1s, max delay 30s, full jitter.
- Retry only on transient errors (5xx, throttle, timeout, connection reset).
- Never retry on 4xx (client errors): except 429 (throttle).

**AWS SDK retries:**
- Python (`boto3`): configure via `botocore.config.Config(retries={'max_attempts': 5, 'mode': 'adaptive'})`.
- Java: `RetryPolicy.builder().numRetries(5).build()` on SDK client.
- TypeScript: `maxAttempts: 5` in SDK client config.

### Level 3: Circuit breaker

- Track failure rate over sliding window (e.g., 10 calls / 60 seconds).
- States: CLOSED (normal) -> OPEN (failing, reject calls) -> HALF-OPEN (probe).
- Open circuit after failure threshold exceeded; probe periodically.
- Libraries: `pybreaker` (Python), `resilience4j` (Java), `opossum` (TypeScript).

### Level 4: Fallback and degradation

- Define a fallback for every external dependency. Without a fallback, a single dependency outage cascades into full service unavailability.
- Fallback options: cached response, default value, degraded feature, queue for later.
- Always log fallback activation: silent fallbacks mask outages that would otherwise be investigated and fixed.

### Level 5: Dead-letter and poison pill handling

- SQS: configure DLQ with `maxReceiveCount` (typically 3-5).
- Lambda: configure on-failure destination (SQS DLQ or SNS).
- Step Functions: use `Catch` blocks with `ResultPath` to capture error.
- Glue: configure job bookmarks and retry counts.
- Always alert on DLQ depth > 0.

## Error propagation rules

- Catch at service boundaries; let errors propagate within a service. Catching too early hides the original context and makes debugging harder.
- At API boundaries: map internal errors to HTTP status codes so callers can handle them correctly.
- At async boundaries (SQS/SNS/EventBridge): ensure failed messages land in a DLQ: without this, failures are silently dropped.
- At pipeline boundaries: log error context, mark the partition/file as failed, and continue processing others so one bad record doesn't halt the whole run.
- Don't swallow exceptions silently (`except: pass` / `catch {}` with no action): silent failures are the hardest class of bugs to diagnose.

## Observability integration

- Log errors with structured context: `{"error_code": "...", "service": "...", "trace_id": "..."}`.
- Emit CloudWatch metrics for error rates per service and error type.
- Use X-Ray trace IDs to correlate errors across services.
- Set CloudWatch Alarms on error rate thresholds.

## Language-specific patterns

### Python
- Use `contextlib.suppress` only for truly ignorable errors.
- Use `tenacity` library for configurable retries.
- In async code: handle `asyncio.TimeoutError` explicitly.
- In data pipelines: catch `pyspark.sql.utils.AnalysisException` for schema errors.

### Java
- Use checked exceptions for recoverable errors; unchecked for programming errors.
- Use `resilience4j` for retry + circuit breaker composition.
- In Spring: use `@ControllerAdvice` for centralized exception mapping.
- Handle `SdkException` from AWS SDK v2 for AWS-specific retries.

### TypeScript
- Use `Result<T, E>` pattern (neverthrow) for typed error handling where appropriate.
- Handle `Promise.allSettled` for parallel operations that can partially fail.
- In Express/Fastify: use error middleware for centralized HTTP error mapping.
- Always type catch clauses: `catch (error: unknown)` and narrow with `instanceof`.

## Edge cases

- **Retry storm:** if many instances retry simultaneously, use jitter to spread load.
- **Timeout cascading:** set downstream timeouts shorter than upstream to avoid chain timeouts.
- **Partial failure in batch:** process items individually; collect failures; report aggregated result.
- **AWS throttling:** use adaptive retry mode; consider request rate increases via support ticket.
- **Lambda cold start timeout:** set Lambda timeout > expected cold start + processing time.
- **Data pipeline partial write:** use atomic partition writes (write to temp, rename on success).
- **Cross-service transaction:** use saga pattern with compensating actions instead of distributed transactions.

## Output format

```
## Resilience Assessment
**Component:** <service/function>
**Current gaps:** <unhandled failure modes>
**Applied patterns:**
  - <pattern>: <where and how applied>
**Retry config:** <attempts, backoff, jitter>
**Fallback:** <strategy>
**DLQ/alerting:** <configuration>
**Observability:** <logging/metrics/tracing additions>
```
