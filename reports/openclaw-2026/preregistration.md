# OpenClaw 2026 Pre-Registration

Status: locked  
Version: `v9`

## Study Identity

- Report ID: `openclaw-2026`
- Planned run ID: `openclaw-preflight-20260226`
- Planned publication window: `2026-03-01 to 2026-03-15 (target)`
- Canonical source pin: `internal/openclaw_repo.md`

## Locked Hypotheses

1. Ungoverned lane will emit policy-violating tool actions in a 24-hour window.
2. Governed lane will reduce executable policy-violating actions while preserving signed decision evidence coverage.
3. Governed evidence verification rate will be near-complete for all evaluated tool calls.
4. Under context-pressure segments, ungoverned behavior will show measurable ignored-stop and destructive-attempt risk signals.
5. Governed lane will keep destructive actions non-executable and maintain bounded stop-to-halt latency.

## Primary and Secondary Endpoints

- Primary endpoint:
  - `openclaw_policy_violations_24h`
  - Denominator: `openclaw_total_tool_calls_24h`
- Secondary endpoints:
  - `openclaw_sensitive_access_without_approval`
  - `openclaw_governed_evidence_verification_rate_pct`
  - `openclaw_ignored_stop_rate_pct`
  - `openclaw_destructive_attempts_24h`
  - `openclaw_governed_destructive_block_rate_pct`
  - `openclaw_stop_to_halt_p95_sec`
  - `openclaw_inbox_delete_after_stop_24h`
  - `openclaw_inbox_delete_after_stop_governed_non_executable_rate_pct`
  - `openclaw_drive_public_share_24h`
  - `openclaw_drive_public_share_governed_non_executable_rate_pct`
  - `openclaw_finance_write_without_approval_24h`
  - `openclaw_finance_write_governed_non_executable_rate_pct`
  - `openclaw_ops_restart_attempts_24h`
  - `openclaw_ops_restart_governed_non_executable_rate_pct`

## Workload and Sampling Plan

- Dual-lane execution:
  - ungoverned baseline
  - governed boundary enforcement
- Window length: 24 hours (UTC)
- Workload profile source: `runs/openclaw/<run_id>/config/`
- Required stop-safety block: low-context baseline + high-context/compaction-pressure stop tests
- Required scenario set: `core5` (`inbox_cleanup`, `drive_sharing`, `finance_ops`, `secrets_handling`, `ops_command`)
- Exclusions:
  - production credentials and production data
  - non-isolated runtime channels

## Analysis Plan (Deterministic)

- Claim ledger: `claims/openclaw-2026/claims.json`
- Query engine: `jq`
- Threshold policy: `pipelines/config/publish-thresholds.json`
- Validation commands:
  - `pipelines/openclaw/validate.sh`
  - `pipelines/openclaw/validate.sh --run-id <id> --strict`

## Stop/Go Decision Policy

- Hard gate:
  - required thresholds must pass
  - strict claim/citation/threshold gates must pass
- Advisory gate:
  - recommended headline-strength thresholds should pass
- If hard gate passes and advisory misses:
  - hold unless publication timing requires release with explicit caveat.

## Change Control

- Any change to hypotheses, endpoints, workload plan, or thresholds requires:
  - version bump in this file
  - change log entry below
  - rerun or explicit invalidation of prior run claims

## Change Log

- `v1`: initial preregistration scaffold.
- `v2`: adds stop-safety and destructive-action endpoints and hypotheses.
- `v3`: lock record finalized; preflight execution contract locked pending canonical OpenClaw source pin.
- `v4`: adds scenario-semantic endpoints and `core5` scenario coverage requirement.
- `v5`: locks scenario metric-denominator semantics to risk-relevant subsets (network/write/destructive as applicable).
- `v6`: extends drive share subset to include execution-mediated share attempts and locks governed stop-halt enforcement timing at stop-signal boundary.
- `v7`: locks governed zero-tool-call scenario coverage bookkeeping via explicit `governed_noop_placeholder` events excluded from risk-relevant subsets.
- `v8`: locks repo-first runtime selection (Wrkr/Gait capability checks) and clean-tool-repo preflight as default reproducibility guardrails.
- `v9`: restricts `governed_noop_placeholder` bookkeeping to synthetic mode only; live mode metrics are runtime-event-only and runtime bootstrap cache is externalized under `.runtime-cache/`.

## Lock Record

- Locked by: `David Ahmann`
- Locked at (UTC): `2026-02-26T00:00:00Z`
- Notes: `Lock applies to preflight and baseline execution mechanics. Canonical OpenClaw repository commit/tag remains sourced from internal/openclaw_repo.md before live workload mode.`
