# /merge-policeman — PR Review Queue Scanner & Batch Closer

ARGUMENTS: $ARGUMENTS

## Mission

**The goal is CLOSURE, not reviews.** A review is a means; the end state of every PR this command touches is one of: MERGED, remedy dispatched, author pinged on blocking findings, or explicitly deferred by Bernard. A session that only stacks another review on a PR that already had one is a FAILED session.

**Assignment is NOT a filter — the whole team is tiny and forgets to request reviewers.** The old design gated the actionable queue on `--review-requested=@me`. That was correct when the org had ~80 interns and reviewer assignment was disciplined; today it strands almost every PR, because nobody remembers to add Bernard as a reviewer and the PRs then rot for months with no review at all. **The actionable universe is EVERY open PR that lacks a current, congruent review — whether or not Bernard is the assigned reviewer.** "Assigned to Bernard" is at most a light sort hint and a badge in the table; it is never a gate and never a reason to skip or deprioritize a PR. If a PR is open and unreviewed, Bernard can review it.

> Anchor 2026-07-13: `visalaw-gen-backend#1544` accumulated 14 of Bernard's reviews over a month and stayed open; `visalaw-gen-standalone-services#303/#304` were each APPROVED twice (07-07 and again 07-11) and never merged. The command produced reviews forever and closed nothing. Phase 2 step 0.5 and Phase 3.5 exist to kill exactly that.
>
> Anchor 2026-07-15: the command still led with `--review-requested=@me` as the primary bucket, so a scan surfaced only 4 PRs (the ones where someone happened to assign Bernard) while ~25 other open, unreviewed PRs sat invisible. Bernard: "el equipo es muy malo para asignarme como revisador… quita la métrica de que si está asignado a mí o no. Eso ya no importa." This whole file was rewritten to make "no current review" — not "assigned to me" — the primary axis.

Every PR that enters Phase 2 must exit with a **next-action**, never with just a verdict.

**Blocking findings are NOT a dead end — they route to REMEDY, which makes the PR approvable. Never report a PR (or a batch) as "not approvable" as if that were a terminal state.** A REQUEST_CHANGES verdict is the START of closure, not the end: the command's job is to turn it approvable. Post the findings as inline review threads, then **suggest/dispatch remedy** so the fix is applied and the PR can be approved and merged:
- **Local**: `/remedy-mr <repo>#<N>` — Bernard types it (it is `disable-model-invocation`; Claude CANNOT fire it). Always PRINT the exact invocation for him.
- **CI**: post the PR comment `/ai-remedy approve` (PowerShell / `MSYS_NO_PATHCONV=1`, never bare Git Bash), then verify the "AI Commands" run is non-`skipped`. Claude CAN fire this where the AI Commands workflow exists.

**Remedy applies to HUMAN PRs too, not just VAIR** — fixing a teammate's findings for them and pushing the fix to their branch is the fastest path to green, and "accelerate to approvable" is the whole point. The default framing of a session is never "N PRs not approvable"; it is "N PRs with findings → remedy dispatched → approvable". If a finding is only PLAUSIBLE (not confirmed), the remedy thread says so and lets the remedy agent confirm-or-fix; do not withhold remedy just because certainty is short of 100%.

## Definitions — "needs review" vs "covered"

A congruent review = an `APPROVED` review whose `commit_id` equals the PR's **current** `headRefOid`. Applied per PR:

- **NEEDS REVIEW** (actionable): the PR has **no `APPROVED` review on the current head** — i.e. zero approvals, OR the only approvals are on a stale commit (head moved since), OR the latest review is `CHANGES_REQUESTED` / `COMMENTED`. These are the queue, regardless of who (if anyone) is the assigned reviewer.
- **COVERED** (not actionable): the PR has ≥1 `APPROVED` review on the current head. Route it to closure (merge/ping), never re-review it.

The assigned reviewer (`reviewRequests`) does not enter this classification at all. It is displayed as an **Assigned** badge for awareness only.

## Instructions

### Phase 1: Discovery — Find All Open PRs Lacking a Current Review

1. **PRIMARY query — the actionable universe is ALL open human PRs across Visalaw**, not just the ones assigned to you:
   ```bash
   gh search prs --state=open --owner=Visalaw --json number,title,repository,author,createdAt,url,labels -- -author:app/dependabot -author:app/github-actions
   ```
   This is the source list. Do NOT start from `--review-requested=@me` — that query is now only a *badge source* (step 2), never the filter.

