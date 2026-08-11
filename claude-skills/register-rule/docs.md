# Registering shared documentation or technical findings

For meeting transcripts, technical analysis, audit results, scripts and team decisions that
the TEAM must be able to read. Signals: transcript text, audit data, "the team should know",
analysis with data, a script that solves a specific problem.

Not this path if it describes a behavior the agent should follow ([rules.md](rules.md)), if
it contains a credential ([secrets.md](secrets.md)), or if it is a fact only the agent needs
([memory.md](memory.md)).

## Where it goes in `engineering-notes/`

| Content | Destination |
|---|---|
| Meeting transcript, huddle notes, call summary | `weekly/` or `workflow/` |
| Migration script, cleanup script, one-off tool | `audits/<topic>/` |
| Audit results, CSV data, validation output | `audits/<topic>/` |
| Architecture decision, design proposal | `proposals/` |
| Benchmark results, performance comparison | `benchmarks/` |
| Incident postmortem, RCA | `audits/` |
| Checklist, test plan, launch criteria | `checklists/` |

## Procedure

1. **Extract the key information.** For meetings: decisions, action items, owners,
   deadlines, unresolved questions. For audits: findings, data, recommendations, execution
   plan. For proposals: problem, proposed solution, trade-offs, timeline.
2. **Write it in English** — every doc gets a `README.md` with clear sections, plus date,
   owner and context. For scripts, include the script file and a README explaining it.
3. **Commit and push immediately** — `engineering-notes` is a shared repo, and per
   git-safety a shared-repo change is not done until it is pushed:
   ```bash
   git -C engineering-notes add <files>
   git -C engineering-notes commit -m "docs(<folder>): <short description>"
   git -C engineering-notes push origin main
   ```
4. **Report the GitHub URL** so it can be shared:
   `https://github.com/<ORG>/engineering-notes/blob/main/<path>`

## Rules

- **Never dump a raw transcript** — extract and structure it.
- Every new folder gets a `README.md` explaining the context.
- Convert relative dates to absolute: "next Friday" → `2026-04-10`.
- Tag owners — every action item needs a name.
- Link the Plane issue where applicable, with its full URL, not a bare `<PROJ>-XXX`.
- **Check the audience can open it.** `engineering-notes` is an engineering surface. If the
  reader is Sales, CS, Legal or an exec, they have no GitHub access and the link is a
  locked door — republish through `/mermaid-export`, a Slack canvas, or inline in the
  message.

## Why this path exists

On 2026-04-02 a 68K-chunk Pinecone migration script was shared as a Slack attachment and a
330KB audit CSV previewed as 9 rows, causing a false alarm. The team agreed: technical
artifacts live in `engineering-notes`, not in Slack.
