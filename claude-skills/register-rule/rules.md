# Registering a rule or guideline

A rule tells the agent how to **act**. If it describes something to build later, stop and
read [backlog.md](backlog.md) instead — that misfile is the most common one.

## Step 0: read and consolidate BEFORE writing (mandatory, do NOT append blind)

The default failure of this path is ADDING a fresh block without checking what already
exists — producing duplicate or contradictory sections that bloat the auto-load layer
(`90-memory-policy`: target under 20k tokens, hard cap 30k). Before writing one line:

1. Extract the rule's core concept plus 3-6 keywords.
2. Grep the relevant rules trees. `SKILL.md` already injected the list of rule filenames;
   this searches their contents:
   ```bash
   grep -rniE "<kw1>|<kw2>|<kw3>" ~/.claude/rules/ ~/Documents/engineering-playbook/rules/ ./.claude/rules/ 2>/dev/null
   ```
3. Read every candidate section the grep surfaces, then:
   - **Already covered** → write NOTHING; report `already in <file>:<line>` and stop.
   - **Partially covered, or a section already owns the topic** → EDIT that section
     surgically to integrate the new point. Never stack a new block on top of — or
     contradicting — content that already covers the theme.
   - **Genuinely absent** → only then add, under the most appropriate existing file.
4. Default = edit and consolidate. No grep output proving absence = no right to add a
   block. Auto-load edits must not grow the layer past the cap: tighten existing lines
   before adding new ones.

*Anchor 2026-06-29: in one session Claude appended four times (claude-incidents, 20-honesty,
two sections to 50-output-handling — one contradicting the existing cdb section) instead of
consolidating. Bernard: "agregar más rules para saturar la ventana porque te da hueva leer
lo que ya hay y modificarlo."*

## Step 1: classify the level

NEVER write flat to the current repo's `.claude/rules/` by reflex. That flat-write is the
bug that scattered Bernard's rules across 35+ repos.

| Level | Destination | When |
|---|---|---|
| **Technical-universal** | `~/Documents/engineering-playbook/rules/<name>.md` | Employer- and project-agnostic engineering methodology: how you build, test, refactor, log, review, lay out UI, handle git, communicate. Applies to ANY repo, language or employer. |
| **Personal / OE** | `~/Documents/SerenityOps/.claude/rules/<name>.md` | Overemployment doctrine, identity layers, finances, job search, CV, recruiters, crypto — anything sensitive that must NEVER load in an employer's repo. |
| **Repo-specific** | `./.claude/rules/<name>.md` (current repo only) | Tied to THIS project: its architecture, its deploy, its stack, its file conventions. |

Signals: technical-universal names no company and no repo. Personal/OE mentions employers,
OE, CV, LinkedIn, finances, crypto, identity, job search, recruiters. Repo-specific names
this repo, its stack, its deploy, or concrete files in it.

If you genuinely cannot tell, ask exactly one question: "¿Esta regla es (a) metodología
general para todos tus repos, (b) algo personal/OE, o (c) específica de este proyecto?"

## Step 2: write and propagate

- **Technical-universal** → write to `~/Documents/engineering-playbook/rules/`, add a
  one-line entry to that repo's `README.md` index, then commit and push that repo. It
  reaches every repo through the `~/.claude/rules/playbook` symlink — no per-repo copy. If
  offline, commit locally and report the pending push.
- **Personal / OE** → write to `~/Documents/SerenityOps/.claude/rules/`. Do NOT symlink it
  to the user level; it must never load in an employer's repo.
- **Repo-specific** → write to the current repo's `.claude/rules/` and update its
  `CLAUDE.md` index only if it is a new category.

**Language by destination**: engineering-playbook → English (employer-agnostic). SerenityOps
personal/OE → español, matching the existing OE rules. Repo-specific → that repo's
convention.

Before writing, check the destination for an existing file on the same topic and integrate
there instead of creating a sibling. The entire point of this routing is to stop
duplication; a new file when a sibling already covers the topic re-introduces the bug.

## Promotion into the auto-load layer

A behavioral rule enters `reference/` (or the matching long doc) by default. It may be
promoted into `~/.claude/rules/` only if ALL of these hold: it is an invariant, its compact
form is under ~1KB, it affects nearly every session, and Bernard explicitly approves the
promotion. Anything failing these stays in reference. When in doubt, reference.

## Consider pairing it with a hook

If the rule is mechanically detectable and has already been violated despite existing, the
rule alone will not hold. Offer the hook twin — see [hooks.md](hooks.md).

## After registering

Technical-universal rules are propagated the moment `engineering-playbook` is pushed; the
`~/.claude/rules/playbook` symlink delivers them at next session start, with no further
sync step. The legacy `/sync-rules` flow into `.github-org/ai-rules/rules/shared/` is
deprecated — do NOT invoke it for newly routed rules.
