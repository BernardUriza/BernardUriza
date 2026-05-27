---
description: Remediate a PR up to the green squash-merge button (stops before merge)
argument-hint: [pr-id | url | repo#number]
model: opus
allowed-tools: Read, Edit, Write, Bash, Grep, Glob, AskUserQuestion, WebFetch
disable-model-invocation: true
---

# /remedy-mr — Remediate a PR up to the green squash-merge button

ARGUMENTS: `<pr-id>` — accepts PR number (`546`), full URL (`https://github.com/Visalaw/frontend-core-2.0/pull/546`), or `repo#number` (`visalaw-gen-backend#1217`). Bare numbers infer the current repo from working directory.

## Contract

**`/remedy-mr` is user-invoked only.** It is NOT automatic. When Bernard types `/remedy-mr 546` he is consciously authorizing a big, autonomous batch of work: branch reset, docstring/code fixes on a teammate's branch, force-push, metadata rewrite, approval. The trade-off is that the command has a contract with him: every step below MUST execute — no shortcuts, no "salté esta verificación porque parecía obvia."

The command **stops at the green squash-and-merge button**. It does NOT click it. Bernard decides whether to merge.

The command **may also do nothing** — if after full review there's nothing to remedy, it approves with a clean LGTM comment, reports "no remedy needed", and stops. That's a valid outcome.

This command is usually invoked AFTER `/code-review`. `/code-review` identifies findings; `/remedy-mr` materializes them into commits and shepherds the PR to a mergeable state.

## Same PR channel — never create follow-up PRs

**Every remedy stays in the original PR's branch. `/remedy-mr` never opens a new PR.** This is a hard invariant, not a default. It applies to PRs authored by VAIR, by teammates, and by Bernard — every case.

Why: if `/remedy-mr` discovers an additional finding mid-flight and Claude spins up a separate "follow-up PR with `Part of VISAL-XXX`" authored by Bernard, then approves it on Bernard's behalf, that's self-approval disguised as process. The first approval (on the original PR) was authentic — the bot or teammate did the work, Bernard reviewed and approved. The second approval (on the follow-up Claude itself created) bypasses the human-review gate entirely. Bernard has stated this is unacceptable for VAIR PRs and equally unacceptable for any other PR.

**What to do with additional findings discovered during the remedy:**

| Size of finding | Action |
|---|---|
| Small (≤ ~100 LOC, no new deps, same files or adjacent), tsc + tests still green | **Fold into the same remedy commit.** No new commit message needed beyond the original; no `Part of VISAL-XXX`; no separate PR. |
| Larger (architectural change, new dependency, scope crosses subsystems, external review needed) | **STOP and ask Bernard.** Do not silently expand scope. Bernard decides whether to expand the current PR, defer the finding to a Plane comment, or queue a new piece of work via `/work` pipeline. |

**Forbidden in approval bodies, PR descriptions, and conversation framing:**

- "Worth a follow-up PR with `Part of VISAL-XXX`"
- "Out of scope here, but…"
- "Open question for follow-up"
- "Tracked separately"

Each of those phrases is a trigger that either Claude or Bernard interprets later as "create a separate PR". Replace with one of: (a) the fix folded into the same commit, (b) an inline review comment on the specific line that authored the original PR can address, or (c) a Plane comment on the issue when the work genuinely belongs to a different ticket and a different reviewer.

## Instructions

### Phase 0 — Target acquisition

1. Parse the argument:
   - Bare number → `gh pr view <n>` in the current repo (detect via `git config --get remote.origin.url`).
   - URL → extract `owner/repo/pulls/<n>`.
   - `repo#n` → resolve owner (default `Visalaw`), repo, number.
2. Fetch full state in one call:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json number,title,body,state,isDraft,author,headRefName,baseRefName,headRefOid,mergeable,mergeStateStatus,reviews,reviewRequests,labels,files,additions,deletions,commits
   ```
   The `reviews` field here is **informational only** — it returns review-level metadata (review bodies, overviews, LGTM/REQUEST_CHANGES summaries, reviewer states like APPROVED / COMMENTED / DISMISSED). It does **NOT** include inline review threads — the actual line-by-line findings from Copilot, VAIR, CodeRabbit, or human reviewers. Those live on a separate GraphQL surface (`reviewThreads`) and are fetched in Phase 0.5 below. **Never treat `reviews` as a complete picture of reviewer feedback.**
3. Stop conditions (report and exit):
   - `state: MERGED` → "Already merged — nothing to remedy. Commit: `<oid>`."
   - `state: CLOSED` → "Closed, not merged. Reopen first if remedy is intended."
   - `isDraft: true` → "Draft PR. Author may still be writing. Proceed only if Bernard explicitly re-confirms."

### Phase 0.5 — Existing review threads audit (predecessors)

**This phase exists because Claude shipped a remedy missing one of three findings the Copilot bot had already documented for free** (incident 2026-04-28, PR #1248 visalaw-gen-backend). The `reviews` field from Phase 0 only surfaced Copilot's overview body — not the three inline threads where the actual findings lived. Phase 1's own audit found 2 of 3 by accident; the third (a `response.data.buffer` slice-of-pool bug with explicit suggestion code attached) shipped uncovered. Bernard had to ask "vas a cerrar los comments de copilot" before the threads were even queried. Phase 0.5 closes that hole — every existing reviewer thread is mandatory input before any audit work begins.

1. **Fetch ALL review threads via GraphQL** (the `reviews` REST field is INSUFFICIENT — see Phase 0 step 2):
   ```bash
   gh api graphql \
     -F owner=<owner> \
     -F name=<repo> \
     -F number=<n> \
     -f query='
   query($owner: String!, $name: String!, $number: Int!) {
     repository(owner: $owner, name: $name) {
       pullRequest(number: $number) {
         reviewThreads(last: 100) {
           nodes {
             id
             isResolved
             isOutdated
             path
             line
             comments(first: 5) {
               nodes { author { login } body }
             }
           }
         }
       }
     }
   }' --jq '.data.repository.pullRequest.reviewThreads.nodes'
   ```

2. **Classify and table-format each thread** — extract:
   - Thread ID (`PRRT_*` — needed later for reply + resolve mutations)
   - Author login + bot/human classification (Copilot, VAIR, CodeRabbit, or human teammate)
   - `path:line` — where the thread is anchored
   - First comment body (truncate to ~200 chars for the report; keep full text for Phase 1 cross-reference)
   - Suggestion code if present — Copilot/VAIR/CodeRabbit attach ` ```suggestion ` blocks with concrete fix code; copy these verbatim, they're often the right answer
   - `isResolved` + `isOutdated` flags

   Present the table in your status report so Bernard sees what reviewers already documented before you start writing your own audit:

   ```
   | # | Author | path:line | resolved | outdated | gist (≤200ch) | has suggestion? |
   |---|--------|-----------|----------|----------|---------------|-----------------|
   | 1 | copilot-pull-request-reviewer | src/pdf/pdf.service.ts:256 | false | false | ... | yes |
   | 2 | copilot-pull-request-reviewer | src/pdf/pdf.service.ts:null | false | true  | ... | no |
   | 3 | copilot-pull-request-reviewer | src/pdf/pdf.service.ts:278 | false | false | ... | yes |
   ```

3. **Treat unresolved threads as MANDATORY input to the Phase 1 audit.** Every unresolved finding from a reviewer must end up in one of three buckets — and the bucket is decided BEFORE any code is written:
   - **Folded into the remedy** (small fix per Same-PR-channel rules — ≤ ~100 LOC, no new deps, same files or adjacent)
   - **STOP and ask Bernard** if the finding crosses scope (architectural, new dependency, multi-subsystem)
   - **No-op** if the thread is genuinely outdated, already addressed by a previous commit in this PR, or referencing code that no longer exists

   **Silent ignore is never an option.** A thread skipped without one of those three classifications is a missed finding — exactly the failure mode this phase was built to prevent.

4. **Resolved + outdated threads still need triage**, but lighter. Skim each one to confirm it's actually a no-op on the current head (sometimes a "resolved" thread re-emerges if the PR force-pushed and the resolution didn't carry forward). If still actionable, treat as unresolved. Otherwise note it as `[resolved-prior]` in your table and move on.

