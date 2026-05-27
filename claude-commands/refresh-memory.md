# /refresh-memory — Pre-Flight Rule Refresh

## Purpose

Force Claude to read and restate the rules it violates most often BEFORE starting any task.
Rules in CLAUDE.md files get ignored under cognitive load. Rules fresh in conversation context don't.
This is the antidote to silent degradation.

## When to Use

- At the START of any work session
- Before any UI interaction (Chrome DevTools)
- Before any git operation (push, PR, merge)
- When Bernard suspects Claude is cutting corners
- After switching between tasks (context switch = rule amnesia)

## Instructions

### Step 1: Read the Rules Files

Read ALL files in `.claude/rules/` (project) and `~/.claude/rules/` (global). Do NOT skip any.

### Step 2: Extract and Restate the Top 12

From the rules files, extract the 12 rules most relevant to the CURRENT task context. Present them as a numbered checklist with the **source file** and **incident that created the rule**.

Format each rule as:
```
N. **[SHORT TITLE]** — [one-sentence rule]
   Source: [filename] | Incident: [date + what happened]
```

### Step 3: Identify Task-Specific Risks

Based on what the user is about to do, list 3-5 specific ways Claude could violate these rules during THIS task. Be concrete:
- "I might skip reading PromptsDrawer.tsx before clicking Skills in Chrome"
- "I might push without running tsc first"
- NOT vague like "I might make mistakes"

### Step 4: Commit Out Loud

End with: "I've read these rules. If I violate any of them, call me out immediately."

---

## The Permanent Top 12 (always include these)

These are the rules Claude violates most often, derived from real incidents:

1. **READ CODE FIRST** — Read the source code before interacting with UI, before testing, before changing anything.
   Source: dev-environment.md | Incident: 2026-04-07 — Tried to click Skills drawer without reading DashboardHome.tsx, didn't see the duplicate PromptsDrawer rendering.

2. **SCREENSHOT BEFORE SNAPSHOT** — Take a visual screenshot first to see what's real. Use a11y snapshot only AFTER confirming what's on screen.
   Source: dev-environment.md | Incident: 2026-04-07 — Trusted a11y snapshot showing 2 Skills dialogs, clicked blindly, wasted 10 minutes.

3. **DIAGNOSE BEFORE RETRYING** — When something fails, stop and ask WHY. Never repeat the same failed action with a different UID/parameter.
   Source: session-discipline.md | Incident: 2026-04-07 — Click timed out, tried another UID, timed out again. Zero diagnosis.

4. **VERIFY BRANCH BEFORE EVERY EDIT** — Run `git branch --show-current` before the first Edit/Write in any repo.
   Source: git-safety.md | Incident: 2026-04-07 — Spent 20 min editing PromptsDrawer.tsx on wrong branch.

5. **CURL BEFORE PUSH (BACKEND)** — Every backend change must be tested with curl locally before push. No exceptions.
   Source: session-discipline.md | Incident: 2026-04-06 — Pushed /config endpoint without curl, response interceptor stripped data. Required second PR.

6. **TEAM-VISIBLE ACTIONS NEED PERMISSION** — Before any gh pr comment, review request, workflow trigger: tell Bernard what you're about to do and wait for "dale".
   Source: team-dynamics.md | Incident: 2026-03-30 — Spammed Katie's PR with 6+ /ai-review comments.

7. **NEVER MERGE/CLOSE/DELETE WITHOUT EXPLICIT INSTRUCTION** — Approval ≠ instruction to merge. "Both" ≠ merge. Only "merge it" means merge.
   Source: git.md | Incident: 2026-03-30 — Merged PR #262 as side effect of "resolve threads".

8. **READ THE SCREENSHOT AFTER TAKING IT** — Use the Read tool on the image file to verify what was actually captured before uploading.
   Source: agent-orchestration.md | Incident: 2026-04-07 — Sent 3 "different" screenshots that were identical.

9. **TEST LIKE A HUMAN** — Click the button, see the result, screenshot. No evaluate_script hacks, no DOM manipulation, no z-index boosting.
   Source: dev-environment.md | Incident: 2026-04-07 — Spent 30 min hacking Skills drawer DOM instead of one click.

10. **LIST_PAGES BEFORE EVERY INTERACTION** — Verify which Chrome tab is selected before clicking/typing anything.
    Source: agent-orchestration.md | Incident: multiple — Interacted with wrong tab, blamed "page changed".

11. **NEVER CELEBRATE BEFORE E2E VERIFICATION** — "It works" requires a screenshot proving it works. Not "tsc clean", not "build passed".
    Source: session-discipline.md | Incident: 2026-03-30 — Celebrated rules condensation as "working" across 8 CI runs while Job Summary showed it was broken.

12. **SEARCH BEFORE CLAIMING "DOESN'T EXIST"** — grep the codebase before saying there's no endpoint, no key, no feature.
    Source: session-discipline.md | Incident: 2026-04-02 — Said "no version control for prompts" when PromptsLibraryController had full CRUD.

## Rules

- This command produces OUTPUT ONLY — it never modifies files, runs git commands, or takes actions
- The 12 rules are the MINIMUM — add more if the task context demands it
- Each rule must cite its source file and the incident that created it
- The task-specific risks must be CONCRETE, not vague
- If Claude cannot identify task-specific risks, it means Claude doesn't understand the task yet — ask before proceeding
- This command should take < 30 seconds to execute — it's a checklist, not an essay
