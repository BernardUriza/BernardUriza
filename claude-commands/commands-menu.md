# /commands-menu — Smart Command Index & Context-Aware Launcher

Scan all available slash commands, analyze the current session context, and recommend the most relevant ones. Think of it as a concierge that knows what tools exist AND what you're working on right now.

ARGUMENTS: $ARGUMENTS

## Instructions

### Phase 0: Inventory — Scan All Commands

Scan BOTH command sources in parallel:

1. **Global commands** (`~/.claude/commands/*.md`)
2. **Local commands** (`.claude/commands/*.md` in the current project)

For each command file:
- Read the **first 5 lines** to extract: title, description, arguments
- Count total lines (LOC)
- Check if it uses `AskUserQuestion` (interactive vs fire-and-forget)
- Classify into a category (see table below)

Build the full inventory as an internal data structure before proceeding.

### Phase 1: Context Analysis

Gather current session context in parallel:

1. **Git state**: `git status --short`, `git branch --show-current`, `git log --oneline -5`
2. **Running processes**: check ports 8000, 8080, 9222 (frontend, backend, Chrome DevTools)
3. **Recent conversation**: what has the user been working on in this session?
4. **Repo detection**: which repo(s) are we in? (frontend, backend, monorepo root, standalone)

From this context, determine the user's likely **current mode**:
- **Coding** — uncommitted changes exist, on a feature branch
- **Pre-push** — changes committed but not pushed, build verification needed
- **Reviewing** — on main/staging, no local changes, looking at PRs
- **Debugging** — error patterns in recent conversation, servers may be down
- **Planning** — no code changes, session just started or between tasks
- **Infrastructure** — backend/deploy/AWS context in recent messages

### Phase 2: Categorize & Rank Commands

Classify each command into categories:

| Category | Icon | Commands (examples) |
|----------|------|-------------------|
| Code Quality | 🔍 | `/code-review`, `/cruel-critic`, `/insult`, `/psalm-reader` |
| Refactoring | ♻️ | `/css-to-tailwind`, `/submissive-modularizer`, `/schizo-modernizer`, `/tsx-refactor` |
| Build & Deploy | 🏗️ | `/build-check`, `/aws-checkpoint`, `/kill-zombies` |
| Workflow | 📋 | `/work`, `/triage`, `/immediate-orchestrator` |
| Git & PRs | 🔀 | `/changelog`, `/collect-learnings`, `/sync-rules` |
| UX & Design | 🎨 | `/ux-polish`, `/view-verification` |
| Session Mgmt | 💾 | `/save-context`, `/resume-context` |
| Meta | ⚙️ | `/modify-command`, `/register-rule`, `/commands-menu` |
| Utility | 🔧 | `/cut`, `/histerical-search` |

**Ranking logic** — score each command 0-10 based on context match:
- +5 if category matches current mode (e.g., Build commands when in pre-push mode)
- +3 if the command's scope matches the current repo
- +2 if the user mentioned something related in recent conversation
- +1 base score for frequently used commands
- -3 if the command requires a disconnected MCP (e.g., Chrome DevTools when MCP is down)

### Phase 3: Present the Menu

Use `AskUserQuestion` to present commands grouped by relevance:

```
AskUserQuestion:
  question: "You're in [detected mode] mode on [branch]. Here are your best options:"
  header: "Command"
  options:
    - label: "/[top-ranked-command] (Recommended)"
      description: "[category icon] [one-line description] — [why it's relevant right now]"
    - label: "/[second-command]"
      description: "[category icon] [one-line description] — [why it's relevant]"
    - label: "/[third-command]"
      description: "[category icon] [one-line description] — [why it's relevant]"
    - label: "Show all commands"
      description: "Full inventory with categories — [N] commands available"
```

The top 3 options are ALWAYS context-ranked. The 4th option is always "Show all commands".

### Phase 4A: If User Picks a Command

Confirm and launch:

```
AskUserQuestion:
  question: "Launch /[selected-command]? Any arguments to pass?"
  header: "Launch"
  options:
    - label: "Run it now, no args"
      description: "Launch /[command] immediately with default behavior"
    - label: "Run with arguments"
      description: "I'll type the arguments in Other"
    - label: "Show me the details first"
      description: "Read the full command file and explain what it does before running"
    - label: "Go back to menu"
      description: "Return to the command selection"
```

If "Run it now" or "Run with arguments": invoke the command using the `Skill` tool.
If "Show me the details first": read and summarize the command, then ask again.

### Phase 4B: If User Picks "Show All Commands"

Present the FULL inventory as a formatted table:

```markdown
## 📚 All Commands — N total

### 🔍 Code Quality (N)
| Command | Description | Interactive | LOC |
|---------|-------------|-------------|-----|
| `/code-review` | Surgical code review with severity ratings | ✅ 3 questions | 118 |
| `/cruel-critic` | System-level architectural review | ❌ fire-and-forget | 85 |
| `/insult` | Aggressive reviewer personality mode | ✅ 1 question | 93 |

### ♻️ Refactoring (N)
...

### 🏗️ Build & Deploy (N)
...
```

Then ask:

```
AskUserQuestion:
  question: "Pick a command from the full list, or filter by category:"
  header: "Select"
  options:
    - label: "Code Quality commands"
      description: "N commands for reviewing and auditing code"
    - label: "Refactoring commands"
      description: "N commands for cleaning, converting, and modernizing code"
    - label: "Build & Deploy commands"
      description: "N commands for building, deploying, and infrastructure"
    - label: "I'll type the command name"
      description: "Type /command-name in Other"
```

### Phase 5: Handle $ARGUMENTS Shortcuts

If `$ARGUMENTS` is not empty, skip the interactive menu and fast-track:

- **`$ARGUMENTS` = "all"** or **"list"**: Jump to Phase 4B (show all commands)
- **`$ARGUMENTS` = a category name** (e.g., "build", "refactor", "quality"): Filter to that category and present via AskUserQuestion
- **`$ARGUMENTS` = a command name** (e.g., "insult", "build-check"): Jump to Phase 4A with that command pre-selected
- **`$ARGUMENTS` = "search [keyword]"**: Grep all command files for the keyword and present matches

## Rules

- **NEVER fabricate commands** — only show commands that actually exist in the scanned directories
- **Context detection must be evidence-based** — use git status, port checks, and conversation history. Never guess the mode.
- **Ranking must be explainable** — if the user asks "why this command?", you can justify the recommendation with specific context signals
- **Disconnected MCPs = flag it** — if a command requires Chrome DevTools or Sentry and the MCP is down, note it in the description: "⚠️ Requires Chrome DevTools MCP (currently disconnected)"
- **Local commands override global** — if the same name exists in both, show the local version and note the conflict
- **Fast-track with args** — `$ARGUMENTS` shortcuts bypass the interactive flow for power users
- **Category assignment is best-effort** — if a command doesn't fit neatly, put it in Utility
- **Always show LOC and interactivity** — users want to know if a command is a quick 50-liner or a 200-line deep workflow, and whether it'll ask questions or just run
- **Respond in English** for all file content and command descriptions. Conversation with the user follows their language preference.