2. **Tag which PRs are formally assigned to you** (badge only, NOT a filter). Run it once and keep the set of numbers to mark an `Assigned` column:
   ```bash
   gh search prs --review-requested=@me --state=open --owner=Visalaw --json number,repository
   ```
   A PR being in this set changes nothing about whether it is actionable — it only earns a 👤 badge.

3. **Categorize each PR from step 1:**
   - **Human PRs** — from real teammates. These get full review when they NEED REVIEW.
   - **VAIR PRs** — from `vair-visalaw-ai-reviewer[bot]`. AI-authored work Bernard dispatched; full review (same as human PRs, NOT summary).
   - **Dependabot/Actions PRs** — from `dependabot[bot]` or `github-actions[bot]`. Quick summary only.

4. **Liveness + review-currency check — for EVERY PR, fetch state + mergeStateStatus + reviews + head in ONE call.** NEVER trust the `gh search` snapshot — PRs close/merge between queries. This call also computes whether the PR is COVERED (approval on current head) or NEEDS REVIEW:
   ```bash
   gh pr view <N> --repo Visalaw/<repo> --json state,isDraft,mergeable,mergeStateStatus,reviews,statusCheckRollup,reviewRequests,headRefOid \
     --jq '{state, draft: .isDraft, mergeable, mergeStateStatus, head: (.headRefOid[0:8]),
            approved_on_head: ([.reviews[] | select(.state=="APPROVED" and .commit_id==.headRefOid)] | length),
            approvals_any: ([.reviews[] | select(.state=="APPROVED")] | length),
            changes_requested: ([.reviews[] | select(.state=="CHANGES_REQUESTED")] | length),
            assigned_reviewers: ([.reviewRequests[].login] | join(", ")),
            checks_pass: ([.statusCheckRollup[]? | select(.conclusion != "SUCCESS" and .conclusion != null and .conclusion != "SKIPPED" and .conclusion != "NEUTRAL")] | length == 0)}'
   ```
   Classify each:
   - **If `state != "OPEN"`** → CLOSED/MERGED since discovery. **Discard.** Collect for the dead-PR note.
   - **If `approved_on_head >= 1`** → **COVERED.** Do NOT re-review. If checks pass and `mergeStateStatus == "CLEAN"` → **Ready-to-merge queue** (Phase 3.5). Otherwise → closure/ping queue. An approved-and-current PR left rotting is the #303/#304 failure mode.
   - **Else (`approved_on_head == 0`)** → **NEEDS REVIEW.** Into the actionable queue — *regardless of `assigned_reviewers`*. (`approvals_any >= 1` with `approved_on_head == 0` means a stale approval; still needs a fresh look at the new head.)
   - Print the routing notes:
     - `☠️ Discovery→now drift: N PRs closed/merged. Excluded: #X (CLOSED), #Y (MERGED).`
     - `✅ Covered (approved on current head): #X, #Y — routed to closure, not re-reviewed.`

5. **Query the user's own PRs awaiting review from others** (informational — Bernard doesn't review his own):
   ```bash
   gh search prs --author=@me --state=open --owner=Visalaw --json number,title,repository,createdAt,url,labels
   ```
   For each, the same `gh pr view` snapshot from step 4. Drop any where `state != "OPEN"`.

5b. **Query VAIR-authored PRs explicitly** (they also appear in step 1, but this catches any the search missed):
   ```bash
   gh search prs --author=app/vair-visalaw-ai-reviewer --state=open --owner=Visalaw --json number,title,repository,createdAt,url,labels
   ```
   Same snapshot per PR. VAIR PRs flow through the SAME Phase 2 full review as human PRs.

