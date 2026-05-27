# /ux-polish — UX Refactoring and Pattern Enforcement

ARGUMENTS: $ARGUMENTS

## Instructions

Execute iterative rounds of UX/pattern refactoring on the area the user specifies: **$ARGUMENTS**

The primary focus is **detecting structural anti-patterns** and replacing them with the system's shared components/utilities. Cosmetic visual improvements are secondary.

### Stack Auto-Detection

Before starting, detect the current project's stack:

1. If `next.config.*` or `package.json` with `next` exists → **React/TS/Next.js** (use React section)
2. If `*.sln` or `*.csproj` exists → **Blazor/.NET** (use Blazor section)
3. If both exist → ask the user which stack applies

---

## Stack: React / TypeScript / Next.js

### Phase 1: Exhaustive Audit (DO NOT modify anything yet)

1. **Find ALL files** for the indicated feature/page:
   - `.tsx` / `.ts` components and hooks
   - `.css` stylesheets in `src/app/styles/`
   - Shared utilities in `~/core/utils/`, `~/core/ui/`, `~/core/hooks/`
   - Related types and constants

2. **Read EACH file completely** — don't guess, don't assume.

3. **Classify findings** in these categories (highest to lowest impact):

| Category | Example | Priority |
|----------|---------|----------|
| `any` types | `(lang: any)`, `(files: any[])` — especially in auth, org-scoping, hooks | CRITICAL |
| Object mutation in state | `file as FileWithProgress; file.status = 'error'` instead of immutable spread | CRITICAL |
| useEffect to derive state | `useEffect(() => setX(compute(y)), [y])` instead of `const x = compute(y)` | CRITICAL |
| Monolithic hook (300+ LOC) | Single hook mixing pipeline logic, state, UI helpers | HIGH |
| DRY violation (duplicated pipeline/helpers) | Same pattern copy-pasted in 3+ files | HIGH |
| Hardcoded colors | `bg-gray-100`, `text-gray-900` instead of semantic tokens (`bg-background`, `text-foreground`) | HIGH |
| Inline SVG | Raw `<svg><path>` instead of icon components from `~/icons/` | HIGH |
| Hand-rolled radio/checkbox | Custom `<button>` with manual circle indicators instead of Radix primitives | HIGH |
| Missing `useCallback`/`useMemo` | Handlers recreated every render in hooks that return stable references | MEDIUM |
| Hardcoded constants | Magic numbers, inline fallback arrays that should be config constants | MEDIUM |
| Dead state/imports | State variables written but never read, unused imports | MEDIUM |
| Duplicated computed values | Same derivation computed in 2+ places instead of single `useMemo` | MEDIUM |
| Raw `@keyframes` | Should use `tailwindcss-animate` primitives via `@apply` | LOW |
| Utility class drift | `px-5` when existing pattern is `px-4`, inconsistent spacing | LOW |

### Phase 2: Implement in Rounds

Execute rounds of ~8-12 changes each. Each round:

