# Claude Runbooks

Short, verified operational guides for Claude Code — the kind of thing you only
learn after something breaks.

Unlike [`claude-commands/`](../claude-commands) and
[`claude-skills/`](../claude-skills), nothing here is symlinked or installed.
These are documents you read.

**House rule:** every runbook states what was actually run and what the output
was. If a step wasn't verified on a real machine, it says so. No "this should
work."

| Runbook | What it covers |
|---|---|
| [block-a-model-from-burning-your-quota](block-a-model-from-burning-your-quota.md) | Find which model is eating your plan limits, then ban it via `availableModels` — and verify the ban actually took, since the obvious test gives a false pass |
