# /merge-policeman — PR Review Queue Scanner & Batch Closer

ARGUMENTS: $ARGUMENTS

## Mission

**The goal is CLOSURE, not reviews.** A review is a means; the end state of every PR this command touches is one of: MERGED, remedy dispatched, author pinged on blocking findings, or explicitly deferred by Bernard. A session that only stacks another review on a PR that already had one is a FAILED session.

> Anchor 2026-07-13: `visalaw-gen-backend#1544` accumulated 14 of Bernard's reviews over a month and stayed open; `visalaw-gen-standalone-services#303/#304` were each APPROVED twice (07-07 and again 07-11) and never merged. The command produced reviews forever and closed nothing. Phase 2 step 0.5 and Phase 3.5 exist to kill exactly that.

Every PR that enters Phase 2 must exit with a **next-action**, never with just a verdict.

## Instructions

### Phase 1: Discovery — Find All PRs Requesting Your Review

1. **Query all Visalaw repos** for PRs where the current user is a requested reviewer:
   ```bash
   gh search prs --review-requested=@me --state=open --owner=Visalaw --json number,title,repository,author,createdAt,url,labels
   ```

2. **Separate into three categories:**
   - **Human PRs** — from real teammates. These get full review.
   - **VAIR PRs** — from `vair-visalaw-ai-reviewer[bot]`. These are AI-authored work YOU dispatched and need full review (same treatment as human PRs, NOT summary).
   - **Dependabot/Actions PRs** — from `dependabot[bot]` or `github-actions[bot]`. These get a quick summary only.

3. **Liveness + review status check** — for each human PR, fetch state + mergeStateStatus + reviews in ONE call. NEVER trust the `gh search` snapshot — PRs close/merge between queries.
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json state,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup --jq '{state, draft: .isDraft, mergeable, mergeStateStatus, approvals: [.reviews[] | select(.state == "APPROVED")] | length, checks_pass: ([.statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != null and .conclusion != "SKIPPED" and .conclusion != "NEUTRAL")] | length == 0)}'
   ```
   - **If `state != "OPEN"`** → PR is CLOSED or MERGED since discovery. **Discard it immediately.** Collect these in a "dead PRs" bucket for the summary note.
   - **If `state == "OPEN"` AND ≥1 approval AND all checks pass** → do NOT re-review it and do NOT silently discard it. Move it to the **Ready-to-merge queue** (Phase 3.5) — an approved PR left rotting is the #303/#304 failure mode.
   - Show routed/discarded PRs in two separate notes:
     - `☠️ Skipped N PRs (closed/merged since discovery): #X (CLOSED), #Y (MERGED)`
     - `✅ Moved N PRs to the Ready-to-merge queue (approved + checks passing): #X, #Y`

4. **Query ALL open human PRs across Visalaw repos (team awareness):**
   ```bash
   gh search prs --state=open --owner=Visalaw --json number,title,repository,author,createdAt,url,labels -- -author:app/dependabot -author:app/github-actions
   ```
   - Remove PRs already in the "need your review" list and your own PRs
   - For each remaining PR, get state + review status in ONE call:
     ```bash
     gh pr view <N> --repo Visalaw/<repo> --json state,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup,reviewRequests --jq '{state, draft: .isDraft, mergeable, mergeStateStatus, approvals: [.reviews[] | select(.state == "APPROVED")] | length, changes_requested: [.reviews[] | select(.state == "CHANGES_REQUESTED")] | length, pending_reviewers: [.reviewRequests[].login] | join(", "), checks_pass: ([.statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != null and .conclusion != "SKIPPED" and .conclusion != "NEUTRAL")] | length == 0)}'
     ```
   - **Drop any PR where `state != "OPEN"`** — closed/merged PRs do not belong in any team-awareness table.

