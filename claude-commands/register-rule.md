# Register — rules, hooks, memory, secrets, docs, backlog

This command registers something for posterity. It handles several destinations, and the
**first move is always to ask which one**, not to silently classify.

## MOOD — ask FIRST, in a single AskUserQuestion

Before any grep, any classification, any file write, fire ONE `AskUserQuestion`:

> **"¿Cómo quieres registrar esto?"** — header `Registro`

| Option | Destination | It is… |
|---|---|---|
| **Hook** | `.claude/hooks/` + `settings.local.json` wiring | deterministic ENFORCEMENT — the turn or tool call is blocked when violated (Type H) |
| **Regla** | `~/.claude/rules/` · `engineering-playbook/rules/` · `./.claude/rules/` | INSTRUCTION — how the agent must act (Type 1) |
| **Memoria** | `~/.claude/projects/<sanitized-cwd>/memory/` | an operational FACT about this repo/product (Type M) |
| **Otro** | secret / doc / backlog / no template at all | Types 0, 2, 3 — or Type X |

Rules for the MOOD step:

- **Compute your recommendation BEFORE asking** and put it first, labeled `(Recomendado)`,
  with the reason in the description. Asking blind is lazy; the question exists to let
  Bernard override your read, not to outsource the thinking to him.
- **Skip the ask only when he already named the destination** ("regístralo como hook",
  "esto va a memoria"). Naming it IS the answer — re-asking something already decided is
  disobedience wearing a safety vest (`15-slash-command-obedience`).
- **Hook and rule are not exclusive.** Most enforceable corrections want BOTH: a rule that
  states it and a hook that catches it when the rule-in-context fails. Offer that pairing
  in the same question (`multiSelect: true`).

## The format is a SUGGESTION, not a straitjacket

Every template below is a default shape, not a gate. If what Bernard is registering does
not fit any of them, **do NOT bend it into the closest one** — decide the shape the thing
actually needs, write it that way, and say in one line why you departed. Forcing an input
through a rigid rule-shaped hole is what made past registrations useless: the content
survived, the meaning did not. Think about what deserves to persist, then pick the
container. These are the containers that already exist, ordered by how often they are right:

1. **Hook** — deterministic enforcement → Type H
2. **Rule / guideline** — how the agent should act → Type 1
3. **Memory** — an operational fact worth not being told twice → Type M
4. **Roadmap / backlog item** — something to build later → Type 0
5. **Secret / credential** → Type 2
6. **Shared documentation / findings** → Type 3
7. **None of the above** → Type X

The most common mis-file is sending a roadmap idea through the rule path. Run the Type 0
check BEFORE Type 1.

## Type 0: Roadmap / Backlog items (features, visions, proposals)

When the user is **capturing something to build later** — a feature, a product
vision, a stakeholder proposal — it is a **backlog item, NOT a rule**. A rule
tells the agent how to *act*; a backlog item records *something to build*. Do not
file it under `.claude/rules/`.

### Detect Type 0 (check these first)

- A capability that **doesn't exist yet**: "I want to give them X", "build an
  assistant that…", "a CMS so they can…".
- A **vision / roadmap direction**: "my vision for this project is…".
- A **proposal**: "Miguel suggested…", "someone proposed…".
- **Desiderative / future tense**: *quisiera, me gustaría, sería bueno, algún día,
  deberíamos, podríamos*.

If it's a behavior ("always/never do X", a correction of how you worked) → it's a
rule (Type 1), not backlog.

### Route it

Backlog is **per-repo**: write to **`./.claude/backlog/<slug>.md`** in the
current repo and add a one-line entry to `./.claude/backlog/README.md` (create
the folder + index if absent). Governed by the universal
`backlog-handling.md` rule (in `engineering-playbook`, delivered via the
`~/.claude/rules/playbook` symlink) — read it for the item shape:

```markdown
# <Title>

Status: Proposed | Accepted | In progress | Done | Dropped
Proposed: <YYYY-MM-DD> by <who>

## What it is
## Canonical path to reuse (Art. 6)
## The decision that's the owner's
## Status / next step
```

If the proposal ALSO encodes a hard prohibition, file the backlog item here AND
register the prohibition separately as a Type 1 rule; link them, don't merge.

## Type 1: Rules & Guidelines

