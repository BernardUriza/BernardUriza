---
description: Restore saved context after restarting Claude Code
argument-hint: ""
allowed-tools: Read(*), Bash(*), mcp__atlassian__*, mcp__chrome-devtools__*, Glob(*), Grep(*)
---

# Resume Context - Pick Up Where We Left Off

## Your Mission

Claude Code just restarted. Read the saved context and get back to work as if nothing happened.

---

## Steps

### 1. Read Saved Context
```
Read .claude/SESSION_STATE.md
```

If the file doesn't exist, tell the user there's no saved context and ask what they want to work on.

### 2. Verify State

For each active ticket mentioned:
- Verify the branch exists and is checked out
- Verify uncommitted changes match what was saved
- Verify any PRs mentioned are still open

```bash
cd core/frontend-core-2.0
git branch --show-current
git status --short
```

### 3. Report Back

Tell the user:
- What session you're resuming
- What tickets are active
- What the next step is
- Any discrepancies between saved state and current state

### 4. Continue Working

Pick up from the "To Resume" section and continue the work.

---

## Important

- Don't ask unnecessary questions - the context file has everything
- If state has changed (someone else committed, PR merged, etc.), adapt
- Maintain the same communication style as before
- If SESSION_STATE.md references pending handoffs, prepare them

ARGUMENTS: $ARGUMENTS
