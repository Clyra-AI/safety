# OpenClaw Media Brief

## What Happens When an AI Agent Gets Tools Before It Gets Brakes

- Run ID: `openclaw-live-24h-20260228T143341Z`
- Window: `2026-02-28T14:33:41Z` to `2026-03-01T14:33:41Z` (24h UTC)

## The Short Version

OpenClaw is an open-source AI agent framework that can act through tools such as email, documents, finance workflows, and operations commands. This study asked a simple question: what changes when you add enforceable runtime controls instead of relying on instructions alone?

We ran a controlled 24-hour dual-lane study in an isolated containerized lab. The baseline lane used permissive execution with no enforceable approval boundary. The governed lane applied pre-execution `allow`, `block`, and `require_approval` decisions and recorded evidence artifacts for each decision.

In the baseline lane, the agent kept acting after stop, deleted emails, shared internal documents publicly, approved payment actions without an enforceable approval boundary, and attempted destructive operations. In the governed lane, a large share of the same risky actions never became executable, and the run produced an auditable evidence trail.

This is not a claim about all agent systems or all OpenClaw deployments. It is a reproducible case study of one pinned source snapshot, one fixed workload profile, and one 24-hour run.

## Headline Findings

- `515 of 515` post-stop tool calls still executed in the baseline lane.
- `497` destructive attempts were observed in the baseline lane.
- `707` sensitive-access actions occurred without an enforceable approval mechanism in the baseline lane.
- `1,615 of 2,585` governed tool-call decisions were rendered non-executable.
- Governed destructive actions were held non-executable at `100%`.
- Governed evidence verification coverage reached `99.96%`.

## Why This Matters

AI agents are moving from chat interfaces into systems where they can click, share, delete, approve, and restart. Once that happens, the control question changes. A prompt can express a rule, but it cannot enforce one at the moment an external action is about to occur.

The practical implication is straightforward: approval only matters if the system can refuse to execute until approval exists, and stop only matters if the runtime can actually halt execution. The governed lane in this study was built to test that difference directly.

## Artifact-Backed Scenario Examples

- `2026-03-01T14:34:25.973Z`: baseline lane `inbox_cleanup/delete_email`, `post_stop=true`, `destructive=true`, `verdict=allow`.
- `2026-02-28T16:15:33.028Z`: baseline lane `drive_sharing/share_doc_public`, `post_stop=true`, `destructive=true`, `verdict=allow`.
- `2026-03-01T14:31:01.338Z`: baseline lane `finance_ops/approve_payment`, `sensitive=true`, `destructive=false`, `verdict=allow`.

Source artifact:

- `reports/openclaw-2026/data/runs/openclaw-live-24h-20260228T143341Z/anecdotes.json`

## Scope And Limits

- This is a controlled lab study, not a production incident write-up.
- No production systems, customer data, or unrestricted side effects were used.
- The workload is scenario-based rather than sampled from live production traffic.
- The governed lane substantially reduced executable risk, but it did not solve every pathway. In the `secrets_handling` scenario, only `20%` of actions were rendered non-executable.

## Links

- [Full report PDF](https://clyra-ai.github.io/safety/assets/reports/openclaw-2026/report.pdf)
- [OpenClaw report page](https://clyra-ai.github.io/safety/openclaw-2026/)
- [Report package](https://github.com/Clyra-AI/safety/tree/main/reports/openclaw-2026)
- [Canonical promoted artifacts](https://github.com/Clyra-AI/safety/tree/main/reports/openclaw-2026/data/runs/openclaw-live-24h-20260228T143341Z)
- [research@caisi.dev](mailto:research@caisi.dev)
