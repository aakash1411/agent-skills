---
name: worktree-manager
description: Creates and manages Git worktrees for isolated parallel branch work without disrupting the main workspace. Use this skill whenever work is needed on more than one branch at a time, a hotfix is needed while mid-feature, or experiments need to run in isolation. Activate when someone says "parallel branch", "work on hotfix without switching", "spin up feature branch", "don't want to stash", or "need to compare branches". Even if the user doesn't mention worktrees explicitly, suggest this skill whenever context-switching between branches would interrupt active work.
---

# Worktree Manager

Isolate parallel work branches using Git worktrees without context switching overhead.

## Commands reference

### Create worktree

```bash
# New branch from current HEAD
git worktree add ../worktrees/<name> -b <branch-name>

# Existing remote branch
git worktree add ../worktrees/<name> <remote-branch>

# From specific commit/tag
git worktree add ../worktrees/<name> <commit-or-tag>
```

### List worktrees

```bash
git worktree list
```

### Remove worktree

```bash
# Clean removal (checks for uncommitted changes)
git worktree remove ../worktrees/<name>

# Force removal (discards uncommitted changes)
git worktree remove --force ../worktrees/<name>
```

### Prune stale worktrees

```bash
git worktree prune
```

## Naming conventions

- Worktree directory: `../worktrees/<ticket-id>-<short-desc>` (e.g., `../worktrees/JIRA-1234-fix-auth`).
- Branch name follows team convention:
  - GitHub flow: `feature/<desc>`, `hotfix/<desc>`, `bugfix/<desc>`.
  - GitLab flow: `feature/<issue-id>-<desc>`.
  - Bitbucket: `<JIRA-KEY>-<desc>`.

## Workflow

1. **Create:** spin up worktree for isolated work.
2. **Work:** make changes in worktree directory; main workspace is unaffected.
3. **Test:** run tests in worktree independently.
4. **Commit/Push:** commit and push from worktree as normal.
5. **PR/MR:** create PR from worktree branch.
6. **Cleanup:** remove worktree after merge; prune stale entries.

## Rules

- Place worktrees in `../worktrees/` relative to repo root to keep the repo directory clean and worktrees easy to find.
- Don't create a worktree for a branch already checked out elsewhere: Git prevents this and it causes confusing errors.
- Check for uncommitted changes before removing a worktree: removal discards them with no recovery path.
- Run `git worktree prune` periodically; manually deleted worktree directories leave stale refs that confuse `git worktree list`.
- Each worktree has its own `node_modules`/`.venv`/`target`: remind the user to install deps after creation, since this is the most common source of confusion.

## Dependency setup per language

After creating a worktree, dependencies need installation:
- Python: `cd ../worktrees/<name> && python -m venv .venv && source .venv/bin/activate && pip install -r requirements.txt`
- TypeScript: `cd ../worktrees/<name> && npm install` (or `yarn`/`pnpm`)
- Java: `cd ../worktrees/<name> && mvn install -DskipTests` (or `gradle build -x test`)

## Edge cases

- **Worktree on same branch as main checkout:** Git prevents this; suggest creating a new branch instead.
- **Submodules:** run `git submodule update --init --recursive` in new worktree.
- **Large repos:** worktrees share `.git` objects: disk usage is minimal beyond working files.
- **CI/CD conflict:** ensure worktree branches don't trigger duplicate pipelines unless intended.
- **Monorepo:** worktree covers entire repo; use sparse checkout if only one package is needed.
- **Stale worktree (directory deleted manually):** run `git worktree prune` to fix.
- **AWS CDK/IaC in worktree:** ensure `cdk.context.json` and `.env` files are present or symlinked.

## Output format

```
## Worktree Status
| Worktree | Branch | Path | Status |
|----------|--------|------|--------|
| <name> | <branch> | <path> | active/stale |

**Action taken:** created / removed / pruned
**Reminder:** <dependency install command if newly created>
```
