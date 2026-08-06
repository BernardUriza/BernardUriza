# Registering a secret, token, password or credential

## NEVER write a secret to

- `.claude/rules/` or anything else under `.claude/` — those are committed
- memory files
- any file inside any repo
- a message, a ticket, a PR body, or a log line

## ALWAYS write it to `~/.secrets/`

Outside every repo. One file per credential:

1. Detect the secret type from context (API token, password, OAuth key, login pair).
2. Choose a descriptive filename: `~/.secrets/<service>-<purpose>.txt`.
3. Write the value with its metadata:
   ```
   <Service> <purpose> token
   Created: <YYYY-MM-DD>
   Scope: <read-only, org:ci, etc. — if known>

   <KEY_NAME>=<value>
   ```
4. Update the secrets map table in the security rule ("Local Secrets Map") with the
   filename and purpose — never the value.
5. If the secret is for an MCP server, offer to wire it in `~/.claude.json`.

## Detection patterns (auto-detect, do not ask)

| Pattern | Type | File |
|---|---|---|
| `sntrys_*`, `sntryu_*` | Sentry token | `~/.secrets/sentry-<purpose>.txt` |
| `ghp_*`, `github_pat_*` | GitHub PAT | `~/.secrets/github-<purpose>.txt` |
| `sk-*`, `sk-proj-*` | OpenAI key | `~/.secrets/openai-<purpose>.txt` |
| `xoxb-*`, `xoxp-*` | Slack token | `~/.secrets/slack-<purpose>.txt` |
| `eyJ*` (base64 JWT) | JWT / auth token | `~/.secrets/<service>-token.txt` |
| `@` plus password context | Login credentials | `~/.secrets/<service>-login.txt` |
| `PLANE_PAT=*` | Plane personal API key | `~/.secrets/plane_pat.txt` |
| Anything Bernard calls a token/key/password/secret | Generic secret | `~/.secrets/<context>.txt` |

## After writing

Report the **filename only**, never the value, and never echo the secret back into the
terminal to confirm it. If the credential was pasted into the conversation, say plainly
that it is now in the transcript and that rotating it is his call.

A credential's **location** is a memory-worthy fact; its **value** never is. If future
sessions will need to find this file, add the pointer through [memory.md](memory.md) — the
pointer, not the secret.
