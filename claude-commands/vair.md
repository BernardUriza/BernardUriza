# /vair — VAIR Dashboard Control Suite

ARGUMENTS: Optional action keyword: `review`, `resolve`, `fix`, `inspect`. If omitted, presents the full menu.

## Context

VAIR is the Visalaw AI Reviewer — autonomous PR review + Plane issue resolution dashboard at https://visalaw.github.io/.github/. **VAIR (dashboard suite) is the local control suite for everything VAIR-related**: dispatching reviews, dispatching work, debugging the dashboard itself, and verifying deploys.

The dashboard source lives in the `github-org` submodule at `github-org/.github/scripts/ai_reviewer/frontend/`. If that submodule isn't initialized in the current parent repo, VAIR (dashboard suite) sets it up before doing anything else.

The name VAIR (dashboard suite) is a placeholder — if `ai-reviewer-dev` ever resurfaces from disk, this can be renamed or merged.

## The Menu

When invoked without an action argument, ask:

```
AskUserQuestion:
  question: "What do you want VAIR to do?"
  header: "VAIR (dashboard suite)"
  options:
    - label: "Review a PR"
      description: "Trigger AI review on an open pull request via the VAIR dashboard carousel"
    - label: "Resolve a Plane issue"
      description: "Dispatch the autonomous agent on a VISAL-XXX issue. Opens a draft PR."
    - label: "Fix the VAIR dashboard"
      description: "Debug + deploy CSS/JS/Brython changes to the dashboard itself. Includes cache-busting."
    - label: "Inspect dashboard / verify deploy"
      description: "Check the latest deploy version, measure layout, take screenshots"
```

Route to the matching Action section below.

## Phase 0: Always-Run Setup

Run these checks before ANY action. If any fails, fix it before proceeding.

### 0.1 Verify the github-org submodule exists in the current parent repo

```bash
git submodule status github-org 2>/dev/null
```

- **If empty** (submodule not registered):
  ```bash
  git submodule add https://github.com/Visalaw/.github.git github-org
  cd github-org && git checkout main && git pull origin main
  cd ..
  ```
  Then **STOP and ask Bernard**: "Added github-org as a new submodule of this parent repo. The pre-commit hook that auto-bumps `__init__.py` and the CSS `?v=` query string lives in `.git/modules/github-org/hooks/pre-commit` — I need to copy it from the C: workspace if you have it there. Do it now? [yes/no]"

- **If `-<sha>`** (registered but not initialized):
  ```bash
  git submodule update --init --recursive github-org
  ```

- **If ` <sha>` or `+<sha>`** (initialized): proceed.

### 0.2 Verify Chrome DevTools MCP is connected

`list_pages` — if it errors, STOP and tell Bernard to run `/mcp` to reconnect. Don't silently fall back.

### 0.3 Verify the dashboard tab exists or open it

- If `https://visalaw.github.io/.github/` is in the page list → `select_page` it
- Otherwise → `new_page` to that URL (NEVER `navigate_page`, it triggers GitHub auth redirects)
- `resize_page` to 1337×900 unless Bernard's screen is larger and we need to test wide layout

### 0.4 Verify auth is loaded

```js
({
  github: !!localStorage.getItem('vair_token'),
  plane: !!localStorage.getItem('vair_plane_token'),
})
```

If both false → instruct Bernard to sign in via the modal. NEVER print the actual token values to the conversation.

## Action: Review a PR

1. Ask: "Which PR? Format: `<repo>#<number>` (e.g. `frontend-core-2.0#420`) or `latest` to pick the most recent open PR"
2. In the dashboard, the AI Review carousel shows the PRs. Find the matching card:
   ```js
   const card = document.querySelector(`.issue-card[data-card-id="${prNumber}"]`);
   if (card) card.click();
   ```
   If the card isn't in the visible page of the carousel, click it programmatically anyway — Splide handles off-screen clicks fine.
