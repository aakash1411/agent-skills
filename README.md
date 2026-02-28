# Agent Skills

A collection of reusable skills for AI coding agents (Claude Code, Cursor, Windsurf, etc.).

Each skill is a markdown file (`SKILL.md`) that instructs the agent how to handle a specific workflow: from memory management to CI/CD generation, debugging, testing, and deployment.

## Skills

| Skill | Description |
|-------|-------------|
| [`memory-manager`](memory-manager/SKILL.md) | Centralized per-project memory stored in `~/.windsurf/.memories/<project-name>/`. Progressive disclosure with always-loaded index + on-demand topic files. |
| [`git-explain`](git-explain/SKILL.md) | Generate dated markdown summaries of new changes after `git pull`. |
| [`root-cause-analyzer`](root-cause-analyzer/SKILL.md) | Four-phase debugging framework: evidence → pattern analysis → hypothesis → minimal fix. |
| [`test-first-workflow`](test-first-workflow/SKILL.md) | Enforce RED-GREEN-REFACTOR TDD for Python (pytest), Java (JUnit), and TypeScript (Jest/Vitest). |
| [`completion-guard`](completion-guard/SKILL.md) | Verification gates before declaring any task done: tests, lint, CI, AWS resources, PR hygiene. |
| [`worktree-manager`](worktree-manager/SKILL.md) | Create and manage Git worktrees for isolated parallel branch work. |
| [`system-design-advisor`](system-design-advisor/SKILL.md) | Architectural guidance for enterprise services: layered, hexagonal, DDD, event-driven, data pipelines. |
| [`resilience-patterns`](resilience-patterns/SKILL.md) | Structured error handling, retries, circuit breakers, fallbacks, and observability for AWS services. |
| [`pytest-architect`](pytest-architect/SKILL.md) | Production-grade pytest suite design: fixtures, mocks, async, PySpark, Lambda handler testing. |
| [`perf-profiler`](perf-profiler/SKILL.md) | Profile and optimize Python/Java/TypeScript services and AWS data pipelines. |
| [`ts-service-scaffolder`](ts-service-scaffolder/SKILL.md) | Standardized TypeScript backend service and Lambda handler patterns. |
| [`ci-pipeline-generator`](ci-pipeline-generator/SKILL.md) | Generate CI/CD configs for GitHub Actions, Bitbucket Pipelines, and GitLab CI with AWS deployment integration. |
| [`container-optimizer`](container-optimizer/SKILL.md) | Optimized, secure multi-stage Docker images for Python, Java, and TypeScript on AWS. |
| [`progressive-delivery`](progressive-delivery/SKILL.md) | Multi-stage deployment pipelines with quality gates, canary/blue-green rollouts, and automated rollback. |
| [`credential-vault`](credential-vault/SKILL.md) | Secrets lifecycle management across AWS Secrets Manager, SSM, IAM, OIDC, and CI/CD pipelines. |

## Install

**Single skill (global):**

```bash
curl -sL https://raw.githubusercontent.com/aakash1411/agent-skills/main/install.sh | bash -s -- memory-manager
```

**Single skill (workspace-local):**

```bash
curl -sL https://raw.githubusercontent.com/aakash1411/agent-skills/main/install.sh | bash -s -- memory-manager --workspace
```

**All skills:**

```bash
curl -sL https://raw.githubusercontent.com/aakash1411/agent-skills/main/install.sh | bash -s -- --all
```

**Custom directory (e.g. Cursor):**

```bash
curl -sL https://raw.githubusercontent.com/aakash1411/agent-skills/main/install.sh | bash -s -- --all --dir ~/.cursor/skills
```

**List available skills:**

```bash
curl -sL https://raw.githubusercontent.com/aakash1411/agent-skills/main/install.sh | bash -s -- --list
```

### Manual install

Copy any skill's `SKILL.md` to your agent's skill directory:

```bash
# Windsurf (global)
~/.windsurf/skills/<skill-name>/SKILL.md

# Windsurf (workspace)
.windsurf/skills/<skill-name>/SKILL.md
```

## License

MIT
