# /collect-learnings — Harvest AI Review Knowledge into Learnings Base

Scan recent AI review runs, extract knowledge observations, deduplicate against existing learnings, and let Bernard promote the valuable ones to the policy engine.

ARGUMENTS:

## Instructions

### Phase 0: Ask for Time Range

Use `AskUserQuestion` to ask Bernard what range to scan:

```
AskUserQuestion:
  question: "What time range should I scan for AI review knowledge?"
  header: "Range"
  options:
    - label: "Last 7 days (Recommended)"
      description: "~10-20 runs across both repos"
    - label: "Last 14 days"
      description: "~20-40 runs — deeper sweep"
    - label: "Since last collection"
      description: "Read checkpoint from .github-org/.learnings-checkpoint.json and scan from there"
    - label: "Custom date range"
      description: "I'll provide start/end dates in Other"
```

If "Since last collection": read `C:\Users\buo45\Visalaw\.github-org\.learnings-checkpoint.json` for `last_collected_at` timestamp.

### Phase 1: Fetch Runs from Both Repos

For each repo (`Visalaw/frontend-core-2.0`, `Visalaw/visalaw-gen-backend`):

```bash
gh run list --repo Visalaw/<repo> --workflow=ai-dispatch.yml --limit=50 --json databaseId,status,conclusion,createdAt,displayTitle \
  --jq '[.[] | select(.conclusion == "success" and .createdAt >= "<since-date>")]'
```

Report: "Found N successful review runs in frontend, M in backend."

### Phase 2: Extract Knowledge from Job Summaries

For each successful run, get the Job Summary which contains the `## 🧠 Knowledge Captured` section:

```bash
gh api repos/Visalaw/<repo>/actions/runs/<runId>/jobs --jq '.jobs[] | select(.name | contains("review")) | .id'
```

Then fetch the job's annotations/logs to extract knowledge entries. The knowledge section in the trace follows this format:

```
## 🧠 Knowledge Captured (N)

- **[pattern]** observation text _(confidence: high)_
- **[convention]** observation text _(confidence: medium)_
```

Parse each entry into:
```python
{
    "type": "pattern",        # from the [bracket] tag
    "observation": "...",     # the text after the tag
    "confidence": "high",     # from the parenthetical
    "source_run": 12345,      # GH Actions run ID
    "source_pr": "#237",      # from the run's display title
    "repo": "frontend-core-2.0",
    "date": "2026-03-25"
}
```

If the Job Summary is not accessible via API, try:
```bash
gh run view <runId> --repo Visalaw/<repo> --log 2>/dev/null | grep -A2 "Knowledge Captured"
```

### Phase 3: Load Existing Learnings + Deduplicate

Read both learnings files:
- `C:\Users\buo45\Visalaw\.github-org\learnings\frontend.yml`
- `C:\Users\buo45\Visalaw\.github-org\learnings\backend.yml`

Parse with `yaml.safe_load()` and extract all existing `rule` + `decision_boundary` values.

For each new knowledge observation, check for semantic duplicates:
- Exact substring match against existing `rule` fields
- Key noun overlap (>60% of nouns match) against existing `decision_boundary` fields

Mark each observation as `NEW` or `DUPLICATE (matches FE-XXX)`.

### Phase 4: Present Findings Table

Present all NEW observations in a markdown table:

```markdown
## 🧠 New Knowledge — N observations from M runs

| # | Type | Observation | Confidence | Source PR | Repo |
|---|------|-------------|------------|-----------|------|
| 1 | pattern | Sidebar nav styles are being iteratively... | high | #238 | frontend |
| 2 | convention | Always sanitize file names before S3... | medium | #901 | backend |
| 3 | anti-pattern | useEffect with statusMap causes... | high | #237 | frontend |

**Duplicates skipped:** K observations matched existing learnings.
```

Then ask:

```
AskUserQuestion:
  question: "Which observations should I promote to the learnings base? (enter numbers)"
  header: "Promote"
  options:
    - label: "All of them"
      description: "Promote every NEW observation"
    - label: "None — just reviewing"
      description: "Don't write anything, just show me what's out there"
    - label: "Pick specific ones"
      description: "I'll type the numbers (e.g. 1,3,5) in Other"
```

### Phase 5: Promote Selected to Learnings YAML

For each selected observation:

1. **Determine the target file**: `frontend.yml` or `backend.yml` based on `repo`
2. **Generate the next ID**: Read existing IDs (FE-001, FE-002...), increment to next
3. **Build the YAML entry** — but first, ask Bernard to refine the `decision_boundary`:

Present the raw observation and ask:
```
The AI observed: "[observation]"

I'd write this as:
  rule: "[extracted rule]"
  decision_boundary: "[extracted boundary]"

Does this look right, or do you want to refine it?
```

Use `AskUserQuestion` with the proposed text as preview. Bernard can edit via Other.

4. **Append to YAML file**:
```yaml
  - id: FE-007
    type: pattern
    rule: "..."
    decision_boundary: "..."
    confidence: high
    outcome: untested
    active: true
    added_by: "bernarduriza-visalaw"
    reviewed_by: pending
    date: "2026-03-25"
    source_pr: "frontend-core-2.0#238"
```

5. **Commit + push** to `.github-org`:
```bash
cd .github-org
git add learnings/
git commit -m "chore(learnings): add N entries from AI review harvest"
git push origin main
```

### Phase 6: Write Checkpoint

Write checkpoint to `C:\Users\buo45\Visalaw\.github-org\.learnings-checkpoint.json`:

```json
{
  "last_collected_at": "2026-03-25T19:30:00Z",
  "runs_processed": [12345, 12346, 12347],
  "observations_found": 12,
  "observations_promoted": 3,
  "repos": ["frontend-core-2.0", "visalaw-gen-backend"]
}
```

Commit the checkpoint with the learnings:
```bash
git add .learnings-checkpoint.json
git commit --amend --no-edit
git push origin main --force-with-lease
```

### Phase 7: Report

```
## Collection Complete

- Runs scanned: N (frontend: X, backend: Y)
- Knowledge observations found: M
- Duplicates skipped: K
- Promoted to learnings: P
  - frontend.yml: +A entries (FE-007 through FE-009)
  - backend.yml: +B entries (BE-004 through BE-005)
- Checkpoint saved: 2026-03-25T19:30:00Z
- Next run: /collect-learnings → "Since last collection"
```

## Rules

- **Bernard is the curator** — NEVER auto-promote observations without his explicit approval
- **Deduplicate aggressively** — a duplicate observation is noise, not reinforcement
- **Preserve the YAML schema exactly** — id, type, rule, decision_boundary, confidence, outcome, active, added_by, reviewed_by, date, source_pr
- **IDs are sequential** — FE-001, FE-002... for frontend, BE-001, BE-002... for backend
- **outcome is always `untested`** for new entries — Bernard upgrades to `validated` or `caused_bug` later
- **reviewed_by is always `pending`** — Bernard marks as reviewed later
- **Commit + push is part of the task** — local-only learnings are invisible to the AI reviewer
- **The checkpoint prevents re-processing** — always write it, even if zero observations were promoted
- **If Job Summary API fails**, fall back to log parsing — don't skip runs silently
- **Report full Windows paths** for any files written or modified
