# /copy-to-cdb — Push proposed Slack copies to claude-draft-box

## Context

`claude-draft-box` is a local Bun app at `D:\repos\claude-draft-box` that runs on `http://localhost:3737`. It keeps a queue of drafts Bernard can review and copy manually from the browser UI, without polluting the system clipboard.

This command takes the **most recent** Slack-destined text Claude proposed in the current conversation — only one draft, the latest — POSTs it to the draft-box API, and replies with exactly one line.

Use it when Claude has drafted a Slack message and Bernard wants the current iteration parked in the queue for later — retroactively, without relying on the Stop hook. Earlier iterations of the same message are intentionally ignored: in a long iteration loop they are noise, not signal.

## Instructions

### Phase 1 — Ensure the server is up

Check if the server is already running:

```bash
curl -s -o /dev/null -w "%{http_code}" http://localhost:3737/api/drafts
```

- `200` → skip to Phase 2.
- Anything else (connection refused, non-2xx) → start it in background:

```bash
cd /d/repos/claude-draft-box && bun run dev
```

Use `Bash` with `run_in_background: true`. Then poll readiness, bounded to ~10 seconds:

```bash
for i in $(seq 1 20); do
  code=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:3737/api/drafts)
  if [ "$code" = "200" ]; then break; fi
  sleep 0.5
done
```

If after 10s the server never answers `200`, abort and tell Bernard plainly:

> `claude-draft-box` no arrancó. Revisa `D:\repos\claude-draft-box` — ¿`bun install` corrido?, ¿puerto 3737 ocupado?

No emoji, no one-liner reply when infrastructure is broken — that's a real failure and deserves plain prose.

### Phase 2 — Find the most recent Slack copy in the conversation

Scan the conversation **from the most recent turn backwards** and **stop at the first qualifying draft**. A draft qualifies if ANY of these apply:

- Explicitly labeled: "Slack:", "COPY:", "Mensaje para <persona>", "draft para Slack", "para el canal"
- Lives inside a fenced code block whose surrounding paragraph introduces it as a Slack/DM copy

You take exactly one. Earlier qualifying drafts in the same conversation are previous iterations of the same message — Bernard does not want them. If you find yourself collecting more than one, stop: re-read this section, drop everything except the latest match.

A response that contains multiple disjoint Slack drafts (e.g. one for Katie + one ≤20-word reply for Jason in the SAME response) counts as a single composite draft only when both were framed as the canonical output of that turn. In practice: take the last `<persona>`-labeled draft that appears in the conversation. If that turn also contains a parallel "if Jason is in the thread" reply, include only the primary draft and skip the parallel — the parallel is conditional, not the primary.