6. **Display summary tables** sorted by repo, then by age (oldest first — the longest-rotting PR is the highest priority). **EXCEPTION: the VAIR PRs table is sorted DRAFT-first** (AI-dispatched WIP needs Bernard's triage before anything else), then by age. EVERY table includes a **Merge** column so dead/blocked PRs are visible at a glance, and the "needs review" table includes an **Assigned** column (badge only):

   ```
   ## Human PRs — NEED REVIEW (no approval on current head)   ← the actionable queue
   | # | Repo | PR | Author | Title | Assigned | Merge | Checks | Age |
   |---|------|-----|--------|-------|----------|-------|--------|-----|
   Assigned values: 👤 you | 🧑 <someone-else> | — nobody   (badge only — never a filter)

   ## Human PRs — COVERED (approved on current head)   ← closure only, no re-review
   | # | Repo | PR | Author | Title | Merge | Age |
   |---|------|-----|--------|-------|-------|-----|

   ## Your PRs (waiting on others)
   | # | Repo | PR | Title | Review | Merge | Pending Reviewers | Age |
   |---|------|-----|-------|--------|-------|-------------------|-----|
   Review values: ✅ Approved | 🔄 Changes Requested | ⏳ Pending Review | 📝 Draft

   ## VAIR PRs (AI-authored, your triage — full review) — DRAFTS FIRST
   | # | Repo | PR | Title | Review | Merge | Age |
   |---|------|-----|-------|--------|-------|-----|
   Review values: 📝 Draft (LIST FIRST — top priority) | ✅ Approved | 🔄 Changes Requested | ⏳ Pending Review

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

7. **If ARGUMENTS is provided**, filter the tables to only show PRs matching the argument (repo name, author, PR number, or keyword in title).

8. **Ask the user which PRs to review — with the native `AskUserQuestion` tool, never a free-text question.** Build the options from the **NEEDS REVIEW** table (which now spans the whole org, not just assigned-to-you). Suggested options: all human PRs oldest-first / only VAIR PRs / only the ones assigned to you (👤) as a subset / specific numbers from the table / skip straight to closure routing (Phase 3.5) when the queues are dominated by COVERED PRs. **Never present "assigned to you" as the only or default review set — the default is the full unreviewed queue.**

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

This phase is the point of the command. Route every PR that reached Phase 2 (or was routed here as COVERED by Phase 1 / by step 0.5):

1. **Ready-to-merge queue** (approved on current head + checks green + `mergeStateStatus == CLEAN`): present the queue via `AskUserQuestion` (multiSelect) — "which of these do I merge now?". Bernard's selection IS the explicit merge authorization for exactly those targets:
   ```bash
   gh pr merge <N> --repo Visalaw/<repo> --squash
   ```
   PRs he does not select are recorded as `deferred by Bernard <date>` in the summary. Never merge a PR he did not explicitly pick in this session.

2. **Remedy queue — the DEFAULT route for ANY PR (human OR VAIR) with blocking findings.** This is how "not approvable" becomes "approvable" — always propose remedy on a REQUEST_CHANGES PR, never stop at the verdict. The findings MUST already exist as **inline review threads** on the PR (Phase 3 step 2 posts them — the remedy pipeline reads `reviewThreads` via GraphQL; a chat verdict or PR-body comment is invisible to it). Then dispatch/suggest both routes:
   - **Local**: Bernard types `/remedy-mr <repo>#<N>` — it is `disable-model-invocation`, Claude cannot fire it; ALWAYS print the exact invocation for him to type.
   - **CI**: post the PR comment `/ai-remedy approve` — from PowerShell or `MSYS_NO_PATHCONV=1`, NEVER bare Git Bash (leading-slash path-mangling turns it into a silent no-op), then verify the "AI Commands" run is non-`skipped`. **Before relying on the CI route, confirm the target repo actually has the "AI Commands" workflow** (`gh workflow list --repo Visalaw/<repo>`); not every repo does — if it's absent, the CI comment is a no-op and the local `/remedy-mr` route is the only one. Present the routes via `AskUserQuestion` unless Bernard has already said to remedy — a standing "haz remedy" is authorization, do not re-ask (per slash-command-obedience).

3. **Ping queue** (human PRs blocked on their author, or NEEDS-REVIEW PRs Bernard chose not to review this session): draft the 1-line Slack ping per PR (bare URL, English, channel rules apply), show the drafts, send only on Bernard's go.

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
- ✅ Covered (already approved on head): N PRs
- ☠️ Dead since discovery: N PRs

🔁 Stagnant (≥2 reviews, still open): #X, #Y — these need a closure decision next session, not another review.
```
A session where MERGED and "Remedy dispatched" are both zero and "Findings posted" is the only nonzero count means the command reviewed without closing — say that explicitly instead of dressing it up as progress. **Never phrase the outcome as "N PRs not approvable" and stop** — that is the failure this command exists to kill. Blocking findings are an instruction to dispatch remedy (which makes them approvable), not a terminal verdict. The correct closing sentence on a batch with findings is "N PRs with findings → remedy dispatched (routes: …) → approvable after remedy", never "none approvable".

## Rules

1. **`state` and `mergeStateStatus` are MANDATORY on every `gh pr view`.** The `gh search prs --state=open` snapshot is stale the second it prints — PRs close/merge constantly. Always include `state,isDraft,mergeable,mergeStateStatus` in the `--json` field list. Never call a PR "clean" without verifying `state == "OPEN"` AND `mergeStateStatus == "CLEAN"`. If you ever catch yourself about to say "4 limpios", stop and re-run the liveness check. **This is why this command exists — to never again tell the user a PR is ready when it's actually CLOSED, MERGED, BLOCKED, DIRTY, or UNKNOWN.**
2. **Assignment is never a filter.** The actionable queue is EVERY open PR with no `APPROVED` review on its current head, whether or not Bernard is a requested reviewer. `--review-requested=@me` is a badge source only. Never scope the review universe to assigned-to-you; never deprioritize or skip an unreviewed PR because someone else (or nobody) is the assigned reviewer. Surfacing only the assigned subset is the 2026-07-15 failure — forbidden.
3. **Never approve without reading the full diff.** A quick "LGTM" is not a review.
4. **Security findings are always blocking** — never approve a PR with auth/PII/tenant issues.
5. **Dependabot and github-actions PRs get a summary, not a full review** — list the dep name, version bump, and whether it's a major/minor/patch. The user decides whether to approve or ignore. **VAIR PRs (`vair-visalaw-ai-reviewer[bot]`) are NOT in this category** — they are AI-authored real work and get full review same as human PRs.
6. **Use inline comments, never general PR comments** — findings must point to the exact file and line.
7. **Direct, constructive tone** — "This needs a null check" not "Perhaps we could consider adding validation."
8. **Check for AI review comments already posted** — don't duplicate findings that the VAIR bot already flagged. Reference them if agreeing.
9. **Always ask before submitting** — show the review text and wait for the user's go-ahead.
10. **Flag scope creep** — if a PR touches files outside its stated purpose, call it out.
11. **Codex peer is advisory, never authoritative.** Codex's verdict is a second opinion, not a tiebreaker. Bernard always makes the final call. If verdicts diverge, surface the divergence explicitly — never silently pick one side. If codex is unavailable, the review proceeds with Claude's verdict alone (noted as `Codex peer unavailable`).
12. **Closure over review.** Never leave a reviewed PR without a routed next-action (merge proposed / remedy dispatched / author pinged / explicit deferral by Bernard). Review count is not a success metric; closed PRs are.
13. **Never re-review an unchanged head.** Phase 2 step 0.5 is mandatory. Re-reviewing a PR whose head SHA equals your last review's `commit_id` is the #1544 anti-pattern (14 reviews, 1 month, still open) — forbidden.
14. **Use the native `AskUserQuestion` tool** for batch selection (Phase 1 step 8) and closure routing (Phase 3.5) — never free-text "which ones?" questions buried in prose.
15. **Merges and remedy dispatches are per-target authorizations.** An AskUserQuestion selection authorizes exactly the PRs selected in this session, nothing more. `/remedy-mr` is user-invoked only — print the invocation for Bernard, never simulate or substitute it.
16. **"Covered" is defined by approval on the CURRENT head, not by the presence of any approval.** A stale approval (head moved since it was given) does NOT cover a PR — it still NEEDS REVIEW (delta). Compute `approved_on_head` (`commit_id == headRefOid`), never a bare approval count.
17. **Findings → remedy → approvable. "Not approvable" is never a terminal state.** Every REQUEST_CHANGES verdict must be paired with a remedy route (local `/remedy-mr` printed for Bernard, and/or CI `/ai-remedy approve` where the workflow exists) so the PR is driven to green — for HUMAN PRs as well as VAIR. Reporting a PR or a batch as "none approvable" and stopping is the failure this rule forbids: the command's mission is to MAKE things approvable, and remedy is the lever. A PLAUSIBLE-but-unconfirmed finding still routes to remedy (the thread flags the uncertainty and the remedy agent confirms-or-fixes); do not withhold remedy for want of 100% certainty.

## Severity Levels

| Level | Meaning | Action |
|-------|---------|--------|
| CRITICAL | Security, data leak, crash in prod | REQUEST_CHANGES — blocks merge |
| HIGH | Logic bug, race condition, wrong pattern | REQUEST_CHANGES — must fix |
| MEDIUM | Code smell, missing validation, tech debt | COMMENT — should fix |
| LOW | Style, naming, minor optimization | COMMENT — nice to have |
| INFO | Observation, question, suggestion | COMMENT — FYI |
