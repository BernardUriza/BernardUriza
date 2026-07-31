# Runbook: Ban a specific model from burning your Claude Code quota

**Problem this solves:** one expensive model quietly becomes the thing that pushes
you past your plan limits. You want to forbid *yourself* from selecting it —
enforced by config, not willpower.

Verified on Claude Code `2.1.220`, macOS, 2026-07-31.

---

## 1. Find out whether a model is actually the culprit

Don't ban on a hunch. Get the per-model numbers first:

```bash
npx -y ccusage@latest monthly
```

Compare month over month and look at the **delta**, not the totals. The question
that matters is *"what grew?"*, not *"what is biggest?"*.

A real example — the model under suspicion was only the **second** largest line
item, but it explained essentially **all** of the month-over-month growth:

| Month | Total | Suspect model | Rest |
|---|---|---|---|
| Previous | $6,789 | $593 (9%) | $5,916 |
| Current | $9,782 | $3,551 (36%) | $6,140 |

Growth: **+$2,993 total, +$2,958 from that one model.** That is a ban candidate.
A model that is merely *large* but flat is not what pushed you over the edge.

Also check cost **per token**, not just total — a model can be a small share of
your tokens and a large share of your bill:

| Model | Tokens | Cost | Per million |
|---|---|---|---|
| Suspect | 48.9M | $3,551 | **~$73** |
| Baseline | 130.6M | $4,645 | ~$36 |

### Caveats that will bite you

- **`ccusage` reads one machine.** It parses `~/.claude/projects/**/*.jsonl` on
  the box you run it on. If you use Claude Code from several computers, run it on
  each and add the totals up by hand.
- **Do NOT try to merge several machines' `.claude` dirs into one tree.** I tested
  it: two projects that individually reported $147.65 and $145.70 reported
  **$151.07** when pooled — it does not sum correctly. Run it per machine instead.
- **Server-side services don't appear at all.** Anything using a long-lived OAuth
  token (a bot, a CI job) burns your quota without writing a local transcript.
- **Cost shown is API-equivalent**, not what a subscription plan charges you. Use
  it as a proxy for *relative* weight, not as a bill.

---

## 2. Ban the model

This is **not** a hook. No hook event receives the active model in its payload —
there is no `ModelChange` event. The native mechanism is an allowlist in
`settings.json`.

Add to `~/.claude/settings.json` (merge — don't replace the file):

```json
{
  "availableModels": ["opus", "sonnet", "haiku"],
  "enforceAvailableModels": true
}
```

- `availableModels` accepts **family aliases** (`"opus"` allows every Opus
  version), version prefixes (`"opus-4-5"`), or full model IDs.
- Any model family you leave out is banned. Omitting the list entirely means
  everything is allowed.
- `enforceAvailableModels` also constrains the *Default* selection, so the default
  can't resolve to something outside the list.

Scope options: `~/.claude/settings.json` (all your projects),
`.claude/settings.json` (committed, team-wide), or `.claude/settings.local.json`
(this project, gitignored).

---

## 3. Verify it — do not skip this

A config you haven't exercised is a config that doesn't work. The check takes
30 seconds, and the naive version of it **lies to you**:

```bash
claude --model <banned-model> -p "say only: ok"
```

This still prints `ok` and exits 0. That is **not** proof it failed — the request
was silently served by a permitted model. The exit code tells you nothing; you
have to look at what actually ran.

Read the model out of the session transcript instead:

```bash
python3 - <<'EOF'
import json, glob, os

paths = sorted(glob.glob(os.path.expanduser('~/.claude/projects/*/*.jsonl')),
               key=os.path.getmtime, reverse=True)[:3]

for path in paths:
    models = set()
    with open(path) as fh:
        for line in fh:
            try:
                entry = json.loads(line)
            except ValueError:
                continue
            message = entry.get('message')
            if isinstance(message, dict):
                model = message.get('model')
                if model and model != '<synthetic>':
                    models.add(model)
    if models:
        print(f"{os.path.basename(path)[:8]}  {sorted(models)}")
EOF
```

Transcripts contain non-JSON lines and entries where `message` is `null` or a
plain string, so the guards above are load-bearing, not decoration.

Results from the real test — three runs, banned model requested twice:

| Requested | Actually ran |
|---|---|
| `--model fable-5` | `claude-sonnet-5` |
| `--model fable` | `claude-sonnet-5` |
| no flag (control) | `claude-opus-5` — default intact |

The banned family never appears. That is the receipt.

---

## 4. Things to know before you rely on this

- **You don't control the downgrade target.** Requests for the banned model were
  redirected to Sonnet, not to the first entry in `availableModels` (Opus). If
  your goal is cost control this works in your favor; if you needed a *specific*
  fallback, this setting won't give it to you.
- **It's a guardrail, not a security boundary.** It stops you from picking the
  model; anyone who can edit `settings.json` can undo it. That's the point — it's
  an intentional-friction device against your own habits.
- **Running sessions cache settings in memory.** New `claude` processes pick the
  change up immediately; a session that's already open needs a restart.
- **It's per machine.** `~/.claude/settings.json` is local. Replicate it on every
  box you use, or the ban has a hole in it.
- **It does not cover server-side consumers.** Bots and CI jobs authenticating
  with their own token pick their own model. Audit those separately —
  grep your deploy configs for the model name and check what your job
  definitions actually pass.

---

## 5. Related: audit what else can spend on your behalf

Long-lived OAuth tokens (`claude setup-token`) are invisible to local usage
tooling and outlive the machine that created them. List and revoke them at:

**claude.ai → Settings → Claude Code → "Authorization tokens"**

Not in the developer console — the console only tracks API keys. Two gotchas:

- Before revoking, check whether a deployed service uses that token. A token with
  a single `user:inference` scope is almost certainly a headless service token,
  not an interactive session. Revoking it takes production down.
- The token table does not re-render after a revoke. Reload the page between
  revocations, or your second click hits a stale row and silently does nothing
  while appearing to succeed.
