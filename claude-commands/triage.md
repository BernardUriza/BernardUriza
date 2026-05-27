---
description: Source-to-Plane issue creator with codebase context (Sentry/GitHub/manual)
argument-hint: [sentry [project] [-Nh] | github <repo> | "error description"]
model: opus
allowed-tools: Read, Bash, Grep, Glob, AskUserQuestion, WebFetch
disable-model-invocation: true
---

# /triage — Source-to-Plane Issue Creator with Codebase Context

ARGUMENTS: $ARGUMENTS

## Purpose

Pull errors from a source (Sentry, manual description, or GitHub), analyze the codebase to understand the root cause, and create idempotent **Plane** issues with code-digested descriptions ready for a developer to pick up.

> **Tracker note**: Plane replaced Linear in April 2026 (per `~/.claude/rules/plane.md`). This command writes to Plane via the cloud API. There is no MCP server for Plane — all calls go through `curl` with `$PLANE_PAT` from `~/.secrets/plane_pat.txt`.

---

## Plane Workspace Reference

| Field | Value |
|---|---|
| Workspace slug | `visalaw-ai` |
| Project ID | `28e52ace-f4e7-44d5-83b0-1b8569eac82b` |
| Project identifier | `VISAL` (ticket prefix, e.g. `VISAL-676`) |
| API base | `https://api.plane.so/api/v1/` |
| Auth header | `X-API-Key: $PLANE_PAT` |
| UI URL | `https://app.plane.so/visalaw-ai/browse/VISAL-<n>/` |

Bootstrap in every shell call:
```bash
PLANE_PAT=$(cat ~/.secrets/plane_pat.txt)
PROJECT_ID="28e52ace-f4e7-44d5-83b0-1b8569eac82b"
API_BASE="https://api.plane.so/api/v1/workspaces/visalaw-ai/projects/$PROJECT_ID"
```

---

## Source Adapters

Parse `$ARGUMENTS` to determine the source and scope:

| Argument pattern | Source | Behavior |
|------------------|--------|----------|
| `sentry` | Sentry — all projects | Pull unresolved issues from all Sentry projects (`core-20`, `visalaw-gen-backend`, `drafts`, `node-nestjs`) |
| `sentry core-20` | Sentry — specific project | Pull unresolved issues from `core-20` only |
| `sentry -24h` | Sentry — time-scoped | Pull issues first seen in last 24h |
| `sentry CORE-20-7` | Sentry — single issue | Triage one specific Sentry issue |
| `github frontend-core-2.0` | GitHub Issues | Pull open issues from the specified repo |
| `"error description here"` | Manual | User describes the error — Claude finds it in code and creates the issue |

**Default** (no args): `sentry` — all projects, unresolved, sorted by frequency.

---

## Execution Flow

### Phase 1: Ingest Errors

**For Sentry source:**
```
1. mcp__sentry__list_issues(organizationSlug='visalawai', projectSlugOrId=<project>, query='is:unresolved', sort='freq', limit=20)
2. For each issue, extract: title, culprit, event count, first/last seen, level
3. Group by project (frontend vs backend)
```

**For manual source:**
```
1. Parse the error description from $ARGUMENTS
2. Grep the codebase for related keywords, function names, error messages
3. Build an error profile: affected file(s), error type, likely cause
```

### Phase 2: Deduplicate Against Plane (MANDATORY — idempotency)

Before creating ANY issue, search Plane for existing matches:

```bash
# Search by title keywords
curl -s -H "X-API-Key: $PLANE_PAT" \
  "$API_BASE/issues/?search=<error-keywords-url-encoded>"

# Also search by Sentry issue ID if present
curl -s -H "X-API-Key: $PLANE_PAT" \
  "$API_BASE/issues/?search=CORE-20-7"
```

For each error:
1. Run both searches above.
2. If a match exists (same error signature in `name` or `description_html`):
   - SKIP creation.
   - Mark as `[EXISTING] VISAL-XXX` in the summary table.
   - If the existing issue is in a closed state but the error is still firing → reopen via `PATCH .../issues/<id>/` setting `state` back to a non-closed status.
3. Only proceed to Phase 3 for genuinely new errors.

**Idempotency rule**: Running `/triage sentry` twice in a row MUST produce zero new issues the second time. The dedup check is non-negotiable.

### Phase 3: Codebase Analysis (the differentiator)

For each new error, analyze the codebase to pre-digest the fix:

```
1. From the Sentry culprit/stack trace, identify the source file(s)
   - Frontend: map route paths to `src/app/` files
   - Backend: map module paths to `src/` NestJS files

2. Read the relevant file(s) — find the exact function/line where the error originates

3. Trace the error chain:
   - What calls this function?
   - What data does it expect vs what it received?
   - Is there a missing null check, type mismatch, or race condition?

4. Identify the fix approach:
   - SIMPLE: "Add null guard at line X" / "Fix import path"
   - MODERATE: "Refactor function to handle edge case Y"
   - COMPLEX: "Architecture issue — needs design discussion"

5. Find related files that may need changes (tests, types, shared utils)
```

