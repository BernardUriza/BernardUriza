# /aws-checkpoint - Infrastructure Health Snapshot

ARGUMENTS: $ARGUMENTS

## Instructions

Run an AWS infrastructure health check and append the results to `.claude/reference/infra-checkpoints.md`.

### Phase 0: Ask Scope

If `$ARGUMENTS` is empty or just a trigger word (e.g., "routine", "check"), use `AskUserQuestion` to determine scope:

```
AskUserQuestion:
  question: "What infrastructure scope should I check?"
  header: "Scope"
  options:
    - label: "Staging only (Recommended)"
      description: "backend-v2-service in Visalawgen_staging — fast, ~30s"
    - label: "Production only"
      description: "visalawgen_production cluster — use when prod issues are suspected"
    - label: "Both (staging + prod)"
      description: "Full sweep — compare both environments side by side"
    - label: "Custom cluster/service"
      description: "I'll specify the cluster and service name in Other"
```

If `$ARGUMENTS` explicitly contains "prod", "staging", or "both", skip this question and use the specified scope.

### Phase 1: Collect Data (all in parallel)

Run ALL of these simultaneously:

1. **ECS Health** — `mcp__awslabs-ecs__ecs_resource_management` with `DescribeServices` for `backend-v2-service` in cluster `Visalawgen_staging`
2. **Error Count by Type** — CloudWatch Log Insights on `/ecs/visalaw-v2-stag` for the last 2 hours:
   ```
   fields @timestamp, @message
   | filter level = "error"
   | parse @message '"msg":*,' as errorMsg
   | stats count(*) as total by errorMsg
   | sort total desc
   | limit 10
   ```
3. **Error Rate by Period** — CloudWatch Log Insights for the last 2 hours:
   ```
   fields @timestamp, @message
   | filter level = "error"
   | stats count(*) as total by bin(30m) as period
   | sort period desc
   | limit 4
   ```
4. **SSE Slow Endpoints** — CloudWatch Log Insights for the last 2 hours:
   ```
   fields @timestamp, @message
   | filter @message like /Slow endpoint.*chat-sse/
   | sort @timestamp desc
   | limit 5
   ```
5. **ALB Timeout** — via AWS CLI:
   ```bash
   aws elbv2 describe-load-balancer-attributes \
     --load-balancer-arn "arn:aws:elasticloadbalancing:us-east-1:841579876861:loadbalancer/app/visalaw-v2-stag-alb/c7569ef530a86cb6" \
     --region us-east-1 \
     --query 'Attributes[?Key==`idle_timeout.timeout_seconds`].Value' --output text
   ```

If $ARGUMENTS contains "prod" or "production", ALSO check:
- `visalawgenproductionelb` ALB timeout
- `/ecs/visalawgen_production` log group with the same queries

### Phase 2: Format Checkpoint

Build a checkpoint entry using this exact template:

```
## Checkpoint #N — YYYY-MM-DD HH:MM UTC (HH:MM AM/PM CDT)

**Trigger:** [use $ARGUMENTS if provided, otherwise "routine check"]

### ECS: backend-v2-service
- Status: [status] | Desired: [n] | Running: [n] | Pending: [n]
- Task Def: `visalaw-v2-stag-taskdef:[revision]`
- Deploy: [rolloutState] | Steady state: [timestamp]
- Failed tasks: [n]

### ALB: visalaw-v2-stag-alb
- Idle timeout: [N]s

### CloudWatch Errors (last 2h)
- **Total: N errors** across M records

| Error | Count | Notes |
|-------|-------|-------|
| [top errors from query] | | [flag NEW if not seen in previous checkpoint] |

### SSE Performance
- Slow endpoint warnings: [N]
- Max duration: [N]ms
- Assessment: [one sentence]

### Verdict: [STABLE / DEGRADED / DOWN] [+ one-liner summary]
```

### Phase 3: Compare with Previous

Read `.claude/reference/infra-checkpoints.md` and compare:
- Task def revision changed? → note deploy
- New error types? → flag as **NEW**
- Error counts up/down? → note trend
- SSE improving or degrading? → note trend

### Phase 4: Write

Prepend the new checkpoint at the top of `.claude/reference/infra-checkpoints.md` (after the header, before the previous checkpoint).

### Phase 5: Report

Output exactly 2 lines (Ockham style):

> **[STABLE/DEGRADED/DOWN]** — Task def :[revision], [N] errors/2h, [N] SSE slow. [one key observation].
> Checkpoint #[N] saved to `infra-checkpoints.md`.

### Phase 6: Next Action

If the verdict is **DEGRADED** or **DOWN**, use `AskUserQuestion`:

```
AskUserQuestion:
  question: "Infrastructure is degraded. What do you want to do?"
  header: "Action"
  options:
    - label: "Investigate top errors (Recommended)"
      description: "Drill into CloudWatch logs for the top error patterns — find root cause"
    - label: "Check ECS task events"
      description: "Pull recent ECS events and task stop reasons to find deployment issues"
    - label: "Share on Slack"
      description: "Post the checkpoint summary to #temp-core2-UAT or #plane-updates"
    - label: "Done for now"
      description: "Just save the checkpoint, I'll investigate manually"
```

If the verdict is **STABLE**, skip this question — the 2-line summary is enough.

## Rules

- **ALL data from AWS MCPs** — never guess, never use cached data from previous checks
- **Parallel queries** — launch ECS + all CloudWatch queries + ALB check simultaneously
- **Compare with previous** — every checkpoint must note what changed since the last one
- **Flag new error patterns** — if an error type appears that wasn't in the previous checkpoint, mark it **NEW**
- **Respond in English** — both the 2-line summary and the checkpoint file content are in English
- **Timestamps in UTC** with CDT conversion in parentheses
- **Never skip the write** — the checkpoint MUST be appended to the file, not just reported
- **Increment checkpoint number** — read the last checkpoint number and add 1
