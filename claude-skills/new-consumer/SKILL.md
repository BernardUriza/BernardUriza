---
name: new-consumer
description: Spawn a new thin consumer app from the python-bot template, driven by a functional-requirements spec instead of fragile hand copy-paste. Invoke when the user wants to "create a new app/consumer", "levantar una app nueva", "scaffold an org's site", types /new-consumer, or describes an app to build on the fi stack. Runs scripts/new-consumer.sh for the deterministic mechanics, then fills the creative seam (CLAUDE.md, .claude/rules/, persona, branding) from the spec, and re-greens the build. NOT for editing an existing consumer.
---

# new-consumer — spec-driven consumer bootstrap

Turns "I want an app that does X for org Y" into a configured, green, governed
python-bot consumer — without the fragile `cp -R` + hand-edit dance. The split
that kills the fragility: **intent from the LLM (you), mechanics from a script,
proof from the build.** Honors [[new-project-stack]] (clone python-bot, think in
files), [[framework-canary-consumer]] (consumers stay anorexic), and the
Constitution (Art. 2 verify, Art. 6 reuse canonical).

## Inputs

The user's functional requirements. Capture them into the spec template at
`~/Documents/python-bot/templates/consumer.spec.md` (copy it, fill it). If the
user gave a loose description, draft the spec FROM it and confirm the few fields
that change the build (name, modules, github visibility) — don't interrogate;
fill sane defaults and state them.

## Procedure

### 1. Resolve the spec
- Copy `templates/consumer.spec.md` → a working spec; fill from the user's ask.
- Hard-decide the build-affecting fields: `name` (kebab-case), `modules`
  (subset of `cms,marketplace`; chat is always on), `github` (+visibility).
- Everything else (persona, branding, governance, content) is the seam — keep
  the spec answers; they drive step 3.

### 2. Run the deterministic skeleton
```bash
~/Documents/python-bot/scripts/new-consumer.sh \
  --name <name> --modules <cms,marketplace> [--github] [--public] [--no-build]
```
This copies the template, inits git on `main`, writes `api/.env` +
`web/.env.local` + bakes the composition into `.env.example`, runs the web
build-smoke (the green gate), commits, and — with `--github` — creates the repo
and pushes. If the build fails, STOP and fix; never proceed on red.

### 3. Fill the creative seam (the LLM's job, from the spec)
In the new consumer dir, edit ONLY app-specific files — never fork template logic:
- **`api/app/personas/assistant.md`** — the persona (voice, what it knows, refusals).
- **`web/lib/site.ts`** — site name / title / description.
- **`web/app/globals.css`** — the six `--color-app-*` tokens (from the spec palette).
- **`CLAUDE.md` / `AGENTS.md`** — point at the app's rules; a thin consumer README.
- **`.claude/rules/`** — the app's HARD prohibitions written as bans (per
  `register-rule` discipline): domain constraints, "no auto-post", audience
  rules. This is what makes the consumer governable from birth.
- **`.claude/backlog/`** — seed roadmap items if the spec named "later" features.

Do NOT touch `api/app/{cms,marketplace,features,...}` or `web/components/*` —
those are template surface; growing them is a job for the template (the
canary-driven upstream loop), not the consumer.

### 4. Re-green and commit the seam
- Re-run the web build (`cd web && npx next build`) — the seam must still build.
- If api modules changed (they shouldn't), run `pytest`.
- Commit the seam separately from the bootstrap (one commit = one surface).
- Push if `--github` was used.

### 5. Report with receipts
- Path, branch, GitHub URL (if any), enabled features (`GET /features` shape),
  build result. Be honest about the boot-smoke frontier: the web builds for real;
  the full-stack api boot needs the conda `app` env (fi-runner is not on PyPI).

## Anti-patterns

- **Hand `cp -R` + manual edits** — that's the fragility this skill exists to
  kill. Always go through the script for mechanics.
- **Editing template logic in the consumer** — fork smell. App-specific seam only.
- **Declaring done on a red or unbuilt tree** — the build is the gate, not a vibe.
- **Inventing branding/persona not in the spec** — capture intent first; if the
  spec is silent, ask the one question or state the default you chose.