### Phase 4: Create Plane Issues

For each new error, POST to Plane with this structure:

**Title** (`name` field, max 255 chars): `[<domain>] <concise error description>`
- Domain auto-detected from file paths: `chat`, `drafts`, `upload`, `auth`, `projects`, `infra`
- Bracket prefix gives reviewers an immediate scope cue (per `~/.claude/rules/plane.md`).

**Description** (`description_html` field):

> ⚠️ **WHITESPACE TRAP**: Plane's `description_html` MUST be a single line with zero whitespace between block tags. Newlines between `<p>`, `<ul>`, `<li>` create phantom empty paragraphs. Build the HTML by concatenating strings, not joining with `\n`. See `~/.claude/rules/plane.md` "CRITICAL — `description_html` Whitespace Trap".

Template (rendered to single-line HTML before sending):

```html
<h2>Error</h2><p><strong>Source</strong>: <a href="https://visalawai.sentry.io/issues/CORE-20-X">Sentry CORE-20-X</a> | Manual report</p><p><strong>Severity</strong>: P0/P1/P2/P3 — <strong>Events</strong>: N events, M users — <strong>First seen</strong>: YYYY-MM-DD — <strong>Last seen</strong>: YYYY-MM-DD</p><h2>Root Cause</h2><p>1-3 sentences explaining WHY this error happens, traced from the code.</p><p><strong>File</strong>: <code>src/path/to/file.ts:LINE</code> — <strong>Function</strong>: <code>functionName()</code> — <strong>Trigger</strong>: what user action or system event causes this</p><h2>Suggested Fix</h2><pre><code>// Current (broken):
[relevant code snippet showing the bug]

// Proposed:
[code snippet showing the fix approach]</code></pre><p><strong>Complexity</strong>: Simple | Moderate | Complex</p><h2>Files to touch</h2><ul><li><code>src/path/to/file.ts</code> — what to change</li><li><code>src/path/to/related.ts</code> — if applicable</li></ul><h2>Verification</h2><ul><li>Error no longer appears in Sentry after deploy</li><li>Specific test case based on the error trigger</li></ul>
```

**POST request:**
```bash
curl -s -X POST -H "X-API-Key: $PLANE_PAT" -H "Content-Type: application/json" \
  "$API_BASE/issues/" \
  -d '{
    "name": "[chat] ChatSSEProvider undefined on first render",
    "description_html": "<h2>Error</h2><p>...</p>...",
    "priority": "high"
  }'
```

**Auto-assigned fields:**

| Field | Logic |
|-------|-------|
| **`priority`** | Events > 50 OR P0 pattern → `urgent`. Events > 10 → `high`. Events > 3 → `medium`. Else → `low`. (Plane uses string enum, not 1-4 integers.) |
| **Assignee** | Leave unassigned — let the team self-assign. |
| **State** | Defaults to `Backlog`. Use `Todo` for `urgent`. |

**Sentry link attachment** — Plane doesn't have a "link" field on issue create. Embed the Sentry URL inline in `description_html` instead (already in template above).

### Phase 4.5: Visual verification (MANDATORY per Plane rules)

Per `~/.claude/rules/plane.md` "Mandatory Visual Verification After Every Write": after every POST/PATCH, navigate to `https://app.plane.so/visalaw-ai/browse/VISAL-<n>/` in Chrome DevTools and:

1. Take a screenshot of the collapsed view.
2. Click "Show all" if present.
3. Take a second screenshot of the expanded view.
4. Verify visually: no phantom empty bullets, no extra spacing between paragraphs, code blocks render.

API success (`200` + non-empty `description_html` on `GET`) does NOT prove the ticket reads correctly. If render is broken, `PATCH` the same issue ID with whitespace-free HTML — never delete and recreate (sequence IDs are non-reusable).

### Phase 5: Summary Report

After all issues are processed, output a single summary table:

```
## Triage Summary — [source] — [date]

| # | Status   | VISAL-ID  | Title                                  | Priority | Sentry      |
|---|----------|-----------|----------------------------------------|----------|-------------|
| 1 | NEW      | VISAL-680 | [chat] ChatSSEProvider undefined       | high     | CORE-20-5   |
| 2 | NEW      | VISAL-681 | [auth] middleware timeout fallback     | medium   | CORE-20-6   |
| 3 | EXISTING | VISAL-135 | (already tracked)                      | —        | CORE-20-1   |
| 4 | SKIPPED  | —         | EPIPE broken pipe (noise)              | —        | CORE-20-2   |

Created: 2 new issues
Skipped: 1 existing, 1 noise
Total Sentry unresolved: 7
```

