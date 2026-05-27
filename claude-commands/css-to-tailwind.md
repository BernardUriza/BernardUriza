# CSS to Tailwind — Zero-CSS Enforcer

ARGUMENTS: $ARGUMENTS

## Vision: Only-Tailwind / Zero-CSS

This command has TWO modes of operation:

1. **CSS Raw → Tailwind**: Convert raw CSS properties to `@apply` with Tailwind utilities
2. **Inline → Semantic Extraction**: Find inline Tailwind classes in markup (`.tsx`, `.razor`, etc.) that should be extracted to semantic classes with `@apply` in CSS files

When you find raw CSS, don't look for "the equivalent class" — investigate how Tailwind v4 **solves that problem idiomatically**. Sometimes the answer isn't a class but a structural change:

- A `::before` with content gets replaced with a `<span>` + utilities
- A custom `@keyframes` gets replaced with `animate-spin`, `animate-pulse`, etc.
- A `@media (max-width: 768px)` gets replaced with responsive variants (`md:`, `lg:`) in markup
- A `:hover` in CSS gets replaced with `hover:` directly on the class
- A `.dark .element` gets replaced with `dark:` on the element

**If the refactoring requires multiple levels** (CSS + markup + component), propose it as a plan to the user before applying. Use `WebSearch` to research only-Tailwind patterns when unsure.

The goal is for every CSS file to trend toward zero lines and every component to use semantic classes instead of utility soup. Not tomorrow — but every round should get us closer.

---

## Instructions

### Phase 0: Auto-Detect Project

Detect the project stack automatically before doing anything:

1. **Find CSS files**:
   ```
   Glob: **/*.css (excluding node_modules, dist, .next, output.css, vendor)
   ```

2. **Detect stack** by checking for key files:
   | File found | Stack | Build command |
   |------------|-------|---------------|
   | `next.config.*` | Next.js / React | `npx next build` |
   | `*.csproj` | .NET / Blazor | `dotnet build` |
   | `vite.config.*` | Vite / React | `npx vite build` |
   | `angular.json` | Angular | `npx ng build` |
   | `tailwind.config.*` only | Generic Tailwind | `npx tailwindcss build` |

3. **Detect style directory**: Find where `@apply` rules live (e.g., `src/app/styles/`, `wwwroot/css/`, `src/styles/`)

4. **Detect component file extension**: `.tsx`, `.jsx`, `.razor`, `.vue`, `.svelte`

5. Report: "Detected [stack] project. CSS in [dir]. Components are [ext]. Build: [cmd]."

### Phase 1: Mode Selection

```
AskUserQuestion:
  question: "Which mode do you want to run?"
  options:
    - "CSS Raw → Tailwind @apply" — Convert raw CSS properties to Tailwind utilities
    - "Inline → Semantic Extraction" — Extract utility combos from markup to semantic classes
    - "Both" — CSS raw first, then inline extraction
```

If `$ARGUMENTS` specifies a file or directory, skip this question and auto-detect:
- If argument points to `.css` file(s) → CSS Raw mode
- If argument points to component file(s) (`.tsx`, `.razor`, etc.) → Inline Extraction mode
- If argument is a directory → Both modes on that scope

---

## Mode A: CSS Raw → Tailwind @apply

### Phase A1: Discover CSS Files

1. Use `Glob` to find `.css` files in the detected style directory
2. If user specified a scope via `$ARGUMENTS`, limit to that
3. If no scope, use files **modified recently** (git diff or mtime)

### Phase A2: Read and Convert in Batches

1. Read files in batches of **5-8 files** in parallel (Read tool)
2. For each file, analyze with criteria:
   - Direct conversion (1:1 CSS → Tailwind)
   - Multi-level refactoring needed (CSS + markup changes)
   - Magic values (hardcoded colors, sizes, non-standard numbers)
3. Apply direct conversions using Edit tool
4. Report summary per batch: `N conversions in M files`
5. If multi-level proposals exist, list them as a plan for the user
6. Ask whether to continue to next batch