5. **Query the user's own PRs awaiting review from others:**
   ```bash
   gh search prs --author=@me --state=open --owner=Visalaw --json number,title,repository,createdAt,url,labels
   ```
   For each, get state + review + check status in ONE call:
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json state,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup,reviewRequests --jq '{state, draft: .isDraft, mergeable, mergeStateStatus, approvals: [.reviews[] | select(.state == "APPROVED")] | length, changes_requested: [.reviews[] | select(.state == "CHANGES_REQUESTED")] | length, pending_reviewers: [.reviewRequests[].login] | join(", "), checks_pass: ([.statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != null and .conclusion != "SKIPPED" and .conclusion != "NEUTRAL")] | length == 0)}'
   ```
   - **Drop any PR where `state != "OPEN"`** — your own closed/merged PRs are done, don't waste table space on them.

5b. **Query VAIR-authored PRs (AI-dispatched work in your queue):**
   ```bash
   gh search prs --author=app/vair-visalaw-ai-reviewer --state=open --owner=Visalaw --json number,title,repository,createdAt,url,labels
   ```
   For each, get the same state + review + check snapshot used for human PRs:
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json state,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup,reviewRequests --jq '{state, draft: .isDraft, mergeable, mergeStateStatus, approvals: [.reviews[] | select(.state == "APPROVED")] | length, changes_requested: [.reviews[] | select(.state == "CHANGES_REQUESTED")] | length, pending_reviewers: [.reviewRequests[].login] | join(", "), checks_pass: ([.statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != null and .conclusion != "SKIPPED" and .conclusion != "NEUTRAL")] | length == 0)}'
   ```
   - **Drop any PR where `state != "OPEN"`** — closed/merged VAIR PRs do not belong in the table.
   - VAIR PRs flow through the SAME Phase 2 full review as human PRs (codex peer, full diff read, inline comments). The "Bot PRs" summary path is for dependabot/github-actions only.

