# /sync-rules — Sync Claude Rules to AI Reviewer

Copy shared rules from `.claude/rules/` (source of truth) to `github-org/ai-rules/rules/shared/` (AI reviewer consumes these). Commit and push.

ARGUMENTS:

## Instructions

### 1. Define the sync list (ONLY these files — nothing else)

```python
SYNC_FILES = [
    "security.md",
    "multi-tenancy.md",
    "data-privacy.md",
    "code-quality.md",
    "styling.md",
    "git.md",
    "language.md",
    "data-ref.md",
    "issue-workflow.md",
]
```

**NEVER sync these files — they are Bernard-only rules for interactive Claude Code sessions, NOT for the AI reviewer:**
- `agent-orchestration.md`
- `session-discipline.md`
- `team-dynamics.md`

**Why these are excluded:** They contain personal workflow rules ("Claude proposes ending sessions", "Bernard's communication tone") that pollute the GPT reviewer prompt with irrelevant context. On 2026-03-28, they accidentally leaked into shared/ and added ~5KB of noise to every review prompt.

### 2. Safety check — verify no excluded files exist in shared/

Before syncing, check that excluded files have not leaked into shared/:

```bash
for file in agent-orchestration.md session-discipline.md team-dynamics.md; do
  if [ -f "github-org/ai-rules/rules/shared/$file" ]; then
    echo "WARNING: $file found in shared/ — DELETING (should not be here)"
    rm "github-org/ai-rules/rules/shared/$file"
  fi
done
```

If any were found and deleted, include them in the commit.

### 3. Diff before copying

For each file in `SYNC_FILES`, run:
```bash
diff .claude/rules/<file> github-org/ai-rules/rules/shared/<file>
```

Report a table:

| File | Status |
|------|--------|
| security.md | Changed (15 lines differ) |
| multi-tenancy.md | Identical |
| ... | ... |

If ALL files are identical and no excluded files were found, report "Everything in sync" and stop.

### 4. Copy changed files

```bash
cp .claude/rules/<changed-file> github-org/ai-rules/rules/shared/<changed-file>
```

Only copy files that actually differ. Never touch identical files.

**Special handling for security.md:** Strip the `## Local Secrets Map` section before copying — secrets are local-only and must never reach the shared repo.

```bash
sed '/## Local Secrets Map/,/## Never/{/## Never/!d}' .claude/rules/security.md > github-org/ai-rules/rules/shared/security.md
```

### 5. Commit and push

```bash
cd github-org
git add ai-rules/rules/shared/
git commit -m "chore: sync shared rules from .claude/rules/"
git push origin main
```

### 6. Report

```
Synced N files to github-org/ai-rules/rules/shared/
Changed: security.md, code-quality.md
Unchanged: 7 files
Excluded files cleaned: 0 (or list any that were found and deleted)
Commit: <hash>
```

## Rules

- `SYNC_FILES` is the ONLY allowlist — if a file is not in the list, it does NOT get synced
- `.claude/rules/` is ALWAYS the source of truth — never copy the other direction
- **Never sync files not in SYNC_FILES** — even if they exist in both locations
- Never modify the source files — this is a one-way copy
- Always diff before copying — don't blindly overwrite identical files
- Always commit+push after copying — local-only changes are invisible to the AI reviewer
- Always run the safety check first — catch leaks before they pollute the reviewer prompt
- Strip secrets from security.md before copying
