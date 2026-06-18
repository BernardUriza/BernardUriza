---
name: devto-publish
description: Publish a post from ~/Documents/bernard-blog/posts/<slug>.md to dev.to as a DRAFT. Invoke when the user asks to "publish to dev.to", "post on dev.to", or types /devto-publish. Always asks for confirmation before sending if the post hasn't been reviewed in this session.
---

# devto-publish

Publishes a markdown post from the user's blog repo (`~/Documents/bernard-blog/posts/`) to dev.to as a DRAFT (`published: false`). The user finishes publishing from the dev.to web UI after reviewing the render.

## Inputs

The user passes a **slug** (the filename without extension):

- `/devto-publish 2026-05-25-chain-of-thought-streaming`

If no slug is given, list `posts/` and ask which one.

## Flow

1. **Verify env**: check `DEVTO_API_KEY` is set. If not, tell the user to get one at https://dev.to/settings/extensions and `export DEVTO_API_KEY=...` (do NOT prompt for the key — secrets don't go through chat).

2. **Locate the file**: `~/Documents/bernard-blog/posts/<slug>.md`. If missing, list available posts.

3. **Sanity-check the front-matter** before calling the script:
   - `title:` required, non-empty
   - `tags:` ≤4 (dev.to rule)
   - `description:` ≤140 chars (truncate-warning if longer)
   - All `tags` are lowercase, no spaces (dev.to silently rejects otherwise)

4. **Show the user**: title + tags + first paragraph + word count. Ask "¿confirmas el draft?" — wait for explicit yes.

5. **Choose mode**:
   - If `~/Documents/bernard-blog/.devto-cache/<slug>.json` exists → this is an UPDATE. Run `python scripts/publish.py posts/<slug>.md --update`.
   - Else → CREATE. Run `python scripts/publish.py posts/<slug>.md`.

6. **Report**: the dev.to edit URL from the script output + remind: "el draft está en dev.to; revísalo en el web y dale Publish ahí."

## Hard rules

- **NEVER** include the API key in any output, log, or commit. The script reads `DEVTO_API_KEY` from env; you only pass file paths to it.
- **NEVER** edit the `.md` file from within this skill. If the user wants edits, that's a separate ask — propose them but let the user apply.
- **NEVER** add `published: true` to a post. The script forces `false` anyway, but don't tempt the user. Publishing is a human-gated step.
- The repo lives at `~/Documents/bernard-blog/`. Run the script from that cwd (it resolves the cache dir relatively).

## Example invocation

```
$ /devto-publish 2026-05-25-chain-of-thought-streaming

Voy a publicar este draft a dev.to:

  Title:       "How we built live chain-of-thought streaming in 200 lines"
  Tags:        ai, python, fastapi, sse  (4/4 — max)
  Description: "Walking through Runner.run_stream + FastAPI SSE + ..." (138/140 chars)
  Word count:  ~1100
  First line:  "Live chain-of-thought is the UX trick that makes..."

  Mode: CREATE (no prior draft in cache)

¿confirmas el draft? (y/n)
> y

  ✓ created draft #1234567
    edit: https://dev.to/bernarduriza/...
    dashboard: https://dev.to/dashboard

El draft está en dev.to. Revísalo en el web y dale Publish ahí cuando estés listo.
```