6. **Display summary tables** sorted by repo, then by age (oldest first). **EXCEPTION: the VAIR PRs table is sorted DRAFT-first** (drafts are AI-dispatched work-in-progress that needs Bernard's triage before anything else — they are the highest priority in the queue), then by age within each group. EVERY table includes a **Merge** column so dead/blocked PRs are visible at a glance — no more "limpio" claims about a CLOSED PR:

   ```
   ## Human PRs (need your review)
   | # | Repo | PR | Author | Title | Merge | Age |
   |---|------|-----|--------|-------|-------|-----|

   ## Human PRs (don't need your review)
   | # | Repo | PR | Author | Title | Review | Merge | Age |
   |---|------|-----|--------|-------|--------|-------|-----|
   Review values: ✅ Approved | 🔄 Changes Requested | ⏳ Pending Review | 📝 Draft

   ## Your PRs (waiting on others)
   | # | Repo | PR | Title | Review | Merge | Pending Reviewers | Age |
   |---|------|-----|-------|--------|-------|-------------------|-----|
   Review values: ✅ Approved | 🔄 Changes Requested | ⏳ Pending Review | 📝 Draft

   ## VAIR PRs (AI-authored, your triage — full review) — DRAFTS FIRST
   | # | Repo | PR | Title | Review | Merge | Age |
   |---|------|-----|-------|--------|-------|-----|
   Review values: 📝 Draft (LIST FIRST — top priority) | ✅ Approved | 🔄 Changes Requested | ⏳ Pending Review
   Sort order: drafts (`isDraft: true`) at the top sorted by age, then non-drafts sorted by age.

   ## Bot PRs (Dependabot / github-actions — summary only)
   | # | Repo | PR | Title | Merge | Age |
   |---|------|-----|-------|-------|-----|
   ```

   **Merge column encoding (based on `mergeStateStatus` + `mergeable`):**
   | Value | Emoji | Meaning |
   |-------|-------|---------|
   | `CLEAN` | ✅ CLEAN | Ready to merge |
   | `BLOCKED` | 🚧 BLOCKED | Branch protection (required reviewer/check) |
   | `BEHIND` | ⏪ BEHIND | Base branch advanced, needs update |
   | `DIRTY` | 💥 CONFLICTS | Merge conflicts |
   | `UNSTABLE` | ⚠️ UNSTABLE | Non-required checks failing |
   | `UNKNOWN` | ⏳ UNKNOWN | GitHub still computing — re-query before acting |
   | `HAS_HOOKS` | 🪝 HOOKS | Clean but has hooks pending |
   | `mergeable=CONFLICTING` | 💥 CONFLICTS | Fallback when mergeStateStatus is unreliable |

   **Above the tables**, always print the dead-PR note from step 3 (if any): `☠️ Discovery→now drift: N PRs closed/merged. Excluded: #X (CLOSED), #Y (MERGED).`

7. **If ARGUMENTS is provided**, filter the tables to only show PRs matching the argument (repo name, author, PR number, or keyword in title).

8. **Ask the user which PRs to review — with the native `AskUserQuestion` tool, never a free-text question.** Options: all human PRs in batch / only VAIR PRs / specific numbers from the table / skip straight to closure routing (Phase 3.5) when the queues are dominated by already-reviewed PRs.

### Phase 2: Batch Review — Read and Analyze Each PR

For each PR selected for review, in order:

0. **LIVENESS RE-CHECK (MANDATORY — NEVER SKIP).** Phase 1 data is stale the moment it's printed. PRs close/merge between Phase 1 and Phase 2. Before reading the diff, re-query state:
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json state,mergeStateStatus,updatedAt --jq '{state, mergeStateStatus, updatedAt}'
   ```
   - If `state != "OPEN"` → **SKIP this PR.** Print: `⏭️ PR #N is now <STATE> — skipping review (was OPEN in Phase 1, changed since).`
   - If `mergeStateStatus == "UNKNOWN"` → GitHub has not finished computing. Either wait 5-10s and retry, or proceed with a warning note in the verdict: `⚠️ mergeStateStatus=UNKNOWN at analysis time — re-verify before merge.`
   - Only proceed with steps 1-6 if `state == "OPEN"`.

0.5. **PRIOR-REVIEW MEMORY CHECK (MANDATORY — kills the infinite-review loop).** Before reading the diff, check whether YOU already reviewed this PR and whether anything changed since:
   ```bash
   gh api repos/Visalaw/<repo>/pulls/<N>/reviews --jq '[.[] | select(.user.login == "bernarduriza-visalaw")] | last | {state, commit_id, submitted_at}'
   gh pr view <N> --repo Visalaw/<repo> --json headRefOid --jq .headRefOid
   ```
   - **No prior review** → proceed with the full review (steps 1–6).
   - **Prior review exists AND `commit_id == headRefOid`** (head unchanged since your last review) → **DO NOT RE-REVIEW.** The findings already exist; producing them again is waste. Route directly by the last verdict:
     - `APPROVED` → Ready-to-merge queue (Phase 3.5).
     - `CHANGES_REQUESTED` / `COMMENTED` → Remedy/ping queue (Phase 3.5).
     - Print: `♻️ PR #N already reviewed (<STATE> at <date>, head unchanged) — routing to closure, not re-reviewing.`
   - **Prior review exists AND head moved** → review the DELTA, not the world: `gh api repos/Visalaw/<repo>/compare/<commit_id>...<headRefOid>` for the new commits; the full diff is context only. The verdict block must say `delta review since <short-sha>`.

1. **Read the PR diff:**
   ```bash
   gh pr diff <N> --repo Visalaw/<repo>
   ```

2. **Read PR description and existing comments:**
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json body,comments,reviews,labels,additions,deletions,changedFiles
   ```

3. **Read any AI review comments already posted:**
   ```bash
   gh api repos/Visalaw/<repo>/pulls/<N>/comments --jq '.[] | select(.user.login == "github-actions[bot]" or .user.login == "vair-visalaw-ai-reviewer[bot]") | {path, line, body}' 2>/dev/null | head -50
   ```

4. **Analyze the diff** looking for:
   - Security issues (auth bypass, PII leaks, cross-tenant, injection)
   - Logic bugs (race conditions, null access, wrong state transitions)
   - Code quality (god components, missing error handling, `any` types)
   - Architecture concerns (wrong patterns, wrong location, scope creep)
   - Missing tests or verification

4.5. **Cross-check with codex peer reviewer.** Run an independent second opinion on the same diff. Codex is read-only (cannot modify files) and runs in parallel — its verdict is advisory, NOT a tiebreaker.
   ```bash
   gh pr diff <N> --repo Visalaw/<repo> | codex exec --sandbox read-only --skip-git-repo-check \
     "You are an independent peer reviewer. The PR diff is on stdin.
      Output exactly:
        VERDICT: APPROVE | REQUEST_CHANGES | COMMENT
        TOP_FINDINGS: up to 3 lines as 'severity | file:line | description'
        RISK: one sentence on overall merge risk.
      Be blunt. No preamble. No filler."
   ```
   - **If codex times out or errors** — note `Codex peer unavailable` in the verdict block and proceed with Claude's verdict alone. Never block on codex.
   - **Capture both findings sets** for the verdict block in step 5.

5. **For each PR, produce a quick verdict (dual reviewer):**
   ```
   ### PR #N — title (repo)
   Author: @name | Files: X | +Y/-Z

   **Claude verdict:** APPROVE / REQUEST_CHANGES / COMMENT
   **Codex verdict:** APPROVE / REQUEST_CHANGES / COMMENT  (or "Codex peer unavailable")
   **Convergence:** ✅ AGREE  |  ⚠️ DIVERGE — needs human call  |  ➖ N/A (codex unavailable)

   **Summary (Claude):** 1-2 sentences
   **Summary (Codex):** 1-2 sentences (or omit if unavailable)

   **Findings:** (merged, deduplicated, tagged with source)
   - [severity] file:line — description  *(Claude / Codex / both)*
   ```
   When verdicts diverge, list which finding each reviewer raised that the other missed — never silently collapse into one answer.

6. **If something catches your attention** (security issue, architectural concern, or a judgment call), ask the user before proceeding:
   ```
   "PR #N has [finding]. Should I flag this as a blocking comment or is this acceptable?"
   ```

### Phase 3: Submit Reviews

After all PRs are analyzed and the user has weighed in on flagged items:

1. **For APPROVE verdicts** — submit approval:
   ```bash
   gh pr review <N> --repo Visalaw/<repo> --approve --body "Reviewed — looks good. [brief note]"
   ```

2. **For REQUEST_CHANGES verdicts** — submit with inline comments:
   ```bash
   gh api repos/Visalaw/<repo>/pulls/<N>/reviews \
     --method POST \
     -f event="REQUEST_CHANGES" \
     -f body="[summary]" \
     -f 'comments[][path]=...' \
     -f 'comments[][line]=...' \
     -f 'comments[][body]=...'
   ```

3. **For COMMENT verdicts** — submit non-blocking feedback:
   ```bash
   gh pr review <N> --repo Visalaw/<repo> --comment --body "[feedback]"
   ```

4. **Never submit a review without the user's explicit approval.** Show the review content first and ask "Submit this review?" before executing.

### Phase 3.5: Closure Routing — every PR leaves with a next-action

This phase is the point of the command. Route every PR that reached Phase 2 (or was routed here by step 0.5 / Phase 1):

1. **Ready-to-merge queue** (approved + checks green + `mergeStateStatus == CLEAN`): present the queue via `AskUserQuestion` (multiSelect) — "which of these do I merge now?". Bernard's selection IS the explicit merge authorization for exactly those targets:
   ```bash
   gh pr merge <N> --repo Visalaw/<repo> --squash
   ```
   PRs he does not select are recorded as `deferred by Bernard <date>` in the summary. Never merge a PR he did not explicitly pick in this session.

2. **Remedy queue** (VAIR PRs with REQUEST_CHANGES or unresolved findings): the findings MUST already exist as **inline review threads** on the PR (Phase 3 step 2 posts them — the remedy pipeline reads `reviewThreads` via GraphQL; a chat verdict or PR-body comment is invisible to it). Then offer both dispatch routes via `AskUserQuestion`:
   - **Local**: Bernard types `/remedy-mr <repo>#<N>` — it is `disable-model-invocation`, Claude cannot fire it; print the exact invocation for him to type.
   - **CI**: post the PR comment `/ai-remedy` (or `/ai-remedy approve`) — from PowerShell or `MSYS_NO_PATHCONV=1`, NEVER bare Git Bash (leading-slash path-mangling turns it into a silent no-op), then verify the "AI Commands" run is non-`skipped`.

3. **Ping queue** (human PRs blocked on their author or another reviewer): draft the 1-line Slack ping per PR (bare URL, English, channel rules apply), show the drafts, send only on Bernard's go.

4. **Stagnation flags**: any OPEN PR that already carries ≥2 of your own reviews is flagged `🔁 STAGNANT — needs a closure decision, not another review` and goes into the AskUserQuestion menu with options: merge / remedy / close PR / defer.

### Phase 4: Summary — closure metrics, not review counts

After routing, show:
```
## Session Complete
- MERGED: N PRs (#…)
- Remedy dispatched: N PRs (#…)
- Findings posted (awaiting remedy/author): N PRs
- Author pinged: N PRs
- Deferred by Bernard: N PRs
- ♻️ Re-review skipped (head unchanged): N PRs
- ☠️ Dead since discovery: N PRs

🔁 Stagnant (≥2 reviews, still open): #X, #Y — these need a closure decision next session, not another review.
```
A session where MERGED and "Remedy dispatched" are both zero and "Findings posted" is the only nonzero count means the command reviewed without closing — say that explicitly instead of dressing it up as progress.

## Rules

1. **`state` and `mergeStateStatus` are MANDATORY on every `gh pr view`.** The `gh search prs --state=open` snapshot is stale the second it prints — PRs close/merge constantly. Always include `state,isDraft,mergeable,mergeStateStatus` in the `--json` field list. Never call a PR "clean" without verifying `state == "OPEN"` AND `mergeStateStatus == "CLEAN"`. If you ever catch yourself about to say "4 limpios", stop and re-run the liveness check. **This is why this command exists — to never again tell the user a PR is ready when it's actually CLOSED, MERGED, BLOCKED, DIRTY, or UNKNOWN.**
2. **Never approve without reading the full diff.** A quick "LGTM" is not a review.
3. **Security findings are always blocking** — never approve a PR with auth/PII/tenant issues.
4. **Dependabot and github-actions PRs get a summary, not a full review** — list the dep name, version bump, and whether it's a major/minor/patch. The user decides whether to approve or ignore. **VAIR PRs (`vair-visalaw-ai-reviewer[bot]`) are NOT in this category** — they are AI-authored real work and get full review same as human PRs.
5. **Use inline comments, never general PR comments** — findings must point to the exact file and line.
6. **Direct, constructive tone** — "This needs a null check" not "Perhaps we could consider adding validation."
7. **Check for AI review comments already posted** — don't duplicate findings that the VAIR bot already flagged. Reference them if agreeing.
8. **Always ask before submitting** — show the review text and wait for the user's go-ahead.
9. **Flag scope creep** — if a PR touches files outside its stated purpose, call it out.
10. **Respect seniority** — interns get constructive feedback, senior devs get direct technical notes.
11. **Codex peer is advisory, never authoritative.** Codex's verdict is a second opinion, not a tiebreaker. Bernard always makes the final call. If verdicts diverge, surface the divergence explicitly — never silently pick one side. If codex is unavailable, the review proceeds with Claude's verdict alone (noted as `Codex peer unavailable`).
12. **Closure over review.** Never leave a reviewed PR without a routed next-action (merge proposed / remedy dispatched / author pinged / explicit deferral by Bernard). Review count is not a success metric; closed PRs are.
13. **Never re-review an unchanged head.** Phase 2 step 0.5 is mandatory. Re-reviewing a PR whose head SHA equals your last review's `commit_id` is the #1544 anti-pattern (14 reviews, 1 month, still open) — forbidden.
14. **Use the native `AskUserQuestion` tool** for batch selection (Phase 1 step 8) and closure routing (Phase 3.5) — never free-text "which ones?" questions buried in prose.
15. **Merges and remedy dispatches are per-target authorizations.** An AskUserQuestion selection authorizes exactly the PRs selected in this session, nothing more. `/remedy-mr` is user-invoked only — print the invocation for Bernard, never simulate or substitute it.

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| CRITICAL | Security, data leak, crash in prod | REQUEST_CHANGES — blocks merge |
| HIGH | Logic bug, race condition, wrong pattern | REQUEST_CHANGES — must fix |
| MEDIUM | Code smell, missing validation, tech debt | COMMENT — should fix |
| LOW | Style, naming, minor optimization | COMMENT — nice to have |
| INFO | Observation, question, suggestion | COMMENT — FYI |
