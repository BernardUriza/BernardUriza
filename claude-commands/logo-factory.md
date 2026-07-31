# /logo-factory - Generate app logo via Gemini + derive the full branding collection with Python

ARGUMENTS: brand brief — app name, what it does, visual mood, palette hints. Optional: output dir override (default: `web/branding/` or `public/brand/`, whichever exists).

## Context

One command, full branding kit: generate the master logo images with Gemini
(Chrome DevTools MCP), checkpoint visually with the user, then derive every
asset the app needs with Python/Pillow — favicons down to `.ico`, social
banners, hero backgrounds with the "render behind shadows" treatment
(rancho-studio pattern). Tone: silent efficient — report results, not process.

## Instructions

### Phase 0: Brief & discovery

1. Read repo context (CLAUDE.md, pitch/branding docs) to extract: app name,
   one-liner, palette, forbidden imagery. Merge with the user's brief from
   ARGUMENTS.
2. Detect output dir: existing `web/branding/`, `public/brand/`, or ask.
3. Build TWO prompts (English, for the generator):
   - **Master logo** (wide): emblem + wordmark + tagline, exact style spec.
   - **App icon** (square 1:1): emblem only, no text.
   Always include: flat vector, sharp edges, the palette, and a "no clichés"
   negative clause.

### Phase 1: Chrome diagnostic (HARD RULE — never skip, never pkill)

```bash
lsof -nP -iTCP:9222; lsof -nP -iTCP:9333
curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:9333/json/version
ps -axww | grep chrome-devtools-mcp | grep -v grep
```

Follow `~/CLAUDE.md` Chrome rules: reconcile MCP config, never relaunch
Chrome blindly. The debug profile (`~/.chrome-debug-profile`) must be logged
into Google for Gemini.

### Phase 2: Generate with Gemini

1. `new_page` → `https://gemini.google.com/app`.
2. Open "Upload & tools" menu → enable **Create image** (`menuitemcheckbox`).
   This is mandatory — without it Gemini answers text-only.
3. `fill` the composer with the master-logo prompt → Enter.
4. Poll via `evaluate_script` until no `button[aria-label*="Stop"]` AND a
   `blob:` img exists. Extract with canvas (blob fetch fails cross-context):
   `drawImage` → `toDataURL('image/png')` → save via `filePath` + base64
   decode to `<out>/<app>-logo-v1.png`.
5. Repeat in the SAME conversation for the square icon →
   `<out>/<app>-icon-v1.png`. Re-enable Create image if the toggle reset
   (it resets after page reloads).

### Phase 3: VISUAL CHECKPOINT (blocking)

1. `Read` both PNGs so the user sees them.
2. AskUserQuestion: **Approve** / **Regenerate** (tweaked prompt, same chat —
   Gemini keeps style context) / **Adjust prompt** (user dictates changes).
3. Do NOT derive anything until approved. Burning 15 derivatives from an
   ugly logo is the failure mode this checkpoint exists to prevent.

### Phase 4: Derive the collection (Python/Pillow)

Check `python3 -c "import PIL"` first; `pip install pillow` if missing.
One script, run once, from the two approved masters:

| Asset | File | Size | Source |
|---|---|---|---|
| Favicon ICO | `favicon.ico` | 16+32+48 multi-res | icon |
| Apple touch | `apple-touch-icon.png` | 180×180 | icon |
| PWA icons | `icon-192.png`, `icon-512.png` | 192/512 | icon |
| Logo full | `logo-full.png` | as generated | logo |
| Emblem | `emblem.png` | square crop | icon |
| Mono white | `logo-white.png` | alpha-only recolor | logo |
| OG card | `og-image.png` | 1200×630 | compose |
| Twitter card | `twitter-card.png` | 1200×600 | compose |
| LinkedIn banner | `linkedin-banner.png` | 1584×396 | compose |
| Hero bg | `bg-hero-1920.png` | 1920×1080 | treatment |
| Ultrawide bg | `bg-hero-3440.png` | 3440×1440 | treatment |

**ICO**: `icon.resize((48,48))` then
`img.save("favicon.ico", sizes=[(16,16),(32,32),(48,48)])`.

**Mono white**: keep alpha, fill RGB with white —
`Image.merge("RGBA", (white, white, white, logo.split()[3]))`.

**Social cards** (rancho `gen-og-image.py` pattern): brand panel + logo
lockup on one side, emblem art bleeding off the other edge, gradient mask
(`Image.new("L", (W,1))` ramp → resize → paste) so the seam is invisible.

**Background treatment** (rancho-studio "render entre sombras", baked):

