# TSX Refactor Workflow

**Real talk**: Refactoring frontend code is where visual regressions hide. This guide keeps you from deploying broken layouts and from wasting 2 hours trying to debug why a button changed color when you only touched Tailwind utilities.

## The Core Rule

Work in small batches (10–25 files). After each batch, **visually verify on Vercel** before moving forward. If you skip this, you'll find the bug in production, and Josh will not be happy.

## What We're Actually Doing

- **Cleanup long className strings** → extract into `.css` files with `@apply`
- **Reuse animation code** → move from inline/scattered keyframes into `animations.css`
- **Add data-ref** → so we can find components in the browser DevTools quickly
- **Don't break anything** → visual parity is mandatory; behavior changes = rejected PR

## Non-Negotiable

- English-only (comments, variable names, commit messages)
- No raw CSS animations (`@keyframes` or `animation:` properties) — use Tailwind primitives + `@apply`
- No sneaky UI changes. You're refactoring, not redesigning.
- Don't create 50 tiny semantic classes. If you're extracting, it should be reused 2+ times or be obvious (like `.btn-primary`)
- No utility drift (don't introduce `px-5 py-2.5` if `px-4 py-2` already exists)
- Consolidate duplicates before creating new classes

---

## Finding Refactor Targets

Before starting a batch, scan the codebase systematically:

1. **Search for long className strings** — use patterns like `className="[^"]{120,}"` (grep/semantic search)
2. **Identify repeated utility bundles** — look for the same utility combinations appearing 2+ times across files
3. **Hunt for hidden animations** — find `@keyframes`, `animation:` properties scattered across CSS files
4. **Check for CSS duplication** — same visual patterns defined separately in different component files

**Example scan**:
```
Search: className.*rounded.*border.*bg.*px.*py
Result: 47 matches → audit top 10, extract 2-3 patterns

Search: @keyframes
Result: 3 animations → convert all to animations.css
```

Document findings before starting refactor work — this prevents random or redundant refactoring.

---

## Refactor Priority Order

Always refactor in this order to minimize risk:

1. **Buttons** — most reused, lowest complexity
2. **Form inputs & fields** — shared patterns, clear extraction
3. **Cards & container layouts** — obvious boundaries
4. **Menu & navigation items** — self-contained
5. **Badges & tags** — simple, repeated
6. **Table rows & list items** — moderate complexity
7. **Page shells & layouts** — affects many flows

**Avoid refactoring** (unless necessary):
- Chat rendering components (dynamic lists, SSE)
- Virtual scrollers
- Complex editors
- Custom hook logic
- State management wrappers

This keeps risky refactoring out of your batch.

---

## How Each Batch Works

1. **Pick your scope**: ~10–25 files or ~30–80 total changes. If you're unsure, go smaller.
2. **Make changes** in your local branch
3. **Commit everything** (see commit rules below)
4. **Push to remote**
5. **Wait for Vercel preview** to build (~2–3 min)
6. **Open the preview URL and test**:
   - Hard refresh (Ctrl+Shift+R)
   - Navigate the pages you changed
   - Check Console for errors (no hydration mismatches, no CSS import errors)
   - Use Chrome DevTools → spot-check 5–10 components using their `data-ref` selectors
   - Look for layout shifts, color changes, spacing issues
7. **If anything looks wrong**: fix it immediately in a new commit, push, and re-verify
8. **Only then** start the next batch

**⚠ Don't skip the visual check.** "It compiles" ≠ "it looks right."

### Commit Format for Batches

Each batch gets ONE commit (or 2–3 if you find a bug mid-batch and fix it). Commit message:

```
refactor(styles): [batch-name] — extract 12 components, add animations

- Extracted .btn-primary, .card-base, .form-input into components.css
- Added .anim-fade-in, .anim-dialog-in to animations.css
- Added data-ref to FileUpload, ChatInput, DialogPanel
- Verified on Vercel: no visual drift, all tests pass
```

Keep it brief but clear about what was extracted/added.

---

## Animations: No Raw CSS

**The rule**: If you see `@keyframes` or `animation:` in a CSS file, convert it to Tailwind primitives.

**Where**: `src/styles/animations.css`

**How**:
```css
@layer utilities {
  /* Dialog entrance — fade + zoom */
  .anim-dialog-in {
    @apply animate-in fade-in zoom-in-95 duration-200 ease-out;
  }

  /* Slide up from bottom */
  .anim-slide-up {
    @apply animate-in fade-in slide-in-from-bottom-2 duration-200 ease-out;
  }

  /* Fade in only */
  .anim-fade-in {
    @apply animate-in fade-in duration-200 ease-out;
  }
}
```

Use it: `<div className="anim-dialog-in">...</div>`

**Real constraint**: Some animations can't fit Tailwind's vocab (complex rotation + scale combo). Ask Josh before adding raw CSS.

---

## Semantic Classes: Keep It Simple

**When to extract**:
- className is >120–150 chars (obviously too long)
- repeated 2+ times (no point keeping it duplicated)
- obvious primitive like a button, card, form input, badge

**Where**:
- `src/styles/components.css` → shared basics (button, card, input, tabs)
- `src/styles/auth.css` → auth-specific UI
- `src/styles/dashboard.css` → dashboard-specific
- `src/styles/animations.css` → animation utils only

**DON'T extract** single-use tweaks. If it appears once and never again, leave it inline.

**Naming**: Describe the *role*, not the layout.
- ✅ `.btn-primary`, `.card-base`, `.form-field`
- ❌ `.flex-center-gap-4`, `.p-4-rounded-8`

Keep it minimal. You want maybe 8–12 semantic classes per domain, not 50.

### Consolidation Rule (Deduplication)

Before creating a new semantic class, **check if a similar one already exists**.

If two classes share >80% of utilities, extract a shared base class:

```css
/* Base for all buttons */
.btn-base {
  @apply rounded-lg px-4 py-2 font-medium transition-colors;
}

/* Variants built on base */
.btn-primary {
  @apply btn-base bg-purple-600 text-white hover:bg-purple-700;
}

.btn-secondary {
  @apply btn-base border border-gray-300 bg-white hover:bg-gray-50;
}
```

This prevents class explosion like `.btn-primary`, `.btn-primary-alt`, `.btn-primary-auth`, `.btn-primary-dashboard`.

### Utility Consistency

Prefer existing utility patterns instead of introducing slight variations.

**Bad**:
```css
/* Already exists */
.btn-primary { @apply px-4 py-2 ... }

/* Don't do this */
.btn-special { @apply px-5 py-2.5 ... }  /* Drift! */
```

**Good**:
```css
/* Reuse existing pattern, adjust only what you need */
.btn-special { @apply btn-primary bg-blue-600 ... }
```

If the design explicitly requires `px-5 py-2.5`, document *why* in a comment. Otherwise, stick to the established utility values.

---

## data-ref: Make Components Findable

Every component you touch gets a `data-ref` on the root element.

```tsx
<form data-ref="auth-login-form" className={loginFormClasses}>
  {/* ... */}
</form>

<div data-ref="chat-message-list" className={messageListClasses}>
  {/* ... */}
</div>
```

**Rules**:
- kebab-case, stable across refactors
- don't duplicate if one already exists
- for dynamic lists, pattern is `things-table.row.${id}.action-button`

**Purpose**: So in DevTools you can inspect a component, copy its `data-ref`, and jump to the source file in your editor.

---

## Verification After Each Batch

1. **Push to remote**
2. **Wait for Vercel to build** (2–3 min)
3. **Open the preview URL**
4. **Hard refresh** (Ctrl+Shift+R)
5. **Console check**: No errors, no hydration mismatches, no CSS import failures
6. **Spot-check 5–10 components** in Chrome DevTools using `data-ref` selectors
7. **Test the flows**: click buttons, navigate pages, scroll lists

**If something looks wrong**: Fix it in a new commit, push, refresh, re-verify. Don't move to the next batch until it's clean.

### Visual Diff Checklist (Specific)

When verifying in the Vercel preview, **explicitly check these dimensions**:

- ✅ **Button sizes & padding** — compare `.btn-primary` to original, check `px`, `py`, height
- ✅ **Font sizes & weights** — measure text in inspected components, verify `text-sm`, `font-medium` match design
- ✅ **Border radius** — inspect `rounded-lg` vs. previous, ensure circles/corners are identical
- ✅ **Color tokens** — hover over colored elements, compare `bg-purple-600` in DevTools computed styles
- ✅ **Spacing between elements** — measure gaps, margins, padding in grid/flex layouts
- ✅ **Hover states** — click/hover every button, check cursor, color shift, transition
- ✅ **Focus states** — tab through forms, inspect focus ring (should be visible, not missing)
- ✅ **Animation timing** — dialogs, transitions, fades should feel identical (duration, easing)
- ✅ **Line spacing & text alignment** — check `leading-*` and `text-*` classes, verify paragraph spacing
- ✅ **Responsive breakpoints** — test on mobile/tablet viewports, confirm media queries still work

If *any* metric changed more than 2–4px or 1 opacity step, investigate. Most bugs hide in subtle shifts.

---

## What to Report After Each Batch

- Commits made
- Files touched
- Types of changes (extracted classes, animations, data-refs)
- Any issues found/fixed
- Link to Vercel preview

**Example**:
```
Batch: Auth UI extraction
- 1 commit: refactor(styles): extract auth card and form inputs
- 8 files touched: LoginForm, SignupForm, ForgotPassword, OTPInput, etc.
- Extracted: .btn-primary, .form-field, .auth-card-base into auth.css
- Added data-ref to 8 components
- Verified on Vercel: no visual drift, console clean
- Preview: https://...vercel.app
```

---

## If Something Breaks

1. **Note what's wrong** (visual drift, console error, layout shift)
2. **Fix it immediately** in the same batch — don't push it to the next person
3. **Commit, push, refresh, verify again**
4. **If you can't figure it out**: see "Fast Rollback" below

---

## Fast Rollback

If a batch introduces visual drift or console errors that you **cannot fix quickly** (<15 min):

1. **Revert the commit** — `git revert HEAD` (or `git reset --hard` if not pushed yet)
2. **Push the revert** — `git push` (this automatically alerts the team)
3. **Verify the preview is restored** — hard refresh Vercel preview, confirm visual parity
4. **Document the issue** — comment on the PR or open a GitHub issue with screenshots
5. **Restart batch with smaller scope** — split batch in half, tackle only the stable parts first

**Why fast rollback matters**: A broken refactor in production costs 2+ hours to debug. A quick revert costs 2 min.

---

## Real Gotchas

- **Tailwind v4 changes** → check `animation-duration` vs `duration-*`, some primitives may have renamed
- **Next.js CSS modules** → if you add a new `.css` file, make sure it's imported in `globals.css`
- **Hydration mismatch** → usually means server-rendered HTML doesn't match client CSS. Hard refresh often fixes it, but if it persists, check class names match exactly
- **data-ref typos** → easy to misspell; always verify in DevTools that it's applied correctly
- **Extracting too early** → if you extract a class after seeing it once, you might have to refactor it again in 2 weeks. Wait for 2 uses before extracting.
- **Vercel cache** → sometimes the preview doesn't update immediately. Try hard refresh or wait 30s and reload
- **CSS file import order** → if a new `.css` file is added, verify it's imported *before* component-specific styles would override it

---

## Summary

**Before each batch**:
- 🔍 Detect offenders (long classNames, repeated patterns, animations)
- 📋 Follow priority order (buttons → inputs → cards → layouts)
- ✅ Check for duplicates before extracting

**During the batch**:
- 🔨 Small batches (10–25 files, ~30–80 changes)
- 💾 Commit with clear message
- 🚀 Push to remote

**After verifying**:
- 🎨 Hard refresh Vercel preview (Ctrl+Shift+R)
- 🔗 Spot-check 5–10 components with `data-ref` selectors
- ✏️ Use **Visual Diff Checklist** — check padding, colors, fonts, spacing, animations
- 🛑 No visual drift, no console errors
- 📝 Report what was done (files, classes, animations, issues)

**If broken**:
- 🔧 Fix immediately in same batch, or
- ↩️ Fast rollback, then restart with smaller scope

**Key patterns**:
- No raw CSS animations — use Tailwind utilities + `@apply`
- Extract only what repeats (2+ uses or obvious primitives)
- Consolidate duplicates — avoid `.btn-primary-alt` style proliferation
- Maintain utility consistency — don't drift spacing or sizing
- Add `data-ref` to everything you touch
- Don't refactor complex components (chat, virtual lists, editors)