5. **Output of this phase**: a thread table (above) + a per-thread classification table you'll re-use in Phase 1 step 4 (cross-reference) and Phase 6 step 5 (reply + resolve). Keep both as scratchpad — they are not optional artifacts.

### Phase 1 — Code review (diff audit, no code changes yet)

1. Fetch the full diff:
   ```bash
   gh pr diff <n> --repo <owner>/<repo>
   ```
2. For each changed file, read the FULL file on the PR branch (not just the diff hunks — context matters):
   ```bash
   git show origin/<head-ref>:<path>
   ```
3. Classify findings:

   | Tier | What qualifies | Action |
   |------|----------------|--------|
   | **Critical** | Security, data loss, production breakage, logic bugs, violates security invariants | Remedy commit required |
   | **Important** | Code quality regression (deleted WHY-comments, `any` in auth, god object creep, test gaps for a bug that already escaped), wrong pattern vs codebase convention | Remedy commit recommended |
   | **Suggestions** | Naming, minor refactors, optional improvements | Inline review comments only |
   | **Hygiene** | Missing labels, empty PR body, non-conventional title, missing Plane ref (`VISAL-XXX`) | Metadata-only fix via `gh api PATCH` + `gh api POST /labels` |

4. **Cross-reference against Phase 0.5 threads** — for every finding you classified above, check whether it was already documented by an existing reviewer thread:
   - If yes → annotate the finding with `covered by thread <PRRT_xxx>`. The remedy must address BOTH (the code fix and the thread close in Phase 6 step 5).
   - If no → it's a new finding from your own audit. Treat it per the same Same-PR-channel rules (small fold-in, large STOP-and-ask).
   - Conversely, every Phase 0.5 thread must end up tagged either `covered by Phase 1 finding #N` or `no remedy needed (no-op / outdated / already addressed by previous commit)`. **A thread with no Phase 1 mapping is a missed finding.** Re-read the thread until it falls into one of those two buckets.

