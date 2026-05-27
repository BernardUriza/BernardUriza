# Register Custom Rule

This command handles TWO types of input — detect which one automatically:

## Type 1: Rules & Guidelines

When the user provides a new rule or guideline for working with this codebase:

1. Extract the rule content from the user's message
2. Determine the appropriate rule file in `.claude/rules/` based on the rule's domain (e.g., `testing.md`, `security.md`, `git.md`)
3. If the rule fits an existing file, append or update it
4. If the rule is entirely new category, create a new file following the naming convention
5. Update the index section in `CLAUDE.md` if a new category is added
6. Never create duplicate rules across files — consolidate related rules in the appropriate location

**Language**: All rules must be written in English, regardless of the input language.

**File patterns & saving rules**: When creating or updating rule files under `.claude/rules/`, follow the repository's existing conventions:

- Use lowercase, descriptive filenames with a `.md` extension (e.g., `testing.md`, `security.md`).
- Place the file in the `.claude/rules/` directory.
- If updating an existing file, append new content under a clear header and keep the file organized by sections; preserve existing formatting and style.
- If creating a new category, add the new filename and a one-line description to the index section in `CLAUDE.md`.
- Avoid duplicate or overlapping rules: check existing files for related content before adding new rules.
- Keep all rule text in English and match the tone and structure used across other `.claude/rules/*.md` files.

Follow these patterns to maintain consistency across the codebase and make rules discoverable by other contributors.

## Type 2: Secrets, Tokens, Passwords & Credentials

When the user provides a token, password, API key, or any credential:

**NEVER** write secrets to:
- `.claude/rules/` (committed to repo)
- `.claude/` anything (committed to repo)
- Memory files
- Any file inside the repo

**ALWAYS** write secrets to `~/.secrets/` (outside all repos):

1. Detect the secret type from context (API token, password, OAuth key, etc.)
2. Determine a descriptive filename: `~/.secrets/<service>-<purpose>.txt`
3. Write the secret to that file with metadata:
   ```
   <Service> <purpose> token
   Created: <date>
   Scope: <read-only, org:ci, etc. — if known>

   <KEY_NAME>=<value>
   ```
4. Update the secrets map in `.claude/rules/security.md` (the table under "Local Secrets Map")
5. If the secret is for an MCP server, offer to configure it in `~/.claude.json`

### Detection patterns (auto-detect, don't ask):

| Pattern | Type | Example |
|---------|------|---------|
| `sntrys_*`, `sntryu_*` | Sentry token | `~/.secrets/sentry-<purpose>.txt` |
| `ghp_*`, `github_pat_*` | GitHub PAT | `~/.secrets/github-<purpose>.txt` |
| `sk-*`, `sk-proj-*` | OpenAI key | `~/.secrets/openai-<purpose>.txt` |
| `xoxb-*`, `xoxp-*` | Slack token | `~/.secrets/slack-<purpose>.txt` |
| `eyJ*` (base64 JWT) | JWT / auth token | `~/.secrets/<service>-token.txt` |
| Contains `@` + password context | Login credentials | `~/.secrets/<service>-login.txt` |
| `PLANE_PAT=*` | Plane personal API key | `~/.secrets/plane_pat.txt` |
| Any string the user explicitly calls a token/key/password/secret | Generic secret | `~/.secrets/<context>.txt` |

### How to distinguish Type 1 vs Type 2:

- If the input contains a token pattern (above) or the user says "token", "key", "password", "secret", "credential" → **Type 2**
- If the input describes a behavior, convention, or workflow rule → **Type 1**
- If ambiguous, ask: "Is this a secret/credential to store securely, or a rule for the codebase?"

## Type 3: Documentation & Technical Findings

When the user provides meeting transcripts, technical analysis, audit results, or team decisions that should be shared:

### Detection patterns (auto-detect, don't ask):

| Pattern | Destination | Example |
|---------|-------------|---------|
| Meeting transcript, huddle notes, call summary | `engineering-notes/weekly/` or `engineering-notes/workflow/` | Sprint decisions, feature discussions |
| Migration script, cleanup script, one-off tool | `engineering-notes/audits/<topic>/` | `audits/jdsupra-pinecone-migration/` |
| Audit results, CSV data, validation output | `engineering-notes/audits/<topic>/` | Chunk audit, parity check |
| Architecture decision, design proposal | `engineering-notes/proposals/` | New feature design, decomposition plan |
| Benchmark results, performance comparison | `engineering-notes/benchmarks/` | LLM latency, build times |
| Incident postmortem, RCA | `engineering-notes/audits/` | Root cause analysis with timeline |
| Checklist, test plan, launch criteria | `engineering-notes/checklists/` | UAT plan, go/no-go criteria |

### How to distinguish from Type 1 and Type 2:

- If the input describes a **behavior Claude should follow** → Type 1 (rule)
- If the input contains a **token/key/password** → Type 2 (secret)
- If the input is **knowledge the team should have** (findings, decisions, analysis, scripts, meeting notes) → **Type 3 (documentation)**
- Key signals for Type 3: meeting transcript text, audit data, "the team should know", analysis with data, scripts that solve a specific problem

### Procedure:

1. **Extract key information** from the input:
   - For meetings: decisions made, action items, owners, deadlines, unresolved questions
   - For audits: findings, data, recommendations, execution plan
   - For proposals: problem statement, proposed solution, trade-offs, timeline

2. **Determine the correct folder** in `engineering-notes/` based on the detection table above

3. **Write the documentation** in English (language rule applies):
   - Every doc gets a `README.md` with clear sections
   - Include date, owner, and context
   - For scripts: include the script file + README explaining it
   - For meeting notes: extract structured notes, not raw transcript

4. **Commit + push immediately** — engineering-notes is a shared repo:
   ```bash
   cd engineering-notes
   git add <files>
   git commit -m "docs(<folder>): <short description>"
   git push origin main
   ```

5. **Report the GitHub URL** so it can be shared in Slack:
   ```
   https://github.com/Visalaw/engineering-notes/blob/main/<path>
   ```

### Rules for Type 3:

- **Never dump raw transcripts** — always extract and structure the information
- **Always include a README.md** in new folders explaining the context
- **Convert relative dates to absolute** — "next Friday" → "2026-04-10"
- **Tag owners** — every action item needs a name
- **Link to Plane issues** where applicable — `VISAL-XXX`

### Why This Type Exists

On 2026-04-02, Ram shared a 68K-chunk Pinecone migration script as a Slack attachment. The 330KB audit CSV previewed as 9 rows in Slack, causing a false alarm. Bernard and Ram agreed: all technical artifacts go in `engineering-notes/`, not Slack. This type automates that workflow — when someone shares findings or scripts in conversation, `/register-rule` detects it and writes it to the right place in engineering-notes.

## After registering a rule (Type 1 only)

If the rule was written to a **shared** file (one that also exists in `.github-org/ai-rules/rules/shared/`), offer to sync:

Shared files: `security.md`, `multi-tenancy.md`, `data-privacy.md`, `code-quality.md`, `styling.md`, `git.md`, `language.md`, `data-ref.md`, `issue-workflow.md`

Ask: "This rule is in a shared file. Run `/sync-rules` to push it to the AI reviewer?"
- If yes → invoke `/sync-rules`
- If no → remind: "Run `/sync-rules` later to keep the AI reviewer in sync."
