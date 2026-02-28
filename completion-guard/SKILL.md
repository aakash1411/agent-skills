---
name: completion-guard
description: Prevents premature task completion by enforcing verification gates before declaring work done. Use this skill whenever a task, feature, PR, deployment, or pipeline change is being wrapped up: even if it "looks done". Activate it when someone says "done", "finished", "ready for review", "ship it", "mark complete", or is about to open a PR. Don't let work be declared complete without running through the gates: most production incidents come from skipping this step.
---

# Completion Guard

Never declare "done" without verified evidence across all required gates.

## Verification gates (check all applicable)

### Gate 1: Code correctness

- [ ] All modified files saved and syntactically valid.
- [ ] No unresolved TODO/FIXME/HACK markers introduced by this change.
- [ ] No commented-out code left behind (unless explicitly justified).
- [ ] Type checks pass:
  - Python: `mypy` or `pyright` (if configured).
  - Java: compilation succeeds with no warnings-as-errors.
  - TypeScript: `tsc --noEmit` passes.

### Gate 2: Test verification

- [ ] Relevant test suite runs and passes: `pytest`, `mvn test`, `npm test`, or equivalent.
- [ ] No skipped tests that were previously passing.
- [ ] New code has corresponding tests (per test-first-workflow expectations).
- [ ] Integration tests pass if change touches API contracts or data schemas.

### Gate 3: Lint and format

- [ ] Linter passes: `ruff`/`flake8` (Python), `eslint` (TypeScript), `checkstyle`/`spotless` (Java).
- [ ] Formatter applied: `black`/`ruff format` (Python), `prettier` (TypeScript), `google-java-format` (Java).
- [ ] No new lint warnings introduced.

### Gate 4: CI pipeline status

- [ ] GitHub Actions / Bitbucket Pipelines / GitLab CI pipeline is green.
- [ ] All required status checks pass.
- [ ] No flaky test failures (if flaky, document and link to tracking issue).

### Gate 5: AWS resource verification (if applicable)

- [ ] CloudFormation/CDK/Terraform changes validated: `cdk diff`, `terraform plan`, `cfn-lint`.
- [ ] No unintended resource deletions or replacements.
- [ ] IAM policy changes reviewed for least-privilege.
- [ ] Lambda/ECS/Glue resource configurations match expectations.

### Gate 6: Documentation and PR hygiene

- [ ] PR/MR description explains what and why.
- [ ] Breaking changes documented.
- [ ] Migration steps included if schema or API changed.
- [ ] Reviewers assigned (if team convention).

## Behavior

1. When completion is claimed, run through all applicable gates.
2. Report gate status as checklist with pass/fail/skip per gate.
3. If any required gate fails, block completion and report what needs fixing.
4. Only declare complete when all required gates pass.

## Rules

- Gate 2 (tests) is always required: there is no category of change small enough to skip test verification.
- Gate 5 (AWS) applies only when infra-as-code or AWS resources are modified.
- When a gate can't be automatically verified, flag it explicitly for manual review rather than silently skipping it.
- For data pipeline changes: verify sample data output matches expectations: code correctness alone doesn't guarantee data correctness.
- For schema changes: verify backward compatibility or document the breaking change: silent schema breaks are the hardest production issues to debug.

## Edge cases

- **CI is broken for unrelated reasons:** note the unrelated failure, verify local tests pass, flag for manual CI review.
- **No test framework configured:** flag as a blocker; do not silently skip testing.
- **Partial deployment (multi-service):** verify each service independently before declaring overall completion.
- **Hotfix under time pressure:** still run Gate 1 + Gate 2 minimum; document skipped gates with justification.
- **Monorepo with affected/unaffected packages:** only run gates for affected packages.

## Output format

```
## Completion Verification
| Gate | Status | Details |
|------|--------|---------|
| Code correctness | ✅/❌ | ... |
| Tests | ✅/❌ | ... |
| Lint/format | ✅/❌ | ... |
| CI pipeline | ✅/❌ | ... |
| AWS resources | ✅/❌/⏭ | ... |
| Docs/PR hygiene | ✅/❌ | ... |

**Result:** PASS / BLOCKED (fix: ...)
```
