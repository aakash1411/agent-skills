---
name: test-first-workflow
description: Enforces the RED-GREEN-REFACTOR TDD cycle for Python (pytest), Java (JUnit/TestNG), and TypeScript (Jest/Vitest). Use this skill whenever new functionality is being added, existing code is being refactored, or behavior is being changed: even for "small" or "obvious" changes. Activate it when someone says "implement", "add feature", "write tests for", "refactor", "TDD", or "test first". Don't skip this skill just because the change seems trivial: untested code is the most common source of regressions.
---

# Test-First Workflow

Enforce RED-GREEN-REFACTOR for Python, Java, and TypeScript in enterprise codebases.

## Cycle (strict order)

### RED: Write failing test

1. Identify the behavior to implement as a testable assertion.
2. Write test using project's framework:
   - Python: `pytest` with fixtures; use `conftest.py` for shared setup.
   - Java: `JUnit 5` or `TestNG`; use `@BeforeEach` for setup; Mockito for mocks.
   - TypeScript: `Jest` or `Vitest`; use `describe`/`it` blocks; mock with `jest.mock` or `vi.mock`.
3. Run the test and confirm it **fails** for the right reason (not an import error, not a wrong assertion). Failing for the right reason proves the test actually covers the behavior you intend to implement.
4. If the test passes immediately, the test is wrong or the behavior already exists: investigate before writing any implementation.

### GREEN: Minimal implementation

1. Write the smallest code that makes the test pass.
2. No optimization, no refactoring, no extra features.
3. Run test and confirm it **passes**.
4. Run full related test suite to check no regressions.

### REFACTOR: Clean up

1. Improve code structure, naming, duplication: without changing behavior.
2. Run tests after each refactor step to confirm green stays green.
3. Extract helpers, reduce complexity, improve types/contracts.

## Test design rules

- One assertion per test (or one logical behavior per test).
- Test names describe behavior, not implementation: `test_returns_404_when_user_not_found` not `test_get_user`.
- Use arrange-act-assert (AAA) pattern.
- Mock external dependencies (AWS services, databases, HTTP calls): never hit real infra in unit tests.
- For data pipelines: test transformations with small deterministic DataFrames/datasets.

## AWS-specific testing patterns

- Mock AWS SDK calls using:
  - Python: `moto`, `botocore.stub.Stubber`, or `unittest.mock.patch`.
  - Java: `aws-sdk-java-v2` mock clients or LocalStack.
  - TypeScript: `aws-sdk-client-mock` or `jest.mock('@aws-sdk/client-*')`.
- For Lambda handlers: test handler function directly with synthetic event payloads.
- For Step Functions: test individual state logic; mock state transitions.
- For Glue jobs: test PySpark transforms with small local SparkSession.
- For S3/DynamoDB interactions: use moto or LocalStack; never hit real AWS in tests.

## Coverage expectations

- New code: aim for ≥80% line coverage on new paths.
- Critical paths (auth, payments, data transforms): aim for ≥90%.
- Do not chase 100%: focus on behavior coverage, not line coverage.
- Report uncovered branches explicitly if skipping intentionally.

## Edge cases to address in tests

- Null/None/undefined inputs.
- Empty collections, zero-length strings.
- Boundary values (0, -1, MAX_INT, empty partition).
- Concurrent access patterns (if applicable).
- Timeout and retry scenarios for AWS calls.
- Malformed input data (bad JSON, wrong schema, encoding issues).
- Permission denied / access errors from AWS services.

## Rules

- Write the failing test before any implementation. Implementing first makes it easy to write tests that pass trivially without actually verifying behavior.
- Don't skip the RED phase for "obvious" changes: obvious changes have obvious bugs too.
- If refactoring breaks a test, stop and fix the test before continuing. A broken test during refactor means behavior changed, which is the opposite of what refactoring means.
- Keep test files adjacent to source or in a dedicated `tests/` dir per project convention.
- Don't mix unit and integration tests in the same file: they have different speed, setup, and isolation requirements.

## Output format per cycle

```
## TDD Cycle
**Behavior:** <what is being tested>
**RED:** <test written, confirmed failing, failure reason>
**GREEN:** <implementation summary, test now passes>
**REFACTOR:** <cleanup done, tests still green>
**Coverage delta:** <lines/branches added>
```
