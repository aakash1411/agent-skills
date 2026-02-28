---
name: git-explain
description: Generates dated markdown files summarizing the new changes introduced by a git pull. Use this skill whenever a pull has just happened and the changes need to be understood, documented, or communicated to the team. Activate when someone says "git explain", "explain pull", "explain changes", "what changed", "summarize the pull", or "what came in". Also use it proactively after any pull that brings in more than a handful of commits: understanding what changed before working with it prevents broken assumptions.
---

# Git Explain

Generate dated markdown files summarizing only the new changes introduced by a `git pull`.

## Core rules

- Run `git pull` first, then explain only the new changes.
- Create one dated markdown file per pull in the repo root: `git-explain-YYYY-MM-DD.md`.
- Keep explanations concise but focused on impact and intent.
- Never include secrets or sensitive data; redact if detected.
- Use deterministic file naming and section structure so files are easy to find and compare.

## Workflow

### Step 1: Pull latest changes

Always pull first to ensure we're explaining the latest incoming changes:

```bash
git pull
```

### Step 2: Detect new changes

Identify what changed in this pull:
- Get commit range from pull output (HEAD~N..HEAD)
- Use `git log --oneline HEAD~N..HEAD` to list new commits
- Use `git diff --name-status HEAD~N..HEAD` to see file changes
- Use `git diff --stat HEAD~N..HEAD` for change statistics

### Step 3: Create explanation file

Create file: `git-explain-YYYY-MM-DD.md` in repo root with this structure:

```markdown
# Git Changes Explanation
**Date:** YYYY-MM-DD  
**Pull Range:** <commit-range>  
**New Commits:** <count>

## Summary
<1-2 sentence overview of what changed>

## New Commits
- <commit-hash> <commit-message>
- <commit-hash> <commit-message>
...

## File Changes
### Added
- `path/to/file` (new file)
...

### Modified
- `path/to/file` (modified)
...

### Deleted
- `path/to/file` (deleted)
...

## Impact Analysis
### Breaking Changes
- List any breaking changes with affected areas

### New Features
- List new features and their locations

### Bug Fixes
- List bug fixes and what they address

### Configuration Changes
- List config/env/tooling changes

## Next Actions
- [ ] Review breaking changes
- [ ] Update documentation if needed
- [ ] Test new features
- [ ] Coordinate with team if breaking changes exist

## Notes
- Any additional context or warnings
- Dependencies that need updating
- Migration steps if required
```

### Step 4: Fill sections

**Summary:** Explain the overall theme of the pull (feature addition, bug fixes, refactor, etc.)

**New Commits:** List each commit with brief explanation of what it does and why it was made.

**File Changes:** For each changed file, describe the nature of changes and any dependencies or implications.

**Impact Analysis:** Categorize changes by impact level.

**Next Actions:** Provide actionable checklist for team members.

## Implementation details

### Detecting pull range

When `git pull` completes, capture the output to determine the commit range:
- If pull was fast-forward: range is `HEAD~N..HEAD` where N is number of new commits
- If pull was merge: range is `HEAD@{1}..HEAD` (before pull to after pull)

### Parsing git output

Use these commands to gather change information:

```bash
# Get new commits with messages
git log --oneline --pretty=format:"%h %s" HEAD~N..HEAD

# Get file change details
git diff --name-status HEAD~N..HEAD

# Get change statistics
git diff --stat HEAD~N..HEAD

# Get detailed diff for important files
git diff HEAD~N..HEAD -- path/to/important/file
```

### Handling special cases

**No changes:** If pull reports "Already up to date", create minimal file noting no new changes.

**Merge conflicts:** If pull had conflicts, note them in the explanation and suggest resolution steps.

**Large pulls:** If pull contains many commits (>20), group commits by feature/area in the explanation.

**Binary files:** Note binary file changes but don't attempt to explain content changes.

## File naming convention

Always use: `git-explain-YYYY-MM-DD.md`

If multiple pulls happen on the same day, append letters:
- `git-explain-YYYY-MM-DD-a.md`
- `git-explain-YYYY-MM-DD-b.md`
- etc.

## Content guidelines

- Focus on impact and intent, not just what changed.
- Include actionable next steps.
- Note any breaking changes prominently.
- Reference related files or documentation when helpful.

## Edge cases

**Repo not writable:** Output the markdown content directly to user with instructions to save manually.

**No git history:** If repo is new or has no history, note this and explain the initial state.

**Large diffs:** If diff is very large, focus on high-level summary and most important changes.

**Sensitive files:** If changes involve sensitive files (keys, passwords), note the file change but redact content details.

## Example output

For a pull with 3 commits adding a new feature:

```markdown
# Git Changes Explanation
**Date:** 2026-02-18  
**Pull Range:** HEAD~3..HEAD  
**New Commits:** 3

## Summary
Added user authentication feature with login/logout endpoints and database schema updates.

## New Commits
- a1b2c3d feat: add user login endpoint
- d4e5f6g feat: implement user logout
- h7i8j9k feat: update database schema for users

## File Changes
### Added
- `src/auth/login.py` (new authentication module)
- `src/auth/logout.py` (logout functionality)
- `migrations/001_add_users.sql` (database schema)

### Modified
- `src/main.py` (added auth routes)
- `requirements.txt` (added Flask-Login dependency)

## Impact Analysis
### New Features
- User authentication system now available
- Login/logout endpoints at `/auth/login` and `/auth/logout`

### Configuration Changes
- New database migration required
- New dependency: Flask-Login

## Next Actions
- [ ] Run database migration
- [ ] Update API documentation
- [ ] Test login/logout flow
- [ ] Review security implications

## Notes
- Requires database migration before deployment
- Session management uses Flask-Login defaults
```

## Reporting format

After creating the explanation file, report:
- `Created:` path to explanation file
- `Summary:` brief overview of what changed
- `Commits:` number and type of changes
- `Impact:` high-level impact assessment

Do not dump the full file contents unless explicitly requested.
