---
name: root-cause-analyzer
description: Structured four-phase debugging framework for enterprise codebases that enforces root-cause identification before any fix is proposed. Use this skill whenever a bug, test failure, build error, runtime exception, or unexpected behavior appears in Python, Java, or TypeScript services: even if the problem seems obvious. Also use it for AWS service failures (Lambda, ECS, Step Functions, Glue), CI pipeline failures (GitHub Actions, Bitbucket, GitLab), and any situation where someone says "why is this failing", "trace this", "investigate", or "debug". Don't wait to be explicitly asked: if something is broken, activate this skill.
---

# Root Cause Analyzer

Disciplined debugging for enterprise Python/Java/TypeScript codebases on AWS.

## Four phases (execute in order, never skip)

### Phase 1: Evidence collection

Gather facts before theorizing:
- Read error messages, stack traces, and logs verbatim.
- Identify the failing component: file, function, line, service.
- Check recent changes: `git log --oneline -20`, `git diff HEAD~5..HEAD -- <suspect-paths>`.
- For AWS failures: check CloudWatch logs, X-Ray traces, Step Functions execution history.
- For data pipeline failures: check Glue job logs, EMR step logs, Athena query history.
- Record: what works vs what doesn't; when it last worked; what changed since.

### Phase 2: Pattern analysis

- Compare failing vs passing cases (inputs, environment, timing).
- Check for known patterns:
  - Python: import cycles, GIL contention, async/await misuse, pandas dtype coercion.
  - Java: NPE chains, classpath conflicts, thread deadlocks, Spring bean wiring.
  - TypeScript: type narrowing gaps, null vs undefined, async error swallowing, module resolution.
- Check environment differences: dev vs staging vs prod; env vars; IAM permissions; VPC/security groups.
- Check data differences: schema drift, null columns, encoding, partition keys.

### Phase 3: Hypothesis and validation

- State the hypothesis explicitly: "The failure occurs because X, triggered by Y." This forces precision and prevents vague "it might be" thinking.
- Validate with a minimal targeted test or log statement: guessing wastes time and can mask the real cause.
- If the hypothesis fails, return to Phase 1 with the new evidence.
- After 3 failed cycles, surface findings to the user: more evidence is needed before proceeding.

### Phase 4: Minimal fix and verification

- Propose the smallest change that eliminates the root cause. Larger changes introduce new risk and obscure whether the fix actually worked.
- Fix the upstream cause, not downstream symptoms: patching symptoms leaves the root cause in place.
- Run the relevant test suite to confirm the fix.
- Check for regressions in adjacent components.
- Document: root cause, fix applied, verification method.

## Rules

- Complete Phase 1 and Phase 2 before proposing any fix. Skipping evidence collection leads to wrong fixes that waste more time than the phases themselves.
- Avoid random patches and shotgun debugging: they accumulate technical debt and rarely address root cause.
- If root cause spans multiple services, map the causal chain before fixing any single service.
- For AWS infrastructure issues, distinguish between code bugs and infra misconfiguration: the fix path is completely different.
- For data pipeline failures, distinguish between data quality issues and code logic errors before touching code.
- Check whether the bug exists across branches (main, develop, feature) to understand blast radius.

## Git provider integration

- GitHub: reference issue numbers in findings; suggest PR labels (`bug`, `hotfix`).
- Bitbucket: reference Jira keys if present in branch names or commit messages.
- GitLab: reference issue IDs; suggest MR labels.

## Edge cases

- **Flaky test:** require 3+ consecutive reproductions before declaring root cause.
- **Heisenbug (disappears under observation):** add non-intrusive logging; avoid debugger-dependent diagnosis.
- **Multi-service failure cascade:** trace to originating service first; fix upstream.
- **Permission/IAM error:** verify IAM policies and trust relationships before blaming code.
- **Data pipeline schema drift:** check upstream producer schema changes before fixing consumer code.
- **Race condition:** add timing annotations; reproduce under load if needed.
- **Environment-specific:** compare env var values, SDK versions, runtime versions across envs.

## Output format

```
## Root Cause Analysis
**Component:** <file/service>
**Phase:** <1-4>
**Root cause:** <one-line summary>
**Evidence:** <what confirmed it>
**Fix:** <minimal change description>
**Verification:** <how confirmed fix works>
**Regression check:** <what else was tested>
```
