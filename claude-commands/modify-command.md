# /modify-command - Interactive Wizard for Creating and Modifying Claude Code Commands

## Context

This command launches an **interactive wizard** that guides the user step by step to create a new command or modify an existing one in `.claude/commands/`. It uses `AskUserQuestion` at each step to gather context, preferences, and constraints before generating the final `.md` file.

**Commands directory**: `.claude/commands/`
**File format**: Markdown (`.md`)
**Invocation**: `/command-name` in Claude Code

---

## Execution Instructions

### IMPORTANT: Mandatory Flow

1. **NEVER** generate a command without completing ALL questions
2. **ALWAYS** use `AskUserQuestion` for each step — don't assume answers
3. **ALWAYS** show a preview of the generated command BEFORE writing the file
4. **ALWAYS** verify that the command name doesn't collide with an existing one (when creating)
5. **ALWAYS** read the existing command completely before modifying it
6. **NEVER edit a command in a single location in isolation.** The same command file is mirrored across MULTIPLE repos (see STEP 0 "Duplicate-copy detection"). Editing one copy while the others drift is how a command silently "doesn't change" — the copy that runs on the user's machine is not the copy you edited. Every create/modify/delete MUST (a) detect all copies up-front, (b) apply the change to ALL real copies so they end byte-identical, and (c) close with the propagation + sync step (FILE GENERATION step 5). A change that touches one copy and forgets the rest is a FAILED run, even if that one copy is correct.

---

## STEP 0: Discovery — Inventory of Existing Commands

Before the first question, Claude MUST scan BOTH command sources:

1. **GLOBAL commands** (shared across all repos):
   ```bash
   ls -la ~/.claude/commands/*.md 2>/dev/null
   ```

2. **LOCAL commands** (specific to this project):
   ```bash
   ls -la .claude/commands/*.md 2>/dev/null
   ```

3. Read the content of each command to have full context of what already exists.

4. Build a mental inventory with the source of each one:
   - Command name
   - **Source**: 🌐 Global (`~/.claude/commands/`) or 📁 Local (`.claude/commands/`)
   - Purpose (first line of the file)
   - Line count (LOC)
   - Whether it has `ARGUMENTS` or not
   - Tone/personality (formal, aggressive, technical, etc.)

**IMPORTANT**: Local commands take priority over global ones if there's a name collision.

Global commands live in the repo `BernardUriza/BernardUriza` (profile repo) and are synced via symlink. If the user wants to create/modify a universal command, write to `~/.claude/commands/`. If it's specific to the current project, write to `.claude/commands/`.

This inventory is used in subsequent questions to offer informed options.

### STEP 0.5: Duplicate-copy detection (MANDATORY — the same command lives in ≥4 repos)

`~/.claude/commands/` is a **symlink** to the profile repo `~/Documents/BernardUriza/claude-commands/` — those two paths are the SAME file (same inode). But the same command name is ALSO mirrored, as independent divergent copies, into several other repos that distribute commands/rules to the team and the AI reviewer (VAIR). **Before touching any command, find every copy and check whether they have drifted.** Known real stores (ignore worktrees, `jobs/`, `tmp/`, and package caches — those are ephemeral):

