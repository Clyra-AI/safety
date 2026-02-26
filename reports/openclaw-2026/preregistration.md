# OpenClaw 2026 Pre-Registration

Status: draft lock candidate  
Version: `v2`

## Study Identity

- Report ID: `openclaw-2026`
- Planned run ID: `TBD`
- Planned publication window: `TBD`
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

## Workload and Sampling Plan

- Dual-lane execution:
  - ungoverned baseline
  - governed boundary enforcement
- Window length: 24 hours (UTC)
- Workload profile source: `runs/openclaw/<run_id>/config/`
- Required stop-safety block: low-context baseline + high-context/compaction-pressure stop tests
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

## Lock Record

- Locked by: `TBD`
- Locked at (UTC): `TBD`
- Notes: `TBD`