5. **Decision gate**: what does this PR need?
   - Critical or Important findings (from your audit OR from Phase 0.5 threads) → **remedy commit**. Proceed to Phase 2.
   - Only Suggestions → **approve with inline comments**, fix metadata, skip to Phase 6 (still process threads in step 5).
   - Only Hygiene → **metadata-only remedy**, skip to Phase 6 (still process threads).
   - No findings AND every Phase 0.5 thread is a no-op/outdated → **LGTM approve** after closing threads in Phase 6 step 5.

   Findings discovered DURING this audit (or later, in Phase 3-5) get resolved on THIS PR's branch — small ones folded into the same remedy commit, large ones halted with a question to Bernard. Never deferred to a follow-up PR. See "Same PR channel" above.

### Phase 2 — Branch safety audit (THE CRITICAL GATE)

**This is the phase that saved Bernard from data loss today. Execute it in full, even if it feels redundant.**

Work on `local-testing` only. Never check out a teammate's branch directly.

1. **Record pre-state** (for recovery if something goes wrong):
   ```bash
   cd <repo-root>
   STARTING_BRANCH="$(git branch --show-current)"
   STARTING_SHA="$(git rev-parse HEAD)"
   echo "Starting at: $STARTING_BRANCH @ $STARTING_SHA"
   ```

2. **Switch to `local-testing`** (if not already):
   ```bash
   git checkout local-testing
   ```

3. **Unique commits ahead of base** — commits that would be LOST on hard reset:
   ```bash
   BASE_BRANCH="main"  # or staging-v2 for backend
   git fetch origin <base-branch>
   AHEAD="$(git log --oneline local-testing ^origin/<base-branch>)"
   if [ -n "$AHEAD" ]; then
     echo "WARNING: local-testing has these commits NOT in origin/<base-branch>:"
     echo "$AHEAD"
     # STOP and ask Bernard: cherry-pick to a backup branch, delete, or abort remedy.
   fi
   ```

4. **Uncommitted changes** (staged + unstaged):
   ```bash
   DIRTY="$(git status --porcelain | grep -vE '^\?\?')"
   if [ -n "$DIRTY" ]; then
     # STOP. Stash with a named ref, never silently reset.
     git stash push -m "remedy-mr-pre-<n>-$(date +%s)" --include-untracked=0
     # Or ask Bernard what to do.
   fi
   ```

