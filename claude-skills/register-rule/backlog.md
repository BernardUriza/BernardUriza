# Registering a roadmap / backlog item

When Bernard is **capturing something to build later** — a feature, a product vision, a
stakeholder proposal — it is a backlog item, NOT a rule. A rule tells the agent how to
*act*; a backlog item records *something to build*. Do not file it under `rules/`.

## Detect it

- A capability that **does not exist yet**: "I want to give them X", "build an assistant
  that…", "a CMS so they can…".
- A **vision or roadmap direction**: "my vision for this project is…".
- A **proposal**: "Miguel suggested…", "someone proposed…".
- **Desiderative or future tense**: *quisiera, me gustaría, sería bueno, algún día,
  deberíamos, podríamos*.

If it is a behavior — "always/never do X", a correction of how you worked — it is a rule.
Read [rules.md](rules.md) instead.

When the two are genuinely mixed, prefer backlog: file the item here AND register the
embedded prohibition separately as a rule, linking them rather than merging them.

## Where it goes

Backlog is **per-repo**: `./.claude/backlog/<slug>.md` in the current repo, plus a one-line
entry in `./.claude/backlog/README.md`. Create the folder and index if absent.

Governed by the universal `backlog-handling.md` rule, in `engineering-playbook` and
delivered through the `~/.claude/rules/playbook` symlink — read it for the authoritative
item shape before writing.

```markdown
# <Title>

Status: Proposed | Accepted | In progress | Done | Dropped
Proposed: <YYYY-MM-DD> by <who>

## What it is
## Canonical path to reuse (Art. 6)
## The decision that's the owner's
## Status / next step
```

Convert relative dates to absolute, and name the person who proposed it. An unattributed
backlog item cannot be resolved later.
