# /ux-polish — UX Refactoring and Pattern Enforcement

ARGUMENTS: $ARGUMENTS

## Instructions

Execute iterative rounds of UX/pattern refactoring on the area the user specifies: **$ARGUMENTS**

The primary focus is **detecting structural anti-patterns** and replacing them with **the canonical patterns this project already uses** — never with patterns from another project. Cosmetic visual improvements are secondary.

This command is **stack-agnostic**: it does not assume any framework, component library, import alias, design-token scheme, or build command. It **discovers** them from the repository in Phase 0 and enforces what it finds. If the project has no canonical primitive for a given concern, you propose extracting one — you never invent a name from another codebase.

---

## Phase 0: Discover the Project's Conventions (NEVER skip)

Before auditing a single file, learn how THIS repo works. Read, don't assume. Record each finding — every later phase references it.

1. **Stack & language** — inspect manifests: `package.json`, `*.csproj`/`*.sln`, `pyproject.toml`/`requirements.txt`, `go.mod`, `Cargo.toml`, `pubspec.yaml`, `composer.json`, `Gemfile`, etc. Identify the UI framework from dependencies (Next/React, Vue, Svelte, Angular, Blazor, SwiftUI, Flutter, …). If multiple UI surfaces exist, scope to the one `$ARGUMENTS` lives in.

2. **Verify command** — derive the real build/typecheck/lint commands from the repo, do NOT hardcode:
   - JS/TS: `package.json` `scripts` (`build`, `typecheck`/`tsc`, `lint`). Prefer the project's script over a raw tool call.
   - .NET: `dotnet build`. Python: the configured `ruff`/`mypy`/`pytest`. Make-based: `make build`/`make check`. Etc.
   - If a script exists, call it through the project's package manager (`npm`/`pnpm`/`yarn`/`bun` — detect from the lockfile).

3. **Import alias** — read `tsconfig.json`/`jsconfig.json` `paths`, bundler config, or language equivalent. Use the alias the repo actually uses (`~/`, `@/`, `src/…`, a Go module path, a .NET namespace). Never impose an alias from another project.

4. **Canonical component library** — find where shared/design-system primitives live (e.g. `components/ui/`, `core/ui/`, a published package, a Razor component folder). List the form, modal, button, and selection primitives that already exist. These — and only these — are the migration targets.

5. **Design tokens** — find the token source: Tailwind `theme`/`@theme`, CSS custom properties, a `tokens.*`/`theme.*` file, a design-system package. Record the semantic token names (background, foreground, muted, border, primary…) as the project spells them.

6. **Icon system** — find how icons are rendered (an icon package, a local `icons/` barrel, inline SVG-by-convention). Record the canonical way so you can flag deviations.

7. **State/render idioms** — note the framework's correct patterns (derive-don't-store, immutable updates, memoization, disposal) so the audit speaks the project's dialect.

**Output a short "Conventions" block** summarizing 1–7 before Phase 1. If any item is genuinely undiscoverable, say so explicitly — do not fill it with a guess.

---

## Phase 1: Exhaustive Audit (DO NOT modify anything yet)

1. **Find ALL files** for the indicated feature/page in `$ARGUMENTS`: components, logic/hooks/code-behind, stylesheets, related types/constants, and the shared utilities discovered in Phase 0.

2. **Read EACH file completely** — don't guess, don't assume.

3. **Classify findings** using the universal categories below (highest to lowest impact). Each row is framework-independent; map "canonical primitive" to whatever Phase 0 found.

| Category | What it looks like (any stack) | Priority |
|----------|-------------------------------|----------|
| Untyped escape hatches | `any`/`object`/`dynamic`/`interface{}` in auth, scoping, data boundaries | CRITICAL |
| Mutating shared/state objects | In-place mutation where the framework requires immutable updates | CRITICAL |
| Derived state stored & synced | Effect/watcher that re-stores a value computable directly from inputs | CRITICAL |
| Hand-rolled vs canonical primitive | Raw input/select/checkbox/modal instead of the project's discovered form/modal primitive | CRITICAL |
| Monolithic unit | One file mixing logic, state, and presentation past the repo's norm | HIGH |
| DRY violation | Same block/pipeline/helper copy-pasted in 3+ places | HIGH |
| Hardcoded visual values | Literal colors/sizes instead of the project's semantic design tokens | HIGH |
| Off-system iconography | Icons rendered against the repo's discovered convention | HIGH |
| Redundant boilerplate | Imports/namespaces/usings already provided globally by the project | MEDIUM |
| Missing memoization/stability | Recreated handlers/derivations where the framework expects stable refs | MEDIUM |
| Magic numbers/strings | Inline literals that should be named constants/config | MEDIUM |
| Dead code | State written-never-read, unused imports, orphaned helpers | MEDIUM |
| Missing cleanup | Timers/subscriptions/listeners without disposal | MEDIUM |
| Style drift | Inconsistent spacing/scale vs the established pattern | LOW |
| Orphan styles | Unreferenced keyframes/classes; raw animation where a primitive exists | LOW |
| Accessibility/touch | Sub-44px targets, illegible contrast, missing keyboard close on overlays | LOW |