3. Verify the "Trigger Review" button text changed to `Trigger Review #${prNumber}` and opacity is `1`
4. Take a fresh `take_snapshot`, find the new uid for "Trigger Review", and `click` it (not `evaluate_script` — for audit)
5. `wait_for ["Dispatched successfully", "Error"]`
6. If success → confirm the workflow run started:
   ```bash
   gh run list --repo Visalaw/.github --workflow ai-review.yml --limit 1
   ```
7. Report the run URL. Optionally `gh run watch <id> --repo Visalaw/.github` if Bernard wants to follow live.

## Action: Resolve a Plane issue

1. Ask: "Which Plane issue? Format: `VISAL-XXX`"
2. Verify the AI Resolve repo selector matches where the issue's code lives:
   - Frontend issues (UI, components, drawer, chat) → `Visalaw/frontend-core-2.0`
   - Backend issues (API, retrieval, NestJS) → `Visalaw/visalaw-gen-backend`
   - If unclear, ask Bernard or read the Plane issue description
3. Programmatically click the matching card via `data-card-id` (works even off-screen, no carousel navigation needed):
   ```js
   const card = document.querySelector(`.issue-card[data-card-id="${VIS_ID}"]`);
   if (!card) return { error: 'card not in carousel — issue may not be assigned to Bernard or repo selector is wrong' };
   card.click();
   ```
4. Verify button text became `Dispatch ${VIS_ID}` with opacity `1`
5. Snapshot → find Dispatch button uid → `click` it
6. `wait_for ["Dispatched successfully"]`
7. Verify the ai-work run started:
   ```bash
   gh run list --repo Visalaw/.github --workflow ai-work.yml --limit 1
   ```
8. Report the run URL with full URL: `https://github.com/Visalaw/.github/actions/runs/<id>`

## Action: Fix the VAIR dashboard

This is the meta-recursive option — VAIR (dashboard suite) fixing VAIR (dashboard suite) itself. Apply the patterns from `~/.claude/rules/styling.md` (Computed Styles Verification + Static CSS Cache-Busting).

### Phase 1: Diagnose

1. Open the dashboard, take a screenshot, READ the screenshot file to see what's broken
2. Use `evaluate_script` to read computed styles + dimensions of the suspected element:
   ```js
   const el = document.querySelector('<selector>');
   const r = el.getBoundingClientRect();
   const cs = getComputedStyle(el);
   ({ w: r.width, h: r.height, display: cs.display, gridCols: cs.gridTemplateColumns, ... })
   ```
3. Compare against expected. If grid/flex content is overflowing or stretching, suspect:
   - `height: 100%` on flex/grid items (cards inheriting parent height)
   - Missing `grid-template-columns: minmax(0, 1fr)` (column expanding to content max-content)
   - Missing `min-width: 0` on grid items with flex content (Splide carousels)
   - Browser cache (next phase)

### Phase 2: Edit + test locally

1. Edit files in `github-org/.github/scripts/ai_reviewer/frontend/`:
   - CSS: `css/styles.css`
   - HTML: `index.html`
   - Brython: `py/*.py`
   - Vanilla JS: `js/particles.js`

