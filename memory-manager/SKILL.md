---
name: memory-manager
description: Agent-agnostic per-project memory system storing context in ~/.windsurf/.memories/<project-name>/: outside repos, one subfolder per project, always accessible. Use this skill at the start of every session to load project context, and at the end of every meaningful task to record what changed. Activate when someone says "init memories", "update index", "log this", "update architecture", "show memory summary", "freeze memories", "set up memories", or when starting work on a project for the first time. Don't wait to be asked to update memories after completing a task: if something meaningful changed, log it.
---

# Memory Manager

Centralized per-project memory with progressive disclosure, stored outside repos:
- **Index file** (`00_INDEX.md`): always loaded, short, points to topic files.
- **Topic files** (`01_*.md`, `02_*.md`, ...): loaded on demand when the agent needs deeper context.

## How this skill works

- Works with any coding agent (Claude Code, Cursor, Windsurf) using only file read/write tools: no agent-specific memory APIs.
- All files live under `~/.windsurf/.memories/<project-name>/` where `<project-name>` is the repo root directory name (e.g. repo at `~/myProjects/my-api` → `~/.windsurf/.memories/my-api/`).
- Keeping memories outside repos means no `.gitignore` needed and no risk of committing context into source control.

## Core rules

- **Index stays short:** `00_INDEX.md` must stay under 150 lines. If it exceeds 150, compress or move detail into a topic file.
- **Progressive disclosure:** agent reads `00_INDEX.md` first on every session/task start; opens topic files only when a question or task touches that topic.
- **No secrets:** never store secret values (keys, tokens, passwords). Use `REDACTED` and note why.
- **No large code blocks:** store pattern descriptions + file path references, not code.
- **Idempotent updates:** re-running must not duplicate content. Merge and deduplicate.
- **Minimal diffs:** edit only changed lines/sections. Prefer append for logs, surgical edit for facts.
- **Deterministic structure:** predictable file names, numbered prefixes, consistent section headings.
- **Safe defaults:** when uncertain, make best-effort update; do not block progress.

## File structure

```
~/.windsurf/.memories/
└── <project-name>/          # One subfolder per project (repo root dir name)
    ├── 00_INDEX.md          # Always loaded. Project overview + pointers.
    ├── 01_ARCHITECTURE.md   # Service/module map, data flow, boundaries.
    ├── 02_DEPLOYMENT.md     # Environments, CI/CD, deploy/rollback steps.
    ├── 03_RUNBOOKS.md       # Operational procedures, common fixes, oncall.
    ├── 04_DECISIONS.md      # Architecture Decision Records (ADRs), rationale.
    ├── 05_GOTCHAS.md        # Sharp edges, known bugs, non-obvious behavior.
    ├── 06_TASK_LOG.md       # Recent work log: date, what changed, paths.
    ├── 07_PREFERENCES.md    # Coding style, communication, constraints.
    └── NN_<TOPIC>.md        # Additional topic files as needed.
```

### Resolving project name

- Use the repo root directory name as `<project-name>`.
- Detect repo root via `git rev-parse --show-toplevel` or use the workspace root path.
- If not in a git repo, use the workspace/folder name opened in the agent.
- Example: repo at `/Users/alice/myProjects/payments-service` → project name is `payments-service`.

### File numbering convention

- `00` = index (always exactly one).
- `01`–`06` = standard topic files (create on init if applicable).
- `07` = preferences (coding style, communication, constraints).
- `08`+ = project-specific topics added as needed (e.g., `08_API_CONTRACTS.md`, `09_DATA_MODELS.md`).

### When to create vs skip topic files

- Create a topic file only when there is verified content to put in it.
- On project init, create `00_INDEX.md` always. Create other files only if the repo scan yields relevant content for that topic.
- For small projects, `00_INDEX.md` + `06_TASK_LOG.md` + `07_PREFERENCES.md` may be sufficient.
- All paths in topic file pointers must use the full `~/.windsurf/.memories/<project-name>/` prefix.

## 00_INDEX.md specification (always loaded)

Hard limit: **150 lines**. Target: **80–120 lines**.

### Required sections

```markdown
# Project Memory Index
Last updated: YYYY-MM-DD

## What this repo is
- One-liner purpose
- Primary users / surfaces
- Key languages / frameworks

## How to run locally
- Prerequisites
- Quickstart commands
- Common env vars (names only, no values)

## How to test
- Test commands
- Coverage expectations

## Where things live
- /path/ -> responsibility
- /path/ -> responsibility

## Topic files (open only when needed)
- Architecture: ~/.windsurf/.memories/<project-name>/01_ARCHITECTURE.md
- Deployment: ~/.windsurf/.memories/<project-name>/02_DEPLOYMENT.md
- Runbooks: ~/.windsurf/.memories/<project-name>/03_RUNBOOKS.md
- Decisions / ADRs: ~/.windsurf/.memories/<project-name>/04_DECISIONS.md
- Gotchas: ~/.windsurf/.memories/<project-name>/05_GOTCHAS.md
- Task log: ~/.windsurf/.memories/<project-name>/06_TASK_LOG.md
- Preferences: ~/.windsurf/.memories/<project-name>/07_PREFERENCES.md

## Current constraints / invariants
- "Constraint or rule that always applies"
- "Another invariant"

## Active context (≤5 lines)
- Current objective or focus area
- Immediate next step
```