When the user provides a new rule or guideline, the **FIRST decision is which LEVEL it belongs to** — NEVER write flat to the current repo's `.claude/rules/`. That flat-write is the exact bug that scattered Bernard's rules across 35+ repos. Route by level:

### Step 0 — Read & consolidate BEFORE writing (mandatory; do NOT append blind)

The default failure of this command is ADDING a fresh block without checking what
already exists — producing duplicate/contradictory sections that bloat the auto-load
layer (`90-memory-policy`: target <20k, hard cap 30k tokens). Before writing one line:

1. Extract the rule's core concept + 3-6 keywords.
2. Grep the relevant rules tree(s):
   `grep -rniE "<kw1>|<kw2>|<kw3>" ~/.claude/rules/ ~/Documents/engineering-playbook/rules/ ./.claude/rules/ 2>/dev/null`
3. Read every candidate section the grep surfaces, then:
   - **Already covered** → write NOTHING; report `already in <file>:<line>` and stop.
   - **Partially covered / a section already owns the topic** → EDIT that section
     surgically to integrate the new point. NEVER stack a new block on top of — or
     contradicting — content that already covers the theme.
   - **Genuinely absent** → only then add, under the most appropriate existing file.
4. Default = edit/consolidate. Appending when a section already covers the theme is
   FORBIDDEN. No grep output proving absence = no right to add a block. Auto-load
   edits must not grow the layer past the cap — tighten existing lines before adding.

*Anchor 2026-06-29: in one session Claude appended four times (claude-incidents,
20-honesty, two sections to 50-output-handling — one contradicting the existing cdb
section) instead of consolidating. Bernard: "agregar más rules para saturar la ventana
porque te da hueva leer lo que ya hay y modificarlo." This STEP 0 (present in the old
local register-rule, lost in this global one) exists so that never repeats.*

### Step 1 — Classify the level

| Level | Destination | When |
|-------|-------------|------|
| **Technical-universal** | `~/Documents/engineering-playbook/rules/<name>.md` | Employer/project-agnostic engineering methodology: how you build, test, refactor, log, review, lay out UI, handle git, communicate. Applies to ANY repo, language, or employer. |
| **Personal / OE** | `~/Documents/SerenityOps/.claude/rules/<name>.md` | Overemployment doctrine, identity layers, finances, job-search, CV, recruiters, crypto — anything sensitive that must NEVER load in an employer's repo. |
| **Repo-specific** | `./.claude/rules/<name>.md` (current repo only) | Tied to THIS project: its architecture, its deploy, its particular stack, its file conventions. |

### Step 2 — Auto-detect; ask only if genuinely ambiguous

Signals:
- **Technical-universal**: "always do X in any project", TDD / refactor / git / logging / naming / CSS / debugging / standup / demo workflow — names no company and no repo.
- **Personal / OE**: mentions employers, OE, CV, LinkedIn, finances, crypto, identity, job search, recruiters.
- **Repo-specific**: names this repo, its specific stack, its deploy, or concrete files in this project.

If you can't tell, ask exactly one question: "¿Esta regla es (a) metodología general para todos tus repos, (b) algo personal/OE, o (c) específica de este proyecto?"

### Step 3 — Write and propagate

- **Technical-universal** → write to `~/Documents/engineering-playbook/rules/`, add a one-line entry to that repo's `README.md` index, then `git -C ~/Documents/engineering-playbook add -A && git -C ~/Documents/engineering-playbook commit && git -C ~/Documents/engineering-playbook push` (if offline, commit locally and report the pending push). It reaches every repo via the `~/.claude/rules/playbook` symlink — **no per-repo copy**.
- **Personal / OE** → write to `~/Documents/SerenityOps/.claude/rules/`. Do NOT symlink to user-level — it must never load in employer repos.
- **Repo-specific** → write to the current repo's `.claude/rules/` and update its `CLAUDE.md` index if it's a new category.

**Language by destination**: engineering-playbook → **English** (employer-agnostic, professional). SerenityOps personal/OE → **español** (match the existing OE rules). Repo-specific → match that repo's convention.

**Before writing, ALWAYS** check the destination for an existing file on the same topic and append there instead of creating a new one. The entire point of this routing is to STOP duplication — creating a new file when a sibling already covers the topic re-introduces the exact bug we are killing.

## Type 2: Secrets, Tokens, Passwords & Credentials