| Store | Path | Audience |
|-------|------|----------|
| Profile repo (**runs on Bernard's machine**) | `~/Documents/BernardUriza/claude-commands/` (= `~/.claude/commands/` symlink) | Bernard, all repos |
| `.github` org repo | `<repos>/Visalaw/github-org/ai-rules/commands/` | Team / VAIR distribution |
| dotgithub clone | `<repos>/dotgithub/ai-rules/commands/` | Team / VAIR distribution |
| engineering-notes | `<repos>/Visalaw/engineering-notes/workflow/claude-commands/` | Team workflow docs |
| Project-local | `<project>/.claude/commands/` | The one repo it lives in |

Run the detection and drift check:
```bash
# 1. Find every copy of the target command across the known stores
find ~/Documents/BernardUriza/claude-commands \
     /d/repos/Visalaw/github-org/ai-rules/commands \
     /d/repos/dotgithub/ai-rules/commands \
     /d/repos/Visalaw/engineering-notes/workflow/claude-commands \
     /d/repos/Visalaw/.claude/commands \
     -maxdepth 1 -iname '<name>.md' 2>/dev/null

# 2. Compare their content hashes — if they differ, they have DRIFTED
for f in <the paths from step 1>; do printf '%s  %5s lines  %s\n' "$(sha1sum < "$f" | cut -c1-10)" "$(wc -l < "$f")" "$f"; done
```
- **All hashes equal** → in sync; proceed and remember to update ALL of them.
- **Hashes differ** → they have DRIFTED. Report the drift to the user with a table (path / mtime / hash / size), identify **which copy actually runs** (the profile repo is what `/<name>` executes on Bernard's machine), and ask via `AskUserQuestion` which version is canonical BEFORE editing. Never assume; never silently pick one. Reconcile to ONE improved version, then propagate it to all copies (FILE GENERATION step 5).

This drift is the exact failure that made a "modified" command appear unchanged: the edit landed on a team-distribution copy while the profile copy that actually runs was never touched. STEP 0.5 exists to make that impossible.

---

## STEP 1: Initial Question — Create or Modify

```
AskUserQuestion:
  question: "Do you want to create a new command or modify an existing one?"
  header: "Action"
  options:
    - label: "Create new command"
      description: "Design a command from scratch with custom name, purpose, and behavior"
    - label: "Modify existing command"
      description: "Edit a command that already exists — change its behavior, add phases, adjust tone"
    - label: "Duplicate and adapt"
      description: "Take an existing command as a base and create a variant with changes"
    - label: "Delete command"
      description: "Review and confirm deletion of a command that's no longer used"
```

### Behavior per response:

**Create new command** -> Go to STEP 1B (Scope) -> STEP 2A (Name)
**Modify existing** -> Go to STEP 2B (Selection)
**Duplicate and adapt** -> Go to STEP 2C (Selection + New name)
**Delete command** -> Go to STEP 2D (Confirmation)

---

## STEP 1B: Scope — Global or Local

```
AskUserQuestion:
  question: "Where should this command live?"
  header: "Scope"
  options:
    - label: "🌐 Global (all repos)"
      description: "Saved in ~/.claude/commands/ (synced via BernardUriza/BernardUriza repo). Available in ALL projects."
    - label: "📁 Local (this project only)"
      description: "Saved in .claude/commands/ of this repo. Only available here."
```

**Global**: Write to `~/.claude/commands/[name].md`. Afterwards remind the user to commit+push in the profile repo.
**Local**: Write to `.claude/commands/[name].md` as before.

---

## STEP 2A: Command Name (creation only)

```
AskUserQuestion:
  question: "What do you want to name the command? (it will be invoked as /name)"
  header: "Name"
  options:
    - label: "Suggest names"
      description: "Claude suggests 3-4 names based on the purpose you describe next"
    - label: "I already have a name"
      description: "I'll write the exact name I want to use"
```

### Name validations:
- Only lowercase letters, numbers, and hyphens: `[a-z0-9-]+`
- Cannot start or end with a hyphen
- Cannot collide with existing commands
- Cannot collide with Claude Code built-in commands (`help`, `clear`, `compact`, `config`, etc.)
- Maximum 30 characters
- Must be descriptive (not `cmd1` or `test123`)

### Reserved built-in commands (DO NOT use these names):
- `help`, `clear`, `compact`, `config`, `cost`, `doctor`, `fast`
- `init`, `login`, `logout`, `memory`, `model`, `permissions`
- `review`, `status`, `terminal-setup`, `vim`, `bug`

If the name collides, inform the user and ask for another.

---

## STEP 2B: Select Existing Command (modification only)

Present the existing commands as options:

```
AskUserQuestion:
  question: "Which command do you want to modify?"
  header: "Command"
  options:
    - label: "/work"
      description: "Work session start with demanding mentor (75 lines)"
    - label: "/ux-polish"
      description: "UX quick wins rounds for pages/features (83 lines)"
    - label: "/insult"
      description: "Aggressive reviewer with blunt personality (93 lines)"
    - label: "/css-to-tailwind"
      description: "Batch converter from raw CSS to Tailwind @apply (187 lines)"
```

Options are generated DYNAMICALLY from the STEP 0 inventory.
Include LOC and short description for each one.

---

## STEP 2C: Duplicate and Adapt

Same selection as STEP 2B, but then ask for the new name (STEP 2A).
Read the complete content of the source command as a base.

---

## STEP 2D: Deletion

Show the content of the command to delete and ask for explicit confirmation.
If the user confirms, delete with `rm` and report.

---

## STEP 3: Purpose and Scope

```
AskUserQuestion:
  question: "What is the main purpose of this command? Describe in 1-2 sentences what it should do when invoked."
  header: "Purpose"
  options:
    - label: "Code automation"
      description: "Refactor, clean, convert, migrate code automatically"
    - label: "Audit / Review"
      description: "Analyze code/UI and report findings classified by severity"
    - label: "Personality / Mode"
      description: "Activate a specific interaction mode (tone, language, attitude)"
    - label: "Workflow / Process"
      description: "Guide a workflow with defined steps (deploy, testing, onboarding)"
```

### Automatic follow-up:

After the selection, Claude MUST ask in free text:
> "Describe in your own words what exactly this command should do. The more detail, the better it turns out."

This is captured as the `Other` from AskUserQuestion or as a follow-up message.

---

## STEP 4: Tone and Personality

```
AskUserQuestion:
  question: "What tone should the command have when it runs?"
  header: "Tone"
  options:
    - label: "Direct professional"
      description: "No frills, executable instructions, like a technical manual. Example: /work"
    - label: "Aggressive blunt"
      description: "Raw, high-energy, attacks bad code. Loyal to the user. Example: /insult"
    - label: "Patient mentor"
      description: "Explanatory, didactic, step-by-step guidance without pressure"
    - label: "Silent efficient"
      description: "Minimum text, maximum action. Only reports results, doesn't explain. Example: /css-to-tailwind"
```

### Notes per tone:

**Direct professional**:
- Structure: Context -> Diagnosis -> Action -> Closing
- No emojis unless the user requests them
- Imperative language: "Do X", "Verify Y", "Report Z"

**Aggressive blunt**:
- Aggressive, blunt, in the user's language. Code stays in English.
- Insults go toward the CODE, never the user
- Self-criticism when Claude makes mistakes
- Colorful and technical metaphors

**Patient mentor**:
- Explains the WHY of each step
- Offers alternatives when there are trade-offs
- Celebrates progress, not just the final result
- Asks before assuming

**Silent efficient**:
- Zero unnecessary explanations
- Summary tables instead of paragraphs
- Only speaks when there's an error or decision required
- Minimal output: "N changes in M files. Clean build."

---

## STEP 5: Structure and Phases

```
AskUserQuestion:
  question: "How should the command flow be structured?"
  header: "Structure"
  options:
    - label: "Sequential phases"
      description: "Phase 1 -> Phase 2 -> Phase 3. Each phase completes before advancing. Example: /ux-polish (Audit -> Implementation -> Verification)"
    - label: "Iterative rounds"
      description: "Batches of N changes, build, report, ask whether to continue. Example: /css-to-tailwind"
    - label: "Single pass"
      description: "Execute everything from start to finish without intermediate pauses"
    - label: "Continuous interactive"
      description: "Ask the user at each key decision, like a wizard"
```

### Follow-up for sequential phases:

```
AskUserQuestion:
  question: "How many phases should it have?"
  header: "Phases"
  options:
    - label: "2 phases"
      description: "Analysis + Execution"
    - label: "3 phases"
      description: "Analysis + Execution + Verification"
    - label: "4+ phases"
      description: "I'll describe the phases I need"
```

### Follow-up for iterative rounds:

```
AskUserQuestion:
  question: "How many changes per round?"
  header: "Round size"
  options:
    - label: "5-8 changes"
      description: "Small batches, more control"
    - label: "8-12 changes"
      description: "Balance between speed and control (recommended)"
    - label: "12-20 changes"
      description: "Large batches, fewer interruptions"
    - label: "No limit"
      description: "Apply everything found at once"
```

---

## STEP 6: Command Arguments

```
AskUserQuestion:
  question: "Does the command need arguments from the user when invoked?"
  header: "Arguments"
  options:
    - label: "Yes, a free argument"
      description: "The user writes free text after the command. Example: /ux-polish POS"
    - label: "Yes, formatted arguments"
      description: "The user passes flags or structured parameters. Example: /deploy --env staging"
    - label: "No, no arguments"
      description: "The command runs as-is, no additional input. Example: /work"
    - label: "Optional"
      description: "Works without arguments but accepts one to limit scope"
```

### If it has arguments:

Claude MUST include in the generated file:
```markdown
ARGUMENTS: $ARGUMENTS
```

And reference `$ARGUMENTS` in the instructions where the user input is used.

---

## STEP 7: Rules and Constraints

```
AskUserQuestion:
  question: "What critical constraints must the command respect?"
  header: "Rules"
  multiSelect: true
  options:
    - label: "Don't change business logic"
      description: "Only visual changes, UX, cleanup — never touch functional behavior"
    - label: "Verify build afterwards"
      description: "Run the project's build command to validate 0 errors"
    - label: "Respect design tokens"
      description: "Use CSS design system variables, never hardcode colors/sizes"
    - label: "Ask confirmation before deleting"
      description: "Never delete files or code without explicit user confirmation"
```

### Additional rules that are ALWAYS included (not asked):

1. **DRY**: No code repetition of any kind
2. **Modern language features**: Use the latest stable features of the detected stack
3. **Follow project import conventions**: Detect from existing code and match
4. **No emojis**: Unless the user explicitly requests them
5. **Verify before celebrating**: Never say "done" without confirming it works

---

## STEP 8: Interaction Examples (for commands with personality)

Only if the tone chosen in STEP 4 was "Aggressive blunt" or "Patient mentor":

```
AskUserQuestion:
  question: "Do you want to include examples of how Claude should respond when using this command?"
  header: "Examples"
  options:
    - label: "Yes, generate examples"
      description: "Claude generates 3-4 examples of typical interactions based on the chosen tone"
    - label: "Yes, I'll provide examples"
      description: "I'll write example phrases that Claude should use as reference"
    - label: "No, just instructions"
      description: "The tone is described in the instructions, without explicit examples"
```

### Example templates per tone:

**Aggressive blunt**:
```markdown
## Interaction Examples
- **Attack**: "What the hell is this 500-line file? Not a single component extracted. I'm going to tear this apart."
- **Improvement**: [Refactored code with explanations]
- **Self-criticism**: "I screwed up that regex, but it's fixed now. My bad."
- **Questioning**: "This service injects 8 dependencies. Is it a god object or is there a reason? Tell me and I'll split it."
```

**Patient mentor**:
```markdown
## Interaction Examples
- **Explanation**: "I'm going to use the Repository pattern here because it lets us change the database without touching business logic."
- **Alternative**: "We can solve this with a Mediator or with direct injection. The Mediator adds a layer but gives more flexibility. What do you prefer?"
- **Celebration**: "Excellent — with this change the page loads 40% faster. Good work."
```

---

## FILE GENERATION

After completing ALL questions, Claude MUST:

### 1. Show Preview

Present the COMPLETE content of the generated file in a code block:

```
Here's the generated command. Review it and tell me if you want to adjust anything before saving:

[complete .md content]
```

### 2. Ask for Confirmation

```
AskUserQuestion:
  question: "Does the command look good? Save it to .claude/commands/[name].md?"
  header: "Confirm"
  options:
    - label: "Save as-is"
      description: "Write the file and done"
    - label: "Adjust something"
      description: "I want to change a part before saving"
    - label: "Start over"
      description: "Discard and redo the questions from the beginning"
```

### 3. Write File

Use the `Write` tool to create/overwrite the file:
```
Write: .claude/commands/[name].md
```

### 4. Verify

Confirm that the file exists and has the correct content:
```bash
wc -l .claude/commands/[name].md
head -3 .claude/commands/[name].md
```

Report: "Command `/name` saved — N lines. Invoke it with `/name` in any session."

### 5. Propagate to ALL copies + sync (MANDATORY for global commands — never profile-only)

A global command is NOT done when only the profile copy is written. Propagate the identical file to every real store detected in STEP 0.5 so they end byte-identical, then run the sync command and commit the shared repos.

```bash
# a. Propagate the canonical file to every other real copy (byte-identical)
SRC=~/Documents/BernardUriza/claude-commands/[name].md
for dst in \
  /d/repos/Visalaw/github-org/ai-rules/commands/[name].md \
  /d/repos/dotgithub/ai-rules/commands/[name].md ; do
  [ -e "$dst" ] && cp "$SRC" "$dst"   # only overwrite stores that already carry this command; ask before ADDING it to a new store
done

# b. Verify all hashes now match (the go/no-go gate)
for f in "$SRC" /d/repos/Visalaw/github-org/ai-rules/commands/[name].md /d/repos/dotgithub/ai-rules/commands/[name].md; do
  [ -e "$f" ] && printf '%s  %s\n' "$(sha1sum < "$f" | cut -c1-12)" "$f"
done
```

Then push each store the change touched:
- **Profile repo** — this is what `/sync-commands` publishes. Run `/sync-commands` (or `cd ~/Documents/BernardUriza && git add -A && git commit -m "feat(commands): <name> — <change>" && git push`). Never hand-write an attribution footer in git output.
- **Shared repos (`github-org`, `dotgithub`, `engineering-notes`)** — these are TEAM repos. Committing is autonomous, but a **push to their protected/`main` branch is gated** — surface it as an `AskUserQuestion` for Bernard's go, or push to a feature branch + open a draft PR. Never force a shared-repo `main` push as a side effect of a command edit. Per git-safety, a shared-repo change is NOT "done" until committed **and** pushed — do not report completion while it sits local.

Report: which copies were updated, the matching hash, and the exact sync/commit state of each repo (pushed / committed-local / awaiting Bernard's go). If any copy could not be reconciled, say so explicitly — a silent partial propagation is the drift bug returning.

---

## STRUCTURE TEMPLATES

Based on the command type, use these templates as a skeleton:

### Template: Code Automation

```markdown
# /name - Short description

ARGUMENTS: $ARGUMENTS

## Instructions

### Phase 1: Discovery

1. Find relevant files using Glob/Grep
2. Read files in batches of 5-8 in parallel
3. Identify patterns to modify

### Phase 2: Batch Execution

1. Apply changes using Edit tool
2. Report summary per batch
3. Ask whether to continue

### Phase 3: Verification

```bash
# Detect and run the project's build command (from package.json, Makefile, .csproj, etc.)
```

## Rules

- [rules from STEP 7]

## [Conversions/Patterns/etc.] Table

| Before | After |
|--------|-------|
| ... | ... |
```

### Template: Audit / Review

```markdown
# /name - Short description

ARGUMENTS: $ARGUMENTS

## Instructions

### Phase 1: Exhaustive Audit (DO NOT modify anything yet)

1. Find ALL files in the specified scope
2. Read EACH file completely
3. Classify findings by severity:

| Category | Example | Priority |
|----------|---------|----------|
| [critical] | ... | CRITICAL |
| [high] | ... | HIGH |
| [medium] | ... | MEDIUM |
| [low] | ... | LOW |

### Phase 2: Implement in Rounds

Rounds of ~N changes. Each round:
1. List changes BEFORE applying
2. Apply changes
3. Build verify
4. Report summary

### Phase 3: Next Round

Ask: "Round N completed — X changes, clean build. Continue?"

## Rules

- [rules from STEP 7]

## Checklist per File Type

**[type1]:**
- [ ] ...
- [ ] ...

**[type2]:**
- [ ] ...
```

### Template: Personality / Mode

```markdown
# Descriptive Title

## Introduction

Description of the role and personality that Claude should adopt.

## Role and Personality

- **[trait 1]**: Description
- **[trait 2]**: Description
- **[trait 3]**: Description

## Behavior

### Main Phases

1. **[phase 1]**: What Claude does first
2. **[phase 2]**: What Claude does next

### Key Rules

- **Language**: ...
- **Tone**: ...
- **Constraints**: ...

## Interaction Examples

- **[type1]**: "Example response"
- **[type2]**: "Example response"
- **[type3]**: "Example response"
```

### Template: Workflow / Process

```markdown
# /name - Short description

## Context

Description of the workflow and when to use it.

## Operational Format

### Start

1. Verify state (git status, processes, etc.)
2. Initial question to the user

### During the Session

1. Focus on current task
2. Continuous feedback
3. Document decisions

### Closing

1. Summary of what was accomplished
2. Pending tasks
3. Suggested next step

## Connection to the Project Mission

- How this helps the end users
- How this helps real clients
```

---

## QUALITY RULES FOR GENERATED COMMANDS

### Mandatory minimums:

| Criterion | Minimum | Ideal |
|-----------|---------|-------|
| Lines of code (LOC) | 50 | 100+ |
| Sections with `##` | 3 | 5+ |
| Rules/constraints | 3 | 6+ |
| Examples (if applicable) | 2 | 4+ |

### Mandatory structure:

Every command MUST have these sections (in order):

1. **Title** — `# /name - Description` (line 1)
2. **Arguments** — `ARGUMENTS: $ARGUMENTS` (if applicable, line 3)
3. **Instructions** — `## Instructions` (the heart of the command)
4. **Rules** — `## Rules` or `## Strict Rules` (constraints)

Optional but recommended sections:

5. **Context** — Why this command exists
6. **Examples** — What it looks like in action
7. **Checklist** — Verifications per file type
8. **Reference tables** — Mappings, conversions, etc.

### Anti-patterns in commands:

| Anti-pattern | Problem | Solution |
|--------------|---------|----------|
| Vague instructions | "Improve the code" — what does that mean? | Specify: "Convert `new List<>()` to `[]`" |
| No rules | Claude improvises and can break things | Minimum 3 explicit rules |
| No verification | No way to know if it worked | Include a build/test step |
| Monolithic | One block of text without structure | Split into Phases/Steps with headers |
| No examples (for tones) | Claude misinterprets the personality | Minimum 3 interaction examples |
| Contradictory rules | "Never change logic" + "Refactor everything" | Review coherence before saving |

---

## FLOW FOR MODIFYING EXISTING COMMANDS

When the user chooses "Modify existing":

### 1. Detect all copies, then read the canonical one

Run STEP 0.5 duplicate-copy detection for `[name]` FIRST. If the copies have drifted, resolve which is canonical (per STEP 0.5) before reading. Then read the canonical copy completely:

```bash
cat ~/Documents/BernardUriza/claude-commands/[name].md   # the copy that runs for Bernard
```

Never `cat` a single project-local copy and assume it is the whole story — a modify run that reads one copy and edits one copy is the drift bug this command exists to prevent.

### 2. Show summary

"The command `/name` has N lines with these sections: [list]. What do you want to change?"

### 3. Ask what to modify

```
AskUserQuestion:
  question: "What aspect of the command do you want to modify?"
  header: "Modify"
  multiSelect: true
  options:
    - label: "Add new phase/section"
      description: "Insert a step or section that doesn't exist"
    - label: "Change tone/personality"
      description: "Adjust how Claude responds when using this command"
    - label: "Add/change rules"
      description: "Modify the constraints and validations"
    - label: "Expand content"
      description: "Make the command more detailed, add tables, checklists, examples"
```

### 4. Iterate with specific questions

Based on what was selected, ask follow-up questions for each area to modify.

### 5. Apply changes

Use `Edit` tool for surgical modifications (don't rewrite the entire file).
If changes exceed 50% of the file, use `Write` for a complete rewrite.

### 6. Verify

Show diff or final content to the user before confirming.

---

## EXISTING COMMANDS METRICS (reference)

| Command | LOC | Sections | Rules | Has Args | Tone |
|---------|-----|----------|-------|----------|------|
| /work | 75 | 6 | 3 | No | Professional |
| /ux-polish | 83 | 7 | 12 | Yes ($ARGUMENTS) | Silent |
| /insult | 93 | 8 | 6 | Yes ($ARGUMENTS) | Aggressive |
| /css-to-tailwind | 187 | 12 | 7 | No | Silent |

This table is updated DYNAMICALLY when executing STEP 0.

---

## FINAL NOTES

### Rapid iteration

If the user isn't satisfied with the result, offer:
1. "Want to adjust just one section?"
2. "Want to change the tone completely?"
3. "Want to add more rules?"

Each adjustment is a round of `AskUserQuestion` + `Edit`.

### Consistency with the ecosystem

Every generated command MUST:
- Respect the rules from `.claude/rules/` (DRY, modern language features, imports, etc.)
- Connect to the project's mission ("How does this help the end users?")
- Be invocable immediately after creation (no additional setup)
- Use `AskUserQuestion` instead of plain text questions when there are clear options

### About size

- Short commands (<50 LOC) are suspicious — they're probably missing detail
- Long commands (>300 LOC) are normal if they have reference tables (like /css-to-tailwind)
- Length should be proportional to the complexity of the desired behavior
- Never artificially inflate — every line must add value

---

_Documented: 2026-03-07 | The meta-command to rule them all_
