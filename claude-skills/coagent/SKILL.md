---
name: coagent
description: Seed the orchestrator coagent (a custom ChatGPT GPT) a dense master prompt and read its advice/draft back — the OUTBOUND direction of the relay. Invoke when the user asks to "ask the coagent", "seed the coagent", "get the coagent's take", types /coagent, or runs a pipeline stage that consults the orchestrator (e.g. vegan etapa-3 / coagent-advise). NOT the inbound relay — that's /exchange-coagent. Claude composes the master prompt (judgment) and drives ChatGPT via the chrome-devtools MCP (transport). Claude never posts anywhere downstream; the send button stays the user's.
---

# coagent — outbound seed & read

Drives the **orchestrator coagent** (a custom ChatGPT GPT of Bernard's: Insult /
AURITY / Reaper) to stress-test a play and draft. Claude SEEDS a dense master
prompt and reads the response back. This is the **outbound** variant of the relay
(`[[coagent]]`); the **inbound** direction (coagent leaves Claude a step → Claude
executes) is `/exchange-coagent`. They are complementary, not duplicates.

**Firewall (Art. 4):** seeding the coagent and reading its advice is REVERSIBLE —
it is just asking ChatGPT. This skill never performs the downstream irreversible
act (posting to FB, sending an email, deploying). The verdict + draft go to the
user; the send button is the user's.

**The JUDGMENT is never scripted.** Claude composes the master prompt. The only
scripted piece is the deterministic, safety-critical identity resolution
(`scripts/resolve-coagent.py`). Everything else is MCP-driven because ChatGPT's DOM
changes often (a hardcoded Playwright driver rots; the chrome-devtools MCP absorbs
DOM drift). The volatile selectors live in ONE place (Step 3–6 below).

## GOLDEN PATH

### Step 0 — Resolve the coagent BY IDENTITY (never guess the tab, `[[coagent]]` §0)

Run the helper from the project root:

```bash
python3 ~/.claude/skills/coagent/scripts/resolve-coagent.py
```

It reads `COAGENT_CHATGPT_URL` from **this project's** `.env` and prints the URL +
chat id. If it errors (no `.env`, empty var), **ASK the user for the coagent chat
URL/id — do NOT adopt whatever ChatGPT tab happens to be open** (`[[coagent]]` §0:
a new project has no coagent; the louder your certainty about "the open tab", the
more you must verify). `--env <path>` overrides the location.

### Step 1 — Reuse the coagent tab, don't duplicate (`[[coagent]]` §0.5)

`list_pages` first. If a tab is already on the EXACT coagent URL/chat-id,
`select_page` it. Only `new_page(<url>)` if none exists. **Never `navigate_page` a
tab showing a different ChatGPT chat** — open your own; leave the user's tabs alone.

### Step 2 — Verify `location.href` JUST before writing (`[[coagent]]` §0.5)

Tabs move between `select_page` and the write. `evaluate_script` returning
`location.href` + `document.title`; **abort the send if the href does not contain
the resolved chat id.** Certainty is the tell, not the green light.

### Step 3 — Insert the master prompt (ChatGPT accepts execCommand)

ChatGPT's composer is a simple contenteditable (NOT Lexical like FB — see
`[[chrome-devtools-contenteditable-input]]`), so `execCommand` works:

```js
() => {
  const el = document.querySelector('#prompt-textarea');
  if (!el) return { ok:false, error:'no composer (#prompt-textarea) — logged out or DOM changed' };
  el.focus();
  document.execCommand('selectAll'); document.execCommand('delete');
  const text = `<MASTER PROMPT inline>`;   // see args gotcha below
  document.execCommand('insertText', false, text);
  return { ok:true, len: el.innerText.length };
}
```

**`args` GOTCHA (already paid):** this MCP treats each `evaluate_script.args` item
as an element uid, not a string → passing the text via `args` fails. **Embed the
text INSIDE the function body** as a template literal (no `args`).

The master prompt MUST open with the identity line (`[[coagent]]` §5):
`hola soy claude code, escribo desde exchange-coagent devtools.`

### Step 4 — Send

`press_key Enter`. Verify the composer emptied + the assistant message count rose.

### Step 5 — Wait by CONTENT STABILITY, never by the stop-button (`[[coagent-advise]]` Step 6)

GOTCHA (paid 2026-06-18): `[data-testid="stop-button"]` is **stale** — ChatGPT's
composer DOM changed and that testid no longer fires (a 30s poll during a real
generation never saw it; at idle there is no `send-button` nor `stop-button`, only
`composer-plus-btn`). Trusting it nearly produced a fake-green ("no reply" when
there was one, Art. 2). **Robust, UI-churn-proof fix:** poll the `innerText.length`
of the LAST `[data-message-author-role="assistant"]` until it stops changing
(unchanged across 2–3 ~1.5s checks) **and** `len > 0`. Content signal, not an
attribute, so it survives ChatGPT redesigns:

```js
async () => {
  const sleep = ms => new Promise(r => setTimeout(r, ms));
  const lastA = () => [...document.querySelectorAll('[data-message-author-role="assistant"]')].pop();
  let prev = -1, stable = 0;
  for (let i = 0; i < 40; i++) {
    const t = (lastA()?.innerText || '').length;
    stable = (t === prev && t > 0) ? stable + 1 : 0;
    if (stable >= 2) break;
    prev = t; await sleep(1500);
  }
  return { len: prev };
}
```

When stable, read the text in a separate call (Step 6). Do NOT regex
`document.body.innerText` for "error" — it matches the word inside the chat content
itself (false positive).

### Step 6 — Read the response (separate call — DOM reconciles async)

Read the last `[data-message-author-role="assistant"]` `innerText` in a SEPARATE
`evaluate_script` round-trip. The same-call read returns stale text.

### Step 7 — Hand the verdict + draft to the user

It is intelligence for the user, not an order for Claude. Claude does NOT post it
anywhere — that is a separate, irreversible, user-authorized step.

## The master prompt — dense, in this order (`[[coagent-advise]]`)

Identity line → which stage/task → the source material verbatim (the post, the
thread, the board) → the highest-leverage play + reasoning, asking for a
stress-test ("don't coddle me", Art. 3) → the risk to anticipate → explicit ask
(confirm/refute the target; draft in the user's voice; mark what NOT to say) →
scope reminder (draft only; the send button is the user's).

## Why this is a skill, not a loose command

A `~/.claude/commands/*.md` file can't bundle helpers; a skill directory can
(`scripts/resolve-coagent.py`). The deterministic identity resolution lives in
`scripts/`; the volatile, judgment-laden driving stays MCP-driven in this SKILL.md.

See also `[[coagent]]` (the relay doctrine + §0/§0.5 identity safety),
`/exchange-coagent` (the inbound sibling), and `[[coagent-advise]]` (the
project-level rule this generalizes).