### Index rules

- **"Topic files" section is mandatory**: it is the pointer table. Every topic file must be listed here.
- **"Active context" section** replaces the old working memory concept: keep it to ≤5 lines; rotate frequently.
- If a new topic file is created, add one pointer line to the "Topic files" section.
- If the index exceeds 150 lines, move detail into the appropriate topic file and replace with a pointer.

## Topic file specifications

### 01_ARCHITECTURE.md

```markdown
# Architecture

## System overview
- High-level description (2–3 lines)

## Component map
- component/path -> responsibility (service/library/infra)

## Data flow
- source -> transform -> destination

## Key integrations
- External service: purpose, auth method (no secrets)

## Boundaries / contracts
- API contracts between services
- Shared schemas or event formats
```

### 02_DEPLOYMENT.md

```markdown
# Deployment

## Environments
- dev: account/region, purpose
- staging: account/region, purpose
- prod: account/region, purpose

## CI/CD
- Pipeline tool (GitHub Actions / Bitbucket Pipelines / GitLab CI)
- Build steps summary
- Deploy steps summary
- Rollback steps

## AWS specifics (if applicable)
- SSO config (profile names, not credentials)
- Key services used
- IaC tool and location

## Common deployment failures
- Symptom: fix
```

### 03_RUNBOOKS.md

```markdown
# Runbooks

## Operational procedures
- Procedure name: steps

## Common fixes
- Problem: solution

## Monitoring / alerting
- What is monitored
- Where to look (dashboards, logs)

## Escalation
- Who to contact for what
```

### 04_DECISIONS.md

```markdown
# Decisions (ADRs)

Format per entry:
## YYYY-MM-DD: Decision title
- **Status:** accepted / superseded / deprecated
- **Context:** why this decision was needed (1–2 lines)
- **Decision:** what was decided
- **Consequences:** trade-offs accepted
```

### 05_GOTCHAS.md

```markdown
# Gotchas & Sharp Edges

Format per entry:
## Category (e.g., Build, Deploy, Data, Auth)
- **Gotcha:** description
- **Impact:** what goes wrong
- **Fix/Workaround:** how to handle it
```

### 06_TASK_LOG.md

```markdown
# Task Log

Format per entry (most recent first):
## YYYY-MM-DD: Short description
- What changed
- Files/paths affected
- Links to PRs/issues if applicable
- Follow-up needed: yes/no + detail
```

Keep last ~20 entries. Archive older entries by moving to a dated section at the bottom or deleting if no longer relevant.

### 07_PREFERENCES.md

```markdown
# Preferences

## Coding style
- comments: minimal | normal | extensive
- typing: none | partial | strict
- errors: raise | return | Result/Either
- logging: style and level
- naming: conventions per language

## Architecture preferences
- Patterns to favor / avoid
- Modularity expectations

## Testing
- Framework preferences
- Coverage expectations
- Mock strategies

## Tooling
- Lint / format tools
- CI expectations
- Commit / PR style

## Communication
- Verbosity: low | med | high
- Assumptions vs questions
- Diff-first reporting preference

## Constraints ("never do")
- Hard rules that override all else

## Conflict resolution
- If user preference conflicts with repo config, follow repo config and record conflict here.
```

## Command reference

| Phrase | Action |
|---|---|
| `init memories`, `start project`, `set up memories` | Create `~/.windsurf/.memories/<project-name>/` + files |
| `update index` | Refresh `00_INDEX.md` from current state |
| `update <topic>` (e.g., `update architecture`, `update deployment`) | Update the matching topic file |
| `update task log`, `log this` | Append entry to `06_TASK_LOG.md` |
| `update preferences`, `update prefs` | Update `07_PREFERENCES.md` |
| `add topic <name>` | Create new numbered topic file + add pointer to index |
| `show memory summary` | Print index overview + list of topic files with 1-line status each |
| `freeze memories` / `do not update memories` | Pause all auto-updates |
| `resume memories` / `resume updates` | Resume auto-updates |
| `compress index` | Reduce `00_INDEX.md` under 150 lines by pushing detail to topic files |

## Project-start behavior

Detect project start when:
- User says start/init/new project/set up memories.
- `~/.windsurf/.memories/<project-name>/` directory is missing.
- `00_INDEX.md` is missing.