---

## Smart Filtering — What NOT to Create Issues For

Skip these patterns (mark as SKIPPED with reason):

| Pattern | Reason |
|---------|--------|
| `EPIPE: broken pipe` with < 10 events | Normal SSE disconnection noise |
| `Missing Supabase env vars` on preview deploys only | Preview env not configured — not a bug |
| `ChunkLoadError` with < 5 events | User cache issue, self-resolving |
| Errors only in `development` environment | Dev-only, not production |
| Errors last seen > 30 days ago | Stale — likely already fixed |

If unsure whether to skip, **create the issue anyway** with `low` priority. False positives are cheaper than missed bugs.

---

## Priority Mapping — Sentry to Plane

| Sentry Signal | Plane Priority | Rationale |
|---------------|----------------|-----------|
| `level: fatal` or `level: error` + auth/data flow | `urgent` | Users blocked or data at risk |
| `level: error` + > 50 events in 24h | `urgent` | High volume = many users affected |
| `level: error` + > 10 events | `high` | Significant but not critical |
| `level: error` + < 10 events | `medium` | Isolated or infrequent |
| `level: warning` | `low` | Degraded but functional |
| `level: info` | Skip | Not an error |

---

## Domain Detection — File Path to Bracket Prefix

| File path pattern | Bracket prefix |
|-------------------|----------------|
| `src/app/dashboard/*/chats/*`, `src/core/hooks/useChat*` | `[chat]` |
| `src/app/dashboard/*/drafts/*`, `src/core/hooks/useDraft*` | `[drafts]` |
| `src/app/dashboard/*/projects/*` | `[projects]` |
| `src/app/auth/*`, `src/middleware.ts`, `*supabase*` | `[auth]` |
| `*upload*`, `*support-document*`, `*presign*` | `[upload]` |
| `src/chat/*`, `*retriev*`, `*pinecone*` (backend) | `[chat]` |
| `src/drafts/*` (backend) | `[drafts]` |
| Everything else | `[infra]` |

---

## Rules

1. **Idempotent or nothing** — NEVER create a duplicate Plane issue. Search first, create second. This is the #1 rule.
2. **Code context is mandatory** — every issue description MUST include the specific file, function, and a suggested fix. A Plane issue that says "fix this error" without code context is useless. Read the code BEFORE writing the description.
3. **One error = one issue** — don't bundle multiple Sentry errors into one Plane issue unless they share the exact same root cause in the exact same function.
4. **Sentry link inline** — every issue created from Sentry MUST have the Sentry URL embedded in `description_html`. Plane doesn't support attached links on create.
5. **No PII in descriptions** — use `orgId`, `caseId`, `userId` — never real names, emails, or A-numbers. Even if Sentry shows PII (it shouldn't), strip it before writing to Plane.
6. **English only** — all issue titles and descriptions in English (per `~/.claude/rules/language.md`).
7. **Don't assign** — leave issues unassigned for team self-assignment. If the error is clearly in a domain owned by one person (e.g., integrations → Rohan), note it in the description but still don't assign.
8. **Be brief** — the description should be scannable in 30 seconds. Lead with the fix, not the archaeology. A dev should read it and know exactly what file to open and what to change.
9. **Sentry is read-only** — the MCP token (`sntryu_*`) has read-only scope. NEVER attempt `mcp__sentry__update_issue`. All issue lifecycle management happens in Plane.
10. **`description_html` whitespace-free** — single-line HTML, zero whitespace between block tags. Concatenate, don't join with `\n`.
11. **Mandatory visual verification** — open the created ticket UI in Chrome after every POST/PATCH (Phase 4.5). API 200 ≠ ticket renders correctly.
12. **`PATCH` to fix render bugs, never delete-and-recreate** — sequence IDs are non-reusable. Burning `VISAL-N` because of an HTML mistake is permanent waste.

---

## Examples

**Input**: `/triage sentry core-20`
**Output**: Pulls 7 unresolved issues from core-20, deduplicates against Plane, creates 4 new issues (skips 2 noise + 1 existing), outputs summary table, screenshots each new ticket UI.

**Input**: `/triage sentry CORE-20-5`
**Output**: Gets details on CORE-20-5 (ChatSSEProvider undefined), reads `src/app/dashboard/[organization]/chats/[chatId]/page.tsx`, identifies missing dynamic import, creates `VISAL-XXX` with exact fix code embedded as `<pre><code>` in `description_html`.

**Input**: `/triage "users report chat is not loading after login"`
**Output**: Greps codebase for auth → chat flow, identifies likely race condition in session hydration, creates `VISAL-XXX` with file paths and fix approach.

**Input**: `/triage sentry -24h`
**Output**: Only processes errors first seen in the last 24 hours. Fast daily triage.
