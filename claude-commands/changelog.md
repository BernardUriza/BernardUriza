# /changelog — Automated Changelog Generator

Generate a formatted changelog comparing two git refs (branches, tags, commits). Supports dual output: GitHub/Notion markdown + Slack mrkdwn. Groups by type AND scope.

ARGUMENTS: $ARGUMENTS

## Usage

```
/changelog                                    # all commits on current branch vs its upstream
/changelog staging-v2                         # current branch vs staging-v2
/changelog main..feature/drafts-staging       # explicit range
/changelog staging-v2 --slack                 # Slack mrkdwn output only
/changelog main --since="2026-03-20"          # filter by date
/changelog main --scope=chat,drafts           # filter by scope
/changelog main --repo=Visalaw/visalaw-gen-backend  # different repo via gh API
```

## Instructions

### Step 0: Interactive Config (when no arguments)

If `$ARGUMENTS` is empty, use `AskUserQuestion` to gather parameters interactively:

```
AskUserQuestion:
  question: "Which repo should I generate the changelog for?"
  header: "Repo"
  options:
    - label: "Frontend (frontend-core-2.0) (Recommended)"
      description: "Current branch vs main — local git log"
    - label: "Backend (visalaw-gen-backend)"
      description: "Current branch vs staging-v2 — local git log"
    - label: "Both repos"
      description: "Generate changelogs for frontend AND backend, side by side"
    - label: "Custom range"
      description: "I'll specify base..head or a remote repo in Other"
```

Then ask for output format:

```
AskUserQuestion:
  question: "What format do you need?"
  header: "Format"
  options:
    - label: "Slack mrkdwn (Recommended)"
      description: "Ready to paste into #temp-core2-UAT or #plane-updates"
    - label: "Markdown"
      description: "For GitHub PRs, Notion, or engineering-notes"
    - label: "Both"
      description: "Generate both Slack and Markdown versions"
```

If `$ARGUMENTS` are provided with explicit flags (`--slack`, `--repo`, etc.), skip these questions.

### Step 1: Parse Arguments

Parse `$ARGUMENTS` for:
- **Range**: `base..head` or single ref (compare current branch to that ref)
- **Flags**: `--slack` (Slack mrkdwn), `--md` (markdown, default), `--both` (both formats)
- **Filters**: `--since="date"`, `--scope=x,y`, `--author=username`
- **Remote**: `--repo=owner/repo` (use `gh api` instead of local git)

If no arguments: detect current branch, compare against its upstream tracking branch or `main`.

### Step 2: Extract Commits

**Local repo:**
```bash
git log base..head --no-merges --format="%H|%s|%an|%ad" --date=short
```

**Remote repo (via gh):**
```bash
gh api repos/{owner}/{repo}/compare/{base}...{head} --jq '.commits[] | "\(.sha[0:7])|\(.commit.message | split("\n")[0])|\(.commit.author.name)|\(.commit.author.date[0:10])"'
```

### Step 3: Parse Conventional Commits

For each commit message, extract:
- **type**: feat, fix, refactor, chore, docs, test, perf
- **scope**: whatever is in parentheses — `feat(chat)` → scope = `chat`
- **description**: the rest after the colon
- **breaking**: if message contains `!` before `:` or body contains `BREAKING CHANGE`

Commits that don't follow conventional format go into an "Other" category.

### Step 4: Group and Sort

**Primary grouping: by TYPE** (ordered by importance)
1. 💥 Breaking Changes
2. 🚀 Features (`feat`)
3. 🐛 Bug Fixes (`fix`)
4. 🔒 Security (`fix` with scope containing `security`, or commits mentioning security/PII/auth)
5. ♻️ Refactors (`refactor`)
6. 📝 Documentation (`docs`)
7. 🧪 Tests (`test`)
8. 🔧 Chores (`chore`)
9. ⚡ Performance (`perf`)

