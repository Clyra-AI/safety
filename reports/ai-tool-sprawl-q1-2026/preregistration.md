# AI Tool Sprawl Q1 2026 Pre-Registration

Status: locked  
Version: `v5`

## Study Identity

- Report ID: `ai-tool-sprawl-q1-2026`
- Calibration run cohort: `internal/repos.md` (AI-native 50 pre-pass)
- Calibration reference run ID: `sprawl-ai50-prepass-20260303T203500Z`
- Calibration tuned reference run ID: `sprawl-ai50-tuned3-clean-20260303T210808Z`
- Planned publication-campaign run ID: `sprawl-live-<timestamp>`
- Planned publication window: `2026-04-01 to 2026-04-30 (target)`
- Target list source: `internal/repos.md`

## Locked Hypotheses

1. The sample will contain a measurable unapproved-to-approved AI tool gap.
2. A non-trivial fraction of organizations will show inventory/transparency evidence gaps.
3. Deterministic baseline and enrich outputs will diverge and must remain explicitly separated in reporting.
4. A measurable share of organizations will expose destructive-capable tooling without enforceable approval gates.
5. Prompt-only controls and missing audit artifacts will be prevalent enough to support board-level governance risk statements.

## Primary and Secondary Endpoints

- Primary endpoint:
  - `sprawl_unapproved_to_approved_ratio`
  - Denominator: aggregate approved tool count
- Secondary endpoints:
  - `sprawl_avg_unknown_tools_per_org`
  - `sprawl_article50_gap_prevalence_pct`
  - `sprawl_orgs_scanned`
  - `sprawl_orgs_with_destructive_tooling_pct`
  - `sprawl_orgs_without_approval_gate_pct`
  - `sprawl_orgs_prompt_only_controls_pct`
  - `sprawl_orgs_without_audit_artifacts_pct`

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
- Calibration gate:
  - detector coverage summary must be generated for the selected cohort
  - non-`source_repo` extraction quality must be reviewed before publication-scale run
  - `sprawl_non_source_recall_exists_pct >= 60.0`
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
- `v2`: adds destructive-capability and control-posture prevalence endpoints/hypotheses.
- `v3`: lock record finalized; preflight execution contract locked pending canonical target list in internal/repos.md.
- `v4`: adds mandatory detector-calibration stage and records AI-native 50 calibration reference run.
- `v5`: adds explicit calibration threshold (`>=60%` recall_exists) and records tuned clean calibration run ID.

## Lock Record

- Locked by: `David Ahmann`
- Locked at (UTC): `2026-02-26T00:00:00Z`
- Notes: `Lock applies to baseline+enrich mechanics, guardrails, and publish gates. Canonical scan targets remain sourced from internal/repos.md before production campaign runs.`
