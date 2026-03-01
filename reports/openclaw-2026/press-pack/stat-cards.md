# OpenClaw Stat Cards Copy

Status: release candidate

## Card 1
- Stat label: Policy-violating outcomes (24h, governed)
- Stat value: `1,615`
- One-sentence context: In the same 24-hour workload, 1,615 governed decisions were non-executable (`block` or `require_approval`).
- Artifact/query reference: `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/governed_summary.json` with `jq '.metrics.blocked_calls + (.counters.require_approval_count // 0)'`

## Card 2
- Stat label: Sensitive accesses without approval (24h, ungoverned)
- Stat value: `707`
- One-sentence context: The ungoverned lane executed 707 sensitive-access actions without an enforceable approval mechanism.
- Artifact/query reference: `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/ungoverned_summary.json` with `jq '.metrics.sensitive_access_without_approval'`

## Card 3
- Stat label: Ignored stop rate (ungoverned)
- Stat value: `100%`
- One-sentence context: Every valid stop signal in the ungoverned lane still resulted in post-stop executable actions.
- Artifact/query reference: `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/ungoverned_summary.json` with `jq '.metrics.ignored_stop_rate_pct'`
- Incident example: `2026-02-28T14:35:13.798Z`, `inbox_cleanup/delete_email`, `post_stop=true`.

## Card 4
- Stat label: Destructive attempts (24h, ungoverned)
- Stat value: `497`
- One-sentence context: Destructive actions were attempted 497 times in the ungoverned lane over the 24-hour window.
- Artifact/query reference: `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/ungoverned_summary.json` with `jq '.metrics.destructive_attempts_24h'`

## Card 5
- Stat label: Governed destructive non-executable rate
- Stat value: `100%`
- One-sentence context: Governed destructive attempts were fully held non-executable in the canonical run.
- Artifact/query reference: `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/governed_summary.json` with `jq '.metrics.destructive_block_rate_pct'`

## Visual Asset
- File: `reports/openclaw-2026/assets/headline-stats/governed_decision_outcomes_24h.png`
- Caption: `Governed decision outcomes in 24h: allow 970, block 1278, require approval 337.`
- Source metrics:
  - `runs/openclaw/openclaw-live-24h-20260228T143341Z/derived/governed_summary.json` (`.counters.allow_count`, `.counters.block_count`, `.counters.require_approval_count`)