5. **Untracked files audit** — these SURVIVE `git reset --hard` but can still be accidentally staged by `git add -A` later in this flow:
   ```bash
   UNTRACKED="$(git status --porcelain | grep '^??')"
   if [ -n "$UNTRACKED" ]; then
     echo "Untracked files present (will be preserved through reset, but must not be staged in remedy commit):"
     echo "$UNTRACKED"
     # Catalog them mentally. When staging in Phase 5, NEVER use `git add -A` or `git add .`.
   fi
   ```

6. **Fetch the PR branch fresh** and capture its current remote SHA (needed later for `--force-with-lease`):
   ```bash
   git fetch origin <head-ref>
   OLD_REMOTE_SHA="$(git rev-parse origin/<head-ref>)"
   ```

7. **Only after all four checks green**: reset `local-testing` to the PR's current HEAD:
   ```bash
   git reset --hard origin/<head-ref>
   ```

### Phase 3 — Apply fixes (surgical)

1. **Use `Edit` or `Write` for specific files only.** Never `Bash sed`, never `rewrite-everything`.
2. Keep the PR author's commits intact — stack a new commit on top.
3. **Do NOT touch files outside the scope of the findings.** If Phase 1 flagged 2 files, only those 2 files get edited.
4. If restoring deleted content (e.g., JSDoc that Katie trimmed): re-read the content from git history:
   ```bash
   git show <pre-deletion-sha>:<path>
   ```
   …and hand-craft the Edit, adapting as needed.

### Phase 4 — Verification (non-negotiable)

1. **Type check**:
   ```bash
   npx tsc --noEmit
   # Exit code must be 0.
   ```