1. **List the changes** BEFORE applying them (table with #, description, file, category)
2. **Prioritize**: CRITICAL first, then HIGH, then MEDIUM, LOW last
3. **Apply all changes** in the batch
4. **Verify**: `npx tsc --noEmit` (zero errors) + `npx next build` (must pass)
5. **Report** a summary of the round

### Phase 3: Next Round

After each round, ask: "Round N complete — X changes, clean build. Continue?"

---

### Replacement Patterns (React/TS)

#### Object Mutation → Immutable Helpers

**Before (anti-pattern):**
```tsx
const fileWithProgress = file as FileWithProgress;
fileWithProgress.id = `${file.name}-${index}`;
fileWithProgress.status = 'idle';
```

**After (correct):**
```tsx
import { createFileWithProgress } from '~/core/utils/file-progress';
const wrapped = files.map(createFileWithProgress);
```

#### useEffect Derived State → Direct Calculation

**Before (anti-pattern):**
```tsx
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);
```

**After (correct):**
```tsx
const fullName = `${firstName} ${lastName}`;
```

#### Duplicated setFiles(prev => prev.map(...)) → Shared Helpers

**Before (anti-pattern):**
```tsx
setSelectedFiles(prev => prev.map(f => {
  if (f.id === file.id) { f.status = 'error'; f.progress = 0; return f; }
  return f;
}) as FileWithProgress[]);
// Repeated 11 times...
```

**After (correct):**
```tsx
import { updateFileById, markAllFiles, markFilesByIds } from '~/core/utils/file-progress';
setFiles(prev => updateFileById(prev, file.id!, { status: 'error', progress: 0 }));
```

#### Hand-rolled Radio Buttons → RadioCardGroup

**Before (anti-pattern):**
```tsx
<button onClick={() => setValue('a')}
  className={cn('rounded-lg border-2 p-4', value === 'a' ? 'border-primary-600 bg-primary-50' : 'border-gray-200')}>
  <div className="flex h-5 w-5 rounded-full border-2 ...">
    {value === 'a' && <div className="h-3 w-3 rounded-full bg-primary-600" />}
  </div>
  <p>Option A</p>
</button>
{/* Repeated 4 times... */}
```

**After (correct):**
```tsx
import { RadioCardGroup } from '~/core/ui/FormControls';
<RadioCardGroup
  options={[{ value: 'a', label: 'Option A', description: '...' }]}
  value={value}
  onValueChange={setValue}
/>
```

#### Hardcoded Colors → Semantic Tokens

**Before:** `bg-gray-100 text-gray-900 border-gray-200`
**After:** `bg-muted text-foreground border-border`

#### Inline SVG → Icon Components

**Before:** `<svg viewBox="0 0 24 24"><path d="M12..." /></svg>`
**After:** `import { Check } from '~/icons/outlines'; <Check className="h-4 w-4" />`

---

### Strict Rules (React/TS)

- **NEVER change business logic** — only structure, patterns, cleanup
- **NEVER break the build** — `npx tsc --noEmit` + `npx next build` after each round
- **No `any`** — especially in auth, session, org-scoping. Use proper types.
- **Imports use `~/`** not `@/`
- **Server Components by default** — Client only when real interactivity needed
- **No magic numbers** — `MAX_UPLOAD_TIMEOUT_MS` not `180000`
- **No inline SVG** — use icon components from `~/icons/`
- **Semantic tokens** — `bg-background` not `bg-white`, `text-foreground` not `text-gray-900`
- **`cn()` for conditional classes** — from `~/core/generic/shadcn-utils`
- **Extract `@apply` classes** — reused 2+ times or >40 chars, into `src/app/styles/*.css`
- **Shared helpers over local copies** — if a helper exists in `~/core/utils/`, import it

### Per-File Checklist (React/TS)

**Hooks (.ts):**
- [ ] No `any` types
- [ ] No `useEffect` to derive state — calculate directly
- [ ] Immutable state updates (spread, not mutation)
- [ ] `useCallback` for handlers passed as props
- [ ] `useMemo` for expensive computations
- [ ] Shared helpers imported from `~/core/utils/` not redefined locally
- [ ] Hook < 300 LOC (if bigger, decompose into pipeline steps + composing hook)

**Components (.tsx):**
- [ ] No inline SVG — use `~/icons/` components
- [ ] No hand-rolled radio/checkbox — use Radix primitives from `~/core/ui/FormControls`
- [ ] Semantic color tokens, not hardcoded Tailwind colors
- [ ] No magic numbers
- [ ] `cn()` for conditional classes
- [ ] `data-ref` attributes on interactive elements

**Styles (.css):**
- [ ] Uses semantic CSS extraction (`@apply`) for reused patterns
- [ ] No raw `@keyframes` — use `tailwindcss-animate`
- [ ] No orphan classes

---

## Stack: Blazor / .NET

### Phase 1: Exhaustive Audit (DO NOT modify anything yet)

1. **Find ALL files** for the indicated feature/page:
   - `.razor` components (markup)
   - `.razor.cs` code-behinds
   - `.css` stylesheets in `wwwroot/css/`
   - Partials and related sub-components
   - Relevant design tokens (`_tokens.css`, `_variables.css`)

2. **Read EACH file completely** — don't guess, don't assume.

3. **Classify findings** in these categories (highest to lowest impact):

| Category | Example | Priority |
|----------|---------|----------|
| Raw HTML form without FormField | Manual `<input>` + `<label>` that should be `<FormField>` | CRITICAL |
| Form without FormSection | Field groups without structure, generic divs instead of `<FormSection>` with Layout | CRITICAL |
| Modal without BaseModal | Hand-rolled `<div class="modal-*">` instead of `<BaseModal>` | CRITICAL |
| Monolithic component (300+ lines) | .razor file with everything mixed, no sub-components | HIGH |
| DRY violation (repeated HTML) | Same HTML/CSS block copy-pasted in 3+ files | HIGH |
| Redundant @using | Import already in `_Imports.razor` | HIGH |
| Redundant @namespace | `@namespace` in file already in the correct folder | HIGH |
| Select/dropdown without VhSelect | Raw HTML `<select>` that should use `FormField Type="FormInputType.Select"` | HIGH |
| Checkbox without FormField Check | Raw `<input type="checkbox">` that should be `FormField Type="FormInputType.Check"` | MEDIUM |
| Old .NET code | `new List<>()` instead of `[]`, braced namespace, constructor boilerplate | MEDIUM |
| Illegible/invisible | Text < 11px, invisible color on dark bg | LOW |
| Insufficient touch target | Button < 44px | LOW |
| Poor empty state | 16px icon, no hint text | LOW |
| Orphan CSS | Keyframes without reference, dead classes | LOW |

### Phase 2: Implement in Rounds

Execute rounds of ~8-12 changes each. Each round:

1. **List the changes** BEFORE applying them (table with #, description, file, category)
2. **Prioritize**: CRITICAL first, then HIGH, then MEDIUM, LOW last
3. **Apply all changes** in the batch
4. **Run `dotnet build`** to verify 0 errors
5. **Report** a summary of the round

### Phase 3: Next Round

After each round, ask: "Round N complete — X changes, clean build. Continue?"

---

### Replacement Patterns (Blazor)

#### HTML Form → FormField + FormSection

**Before (anti-pattern):**
```razor
<div class="form-group">
    <label for="name">Name</label>
    <input type="text" id="name" @bind="Model.Name" placeholder="Enter name" />
</div>
```

**After (correct):**
```razor
<FormSection Title="Product Data" Icon="package" Layout="FormLayout.TwoColumn">
    <FormField TValue="string" Id="name" Label="Name" Type="FormInputType.Text"
               @bind-Value="Model.Name" Placeholder="Enter name" Required />
</FormSection>
```

#### HTML Select → FormField Select

**Before:**
```razor
<select @bind="Model.Category">
    <option value="">Select...</option>
    @foreach (var cat in _categories)
    {
        <option value="@cat.Id">@cat.Name</option>
    }
</select>
```

**After:**
```razor
<FormField TValue="Guid" Id="category" Label="Category" Type="FormInputType.Select"
           @bind-Value="Model.Category" Options="_categoryOptions" Required />
```

#### Div Modal → BaseModal

**Before:**
```razor
@if (_showModal)
{
    <div class="modal-backdrop" @onclick="CloseModal">...</div>
}
```

**After:**
```razor
<BaseModal Visible="@_showModal" Title="Title" HeaderIcon="edit"
           Size="ModalSize.Medium" IsProcessing="@_saving"
           CloseOnBackdrop="true" OnClose="@(() => _showModal = false)">
    <ChildContent>@* content *@</ChildContent>
</BaseModal>
```

#### Monolithic Component → Split

**Signals that a split is needed:**
- File > 200 lines of markup
- `@code` block > 100 lines → extract to `.razor.cs`
- 3+ visually distinct sections → each one = sub-component
- 10+ `@inject` → too many responsibilities

---

### Strict Rules (Blazor)

- **NEVER change business logic** — only structure, UX, patterns, cleanup
- **NEVER break the build** — verify after each round
- **Respect design tokens** — use `var(--pos-*)` / `var(--text-*)`, don't hardcode colors
- **`@using` goes in `_Imports.razor`** unless there's a documented conflict
- **`@namespace` is redundant** if the file is in the correct folder — remove it
- **Modern .NET**: `[]` instead of `new()`, file-scoped namespaces, collection expressions
- **FormField is the standard** — all raw `<input>`, `<select>`, `<textarea>` must migrate
- **BaseModal is the standard** — all hand-rolled modals must migrate
- **If a FormField Type doesn't exist for the case**, use `FormInputType.Custom` with `ChildContent`
- **When migrating selects**, create the `VhSelectOption<T>` list where data is loaded
- **Keyboard shortcuts**: overlays/modals must close with Escape

### Per-File Checklist (Blazor)

**Razor:**
- [ ] No raw `<input>`, `<select>`, `<textarea>` (use FormField)
- [ ] No manual `<label>` + `<input>` (FormField includes label)
- [ ] No manual `<div class="modal-*">` (use BaseModal)
- [ ] Fields grouped in FormSection with correct Layout
- [ ] No redundant `@namespace`
- [ ] No `@using` already in `_Imports.razor`
- [ ] `[]` instead of `new()` for Parameter defaults
- [ ] File < 300 lines (if not, split)
- [ ] `@implements IDisposable` if there are timers/subscriptions

**CSS:**
- [ ] Uses design system tokens
- [ ] No orphan classes
- [ ] No keyframes without reference

**Code-behind (.cs):**
- [ ] No dead injections (injected services never used)
- [ ] Timers with proper Dispose
- [ ] Primary constructors where applicable

---

## Closing: Build and Verification

When ALL work from the command is done, ask with `AskUserQuestion`:

**React/TS:**
- **"tsc + next build + Chrome DevTools"**: Run both checks, open Chrome DevTools, take screenshot, report console errors
- **"tsc + build only"**: Run `npx tsc --noEmit` + `npx next build`, report errors
- **"I'll verify myself"**: Finish without verifying

**Blazor:**
- **"Build + Chrome DevTools"**: Run `dotnet build`, report warnings/errors, open Chrome DevTools
- **"Build only"**: Run `dotnet build` and report
- **"I'll do it with /build-check"**: Finish without verifying