Extract the BODY only — strip:
- Outer code fences (```` ``` ````)
- Leading labels ("Slack:", "COPY to Josh:", etc.)
- Surrounding commentary like "Aquí va el mensaje:"

Keep Markdown formatting intact — the draft-box server has `slackify-markdown` available and transforms happen in its UI.

If there's NOTHING that qualifies, reply exactly:

```
Nada para copiar 🤔
```

…and stop. No explanation, no list of what was considered.

### Phase 2.5 — Sanitize problematic Unicode chars (MANDATORY, NON-NEGOTIABLE)

Before POSTing, apply the substitution table below to the draft body. **This is not optional.** The Windows clipboard → Slack handoff loses specific Unicode codepoints (renders as `�` or `?` on the recipient side). Sanitization is a SAFETY step, not a style choice — it does not change meaning, only encoding.

| Bad codepoint              | Replace with     | What it is                                |
|----------------------------|------------------|-------------------------------------------|
| `—` (U+2014)               | ` - `            | em-dash (spaces preserve sentence break)  |
| `–` (U+2013)               | `-`              | en-dash                                   |
| `…` (U+2026)               | `...`            | horizontal ellipsis                       |
| `→` (U+2192)               | `->`             | rightwards arrow                          |
| `←` (U+2190)               | `<-`             | leftwards arrow                           |
| `↔` (U+2194)               | `<->`            | left-right arrow                          |
| `'` (U+2018) `'` (U+2019)  | `'`              | smart single quotes                       |
| `"` (U+201C) `"` (U+201D)  | `"`              | smart double quotes                       |
| `•` (U+2022)               | `*`              | bullet                                    |
| `«` (U+00AB) `»` (U+00BB)  | `<<` `>>`        | guillemets                                |
| `≈` (U+2248)               | `~`              | almost equal                              |
| `≠` (U+2260)               | `!=`             | not equal                                 |
| `≤` (U+2264) `≥` (U+2265)  | `<=` `>=`        | less/greater or equal                     |
| `×` (U+00D7)               | `x`              | multiplication sign                       |
| `°` (U+00B0)               | ` deg`           | degree sign                               |
| `™` (U+2122) `®` (U+00AE)  | `(TM)` `(R)`     | trademark, registered                     |

**Allowlist (keep as-is, do NOT sanitize):**

- All printable ASCII (`0x20..0x7E`) including straight `'`, `"`, `-`, `*`, `(`, `)`, `[`, `]`, `{`, `}`
- Spanish accents and punctuation: `á é í ó ú ü ñ Á É Í Ó Ú Ü Ñ ¿ ¡`
- Common Latin-1 letters: `à è ì ò ù ç ã õ` and uppercase equivalents
- Newlines (`\n`), tabs (`\t`)

**Verification before POST:**

After substitution, scan the sanitized body for any character whose codepoint falls in this set: `{U+2013, U+2014, U+2018, U+2019, U+201C, U+201D, U+2022, U+2026, U+2190..U+2194, U+2248, U+2260, U+2264, U+2265, U+00D7, U+00B0, U+00AB, U+00BB, U+2122, U+00AE}`. If any survives, the substitution was incomplete — fix it and re-verify. Do NOT proceed to Phase 3 with any of those codepoints in the body.

**Why this exists (anchor 2026-05-19):** Bernard reported the same bug five times across multiple sessions. Each time Claude promised "I'll use ASCII from now on" and the promise lived only in conversational memory — failing the next round. The fix is structural: the substitution lives in the command file itself, so any invocation of `/copy-to-cdb` performs the sanitization regardless of what Claude remembers about prior conversations.

### Phase 2.6 — URL safety (MANDATORY when the draft contains any `http://` or `https://` URL)

Slack auto-links URLs by parsing them out of the surrounding text. When a URL is immediately followed by punctuation Slack interprets as part of the link envelope, the link gets corrupted on send. Two known failure modes (both observed 2026-05-26):

1. **Trailing `):` after URL** — `PR https://github.com/.../1474):` gets rendered by `slackify-markdown` as `<https://github.com/.../1474|https://github.com/.../1474>` and Slack URL-encodes the pipe character into the href, producing `https://github.com/.../1474%7Chttps://github.com/.../1474` — a 404 destination.
2. **Trailing `>` from a markdown-style autolink** — same family.

**Apply these rewrites to the draft body for every URL match (regex `https?://[^\s<>]+`):**

- If the character immediately after the URL is one of `)` `]` `}` `>` `:` `;` `,` `.` `!` `?` — insert a single space between the URL and that character. Yes, this changes English punctuation slightly (`see (URL).` becomes `see (URL ).`) — that is acceptable; the alternative is a broken link.
- If the character immediately before the URL is one of `(` `[` `{` `<` — insert a single space between that character and the URL.
- If the URL is inside a markdown link form `[text](URL)` leave it alone — Slack's `slackify-markdown` handles that case correctly via `<URL|text>` rendering. The corruption only happens with bare URLs adjacent to punctuation.
- Newline after a bare URL is always safe. When in doubt, put the URL on its own line.

**Verification before POST:**

After URL-safety rewrites, run this check on the sanitized body:

```
matches = re.findall(r'https?://\S+', body)
for url in matches:
    # the literal URL must appear in the body followed by a space, newline, or end-of-string
    # NOT followed by ) ] } > : ; , . ! ?
```

If any URL is still adjacent to a trailing punctuation character, the rewrite was incomplete — fix it before POST.

**Anchor 2026-05-26:** A draft posted with `PR https://github.com/.../1474):` rendered as a `<URL|URL>` pair in Slack with URL-encoded `%7C` in the middle, producing a 404 when clicked. Cost: two round-trips with Bernard and a second corrected draft. The check above would have caught it in Phase 2.6 before POST.

**URL rendering best practice — use markdown link form for every URL.** Even when adjacent punctuation is clean, the `claude-draft-box` UI's "Copy" button runs `slackify-markdown` on the body before placing it on the clipboard. For a bare URL like `https://example.com/page`, slackify converts it to Slack mrkdwn `<https://example.com/page|https://example.com/page>` — the URL gets duplicated as both label and href. When Bernard copies that out of Slack as text (or another reader looks at the raw rendered form), the duplicated URL is visually messy and confused with corruption.

Prefer the markdown link form **for every URL in the draft body**:

| Before (bare URL) | After (markdown link) |
|---|---|
| `See https://github.com/.../1474 for the PR` | `See [PR 1474](https://github.com/.../1474) for the PR` |
| `Diagram: https://visalaw.github.io/.github/diagrams/foo.html` | `Diagram: [Foo flow](https://visalaw.github.io/.github/diagrams/foo.html)` |
| `Plane: https://app.plane.so/visalaw-ai/browse/VISAL-927/` | `Plane: [VISAL-927](https://app.plane.so/visalaw-ai/browse/VISAL-927/)` |

slackify converts `[label](url)` to Slack's `<url|label>` form, which Slack renders as a single clickable link with the human-readable label. No URL duplication, no `<URL|URL>` mess in the copy.

**When to keep a bare URL:** if Bernard explicitly asks for the raw URL string (e.g. to be copy-pasted into a non-Slack context like a Plane ticket or an email), respect that. The markdown link rewrite is the default for Slack drafts.

**Verification step:** after URL-safety rewrites, scan one more time:

```
bare_urls = re.findall(r'(?<!\]\()https?://\S+(?!\))', body)  # bare URLs NOT already inside markdown link
if bare_urls:
    # rewrite each as [label](url) before POST
```

Anchor 2026-05-26 (second incident, same session): a draft posted with the URL on its own line and clean adjacent punctuation STILL rendered in Slack as `<URL|URL>` because slackify-markdown auto-wraps every bare URL. Bernard's pushback was the same as the first incident: "este URL no abre nada". The fix is the markdown link form, not whitespace gymnastics around the URL.

### Phase 3 — POST the draft

You should be holding exactly one draft body. **One tool call. Not seven, not three, one.** If you are about to issue more than a single POST, Phase 2 ran wrong — go back, drop everything except the latest match, and re-enter Phase 3.

#### MANDATORY path — MCP tool (`mcp__claude-draft-box__create_draft`)

**Use the MCP tool. This is not a recommendation — it is the only correct path.** Call `mcp__claude-draft-box__create_draft` once with `{ content, type: "slack", source: "claude-code" }`. The MCP is registered at user scope (`claude mcp list` shows it ✓ Connected in every workspace). The JSON payload travels through MCP's JSON-RPC stdio transport, which preserves every byte of the Unicode content end-to-end.

If `mcp__claude-draft-box__create_draft` is not yet loaded in the current tool list, fetch it with `ToolSearch` first:

```
ToolSearch(query: "select:mcp__claude-draft-box__create_draft", max_results: 1)
```

Then call it. Do NOT skip this and reach for curl just because it feels familiar.

#### Why NOT curl on Windows — the UTF-8 mangling trap

The Bash tool runs commands through git-bash on Windows. When you write `curl -d '{"content":"<text with 👀>"}'`, git-bash converts the literal emoji bytes (4-byte UTF-8 sequences for codepoints above U+FFFF) into question marks (`?`) BEFORE curl ever sees them. The server stores the corrupted `?` in the database, and the clipboard copy will paste `?` to Slack regardless of any sanitization downstream.

Anchor 2026-05-19: Verified by direct test. Draft posted via `python -c "urllib.request.urlopen(...)"` round-tripped 👀✅🚫📋 intact. Identical content posted via `curl -d '...'` from the Bash tool stored as `?? ? ?? ??` in the SQLite database. The corruption point is the shell, not curl, not the server.

#### Last-resort fallback — `python -c` (only when MCP is truly unavailable)

If `mcp__claude-draft-box__create_draft` returned a transport error AND the bug is verified server-side, use Python's `urllib.request` instead of curl. Python writes UTF-8 bytes directly to the HTTP socket without shell intermediation:

```bash
python -c "
import urllib.request, json
data = json.dumps({'content': '<body>', 'type': 'slack', 'source': 'claude-code'}).encode('utf-8')
req = urllib.request.Request('http://localhost:3737/api/drafts', data=data,
  headers={'Content-Type': 'application/json; charset=utf-8'}, method='POST')
resp = urllib.request.urlopen(req)
print(resp.read().decode('utf-8'))
"
```

**FORBIDDEN: `curl --data-binary @/tmp/anything.json` or any variant that reads from a filesystem path.** On Windows with multiple Claude Code sessions running in parallel, temp files at stable paths get overwritten between the `Write` and the `curl` read, causing Session A's POST to send Session B's content. Not theoretical — happened in production 2026-04-24 (draft #20 with "Sentry Replay" content that never appeared in the originating conversation).

**FORBIDDEN: `curl -d '<JSON with Unicode>'`** for any content containing characters above U+007F (emoji, smart quotes that survived Phase 2.5, accented Latin chars in some cases). The Windows git-bash shell mangles the UTF-8 bytes before curl receives them, regardless of any `-H "Content-Type: application/json; charset=utf-8"` header. Use the MCP tool. Repeat: use the MCP tool.

Verify the response returned successfully. If it fails, abort with a plain-prose error naming the failure (status code + body). Do NOT deliver the success one-liner.

### Phase 4 — Reply

On full success, output EXACTLY one line and stop:

```
Copiado al server <emoji>
```

Pick one emoji from this set, rotating so it's not always the same: 🧃 🦑 🦔 🫧 🐙 🪼 🦉 🫗 🦭 🪿

Nothing else. No preamble, no footer, no count, no recap of what was sent, no markdown headers.

## Rules

- **Silent output on success** — the whole point is that the drafts live in the browser queue; re-dumping them in the terminal defeats the purpose.
- **Never touch the system clipboard** — even if tempted. Bernard copies manually from the draft-box UI.
- **Slack only** — PR descriptions, commit messages, code snippets, email bodies do NOT qualify unless Bernard or Claude explicitly framed them as Slack destined.
- **Idempotent** — never kill or restart the server if it's already up. Only start it when the health check fails.
- **Fail loud on infrastructure problems** — missing `bun`, missing repo at `D:\repos\claude-draft-box`, occupied port 3737, server refusing 200 after 10s → plain-prose failure, no one-liner.
- **Footer exception** — this command's single-line success reply deliberately skips the "⚠️ Hipótesis sin verificar" footer. The reply is a deterministic fact (HTTP 2xx from the POST verified in Phase 3), not a hypothesis. The footer rule exists to flag claims Bernard might act on externally; `Copiado al server` has nothing to act on — he opens the browser and copies. If the POST failed, Phase 3 already aborted with prose, never reaching the one-liner.
- **One draft per invocation, period** — never collect multiple drafts and POST them as a batch, even if the conversation has 6 iterations of the same message. Earlier iterations are stale by definition. A single `/copy-to-cdb` call produces a single new entry in the queue. If Bernard wants an earlier iteration parked too, he invokes the command again right after Claude proposes that earlier iteration — not retroactively at the end.
- **History — why this rule exists** — 2026-04-29 incident: a long iteration loop on a Slack message to Emily produced 6 candidate drafts in the conversation. Invoking `/copy-to-cdb` POSTed all 7 (drafts 63-69 in the queue) because the prior version of this command said "every Slack-destined text". Bernard had to delete the 6 stale ones manually. The "every" semantics is wrong: a queue full of stale iterations of the same message is noise, not value. The fix is structural: Phase 2 takes only the latest match.
- **Sanitize before POST (Phase 2.5)** — Apply the Unicode substitution table to the draft body before sending. NEVER POST raw em-dashes, smart quotes, arrows, or other codepoints listed in the Phase 2.5 table. Verify the body contains zero codepoints from the forbidden set after substitution. This rule replaces five prior session-memory promises ("I'll use ASCII from now on") that failed because they lived only in conversational memory.
- **MCP tool is mandatory, curl is forbidden for Unicode content** — On Windows the Bash tool uses git-bash, which mangles 4-byte UTF-8 sequences (every emoji above U+FFFF) into `?` before they reach curl. The server then stores `?` and every downstream consumer sees `?`. The MCP tool `mcp__claude-draft-box__create_draft` uses JSON-RPC stdio transport that preserves every byte. If the MCP isn't loaded in the current tool list, fetch it with `ToolSearch(query: "select:mcp__claude-draft-box__create_draft", ...)` before posting. This rule replaces "I'll remember to use the MCP next time" — same memory-only failure mode as the Phase 2.5 ASCII promises.
- **History — why the MCP rule exists** — 2026-05-19 anchor: emoji round-trip test through `curl -d '...'` in git-bash stored `Round 3 verify: ?? ? ?? ??` in the DB while the source content was `Round 3 verify: 👀 ✅ 🚫 📋`. Same content posted via `python -c "urllib.request.urlopen(...)"` stored intact. Root cause is the shell, not curl, not the server, not any sanitization gap.

## Non-goals

- Not a semantic transformer. `strip-emojis`, `to-mrkdwn`, `strip-markdown` live in the draft-box UI and API — out of scope here. Phase 2.5 is the explicit EXCEPTION to "not a transformer": it sanitizes specific Unicode codepoints that break the Windows clipboard → Slack handoff (rendering as `?` or `?` on receipt). That is a clipboard-safety step, not a stylistic transform — Bernard's message means the same thing with or without an em-dash, but only ONE of those versions survives the round trip intact.
- Not a clipboard tool. Copying to clipboard happens in the browser via `POST /api/drafts/:id/copy`, triggered by Bernard clicking.
- Not an auto-poster. Claude only posts when this command is invoked explicitly. There is no Stop hook; a prior version of this doc referenced one that was never implemented.

## Reference — claude-draft-box API

| Method | Path | Used by this command |
|--------|------|----------------------|
| `GET` | `/api/drafts` | Yes — health check in Phase 1 |
| `POST` | `/api/drafts` | Yes — body `{ content, type, source }` in Phase 3 |
| `POST` | `/api/drafts/:id/copy` | No — UI-triggered, not our job |
| `POST` | `/api/drafts/:id/transform` | No — UI-triggered |