```python
bg = master.resize(cover_fit(W, H), Image.Resampling.LANCZOS)  # scale-125 + object-cover
bg = bg.filter(ImageFilter.GaussianBlur(3))               # blur-[3px]
bg = ImageEnhance.Brightness(bg).enhance(0.45)            # opacity-40 over dark
# vertical shadow ramp: dark(0.8) → mid(0.4) → dark(0.9), like
# bg-gradient-to-b from-X/80 via-X/40 to-X/90
# horizontal: dark edges → clear center (gradient-to-r from-X via-X/10 to-X)
# optional palette tint at 20% multiply
```

Also drop the CSS-only equivalent in the report, for when the site should
do it client-side instead:

```html
<img class="scale-125 object-cover opacity-40 blur-[3px]" ...>
<div class="absolute inset-0 bg-gradient-to-r from-zinc-950 via-zinc-950/10 to-zinc-950"></div>
<div class="absolute inset-0 bg-gradient-to-b from-zinc-950/80 via-zinc-950/40 to-zinc-950/90"></div>
```

### Phase 5: Install & wire (the .ico is the most important output)

Generating the favicon is NOT installing it. **El `.ico` no está hasta que el
navegador lo pinta** — a derived file nobody references is a no-op. This phase
is mandatory; do it yourself, never offer it as an optional next step.

1. Detect the HTML entry / head surface of the app:
   - **Vite**: `web/index.html` or `index.html`
   - **Next.js**: `app/layout.tsx` (`export const metadata` / `icons`) or
     `app/head.tsx` / `pages/_document.tsx`
   - **CRA / static**: `public/index.html`
2. Inject into `<head>` (or the Next `metadata.icons` object), pointing at the
   derived files at their served URL (`/<served-out>/...`):
   - `<link rel="icon" href="/<out>/favicon.ico" sizes="any">`
   - `<link rel="icon" type="image/png" href="/<out>/icon-192.png">`
   - `<link rel="apple-touch-icon" href="/<out>/apple-touch-icon.png">`
   - `<meta name="theme-color" content="<bg hex>">`
   - `og:title` / `og:description` / `og:image` → `/<out>/og-image.png`
   - `twitter:card=summary_large_image` / `twitter:image` → `/<out>/twitter-card.png`
   Idempotent: if a tag already exists, replace its `href`/`content` — never
   duplicate.
3. **VERIFY in the real browser (Art. 2 — fake-green forbidden):**
   - Dev server up? `curl -s -o /dev/null -w "%{http_code}" localhost:<port>`;
     if not, start it (don't ask — Rule 13).
   - `curl <port>/<out>/favicon.ico` → `200 image/x-icon`.
   - Load the page in Chrome DevTools; `evaluate_script` that the rendered
     `link[rel="icon"]` href `fetch`es `200` and the tab paints the icon.
   A `.ico` generated but not served does NOT count as done.

### Phase 6: Verify & report

1. Verify every file exists; print real dims (struct-unpack PNG header) —
   never report a file unverified.
2. Write `<out>/PROMPT.md`: both prompts verbatim + Gemini chat URL +
   palette/design notes (reproducibility).
3. Clean temp files (snapshots, base64 dumps).
4. Report: table of generated files with sizes. Leave everything
   uncommitted and say so — commits are the user's call.

## Rules

1. **Diagnostic before Chrome, always.** Never `pkill` Chrome, never relaunch
   blindly — `~/CLAUDE.md` Chrome rules are law.
2. **Checkpoint before derivation.** No Python derivation on an unapproved
   master. Regeneration happens in the same Gemini chat to keep style.
3. **Masters are never overwritten** — derivation is read-only on `-v1`
   files; a regeneration writes `-v2`.
4. **Prompts get persisted** (`PROMPT.md`) — a logo you can't regenerate is
   a logo you don't own.
5. **Never commit, never push** — report the file list and stop.
6. **English asset names and prompt text**; brand language follows the brief.
7. **No clichés clause is mandatory** in every prompt (no clip-art, no
   fists/megaphones/lightbulbs, unless the brief asks).
8. **Verify before celebrating**: dims checked on disk, not assumed.
9. **The favicon is the deliverable, not the file.** *El `.ico` no está hasta
   que el navegador lo pinta* — generating the file is not installing it.
   Phase 5 wires every icon/OG asset into the app's HTML entry and verifies the
   browser paints the favicon. Skipping the wire-in, or offering it as an
   optional next step instead of doing it, leaves the most important output
   disconnected — that is the failure this rule exists to kill.
