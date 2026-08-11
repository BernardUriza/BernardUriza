# Registering a hook (deterministic enforcement)

## Contents
- What belongs here
- Step 1: use the injected inventory
- Which hook already owns which surface
- Step 2: extend before you create (the 90% path)
- Step 3: creating a new hook (the last 10%)
- Step 4: report

## What belongs here

A hook is what fires when a rule sitting in context did not stop the behavior. It is the
right destination when the violation is **mechanically detectable** — a pattern in the
response text, a tool argument, a branch name, a missing link — and has already happened
more than once despite the rule existing. If it can be detected neither deterministically
nor by a judge prompt, it is a rule, not a hook.

## Step 1: use the injected inventory

`SKILL.md` already injected the hook files on disk and the wiring in effect. **Do not
re-run those commands.** Read the injected wiring block: it is the truth. A file that
appears in the file list but not in the wiring block enforces nothing today.

## Which hook already owns which surface

Semantic map of the employer layer. Cross-check every row against the injected inventory
before relying on it — a hook may have been renamed, retired into `hooks/disabled/`, or
unwired since this was written.

| Surface being guarded | Hook that owns it | Event |
|---|---|---|
| Unverified claims / no evidence | `stop/bernards-law.sh` | Stop |
| Padded recommendation lists | `stop/no-padded-lists.sh` | Stop |
| Bare identifier without its full URL | `stop/no-bare-identifier.sh` | Stop |
| Missing or malformed next-step line | `stop/next-step-check.sh` | Stop |
| Architecture claims untraced to the topology map | `stop/topology-map-check.sh` | Stop |
| Framework or spec behavior recited from memory | `stop/framework-claim-check.sh` | Stop |
| Banner shape / emoji legibility | `stop/emoji-legibility.sh` | Stop |
| Handing work to a teammate instead of doing it | `stop/no-externalization.sh` | Stop |
| Slack permalink / evidence claims | `stop/slack-permalink-check.sh` | Stop |
| Outbound Slack content (person, links, unverified claims) | `slack-outbound-guard.sh` | PreToolUse, Slack send |
| Wrong branch / unsafe push | `enforce-local-testing-branch.sh` | PreToolUse Bash/PowerShell |
| `--reviewer` on a vair PR, vair review-request in Slack | `vair-no-reviewer.sh` | PreToolUse Bash/PowerShell + Slack |
| curl-before-commit gate | `pre-push-curl-check.sh` + `mark-curl-verified.sh` | Pre/PostToolUse |
| Editing without a claimed ticket | `enforce-ticket-claim.sh` | PreToolUse Edit/Write |
| Shared judge + transcript plumbing | `lib/judge-common.sh`, `lib/turn_packet.py` | library — reuse, never re-implement |
| Retired on purpose | `hooks/disabled/` — read the file before reviving it | — |

## Step 2: extend before you create (the 90% path)

The same read-and-consolidate discipline that governs rules governs hooks — harder,
because a hook that duplicates another hook does not merely bloat context, it double-blocks
turns and makes the whole layer read as noise. **In ~90% of cases the new guard belongs
INSIDE a hook that already exists.**

Match on **surface**, not topic: the event being intercepted and the thing being inspected.
A new constraint on Slack wording belongs in `slack-outbound-guard.sh`; a new constraint on
how the final response reads belongs in an existing `stop/` hook. Then take the cheapest
extension that actually works:

1. **Add the pattern to an existing detector** — a keyword, a regex, another case in a
   `case` block. Most registrations end here.
2. **Tune an existing threshold or judge prompt** — the hook already watches the right
   surface, it is just too loose or too strict.
3. **Point a NEW matcher at an EXISTING script** — same script, new event or tool, zero new
   code.
4. **Split a hook only when it has become two hooks in a trench coat** — different event,
   different failure mode, different evidence.

Report which of these you took and why the others did not fit. "I created a new hook"
without that sentence means the 90/10 rule was skipped.

## Step 3: creating a new hook (the last 10%)

Justified only when the surface is genuinely new: a different event, a different tool
matcher, or a check no existing hook can host without becoming incoherent. Then:

- Reuse `lib/judge-common.sh` and `lib/turn_packet.py`. Never re-implement transcript
  parsing or the judge call.
- Block with **exit code 2 and the reason on stderr**. On a Stop hook, exit 2 prevents
  Claude from stopping and forces it to continue; anything else is advisory and will be
  ignored under output pressure — the exact failure the hook exists to catch.
- **Wire it in `.claude/settings.local.json`** under the correct event and matcher. An
  unwired hook file is the #1 silent failure of this layer: it looks registered and
  enforces nothing. Verify with the `/hooks` menu, which shows every configured hook and
  its source read-only.
- **Prove it fires.** Trigger the condition and show the block. A hook that has never
  blocked anything is worse than no hook — it manufactures a false sense of safety.
- Keep it fast. Stop hooks run on every turn; a slow hook taxes every future session.
- Add the twin one-line rule pointer so the instruction and the enforcement stay married.

### Alternative: scope the hook to a skill instead of the whole session

A hook that should only apply while one workflow runs does not belong in
`settings.local.json` at all. Skill and agent frontmatter accept a `hooks:` field using the
exact same JSON shape as the settings file, scoped to that component's lifetime and cleaned
up automatically when it finishes. Prefer this when the guard is meaningless outside the
workflow — it keeps the always-on layer small.

```yaml
---
name: secure-operations
hooks:
  PreToolUse:
    - matcher: "Bash"
      hooks:
        - type: command
          command: "${CLAUDE_SKILL_DIR}/scripts/security-check.sh"
---
```

## Step 4: report

Name the file changed, whether it was an extension or a new file, the exact wiring entry,
and the evidence that it fires. No evidence = not registered.