### What to Convert Directly (to @apply)

Properties where the CSS → Tailwind mapping is 1:1:

- **Layout**: display, position, float, clear, box-sizing
- **Flexbox**: flex-direction, flex-wrap, flex-grow, flex-shrink, align-items, justify-content, align-self, order
- **Grid**: place-items, place-content, grid-auto-flow, align-self
- **Spacing**: margin/padding when value is `0` or `auto`
- **Sizing**: width/height with keyword values (`100%`, `auto`, `100vh`, `min-content`, `max-content`, `fit-content`)
- **Typography**: text-align, text-transform, text-decoration, font-style, font-weight, white-space, text-overflow
- **Visual**: overflow, visibility, opacity, cursor, pointer-events, user-select, appearance, resize, object-fit, list-style
- **Position values**: top/right/bottom/left/inset when value is `0`
- **Borders**: border `0`/`none`, border-radius `0`/`9999px`/`50%`
- **Background**: `transparent`, `none`
- **Z-index**: standard Tailwind values (0, 10, 20, 30, 40, 50, auto)
- **Transitions**: transition-property, transition-duration, transition-timing-function, will-change
- **Misc**: outline `none`/`0`, transform `none`

### Propose as Multi-Level Refactoring (do NOT apply without plan)

These require changes in CSS + markup + possibly the component:

- **Media queries** (`@media`): Tailwind resolves with responsive variants (`sm:`, `md:`, `lg:`, `xl:`, `2xl:`) directly in markup
- **Pseudo-classes** (`:hover`, `:focus`, `:active`, `:disabled`, `:first-child`): Tailwind variants (`hover:`, `focus:`, `active:`, `disabled:`, `first:`)
- **Pseudo-elements** (`::before`, `::after`): Tailwind v4 `before:` and `after:` with `content-['']`, or replace with a real `<span>`
- **Dark mode** (`prefers-color-scheme: dark`, `.dark`): Tailwind `dark:` variant
- **Complex selectors** (`.parent > .child:nth-child(2)`, `.foo + .bar`): No Tailwind equivalent — evaluate restructuring

### Do NOT Convert

- Properties with `var()`, `calc()`, `color-mix()`, `clamp()` — depend on design system
- Properties inside `@keyframes` — but propose replacement with `animate-*` if one exists
- Ambiguous shorthand with multiple values (e.g., `margin: 10px 20px 30px`)
- Lines that already have `@apply`

---

## Mode B: Inline → Semantic Extraction

### Phase B1: Discover Components with Utility Soup

