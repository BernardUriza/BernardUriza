---
description: Save session context before restarting Claude Code (for MCP disconnects)
argument-hint: "[optional description of where we left off]"
allowed-tools: Read(*), Bash(*), Write(*), Edit(*), Glob(*), Grep(*)
---
# Save Context - Session State Preservation

## Your Mission

Claude Code is about to restart (MCP disconnect, context limit, whatever). Your job: capture EVERYTHING about the current session so the next instance can pick up seamlessly.

**Output file:** `.claude/SESSION_STATE.md`

---

## What to Capture

### 1. Active Tickets
For each ticket being worked on:
- Ticket number (e.g., PP-440)
- Branch name in each repo
- Current status (coding, testing, PR review, waiting for merge)
- PR URL if exists

### 2. Branch State
```bash
# Run these commands to get current state
cd core/frontend-core-2.0
git branch --show-current
git status --short
git log --oneline -5
```

### 3. What Was Being Done
- What was the last task/action being performed?
- What was the user's last request?
- Were there any pending handoffs?

### 4. Uncommitted Changes
- List all modified files (git status)
- Brief description of what each change does
- Whether mock data was temporarily modified (RESTORE IT FIRST!)

### 5. Pending Actions
- Things that still need to happen
- PRs waiting to be created
- Reviews to respond to
- Dependencies between tickets

### 6. Key Context
- Important decisions made during the session
- Code review feedback received
- Teammate comments/requests
- Any gotchas or issues discovered

---

## Output Format

Write EVERYTHING to `.claude/SESSION_STATE.md` using this structure:

```markdown
# SESSION STATE - [Date]

## Quick Summary
[2-3 sentences of what was happening]

## Active Tickets

### [TICKET-NUMBER] - [Title]
- **Branch:** `branch-name`
- **Repo:** core/frontend-core-2.0
- **Status:** [coding|testing|PR review|waiting]
- **PR:** [URL or "pending"]
- **Last change:** [what was last modified]
- **Next step:** [what needs to happen next]

## Uncommitted Changes
[list of uncommitted files and what they do]

## Pending Handoffs
[any handoff prompts that need attention]

## Important Context
[decisions, feedback, gotchas]

## To Resume
[exact instructions for the next Claude instance to continue]
```

---

## Execution Steps

1. **Read git state** from all active repos
2. **Check for temp modifications** (mock data, test files) - RESTORE if found
3. **Gather context** from conversation
4. **Write `.claude/SESSION_STATE.md`** with full state
5. **Confirm to user** that context is saved

If ARGUMENTS are provided, include them as additional context in the "Quick Summary" section.

ARGUMENTS: $ARGUMENTS