2. **Tests — chunked, not full suite** (Bernard's machine locks on full runs):
   ```bash
   # Find the test pattern covering the files touched:
   npx jest --testPathPatterns "<affected-slug>" --no-coverage
   # or
   npx vitest run "<affected-slug>"
   ```

3. **Build** (only if core infra / global pipes / middleware changed — Phase 1 should have flagged):
   ```bash
   npx next build  # or npm run build for backend
   ```

4. **Backend curl** (only if backend changes):
   - `curl localhost:8080/api/v1/health` must return 200.
   - At least one authenticated endpoint on the changed path to confirm no 500.

5. Any failure here → STOP, report to Bernard, do not push.

### Phase 5 — Commit & push

1. **Stage specific files by name — NEVER `git add -A` or `git add .`**:
   ```bash
   git add <file-1> <file-2>
   git status  # verify only the intended files are staged
   ```
   If `git status` shows anything unexpected (e.g., an untracked migration that sneaked in), unstage it with `git reset HEAD -- <path>` BEFORE committing.

2. **Commit with a conventional message** describing WHY, not just what:
   ```bash
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <short imperative> (remedy for #<n>)

   <paragraph describing what was remedied and why — reference the concerns
   Phase 1 identified>
   EOF
   )"
   ```
   No `Co-Authored-By: Claude`. Verify email: `git log -1 --format=fuller`.

3. **Push to the PR branch with `--force-with-lease` keyed to the remote SHA captured in Phase 2**:
   ```bash
   git push origin local-testing:<head-ref> \
     --force-with-lease=<head-ref>:$OLD_REMOTE_SHA
   ```
   `--force-with-lease` fails loudly if the author pushed while we worked → abort cleanly instead of clobbering.

4. **Verify the PR picked it up**:
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json headRefOid,additions,deletions,changedFiles --jq '.'
   ```
   `headRefOid` must match the SHA we just pushed.

### Phase 6 — Metadata sweep

Every remedied PR leaves with proper metadata. All via `gh api` (not `gh pr edit`, which silently fails on Projects-classic deprecation).

1. **Title** — conventional commits if it isn't already:
   ```bash
   gh api repos/<owner>/<repo>/pulls/<n> --method PATCH -f title="<type>(<scope>): <description> (VISAL-XXX)"
   ```

2. **Body** — Summary / Changes / Test plan. Minimum 10 lines:
   ```bash
   gh api repos/<owner>/<repo>/pulls/<n> --method PATCH -f body="$BODY"
   ```

3. **Labels** — type + domain (never empty):
   ```bash
   gh api repos/<owner>/<repo>/issues/<n>/labels --method POST \
     -f "labels[]=<bug|enhancement|chore|tech-debt>" \
     -f "labels[]=<frontend|backend|chat|drafts|projects>"
   ```

4. **Verify every edit saved** (Projects-classic error makes `gh pr edit` return non-zero exit code even when the API call partially succeeds):
   ```bash
   gh pr view <n> --repo <owner>/<repo> --json title,body,labels --jq '{title, labels: [.labels[].name], body_lines: (.body | split("\n") | length)}'
   ```

5. **Process every unresolved review thread from Phase 0.5** — this happens BEFORE the approve. Per `git.md` "AI Review Thread Handling": reply inline, then resolve. A bulk PR comment is invisible in the diff view; only inline replies are useful to reviewers.

   For each thread in your Phase 0.5 mapping table, pick the appropriate reply pattern:

   | Outcome of the thread | Reply body pattern |
   |---|---|
   | Folded into remedy commit (small fix) | `Addressed in <sha> — <one-line explanation of the fix>.` |
   | Already covered by an earlier PR commit (no remedy needed) | `Already addressed by <commit-sha> earlier in this PR — <one-line proof>.` |
   | Outdated (line/code no longer exists) | `Outdated — the line/condition this thread targets no longer exists at <sha>.` |
   | Different (and better) approach than the suggestion | `Addressed in <sha> via a different angle. <Brief explanation of why my approach is preferred.>` Real example: Copilot suggested logging inside `convertDocxToPdf` only; the remedy added `logRejectedFetches` in `mergePdfs` — the broader location catches conversion + S3 fetch + PDFLib.load failures, not just conversion failures. |

   **Forbidden in any reply body** (same forbidden list as approval bodies — Same PR channel rule applies here too): "out of scope here", "follow-up PR with `Part of VISAL-XXX`", "open question for follow-up", "tracked separately". If a thread's finding wasn't covered by the remedy and isn't a no-op, the answer is NOT to resolve it with a deferral phrase — it is to STOP and ask Bernard whether to fold the fix in or expand scope.

   Reply + resolve mutations:
   ```bash
   # Reply inline to the thread (use -F + variables to avoid shell-escape issues with backticks)
   gh api graphql \
     -F threadId="<PRRT_xxx>" \
     -F body="<reply body per pattern above>" \
     -f query='mutation($threadId: ID!, $body: String!) {
       addPullRequestReviewThreadReply(input: { pullRequestReviewThreadId: $threadId, body: $body }) {
         comment { id }
       }
     }'

   # Resolve the thread
   gh api graphql \
     -F threadId="<PRRT_xxx>" \
     -f query='mutation($threadId: ID!) {
       resolveReviewThread(input: { threadId: $threadId }) {
         thread { isResolved }
       }
     }'
   ```

6. **Verify zero unresolved threads remain** — gate before approve. Re-run the Phase 0.5 GraphQL query and confirm every thread reports `isResolved: true`:
   ```bash
   gh api graphql -F owner=<owner> -F name=<repo> -F number=<n> -f query='
   query($owner: String!, $name: String!, $number: Int!) {
     repository(owner: $owner, name: $name) {
       pullRequest(number: $number) {
         reviewThreads(last: 100) {
           nodes { id isResolved }
         }
       }
     }
   }' --jq '[.data.repository.pullRequest.reviewThreads.nodes[] | select(.isResolved == false)]'
   ```
   Expected: `[]`. If any thread is still unresolved, **STOP** — do not approve. Either there's a thread you missed (re-check Phase 0.5 mapping) or the resolve mutation silently failed (re-run it).

7. **Approve** — never rubberstamp. The body references the findings from Phase 1, the work from Phases 2-5, and the threads processed in step 5 above. **Forbidden in the approval body**: any phrase suggesting a follow-up PR (e.g., "Worth a follow-up PR with `Part of VISAL-XXX`", "Out of scope here, but…", "Open question for follow-up", "Tracked separately"). If a finding wasn't folded into this PR's commits, it doesn't get mentioned as future work in the approval — it gets handled per the "Same PR channel" decision table. See "Same PR channel" above.
   ```bash
   gh api repos/<owner>/<repo>/pulls/<n>/reviews --method POST -f event="APPROVE" -f body="<thoughtful comment>"
   ```

### Phase 7 — Report & stop (DO NOT MERGE)

Final state report to Bernard:

```
## PR #<n> — ready for the green button