---

## Phase 2: Implement in Rounds

Execute rounds of ~8–12 changes each. Each round:

1. **List the changes** BEFORE applying them (table: #, description, file, category).
2. **Prioritize**: CRITICAL first, then HIGH, MEDIUM, LOW last.
3. **Apply all changes** in the batch.
4. **Verify** with the command discovered in Phase 0 (must pass — zero new errors).
5. **Report** a summary of the round.

## Phase 3: Next Round

After each round, ask: "Round N complete — X changes, clean build. Continue?"

---

## Universal Replacement Principles

These are framework-independent. Express each fix in the project's own primitives (Phase 0), not in any specific library's names.

**Mutation → immutable update**
Replace in-place mutation of state/props with the framework's immutable update path (spread, copy-with, signal set, immutable helper). If the same update repeats 3+ times, extract a shared helper into the project's utils location.

**Stored derived state → direct derivation**
Replace `store + effect-to-resync` with a plain computed value (`const x = f(y)`, computed/memo/selector — whatever the framework provides). An effect is for side effects, not for mirroring inputs.

**Hand-rolled control → canonical primitive**
Replace bespoke inputs/selects/checkboxes/radios/modals with the project's discovered form/modal primitive. If none exists and the pattern recurs 3+ times, propose extracting one into the shared component location — name it by the repo's existing convention, never by another project's.

**Hardcoded visuals → semantic tokens**
Replace literal colors/sizes with the project's semantic tokens (as Phase 0 spelled them). If a needed token is missing, add it to the token source rather than hardcoding.

**Off-system icon → canonical icon path**
Replace inline/ad-hoc icons with the repo's discovered icon convention.

**Duplicated logic → shared helper**
Extract by the Rule of Three: 2 copies stay, 3+ get a single shared helper in the project's utils location. Don't force a generic abstraction that needs 3+ params — duplication beats the wrong abstraction.

**Redundant boilerplate → remove**
Drop imports/namespaces/usings already provided globally, dead state, and unused symbols.

---

## Strict Rules

- **NEVER change business logic** — only structure, patterns, UX, cleanup.
- **NEVER break the build** — run the Phase 0 verify command after each round; red stays red, report it.
- **NEVER import a name, alias, token, or component from another project** — only what Phase 0 proved exists here. If it doesn't exist, propose creating it in the canonical location; don't conjure it.
- **No untyped escape hatches** at data/auth/scoping boundaries — use the language's proper types.
- **Match the repo's idioms** — its alias, its token names, its package manager, its file layout. The code you leave should be indistinguishable from code the project's own team wrote.
- **No magic numbers/strings** — name them as the project names constants.
- **Shared over local** — if a helper/primitive exists, import it; don't redefine.
- **Rule of Three for extraction** — don't extract on the second occurrence, don't tolerate the fourth.
- **Modern language features** — use the current stable idioms of the detected stack (collection literals, file-scoped namespaces, computed signals, etc.).
- **Accessibility floor** — overlays close on Escape, interactive targets ≥44px, legible contrast.

## Per-Unit Checklist (map to the discovered stack)

**Logic units (hooks / code-behind / composables / stores):**
- [ ] No untyped escape hatches
- [ ] Derived values computed directly, not stored-and-synced
- [ ] Immutable state updates
- [ ] Stable references where the framework expects them (memo/callback/computed)
- [ ] Shared helpers imported, not redefined
- [ ] Cleanup for timers/subscriptions
- [ ] Within the repo's size norm (else decompose)

**Presentation units (components / templates / views):**
- [ ] Canonical form/modal/selection primitives, not hand-rolled
- [ ] Semantic design tokens, not hardcoded colors/sizes
- [ ] Canonical icon convention, not off-system icons
- [ ] No magic numbers; conditional styling via the repo's helper
- [ ] Redundant global boilerplate removed

**Styles:**
- [ ] Reused patterns extracted via the project's mechanism
- [ ] No orphan classes/keyframes; animation via the project's primitive

---

## Closing: Build and Verification

When ALL work is done, ask with `AskUserQuestion`, wording the build option with the **actual command discovered in Phase 0**:

- **"Verify + Chrome DevTools"**: Run the project's build/typecheck/lint, then open Chrome DevTools, screenshot the affected surface, report console errors.
- **"Verify only"**: Run the project's build/typecheck/lint and report results.
- **"I'll verify myself"**: Finish without verifying.