1. Use `Grep` to find component files with long `className` strings:
   ```
   Grep: className.*["'`].{40,} (in detected component extension)
   ```
2. If user specified scope, limit to that directory/file
3. Sort results by string length (longest = most urgent to extract)

### Phase B2: Analyze and Classify

For each long className found, classify:

| Criteria | Action |
|----------|--------|
| **Reused 2+ times** (same utility combo in multiple files) | MUST extract — always |
| **Single-use but >40 chars** | Extract for readability and regression resistance |
| **Identifiable UI primitive** (button, card, badge, form field, toggle) | Extract even if single-use |
| **Layout-only wrapper** (`mt-4 flex` and similar) | DO NOT extract — leave inline |
| **One-off positioning** (`absolute top-2 right-3`) | DO NOT extract — leave inline |
| **Contains `group`** | Keep `group` inline, extract the rest to @apply class |

### Phase B3: Extract to Semantic Classes

For each extraction candidate:

1. **Name by role**, not by utilities: `.btn-primary` not `.flex-center-gap-4`
2. **Choose the right CSS file** based on domain:
   - Buttons → `buttons.css`
   - Forms → `forms.css`
   - Cards → `cards.css`
   - Badges → `badges.css`
   - Dashboard elements → `dashboard.css`
   - Settings elements → `settings.css`
   - Modals → `modals.css`
   - Animations → `animations.css`
   - If no domain fits, create a new file or use a general one
3. **Create the @apply rule** in the appropriate CSS file
4. **Replace inline utilities** in the component with the new class name
5. If the component uses `cn()`, keep the semantic class in `cn()` for merge compatibility

### Phase B4: Deduplication Sweep

After extracting, search for duplicate utility patterns across the codebase:

```
Grep: the extracted utility combo (or significant portion)
```

If the same pattern appears in other files → replace with the new semantic class.

Report:

| Semantic Class | Defined In | Used In | LOC Saved |
|----------------|-----------|---------|-----------|
| `.btn-primary` | `buttons.css` | `Header.tsx`, `Sidebar.tsx`, `Modal.tsx` | -45 |

### Semantic Token Migration (opportunistic)

While touching files, migrate hardcoded colors to semantic tokens:

| Hardcoded | Semantic Token |
|-----------|---------------|
| `bg-white` | `bg-background` |
| `bg-gray-50` | `bg-muted` |
| `bg-gray-100` | `bg-muted` |
| `text-gray-900` | `text-foreground` |
| `text-gray-500` | `text-muted-foreground` |
| `text-gray-400` | `text-muted-foreground` |
| `border-gray-200` | `border-border` |
| `border-gray-300` | `border-border` |
| `bg-blue-600` | `bg-primary` |
| `text-blue-600` | `text-primary` |
| `bg-red-500` | `bg-destructive` |
| `text-red-500` | `text-destructive` |

Only migrate when confident of the mapping. If unsure, report as debt.

---

## Report: Magic Values / Technical Debt

At the end of each round, report magic values found:

| File | Line | Property/Class | Magic Value | Suggestion |
|------|------|---------------|-------------|------------|
| `header.css` | 42 | `color` | `#3b82f6` | Should be `var(--brand-primary)` or token |
| `Grid.tsx` | 18 | `className` | `p-[13px]` | Not on Tailwind scale — define token or use `p-3` |

---

## Rules

1. **NEVER** convert properties inside `@keyframes` — but propose replacement with `animate-*` if equivalent exists
2. **NEVER** convert properties using `var()`, `calc()`, `color-mix()`, `clamp()`
3. **NEVER** touch lines that already have `@apply`
4. **NEVER** convert ambiguous shorthand (e.g., `margin: 10px 20px 30px`)
5. If a CSS rule already has an existing `@apply`, **add** classes to the existing `@apply` instead of creating a new one
6. If an `@apply` grows to **12+ classes**, that selector does too much — propose splitting into sub-components
7. Preserve comments, order of non-converted properties, and whitespace/indentation
8. If a file has fewer than 3 convertible properties, **skip** — not worth the churn
9. **`!important` caution**: If original property has `!important`, `@apply` loses it. Use `!` prefix in Tailwind (`@apply !border-0`) or report as special case
10. **Complex selectors** (combinators `>`, `+`, `~`, pseudo-selectors `:nth-child`, `:not`) cannot be expressed in `@apply` — evaluate component restructuring or leave as CSS
11. **ALWAYS** report magic values (hex colors, custom pixels, loose numbers) as technical debt
12. **`group` cannot be in `@apply`** — keep `group` inline in the component, only extract `group-hover:*` utilities
13. **Name semantic classes by role**, not by utilities: `.card-hover` not `.rounded-lg-shadow-md-p-4`
14. **Do NOT extract layout-only wrappers** — `mt-4 flex` is not a semantic class
15. **Do NOT extract one-off positioning** — `absolute top-2 right-3` stays inline

---

## Closing: Build and Verification

When ALL work from the command is done, run the build command detected in Phase 0:

```
AskUserQuestion:
  question: "Build + verification?"
  options:
    - "Build + Chrome DevTools" — Run build, report, open Chrome, take screenshot, check console
    - "Build only" — Run build and report warnings/errors
    - "I'll do it with /build-check" — End without verification
```