**Secondary grouping: by SCOPE** within each type
```
🚀 Features
  chat: Add web search toggle (VISAL-38)
  chat: Chain-of-thought reasoning (VISAL-61)
  drafts: Exhibit list improvements
  integrations: Provider import UX
```

### Step 5: Format Output

**Markdown format (default — for GitHub, Notion, engineering-notes):**

```markdown
# Changelog: `base` → `head`
_Generated: 2026-03-24 | Commits: 25 | Authors: 4_

## 🚀 Features (8)

### chat
- Add web search toggle (VISAL-38) — @bernarduriza-visalaw
- Chain-of-thought reasoning with backend streaming (VISAL-61) — @bernarduriza-visalaw

### drafts
- Exhibit list generation improvements — @BhaktiGhaghda

### integrations
- Translation fixes, modal overflow, provider import UX — @rkatkam1

## 🐛 Bug Fixes (5)

### security
- Remove Intercom secret from client bundle (VISAL-121) — @kharrison1117
- Add recursive PII scrubbing in Sentry beforeSend (VISAL-125) — @kharrison1117

### translate
- Stop Translate flow from crashing with max update depth — @axelgomez-ops

## ♻️ Refactors (2)
- Decompose chat-sse god-method into pipeline modules — @bernarduriza-visalaw

---
_4 authors: bernarduriza-visalaw (12), kharrison1117 (6), axelgomez-ops (4), rkatkam1 (3)_
```

**Slack mrkdwn format (for #temp-core2-UAT, #plane-updates):**

IMPORTANT: Slack uses mrkdwn NOT markdown.
- Bold: `*text*` (single asterisk, NOT double)
- Links: `<url|text>` (NOT `[text](url)`)
- No tables — use bullet lists
- No headers with `#` — use `*bold text*` + emoji

```
📋 *Changelog: `base` → `head`*
_25 commits | 4 authors | 2026-03-24_

🚀 *Features (8)*
• *chat:* Add web search toggle (VISAL-38)
• *chat:* Chain-of-thought reasoning (VISAL-61)
• *drafts:* Exhibit list improvements
• *integrations:* Translation fixes + provider UX

🐛 *Bug Fixes (5)*
• *security:* Remove Intercom secret (VISAL-121)
• *security:* PII scrubbing in Sentry (VISAL-125)
• *translate:* Fix max update depth crash

♻️ *Refactors (2)*
• Decompose chat-sse god-method

_Authors: bernarduriza-visalaw (12), kharrison1117 (6), axelgomez-ops (4), rkatkam1 (3)_
```

### Step 6: Output & Delivery

1. Print the formatted changelog to the conversation
2. If `--both` flag: print both markdown and Slack formats
3. If `--save` flag: write to `engineering-notes/changelogs/{date}-{base}-to-{head}.md`

Then use `AskUserQuestion` for delivery:

```
AskUserQuestion:
  question: "Changelog ready. Where should it go?"
  header: "Deliver"
  multiSelect: true
  options:
    - label: "Post to Slack channel"
      description: "I'll draft the message — you pick the channel (#temp-core2-UAT, #plane-updates, etc.)"
    - label: "Save to engineering-notes"
      description: "Write to engineering-notes/changelogs/{date}-{base}-to-{head}.md and push"
    - label: "Add to PR description"
      description: "Append the changelog to an open PR body — I'll ask which PR"
    - label: "Just show me, done"
      description: "Already printed above — no further action needed"
```

## Rules

- NEVER fabricate commits — only show what `git log` or `gh api` returns
- Always show commit count and author stats
- VISAL-XXX references should link to Plane (`https://app.plane.so/visalaw-ai/browse/VISAL-XXX/`) when in markdown format
- Deduplicate: if a commit appears in multiple scopes, show it once in the most specific scope
- Skip merge commits (`--no-merges`)
- If a scope filter is applied, only show commits matching those scopes
- Date filter uses `--since` flag on git log
- For `--repo` flag, clone is NOT needed — use GitHub compare API
- Language: output in English (repo content rule), conversation in Spanish
