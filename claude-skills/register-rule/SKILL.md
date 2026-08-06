---
name: register-rule
description: Registers something for posterity in the right place — a hook, a rule, a memory fact, a secret, a backlog item, or shared documentation. Use when the user says "regístralo"/"register this", corrects how the agent should work, hands over a credential or token, or captures a finding that must outlive the session.
argument-hint: [what to register]
disable-model-invocation: true
allowed-tools: Bash(find *) Bash(grep *) Bash(ls *) Bash(sha1sum *) Read Glob Grep
---

# Register

Registers something for posterity. The first move is always to ask WHICH destination,
never to silently classify.

## Live inventory (already injected — do NOT re-run these)

Hook files on disk:
!`find ~/.claude/hooks .claude/hooks -maxdepth 2 -type f -name '*.sh' 2>/dev/null | sed 's|.*/hooks/||' | sort | tr '\n' ' '`

Hook wiring actually in effect (scope | event | matcher | script):
!`python -c "import json,os;[[print('  ',lbl,e,'|',g.get('matcher','*'),'|',' '.join(h['command'].split('/')[-1] if h['command'].rstrip().endswith(('.sh','.py')) else '(inline)' for h in g['hooks'])) for e,gs in (json.load(open(f,encoding='utf-8-sig')).get('hooks') or {}).items() for g in gs] for lbl,f in [('[proj]','.claude/settings.local.json'),('[user]',os.path.expanduser('~/.claude/settings.json'))] if os.path.exists(f)]" 2>/dev/null`

Rule files that may already own the topic:
!`ls ~/.claude/rules/*.md ./.claude/rules/*.md 2>/dev/null | xargs -n1 basename | sort -u | tr '\n' ' '`

An empty line above means the command found nothing **at that path** — not that nothing
exists. Say which probe came back empty rather than concluding absence
(`20-honesty`: a malformed check is not a negative result).

The wiring block is the truth about hooks; the file list is not. A hook file that
appears above but not in the wiring block **enforces nothing**.

## MOOD — ask FIRST, in a single AskUserQuestion

Before any grep, any classification, any file write, fire ONE `AskUserQuestion`:

> **"¿Cómo quieres registrar esto?"** — header `Registro`

| Option | Destination | It is… |
|---|---|---|
| **Hook** | `.claude/hooks/` + settings wiring | deterministic ENFORCEMENT — the turn or tool call is blocked when violated |
| **Regla** | `~/.claude/rules/` · `engineering-playbook/rules/` · `./.claude/rules/` | INSTRUCTION — how the agent must act |
| **Memoria** | `~/.claude/projects/<sanitized-cwd>/memory/` | an operational FACT about this repo or product |
| **Otro** | secret · doc · backlog · no template at all | credentials, team findings, things to build later |

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

Every branch file below describes a default shape, not a gate. If what Bernard is
registering does not fit any of them, **do NOT bend it into the closest one** — decide the
shape the thing actually needs, write it that way, and say in one line why you departed.
Forcing an input through a rigid rule-shaped hole is what made past registrations useless:
the content survived, the meaning did not. Think about what deserves to persist, then pick
the container.

## Branch files — read ONLY the one the MOOD step selected

| Destination | Read | Covers |
|---|---|---|
| Hook | [hooks.md](hooks.md) | inventory-first discipline, the 90/10 rule, wiring, proof it fires |
| Rule / guideline | [rules.md](rules.md) | consolidate-before-writing, the three rule levels, propagation |
| Memory | [memory.md](memory.md) | the auto-memory layer, frontmatter shape, index line |
| Roadmap / backlog | [backlog.md](backlog.md) | features, visions, proposals — things to build later |
| Secret / credential | [secrets.md](secrets.md) | `~/.secrets/` only, detection patterns, secrets map |
| Shared documentation | [docs.md](docs.md) | engineering-notes routing, commit + push, report the URL |

Nothing fits? That is a legitimate outcome, not an error:

1. Say in one line what the thing actually is and why no branch fits.
2. Propose the destination and shape it deserves.
3. Write it there, and add whatever index line makes it findable again.

## Two traps that decide the whole registration

**Roadmap misfiled as a rule.** A rule tells the agent how to *act*; a backlog item
records *something to build*. Desiderative tense (*quisiera, me gustaría, sería bueno,
deberíamos*), a capability that does not exist yet, or "someone proposed…" → [backlog.md](backlog.md),
never `rules/`. If the proposal also encodes a hard prohibition, file the backlog item AND
register the prohibition as a rule; link them, do not merge.

**Appending instead of consolidating.** Whatever the destination, read what already covers
the topic before writing one line, and EDIT that instead of stacking a new block beside it.
No grep output proving absence = no right to add a block. This applies to rules, hooks,
memory and docs alike; each branch file states its own version of the check.

## Report

Name the exact file changed, whether it was an edit or a new file, and — for hooks — the
wiring entry plus the evidence it fires. No evidence = not registered.
