# Registering a memory (operational facts)

Governed by `~/.claude/rules/90-memory-policy.md`. This is the default destination for
anything that is a **fact about a repo, product or tooling** rather than a behavior:
which org is internal vs a customer, what parameter an API takes, a schema quirk, a path
gotcha, what a flag actually does, where a credential lives (never its value — that is
[secrets.md](secrets.md)).

The test: *if I would otherwise have to be told this again, it is a memory.*

## Where it goes

`~/.claude/projects/<sanitized-cwd>/memory/<slug>.md`, plus **one line** in that
directory's `MEMORY.md` index.

The exact directory for the current session is stated in the system prompt. If it is not,
derive it from the working directory with separators and the drive colon replaced by
hyphens, and confirm the directory exists before writing:

```bash
ls -d ~/.claude/projects/*/memory
```

`MEMORY.md` is an **index**, never a content store: one line per memory, no frontmatter.

```markdown
- [Title](file.md) — one-line hook so future-you knows whether to open it
```

## File shape

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

Types: `user` = who Bernard is (role, expertise, preferences). `feedback` = guidance he has
given on how to work, corrections and confirmed approaches, including the why. `project` =
ongoing work, goals or constraints not derivable from the code or git history. `reference`
= pointers to external resources (URLs, dashboards, tickets).

## Discipline

- **Consolidate, don't stack.** Read the existing memory files first; if one already covers
  the topic, UPDATE it. A duplicate memory is a future contradiction, and contradictory
  memories are worse than none.
- **Write it the session you learn it, unasked.** Nothing extracts these for you in the
  background. Being told the same thing twice is the failure this layer exists to prevent.
- Convert relative dates to absolute.
- Do NOT save what the repo already records — code structure, past fixes, git history,
  `CLAUDE.md` — or what only matters to this conversation. If asked to save one of those,
  ask what was non-obvious about it and save that instead.
- **Delete memories that turn out to be wrong.** A stale memory outranks nothing, and it
  will be recalled with the same confidence as a true one.
- A `[[link]]` to a memory that does not exist yet is fine — it marks something worth
  writing later, not an error.