| Field | Value |
|---|---|
| URL | <full-url> |
| State | OPEN (APPROVED by bernarduriza-visalaw) |
| mergeStateStatus | CLEAN / UNSTABLE (CI running) |
| Head commit | <short-sha> — "<subject>" |
| Remedy summary | <1-sentence what was fixed> |

## What's left
- [ ] Squash-merge (you) — suggested `--subject "<conventional-title>"`
- [ ] Delete branch (auto if `--delete-branch`)
- [ ] Plane auto-transition to Done on merge (assuming VISAL-XXX linked in PR title or body)

No merge executed. Your call.
```

**Do not invoke `gh pr merge` unless Bernard explicitly confirms.** The command ends here.

### Phase 8 (optional, only if Bernard says "merge")

1. `gh pr merge <n> --repo <owner>/<repo> --squash --subject "<exact-title> (#<n>)" --delete-branch`
2. `cd <repo> && git fetch origin <base-branch> && git reset --hard origin/<base-branch>` — sync local-testing
3. Delete stale local branches left over from the remedy flow.

## Rules

1. **Never `git add -A` or `git add .`** — always specific files by name. Violation is a bug regardless of whether it shipped.
2. **Never `git reset --hard` without running `git log --oneline local-testing ^origin/<base>` first** — verify zero unique commits would be lost. If there are unique commits, STOP and ask.
3. **Never `git stash drop` or `git clean -fd`** in this command — both can destroy work silently.
4. **Work on `local-testing` — never check out the teammate's branch directly.** Pushes go via `git push origin local-testing:<head-ref>`.
5. **`--force-with-lease` keyed to the remote SHA captured at Phase 2.6**, not bare `--force-with-lease`. Prevents silent clobber if the author pushed in parallel.
6. **Curl before push for backend changes.** Touch `/tmp/claude-curl-verified` is a hook bypass for genuinely-frontend work only.
7. **tsc MUST be 0 before push.** Tests MUST be green. No "skipping this test, it's flaky."
8. **Don't merge.** The contract ends at "approved, CI clean, ready to merge." User decides.
9. **No Co-Authored-By lines in commits.** Verify with `git log -1 --format=fuller` before push.
10. **All commits, PR titles, PR bodies, review comments in English.** Español only in conversation with Bernard.
11. **If anything unexpected appears at any phase, STOP and report.** Unexpected untracked file, stale local-testing, merge conflict, CI failure, approvals from others already present — each is a signal to pause, not to work around.
12. **Same PR channel — never create follow-up PRs.** Every fix and every additional finding stays on the original PR's branch. Approval comments must not suggest "follow-up PR with `Part of VISAL-XXX`" or any equivalent phrasing. Self-approval of a Claude-spun-up follow-up PR bypasses the human-review gate and is unacceptable. See "Same PR channel — never create follow-up PRs" above for the small-vs-large decision table.
13. **Existing review threads are mandatory input — never silently ignored.** Phase 0.5 fetches `reviewThreads` via GraphQL before any audit. Every unresolved thread is treated as a finding the remedy must cover (small → fold into commit; large → STOP and ask). At the end of Phase 6, zero unresolved threads remain — verify via the same GraphQL query. The `reviews` field from `gh pr view --json` is informational only (review bodies/states); it is NOT a substitute for the threads query.

## Anti-patterns — what NOT to do

| Anti-pattern | Why it fails | Right move |
|---|---|---|
| `git add -A` after editing 2 files | Grabs untracked migrations, stale debug files, anything else dirty | `git add <file1> <file2>` + `git status` to verify |
| `git reset --hard origin/<their-branch>` without checking local-testing | Silently deletes any commits you had ahead | `git log --oneline local-testing ^origin/<base>` first; if non-empty, STOP |
| `git pull` on the teammate's branch | Creates merge commits in their branch history — ugly, also complicates rebase | Work on local-testing, push via `<source>:<dest>` refspec |
| Squash-merging without `--subject` when branch has >1 commit | Squash message becomes the author's first commit message, losing all your remedy context | Always pass `--subject "<conventional-title> (#<n>)"` |
| `gh pr edit --title` / `--body` | Silently fails on Projects-classic deprecation | `gh api repos/.../pulls/<n> --method PATCH -f title=... -f body=...` |
| Reviewing, approving, and merging in one sweep | Robs the human of the squash-merge decision they explicitly reserved | Stop at approved. Report. Wait. |
| "Fixing" a PR that has approvals from teammates already | Your force-push dismisses their reviews (on frontend: `dismiss_stale_reviews_on_push: true`) | STOP, ask Bernard: "Katie already approved — proceed anyway?" |
| Suggesting "follow-up PR with `Part of VISAL-XXX`" in the approval body | A follow-up PR Claude opens and then approves on Bernard's behalf is self-approval. Even when the original PR was bot-authored, the SECOND approval bypasses human review. | Fold the fix into the same remedy commit (small finding) or STOP and ask Bernard (large finding). Never write any "follow-up" framing in the approval body. |
| Spinning up a new branch + PR mid-`/remedy-mr` because findings expanded | `/remedy-mr` is single-channel by contract — every fix lives on the original PR's branch | If the finding fits, fold it into the same commit and force-push. If it doesn't fit, STOP and ask. |
| Trusting `gh pr view --json reviews` as the complete reviewer feedback surface | `reviews` returns only review bodies/overviews — the actual inline findings from Copilot/VAIR/CodeRabbit live in `reviewThreads` (a separate GraphQL surface). Skipping the GraphQL query means missing the review's actual content. | Run the Phase 0.5 GraphQL query for `reviewThreads` BEFORE the Phase 1 audit. Treat its output as mandatory input. |
| Doing your own audit and shipping a remedy without checking what reviewers already said | You either duplicate work the bot already did or, worse, miss a finding the bot documented with a code suggestion already attached. The remedy ships incomplete and the user has to ask "did you see Copilot's comments?" | Phase 0.5 first. Map your Phase 1 findings against existing threads. Fold every uncovered thread into the same remedy commit (small) or STOP and ask (large). |
| Resolving a thread with "out of scope" / "follow-up PR" / "tracked separately" | Same forbidden list as approval bodies (Same PR channel rule). A resolve with one of these phrases is silently dropping a finding while pretending it's been addressed. | Either fold the fix into the remedy and resolve with "Addressed in `<sha>`", or STOP and ask Bernard. The third option (resolve without addressing) does not exist. |

## Short-circuits (valid "did nothing" outcomes)

- PR is already merged → report merge commit, exit.
- PR is draft → report draft status, exit unless re-confirmed.
- PR diff is 100% clean per Phase 1 → approve with LGTM, fix metadata, exit.
- All findings from existing reviewer threads (Phase 0.5) are already covered by previous commits in the PR or are no-ops on the current code → reply explaining the coverage + resolve each thread + LGTM approve, fix metadata, exit. Don't fabricate a remedy commit when nothing needs changing — the value is processing the existing review and closing the threads, not adding code.
- CI was already red when we started → report CI state, do not remedy until CI is understood.
- `local-testing` has commits ahead that would be lost → ABORT with a clean message, propose cherry-pick targets.

## Exit reports

On success: the Phase 7 report.
On abort: plain prose explaining what condition was hit and what Bernard should do (e.g., "local-testing has 2 commits ahead of main — run `git log local-testing ^origin/main` to see them and decide: cherry-pick to a backup branch or drop them, then re-invoke /remedy-mr").

## Relationship to other commands

- **`/code-review <pr>`** — informs; identifies findings. Usually run first.
- **`/remedy-mr <pr>`** — acts; materializes the code-review's recommendations into commits. Usually run second, with Bernard's explicit consent.
- **`/merge-policeman`** — scans the queue, doesn't touch individual PRs.
- **`/ultrareview`** — deeper than `/code-review`, multi-agent. `/remedy-mr` does NOT replace this; use ultrareview first for high-risk PRs.
