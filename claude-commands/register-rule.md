# Register Custom Rule

This command handles several kinds of input — **detect which one FIRST**, before doing anything else:

1. A **roadmap / backlog item** (a feature, a vision, a proposal not yet built) → Type 0
2. A behavioral **rule / guideline** (how the agent should act) → Type 1
3. A **secret / credential** → Type 2
4. Shared **documentation / findings** → Type 3

The most common mis-file is sending a roadmap idea through the rule path. Run the Type 0 check BEFORE Type 1.

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

## After registering a rule (Type 1 only)

- **Technical-universal** rules are already propagated the moment you push `engineering-playbook` — the `~/.claude/rules/playbook` symlink delivers them to every repo at next session start. No further sync step.
- The legacy `/sync-rules` → AI-reviewer flow (pushing to `.github-org/ai-rules/rules/shared/`) is **deprecated** and slated for removal in the cleanup phase (it was part of the old per-repo `sync-rules` system being retired). Do NOT invoke `/sync-rules` for newly routed rules.