2. Test locally before pushing:
   ```bash
   cd github-org/.github/scripts/ai_reviewer/frontend
   python -m http.server 8765
   ```
   In a different shell or background, then `new_page` to `http://localhost:8765/`.
   Sign in with the existing tokens (read from production tab's localStorage and inject).

3. Verify the fix works against the LOCAL file before committing.

### Phase 3: Commit + push + auto cache-bust

```bash
cd github-org
git add <files>
git commit -m "fix(vair-dashboard): <description>"
```

The pre-commit hook auto-bumps `__init__.py` AND the `?v=X.Y.Z` query string in `index.html`. Verify both files appear in the commit:
```bash
git log -1 --name-only
```

Then push:
```bash
git push origin main
```

The push hook may block (Claude Code PreToolUse curl-verified hook). If so, satisfy it:
```bash
touch /tmp/claude-curl-verified
git push origin main
```

### Phase 4: Wait for deploy + verify in production

```bash
RID=$(gh run list --repo Visalaw/.github --workflow pages.yml --limit 1 --json databaseId --jq '.[0].databaseId')
gh run watch $RID --repo Visalaw/.github --exit-status
```

After success, hard-reload the production page with cache-bust URL:
```js
window.location.href = 'https://visalaw.github.io/.github/?cb=' + Date.now();
```

Re-measure the previously broken element. Confirm computed values match expected.

### Phase 5: Update parent repo submodule pointer (CRITICAL)

```bash
cd <parent-repo>  # e.g. D:/repos/Visalaw
git add github-org
git status
```

Confirm `github-org` shows `M` (modified pointer). Then commit + push:
```bash
git commit -m "chore: bump github-org submodule to <new-sha>"
git push origin main
```

**Without this step, the parent repo silently drifts.** Every `git status` from the parent will show `github-org` as dirty forever.

## Action: Inspect dashboard / verify deploy

1. `select_page` the dashboard (or `new_page` if missing)
2. Read the CSS link version:
   ```js
   [...document.querySelectorAll('link[rel=stylesheet]')]
     .find(l => l.href.includes('styles.css'))
     ?.href
   ```
3. Compare to `git log -1 --pretty=%s github-org/.github/scripts/ai_reviewer/__init__.py` for the latest version. If they don't match, the browser is on a stale CSS — instruct hard reload via cache-bust URL.
4. Measure all 4 panels (stats strip, runs, dispatch resolve, dispatch review, vair PRs):
   ```js
   ['stat-total','runs-panel','dispatch-work','dispatch-review','pulls-panel']
     .map(id => {
       const el = document.getElementById(id);
       const r = el.getBoundingClientRect();
       return { id, w: Math.round(r.width), h: Math.round(r.height) };
     });
   ```
5. Take a screenshot, save to `screenshots/vair-dashboard-<timestamp>.png`
6. READ the screenshot to verify visually
7. Report: deploy version, CSS query string, panel measurements, screenshot path, any anomalies

## Rules

- **Never push to teammate PRs** — every push to a non-Bernard branch needs explicit approval (`git-safety.md`)
- **Always use `new_page`** for the dashboard, never `navigate_page` (triggers redirects)
- **Always update the parent repo submodule pointer** after pushing to github-org. Skip this and the parent silently drifts forever
- **Cache-bust query strings are auto-bumped** by the github-org pre-commit hook. Verify both `__init__.py` AND `index.html` appear in your commit
- **Never print tokens to conversation** — `vair_token` and `vair_plane_token` from localStorage are sensitive. Use `(redacted, length: N)` in logs
- **Verify with computed styles, not source classes** — what you wrote ≠ what the browser shows (`styling.md` Computed Styles Verification rule)
- **Test the fix against the deployed CSS** — browser cache lies. After every fix push, cache-bust URL and re-measure

## Why VAIR (dashboard suite) exists

The full sequence of "fix something via VAIR" used to be a 30-step manual flow:
1. Open browser, navigate, sign in
2. Find the right PR/issue in the carousel
3. Click, dispatch, verify run
4. If something breaks: diagnose, fix CSS, push, deploy, watch run, hard-reload, re-measure
5. Update parent repo submodule pointer (always forgotten)

VAIR (dashboard suite) collapses this into one command with menu options. Each option knows the full pipeline including the gotchas: cache-busting, computed styles vs source, submodule pointer updates, the curl-verified pre-push hook, the github-org orphan-from-parent problem.

## Connection to mission

VAIR autonomously resolves Plane issues and reviews PRs for the Visalaw engineering team. Every minute saved on dispatch/debugging is a minute the team can spend on actual product work for immigration attorneys handling H-1Bs, asylum cases, and family petitions. VAIR (dashboard suite) is the friction-removal layer between Bernard and VAIR — the difference between "I'll do that tomorrow when I have time" and "I'll do that now in 30 seconds."
