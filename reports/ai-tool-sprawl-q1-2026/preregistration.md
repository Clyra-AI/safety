# AI Tool Sprawl Q1 2026 Pre-Registration

Status: draft lock candidate  
Version: `v1`

## Study Identity

- Report ID: `ai-tool-sprawl-q1-2026`
- Planned run ID: `TBD`
- Planned publication window: `TBD`
- Target list source: `internal/repos.md`

## Locked Hypotheses

1. The sample will contain a measurable unapproved-to-approved AI tool gap.
2. A non-trivial fraction of organizations will show inventory/transparency evidence gaps.
3. Deterministic baseline and enrich outputs will diverge and must remain explicitly separated in reporting.

## Primary and Secondary Endpoints

- Primary endpoint:
  - `sprawl_unapproved_to_approved_ratio`
  - Denominator: aggregate approved tool count
- Secondary endpoints:
  - `sprawl_avg_unknown_tools_per_org`
  - `sprawl_article50_gap_prevalence_pct`
  - `sprawl_orgs_scanned`

## Sampling and Exclusion Plan

- Scan frame: repositories/organizations listed in `internal/repos.md`
- Inclusion unit: one entry per `owner/repo`
- Exclusions:
  - inaccessible targets at scan time
  - malformed targets outside `owner/repo` format
  - enrich-only data from headline baseline claims

## Analysis Plan (Deterministic)

- Claim ledger: `claims/ai-tool-sprawl-q1-2026/claims.json`
- Query engine: `jq`
- Threshold policy: `pipelines/config/publish-thresholds.json`
- Validation commands:
  - `pipelines/sprawl/validate.sh`
  - `pipelines/sprawl/validate.sh --run-id <id> --strict`

## Stop/Go Decision Policy

- Hard gate:
  - required thresholds must pass
  - strict claim/citation/threshold gates must pass
- Advisory gate:
  - recommended headline-strength thresholds should pass
- If hard gate passes and advisory misses:
  - hold unless publication timing requires release with explicit caveat.

## Change Control

- Any change to hypotheses, endpoints, sampling rules, or thresholds requires:
  - version bump in this file
  - change log entry below
  - rerun or explicit invalidation of prior run claims

## Change Log

- `v1`: initial preregistration scaffold.

## Lock Record

- Locked by: `TBD`
- Locked at (UTC): `TBD`
- Notes: `TBD`