When the user provides a token, password, API key, or any credential:

**NEVER** write secrets to:
- `.claude/rules/` (committed to repo)
- `.claude/` anything (committed to repo)
- Memory files
- Any file inside the repo

**ALWAYS** write secrets to `~/.secrets/` (outside all repos):

1. Detect the secret type from context (API token, password, OAuth key, etc.)
2. Determine a descriptive filename: `~/.secrets/<service>-<purpose>.txt`
3. Write the secret to that file with metadata:
   ```
   <Service> <purpose> token
   Created: <date>
   Scope: <read-only, org:ci, etc. — if known>

   <KEY_NAME>=<value>
   ```
4. Update the secrets map in `.claude/rules/security.md` (the table under "Local Secrets Map")
5. If the secret is for an MCP server, offer to configure it in `~/.claude.json`

### Detection patterns (auto-detect, don't ask):

| Pattern | Type | Example |
|---------|------|---------|
| `sntrys_*`, `sntryu_*` | Sentry token | `~/.secrets/sentry-<purpose>.txt` |
| `ghp_*`, `github_pat_*` | GitHub PAT | `~/.secrets/github-<purpose>.txt` |
| `sk-*`, `sk-proj-*` | OpenAI key | `~/.secrets/openai-<purpose>.txt` |
| `xoxb-*`, `xoxp-*` | Slack token | `~/.secrets/slack-<purpose>.txt` |
| `eyJ*` (base64 JWT) | JWT / auth token | `~/.secrets/<service>-token.txt` |
| Contains `@` + password context | Login credentials | `~/.secrets/<service>-login.txt` |
| `PLANE_PAT=*` | Plane personal API key | `~/.secrets/plane_pat.txt` |
| Any string the user explicitly calls a token/key/password/secret | Generic secret | `~/.secrets/<context>.txt` |

### How to distinguish Type 0 vs Type 1 vs Type 2:

- If the input describes a **feature/vision/proposal to build later** (something that doesn't exist yet, desiderative tense) → **Type 0 (backlog)**
- If the input contains a token pattern (above) or the user says "token", "key", "password", "secret", "credential" → **Type 2**
- If the input describes a **behavior** the agent should follow ("always/never do X") → **Type 1**
- If ambiguous between backlog and rule, prefer **Type 0** and link any embedded prohibition out to a Type 1 rule.

## Type 3: Documentation & Technical Findings

When the user provides meeting transcripts, technical analysis, audit results, or team decisions that should be shared:

### Detection patterns (auto-detect, don't ask):

| Pattern | Destination | Example |
|---------|-------------|---------|
| Meeting transcript, huddle notes, call summary | `engineering-notes/weekly/` or `engineering-notes/workflow/` | Sprint decisions, feature discussions |
| Migration script, cleanup script, one-off tool | `engineering-notes/audits/<topic>/` | `audits/jdsupra-pinecone-migration/` |
| Audit results, CSV data, validation output | `engineering-notes/audits/<topic>/` | Chunk audit, parity check |
| Architecture decision, design proposal | `engineering-notes/proposals/` | New feature design, decomposition plan |
| Benchmark results, performance comparison | `engineering-notes/benchmarks/` | LLM latency, build times |
| Incident postmortem, RCA | `engineering-notes/audits/` | Root cause analysis with timeline |
| Checklist, test plan, launch criteria | `engineering-notes/checklists/` | UAT plan, go/no-go criteria |

### How to distinguish from Type 1 and Type 2:

- If the input describes a **behavior Claude should follow** → Type 1 (rule)
- If the input contains a **token/key/password** → Type 2 (secret)
- If the input is **knowledge the team should have** (findings, decisions, analysis, scripts, meeting notes) → **Type 3 (documentation)**
- Key signals for Type 3: meeting transcript text, audit data, "the team should know", analysis with data, scripts that solve a specific problem

### Procedure:

1. **Extract key information** from the input:
   - For meetings: decisions made, action items, owners, deadlines, unresolved questions
   - For audits: findings, data, recommendations, execution plan
   - For proposals: problem statement, proposed solution, trade-offs, timeline

2. **Determine the correct folder** in `engineering-notes/` based on the detection table above

3. **Write the documentation** in English (language rule applies):
   - Every doc gets a `README.md` with clear sections
   - Include date, owner, and context
   - For scripts: include the script file + README explaining it
   - For meeting notes: extract structured notes, not raw transcript

4. **Commit + push immediately** — engineering-notes is a shared repo:
   ```bash
   cd engineering-notes
   git add <files>
   git commit -m "docs(<folder>): <short description>"
   git push origin main
   ```

5. **Report the GitHub URL** so it can be shared in Slack:
   ```
   https://github.com/Visalaw/engineering-notes/blob/main/<path>
   ```

### Rules for Type 3:

- **Never dump raw transcripts** — always extract and structure the information
- **Always include a README.md** in new folders explaining the context
- **Convert relative dates to absolute** — "next Friday" → "2026-04-10"
- **Tag owners** — every action item needs a name
- **Link to Plane issues** where applicable — `VISAL-XXX`

### Why This Type Exists

On 2026-04-02, Ram shared a 68K-chunk Pinecone migration script as a Slack attachment. The 330KB audit CSV previewed as 9 rows in Slack, causing a false alarm. Bernard and Ram agreed: all technical artifacts go in `engineering-notes/`, not Slack. This type automates that workflow — when someone shares findings or scripts in conversation, `/register-rule` detects it and writes it to the right place in engineering-notes.

## Type H: Hooks (deterministic enforcement)

A hook is what fires when a rule sitting in context did not stop the behavior. It is the
right destination when the violation is **mechanically detectable** (a pattern in the
response text, a tool argument, a branch name, a missing link) and has already happened
more than once despite the rule existing. If it cannot be detected deterministically or
by a judge prompt, it is a rule, not a hook.

### Step H0 — Inventory what is already wired (MANDATORY, before writing one line)

The same read-and-consolidate discipline that governs rules (Type 1, Step 0) governs
hooks — harder, because a hook that duplicates another hook does not merely bloat the
context, it double-blocks turns and makes the whole layer read as noise. **In ~90% of
cases the new guard belongs INSIDE a hook that already exists.** Creating a file is the
remaining 10%.

```bash
find ~/.claude/hooks .claude/hooks -maxdepth 2 -type f | sort
# The WIRING is the truth, not the file list — an unwired hook does nothing:
python -c "import json;d=json.load(open('.claude/settings.local.json',encoding='utf-8-sig'));print(json.dumps(d.get('hooks'),indent=1))"
```

Snapshot verified in `D:\repos\Visalaw` on 2026-08-06 — re-run the commands above before
trusting it; this table is a starting point, not the source of truth:

| Surface already guarded | Hook that owns it | Event |
|---|---|---|
| Unverified claims / no evidence | `stop/bernards-law.sh` | Stop |
| Padded recommendation lists | `stop/no-padded-lists.sh` | Stop |
| Bare identifier without its full URL | `stop/no-bare-identifier.sh` | Stop |
| Missing / malformed next-step line | `stop/next-step-check.sh` | Stop |
| Architecture claims untraced to the topology map | `stop/topology-map-check.sh` | Stop |
| Framework or spec behavior recited from memory | `stop/framework-claim-check.sh` | Stop |
| Banner shape / emoji legibility | `stop/emoji-legibility.sh` | Stop |
| Handing work to a teammate instead of doing it | `stop/no-externalization.sh` | Stop |
| Slack permalink / evidence claims | `stop/slack-permalink-check.sh` | Stop |
| Outbound Slack content (person, links, unverified claims) | `slack-outbound-guard.sh` | PreToolUse `slack_send_message` |
| Wrong branch / unsafe push | `enforce-local-testing-branch.sh` | PreToolUse `Bash\|PowerShell` |
| `--reviewer` on a vair PR, vair review-request in Slack | `vair-no-reviewer.sh` | PreToolUse `Bash\|PowerShell` + Slack |
| curl-before-commit gate | `pre-push-curl-check.sh` + `mark-curl-verified.sh` | Pre/PostToolUse |
| Editing without a claimed ticket | `enforce-ticket-claim.sh` | PreToolUse `Edit\|Write` |
| Shared judge + transcript plumbing | `lib/judge-common.sh`, `lib/turn_packet.py` | library — reuse, never re-implement |
| Retired on purpose | `hooks/disabled/` — read the file before reviving it | — |

### Step H1 — Extend before you create (the 90% path)

Match on **surface**, not topic: the event being intercepted and the thing being
inspected. A new constraint on Slack wording belongs in `slack-outbound-guard.sh`; a new
constraint on how the final response reads belongs in an existing `stop/` hook. Then take
the cheapest extension that actually works:

1. **Add the pattern to an existing detector** — a keyword, a regex, another case in a
   `case` block. Most registrations end here.
2. **Tune an existing threshold or judge prompt** — the hook already watches the right
   surface, it is just too loose or too strict.
3. **Point a NEW matcher at an EXISTING script** — same script, new event or tool, zero
   new code.
4. **Split a hook only when it has become two hooks in a trench coat** — different event,
   different failure mode, different evidence.

Report which of these you took and why the others did not fit. "I created a new hook"
without that sentence means the 90/10 rule was skipped.

### Step H2 — Creating a new hook (the last 10%)

Justified only when the surface is genuinely new: a different event, a different tool
matcher, or a check no existing hook can host without becoming incoherent. Then:

- Reuse `lib/judge-common.sh` and `lib/turn_packet.py`. Never re-implement transcript
  parsing or the judge call.
- Block with **exit code 2 and the reason on stderr**. Anything else is advisory and will
  be ignored under output pressure — which is the exact failure the hook exists to catch.
- **Wire it in `.claude/settings.local.json`** under the correct event and matcher. An
  unwired hook file is the #1 silent failure of this layer: it looks registered and
  enforces nothing.
- **Prove it fires.** Trigger the condition and show the block. A hook that has never
  blocked anything is worse than no hook — it manufactures a false sense of safety
  (`20-honesty`: a malformed check is not a negative result).
- Keep it fast. Stop hooks run on every turn; a slow hook taxes every future session.
- Add the twin one-line rule pointer so the instruction and the enforcement stay married.

### Step H3 — Report

Name the file changed, whether it was an extension or a new file, the exact wiring entry,
and the evidence that it fires. No evidence = not registered.

## Type M: Memory (operational facts — the default for "don't make me say it twice")

Governed by `~/.claude/rules/90-memory-policy.md`. Route here anything that is a **fact
about this repo, product or tooling** rather than a behavior: which org is internal vs a
customer, what parameter an API takes, a schema quirk, a path gotcha, what a flag actually
does, where a credential lives (never its value — that is Type 2).

Destination: `~/.claude/projects/<sanitized-cwd>/memory/<slug>.md`, plus **one line** in
that directory's `MEMORY.md` index (`- [Title](file.md) — hook`). For this repo the
directory is `C:\Users\buo45\.claude\projects\D--repos-Visalaw\memory\`.

```markdown
---
name: <short-kebab-case-slug>
description: <one-line summary — used to decide relevance during recall>
metadata:
  type: user | feedback | project | reference
---

<the fact. For feedback/project, follow with **Why:** and **How to apply:** lines.
Link related memories with [[their-name]].>
```

Discipline:

- **Consolidate, don't stack** — read the existing memory files first; if one already
  covers the topic, UPDATE it. A duplicate memory is a future contradiction.
- Convert relative dates to absolute.
- Do NOT save what the repo already records (code structure, git history, `CLAUDE.md`) or
  what only matters to this conversation.
- Delete memories that turn out to be wrong. A stale memory outranks nothing.
- `MEMORY.md` is an index, never a content store: one line per memory, no frontmatter.

## Type X: It doesn't fit any of the above

A legitimate outcome, not an error. When the thing worth persisting has no container — a
decision log, a diagram, a checklist, a piece of context that is neither rule nor fact nor
doc — do this instead of forcing it:

1. Say in one line what it actually is and why no existing type fits.
2. Propose the destination and the shape you think it deserves.
3. Write it there, and add whatever index line makes it findable again.

The failure this prevents: a registration mangled into a rule because "rule" was the only
shape on offer, and therefore useless when it was needed.

## After registering a rule (Type 1 only)

- **Technical-universal** rules are already propagated the moment you push `engineering-playbook` — the `~/.claude/rules/playbook` symlink delivers them to every repo at next session start. No further sync step.
- The legacy `/sync-rules` → AI-reviewer flow (pushing to `.github-org/ai-rules/rules/shared/`) is **deprecated** and slated for removal in the cleanup phase (it was part of the old per-repo `sync-rules` system being retired). Do NOT invoke `/sync-rules` for newly routed rules.