Then:
1. Resolve `<project-name>` from repo root dir name (`git rev-parse --show-toplevel` or workspace root).
2. Create `~/.windsurf/.memories/<project-name>/` if missing.
3. Create `00_INDEX.md` always (from template, populated via repo scan).
4. Scan repo for high-signal sources:
   - Prioritize: `README*`, `docs/`, `src/`, entrypoints, build/test scripts, package/config files, infra/IaC.
   - Exclude: `.git/`, `node_modules/`, `dist/`, `build/`, vendor deps, generated dirs, large binaries, lockfiles.
   - Large repos: sample top-level + critical subdirs; cap scan scope.
5. Create topic files only where scan yields content:
   - Found service structure? -> create `01_ARCHITECTURE.md`.
   - Found CI/CD configs or deploy scripts? -> create `02_DEPLOYMENT.md`.
   - Found operational docs? -> create `03_RUNBOOKS.md`.
   - Otherwise skip: can be created later via `add topic`.
6. Always create `06_TASK_LOG.md` (empty template with first entry: "project memory initialized").
7. Always create `07_PREFERENCES.md` (from template; fill from conversation context if available).
8. If files already exist, do not overwrite. Merge safely and preserve user edits.

All files are created at `~/.windsurf/.memories/<project-name>/`: never inside the repo.

## Update policy

### When to update

Updates happen in two modes:

**Manual (explicit trigger):** user says `update <topic>`, `log this`, `update index`, etc. Execute immediately.

**End-of-task (recommended cadence):** at the end of any meaningful change or task completion:
1. Append entry to `06_TASK_LOG.md` (date, what changed, paths).
2. If a durable fact was learned (deploy step, invariant, gotcha), update the appropriate topic file.
3. If a new topic file was created, add pointer to `00_INDEX.md`.
4. Update "Active context" in `00_INDEX.md` if the current focus changed.
5. Update "Last updated" date in `00_INDEX.md`.

**Auto-update (if agent supports):** approximately every 3–5 meaningful user turns, check if `06_TASK_LOG.md` or "Active context" needs refresh. If paused (`freeze memories`), skip.

### What goes where (decision guide)

| Information type | Target file |
|---|---|
| Repo purpose, run/test commands, dir map | `00_INDEX.md` |
| Service boundaries, data flow, integrations | `01_ARCHITECTURE.md` |
| Environments, CI/CD, deploy/rollback | `02_DEPLOYMENT.md` |
| Operational procedures, common fixes | `03_RUNBOOKS.md` |
| Why a decision was made, trade-offs | `04_DECISIONS.md` |
| Non-obvious behavior, known bugs, sharp edges | `05_GOTCHAS.md` |
| What was just done, recent changes | `06_TASK_LOG.md` |
| Coding style, communication, constraints | `07_PREFERENCES.md` |
| Current focus, immediate next step | `00_INDEX.md` → "Active context" |

### Index size enforcement

After any update, check `00_INDEX.md` line count:
- If > 150 lines: identify sections with excessive detail and move to the appropriate topic file, replacing with a pointer line.
- If no appropriate topic file exists, create one and add pointer to index.

### Diff minimization

- Surgical edits only: change only what actually changed.
- Task log: append-only (newest first).
- Decisions: append-only.
- Topic files: edit in place for current facts; append for historical entries.

## Edge cases

- **Home dir not writable:** output exact file contents for manual paste, preserving full paths.
- **Project name collision** (two repos with same dir name): append parent dir segment to disambiguate (e.g. `work__payments-service` vs `personal__payments-service`).
- **Monorepo:** architecture topic must show package boundaries; task log entries can be package-scoped. Consider per-package topic files (e.g., `08_PKG_AUTH.md`, `09_PKG_BILLING.md`).
- **Multiple concurrent projects:** never mix memories across projects. Each project gets its own `~/.windsurf/.memories/<project-name>/` subfolder.
- **Binary/large files:** ignore content; reference paths only.
- **Ambiguous update:** default to task log entry. Do not update architecture/deployment unless explicitly relevant.
- **Topic file grows too large (>300 lines):** split into sub-topics (e.g., `02_DEPLOYMENT.md` → `02A_DEPLOYMENT_AWS.md` + `02B_DEPLOYMENT_CI.md`). Update index pointers.
- **Agent doesn't support file creation:** output file contents with instructions.
- **Conflicting preferences:** if user preference conflicts with repo lint/format config, follow repo config for code changes; record conflict in `07_PREFERENCES.md`.
- **Stale information:** when updating a topic file, remove or mark outdated entries. Prefer deletion over accumulation.

## Reporting format

When files change, report:
- `Changed:` list of file paths
- `Diff summary:` 1-line per file describing what changed

Do not dump full file contents unless user explicitly asks (e.g., `show index`, `show architecture`, `print task log`).
